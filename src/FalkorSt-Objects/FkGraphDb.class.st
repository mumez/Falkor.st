"
I am the connection/graph handle for the high-level FalkorDB object API: a named graph reachable
through an FkFalkorStick connection. I mirror RsStream (RediStick-Stream-Objects), which plays the
same role for a Redis stream, holding a stick/settings/name and lazily creating its stick from
settings the first time a connection is needed.

Responsibility:
- Hold a graph name together with the FkFalkorStick connection it is reached through
- Lazily create and connect an FkFalkorStick from FkSettings when none is supplied
- Answer the FkGraphEndpoint (#endpoint) that runs GRAPH.* commands for this graph
- Provide thin #runCypher:/#runReadOnlyCypher: wrappers so callers don't have to route
  through #endpoint and #name themselves

Collaborators:
- FkFalkorStick: the connection I hold or lazily create
- FkGraphEndpoint: answered by #endpoint, the entry point for GRAPH.* commands
- FkSettings: supplies #targetUrl when I lazily create my own stick

Public API and Key Messages:
- FkGraphDb class >> named: - lazily creates and connects a stick from FkSettings default targetUrl
- FkGraphDb class >> on:named: - uses an already-connected stick; graph name is required either way
- #endpoint - self stick endpoint
- #name - the graph name
- #runCypher: cypherQueryOrString - runs a raw Cypher string or a CyQuery (rendered via
  #cypherStringFor: first) as a write query
- #runCypher:arguments: - like #runCypher: but binds a Dictionary of named parameters via
  FkGraphEndpoint's CYPHER-prefix convention, so a whole property map can be passed as one bound
  parameter instead of being inlined into the Cypher string
- #runReadOnlyCypher: cypherQueryOrString - same as #runCypher:, as a read-only query
- #runReadOnlyCypher:arguments: - like #runCypher:arguments:, as a read-only query
- #createNodeLabeled: / #createNodeLabeled:properties: - CREATE a node with the given label(s),
  answering it wrapped as an FkGraphNode
- #mergeNodeLabeled: / #mergeNodeLabeled:properties: - MERGE (create-if-absent) a node with the
  given label(s), answering it wrapped as an FkGraphNode
- #nodeAt: - MATCH a node by its internal id, answering it wrapped as an FkGraphNode, or nil when
  no such node exists
- #nodesLabeled: / #nodesLabeled:havingAll: / #nodesLabeled:where: - MATCH nodes by label(s),
  optionally filtered by property equality or an arbitrary where-clause block, answering a
  collection of FkGraphNode
- #nodesLabeled:where:orderBy:skip:limit: / #nodesLabeled:where:skip:limit: - like
  #nodesLabeled:where: with ORDER BY/SKIP/LIMIT applied
- #nodeAt:propertyAt:put: - SET a single property by id without fetching the node first,
  answering the query's statistics
- #nodeAt:properties: / #nodeAt:mergeProperties: - SET a node's whole property map by id without
  fetching it first, bound as a single #runCypher:arguments: parameter (not inlined into the
  Cypher string), answering the query's statistics
- #deleteNodeAt: / #deleteNode: - MATCH a node by id (or by an FkGraphNode's id) and DELETE it,
  answering the query's statistics
- #deleteNodesLabeled:havingAll: / #deleteNodesLabeled:where: - bulk-delete nodes matching a
  label plus a property-equality filter or an arbitrary where-clause block, answering the query's
  statistics
- #createRelationshipTyped:fromNodeId:toNodeId:properties: / #createInRelationshipTyped:.../
  #createOutRelationshipTyped:... - CREATE a relationship between two existing nodes by id
  (fromNodeId -> toNodeId / toNodeId -> fromNodeId / fromNodeId -> toNodeId respectively -
  FalkorDB's CREATE always needs an explicit direction), answering it wrapped as an
  FkGraphRelationship
- #mergeRelationshipTyped:fromNodeId:toNodeId:properties: / #mergeInRelationshipTyped:.../
  #mergeOutRelationshipTyped:... - MERGE (create-if-absent) the same three directional variants
- #relationshipAt: - MATCH a relationship by its internal id, answering it wrapped as an
  FkGraphRelationship, or nil when no such relationship exists
- #relationshipAt:propertyAt:put: - SET a single property by id without fetching the relationship
  first, answering the query's statistics
- #relationshipAt:properties: / #relationshipAt:mergeProperties: - SET a relationship's whole
  property map by id without fetching it first, bound as a single #runCypher:arguments: parameter,
  answering the query's statistics
- #deleteRelationshipAt: - MATCH a relationship by id and DELETE it, answering the query's
  statistics
- #oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning: -
  MATCH one-hop paths of the given relationship type(s)/direction from a start node id to end nodes
  matching labels/properties, running the query and applying the given returner block to each
  FkGraphPath-wrapped result, answering the collection of returner results
- #cypherStringFor: aCypherQueryOrString - answers a raw Cypher string unchanged, or renders a
  CyQuery with a FalkorDB-safe delimiter; called internally by #runCypher:/#runReadOnlyCypher: so
  callers can pass either a string or a CyQuery straight through

Implementation Points:
- Closing/disconnecting the stick is the caller's responsibility in both cases; I never disconnect
  it myself (matches RsStream - no release/disconnect method is provided).
- Node-CRUD methods mirror SgGraphDb (../SCypherGraph, reference-only), building Cypher with
  SCypher's CyNode/CyQuery/CyCreate/CyMerge/CyReturn, but answer FkGraphNode-wrapped results
  instead of SgGraphDb's #objectFromCypherResult: raw-record wrapping
- Relationship-CRUD methods mirror SgGraphDb's actions-relationships methods the same way, using
  CyRelationship/CyQuery's matchPathWithNodeAt:nodeAt:createIn:/mergeIn: shortcuts, which both
  build a query returning the whole path (as an FkPath) rather than the relationship alone.
- The three merge*RelationshipTyped:... methods use that path result as-is, unwrapping it via
  #firstRelationshipOrNilFrom: to get at the raw FkRelationship before wrapping it as an
  FkGraphRelationship.
- The three create*RelationshipTyped:... methods cannot: FalkorDB's Cypher parser rejects
  'RETURN p' straight after a 'CREATE p = ...' path assignment ('p' not defined), unlike after
  MATCH/MERGE. They swap the query's trailing RETURN p for RETURN r via
  #firstRelationshipFromCreatePathQuery:returning: instead, so FalkorDB answers the raw
  FkRelationship directly with no path involved.
- #createRelationshipTyped:fromNodeId:toNodeId:properties: builds a directed (fromNodeId ->
  toNodeId) pattern rather than SgGraphDb's undirected one: FalkorDB's Cypher parser separately
  rejects an undirected pattern in CREATE ('Only directed relationships are supported in CREATE'),
  unlike Neo4j. There is no undirected CREATE to fall back to, so it is simply an alias for
  #createOutRelationshipTyped:fromNodeId:toNodeId:properties:, kept as its own method for API
  parity with SgGraphDb's three-way naming. MERGE tolerates undirected patterns, so the merge
  counterpart is unaffected.
- #oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning: mirrors
  SgGraphDb's method of the same name, but applies its returner block to the already-wrapped
  FkGraphPath rather than to the raw FkPath before a generic dispatch-based wrap - falkor.st always
  wraps explicitly by class first (see the relationship-CRUD methods above), so the returner can
  pull startNode/endNode/relationships already as FkGraphNode/FkGraphRelationship without any
  further wrapping step.
"
Class {
	#name : 'FkGraphDb',
	#superclass : 'Object',
	#instVars : [
		'stick',
		'settings',
		'name'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphDb class >> named: graphName [
	^ self new
		name: graphName;
		yourself
]

{ #category : 'instance creation' }
FkGraphDb class >> on: aFkFalkorStick named: graphName [
	^ self new
		stick: aFkFalkorStick;
		name: graphName;
		yourself
]

{ #category : 'actions-nodes' }
FkGraphDb >> createNodeLabeled: labelOrLabels [
	^ self createNodeLabeled: labelOrLabels properties: #()
]

{ #category : 'actions-nodes' }
FkGraphDb >> createNodeLabeled: labelOrLabels properties: props [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n labels: (self labelsFor: labelOrLabels) props: props.
	query := CyQuery statements: { CyCreate of: node. CyReturn of: n }.
	result := self runCypher: query.
	^ self firstNodeOrNilFrom: result
]

{ #category : 'actions-relationships' }
FkGraphDb >> createRelationshipTyped: typeOrTypes fromNodeId: startNodeId toNodeId: endNodeId properties: propertiesArray [
	"Unlike SgGraphDb's Neo4j-oriented reference, FalkorDB's Cypher parser rejects an undirected
	pattern in a CREATE clause ('Only directed relationships are supported in CREATE') - MERGE
	tolerates it, but CREATE does not. There is no undirected CREATE to fall back to, so this is
	simply an alias for #createOutRelationshipTyped:fromNodeId:toNodeId:properties: (fromNodeId ->
	toNodeId), kept as its own method for API parity with SgGraphDb's three-way naming."

	^ self
		createOutRelationshipTyped: typeOrTypes
		fromNodeId: startNodeId
		toNodeId: endNodeId
		properties: propertiesArray
]

{ #category : 'actions-relationships' }
FkGraphDb >> createInRelationshipTyped: typeOrTypes fromNodeId: startNodeId toNodeId: endNodeId properties: propertiesArray [
	| r query |
	query := CyQuery
		matchPathWithNodeAt: startNodeId
		nodeAt: endNodeId
		createIn: [ :startNode :endNode :relIdentifier |
			| rel |
			r := relIdentifier.
			rel := relIdentifier rel: typeOrTypes props: propertiesArray.
			startNode <- rel - endNode ].
	^ self firstRelationshipFromCreatePathQuery: query returning: r
]

{ #category : 'actions-relationships' }
FkGraphDb >> createOutRelationshipTyped: typeOrTypes fromNodeId: startNodeId toNodeId: endNodeId properties: propertiesArray [
	| r query |
	query := CyQuery
		matchPathWithNodeAt: startNodeId
		nodeAt: endNodeId
		createIn: [ :startNode :endNode :relIdentifier |
			| rel |
			r := relIdentifier.
			rel := relIdentifier rel: typeOrTypes props: propertiesArray.
			startNode - rel -> endNode ].
	^ self firstRelationshipFromCreatePathQuery: query returning: r
]

{ #category : 'actions-relationships' }
FkGraphDb >> mergeRelationshipTyped: typeOrTypes fromNodeId: startNodeId toNodeId: endNodeId properties: propertiesArray [
	| query result |
	query := CyQuery
		matchPathWithNodeAt: startNodeId
		nodeAt: endNodeId
		mergeIn: [ :startNode :endNode :relIdentifier |
			| rel |
			rel := relIdentifier rel: typeOrTypes props: propertiesArray.
			startNode - rel - endNode ].
	result := self runCypher: query.
	^ self firstRelationshipOrNilFrom: result
]

{ #category : 'actions-relationships' }
FkGraphDb >> mergeInRelationshipTyped: typeOrTypes fromNodeId: startNodeId toNodeId: endNodeId properties: propertiesArray [
	| query result |
	query := CyQuery
		matchPathWithNodeAt: startNodeId
		nodeAt: endNodeId
		mergeIn: [ :startNode :endNode :relIdentifier |
			| rel |
			rel := relIdentifier rel: typeOrTypes props: propertiesArray.
			startNode <- rel - endNode ].
	result := self runCypher: query.
	^ self firstRelationshipOrNilFrom: result
]

{ #category : 'actions-relationships' }
FkGraphDb >> mergeOutRelationshipTyped: typeOrTypes fromNodeId: startNodeId toNodeId: endNodeId properties: propertiesArray [
	| query result |
	query := CyQuery
		matchPathWithNodeAt: startNodeId
		nodeAt: endNodeId
		mergeIn: [ :startNode :endNode :relIdentifier |
			| rel |
			rel := relIdentifier rel: typeOrTypes props: propertiesArray.
			startNode - rel -> endNode ].
	result := self runCypher: query.
	^ self firstRelationshipOrNilFrom: result
]

{ #category : 'actions-relationships' }
FkGraphDb >> deleteRelationshipAt: systemId [
	| s e r rel query result |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	r := 'r' asCypherIdentifier.
	rel := CyRelationship start: s end: e name: r.
	query := CyQuery match: rel where: (r getId equals: systemId) delete: r.
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipAt: systemId [
	| s e r rel query result |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	r := 'r' asCypherIdentifier.
	rel := CyRelationship start: s end: e name: r.
	query := CyQuery match: rel where: (r getId equals: systemId) return: r.
	result := self runCypher: query.
	result records ifEmpty: [ ^ nil ].
	^ FkGraphRelationship on: result records first first in: self
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipAt: systemId mergeProperties: argsDict [
	| s e r rel query result |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	r := 'r' asCypherIdentifier.
	rel := CyRelationship start: s end: e name: r.
	query := CyQuery
		match: rel
		where: (r getId equals: systemId)
		set: (r addAll: 'values' asCypherParameter).
	result := self runCypher: query arguments: (self valuesArgumentsFor: argsDict).
	^ result statistics
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipAt: systemId properties: argsDict [
	| s e r rel query result |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	r := 'r' asCypherIdentifier.
	rel := CyRelationship start: s end: e name: r.
	query := CyQuery
		match: rel
		where: (r getId equals: systemId)
		set: (r to: 'values' asCypherParameter).
	result := self runCypher: query arguments: (self valuesArgumentsFor: argsDict).
	^ result statistics
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipAt: systemId propertyAt: key put: value [
	| s e r rel query result |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	r := 'r' asCypherIdentifier.
	rel := CyRelationship start: s end: e name: r.
	query := CyQuery match: rel where: (r getId equals: systemId) set: { (r @ key) to: value }.
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'actions-paths' }
FkGraphDb >> oneHopPathsTyped: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder returning: returner [
	| pathBlock query result |
	pathBlock := [ :startNode :rel :endNode | startNode - rel - endNode ].
	direction == #in ifTrue: [ pathBlock := [ :startNode :rel :endNode | startNode <- rel - endNode ] ].
	direction == #out ifTrue: [ pathBlock := [ :startNode :rel :endNode | startNode - rel -> endNode ] ].
	query := CyQuery
		matchPathWithRelationshipsOfTypes: typeOrTypes
		havingAll: relProps
		fromNodeAt: startNodeId
		endNodeIn: [ :e | e node: labels props: endNodeProps ]
		pathIn: pathBlock
		whereIn: whereClauseBuilder.
	result := self runCypher: query.
	^ result records collect: [ :record |
		returner value: (FkGraphPath on: record first in: self) ]
]

{ #category : 'private' }
FkGraphDb >> firstRelationshipOrNilFrom: aFkQueryResult [
	| path |
	aFkQueryResult records ifEmpty: [ ^ nil ].
	path := aFkQueryResult records first first.
	^ FkGraphRelationship on: path relationships first in: self
]

{ #category : 'private' }
FkGraphDb >> firstRelationshipFromCreatePathQuery: query returning: r [
	"FalkorDB's Cypher parser rejects 'RETURN p' straight after a CREATE p = ... path assignment
	('p' not defined), unlike after MATCH/MERGE - swap the query's trailing RETURN p (added by
	CyQuery's matchPathWithNodeAt:nodeAt:createIn:) for RETURN r instead, so the raw FkRelationship
	comes back directly and there is no path left to unwrap."

	| result |
	(query statements last isKindOf: CyReturn)
		ifFalse: [ FkGraphDbError invalidQuery signal: 'Expected the query''s trailing statement to be a CyReturn' ].
	query statements removeLast.
	query addReturn: r.
	result := self runCypher: query.
	result records ifEmpty: [ ^ nil ].
	^ FkGraphRelationship on: result records first first in: self
]

{ #category : 'factory' }
FkGraphDb >> createStick [
	| newStick |
	newStick := FkFalkorStick targetUrl: self settings targetUrl.
	newStick beSticky.
	newStick connect.
	^ newStick
]

{ #category : 'accessing' }
FkGraphDb >> endpoint [
	^ self stick endpoint
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNode: aFkGraphNode [
	^ self deleteNodeAt: aFkGraphNode id
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNodeAt: systemId [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) delete: node.
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNodesLabeled: labelOrLabels havingAll: assocArray [
	^ self deleteNodesLabeled: labelOrLabels where: [ :node | node havingAll: assocArray ]
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNodesLabeled: labelOrLabels where: whereClauseBuilder [
	| node query result |
	node := 'n' asCypherIdentifier.
	query := CyQuery
		match: (CyNode name: node labels: (self labelsFor: labelOrLabels))
		where: (whereClauseBuilder value: node)
		delete: node.
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'private' }
FkGraphDb >> firstNodeOrNilFrom: aFkQueryResult [
	aFkQueryResult records ifEmpty: [ ^ nil ].
	^ FkGraphNode on: aFkQueryResult records first first in: self
]

{ #category : 'private' }
FkGraphDb >> labelsFor: labelOrLabels [
	^ labelOrLabels isArray ifTrue: [ labelOrLabels ] ifFalse: [ Array with: labelOrLabels ]
]

{ #category : 'accessing' }
FkGraphDb >> name [
	^ name
]

{ #category : 'private' }
FkGraphDb >> cypherStringFor: aCypherQueryOrString [
	"A raw Cypher string is answered unchanged. A CyQuery's default delimiter is a bare carriage
	return, which FalkorDB's Cypher parser rejects between clauses - render it with a space
	instead."

	aCypherQueryOrString isString ifTrue: [ ^ aCypherQueryOrString ].
	aCypherQueryOrString delimiter: ' '.
	^ aCypherQueryOrString cypherString
]

{ #category : 'querying' }
FkGraphDb >> runCypher: cypherQueryOrString [
	^ self endpoint graphQuery: self name cypher: (self cypherStringFor: cypherQueryOrString)
]

{ #category : 'querying' }
FkGraphDb >> runCypher: cypherQueryOrString arguments: argsDict [
	^ self
		endpoint
		graphQuery: self name
		cypher: (self cypherStringFor: cypherQueryOrString)
		params: argsDict
]

{ #category : 'querying' }
FkGraphDb >> runReadOnlyCypher: cypherQueryOrString [
	^ self endpoint graphRoQuery: self name cypher: (self cypherStringFor: cypherQueryOrString)
]

{ #category : 'querying' }
FkGraphDb >> runReadOnlyCypher: cypherQueryOrString arguments: argsDict [
	^ self
		endpoint
		graphRoQuery: self name
		cypher: (self cypherStringFor: cypherQueryOrString)
		params: argsDict
]

{ #category : 'actions-nodes' }
FkGraphDb >> mergeNodeLabeled: labelOrLabels [
	^ self mergeNodeLabeled: labelOrLabels properties: #()
]

{ #category : 'actions-nodes' }
FkGraphDb >> mergeNodeLabeled: labelOrLabels properties: props [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n labels: (self labelsFor: labelOrLabels) props: props.
	query := CyQuery statements: { CyMerge of: node. CyReturn of: n }.
	result := self runCypher: query.
	^ self firstNodeOrNilFrom: result
]

{ #category : 'private' }
FkGraphDb >> name: anObject [
	name := anObject
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) return: node.
	result := self runCypher: query.
	^ self firstNodeOrNilFrom: result
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId mergeProperties: argsDict [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery
		match: node
		where: (n getId equals: systemId)
		set: (n addAll: 'values' asCypherParameter).
	result := self runCypher: query arguments: (self valuesArgumentsFor: argsDict).
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId properties: argsDict [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery
		match: node
		where: (n getId equals: systemId)
		set: (n to: 'values' asCypherParameter).
	result := self runCypher: query arguments: (self valuesArgumentsFor: argsDict).
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId propertyAt: key put: value [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) set: { (n @ key) to: value }.
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels [
	^ self nodesLabeled: labelOrLabels havingAll: #()
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels havingAll: assocArray [
	^ self nodesLabeled: labelOrLabels where: [ :node | node havingAll: assocArray ]
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels where: whereClauseBuilder [
	| node query result |
	node := 'n' asCypherIdentifier.
	query := CyQuery
		match: (CyNode name: node labels: (self labelsFor: labelOrLabels))
		where: (whereClauseBuilder value: node)
		return: node.
	result := self runCypher: query.
	^ self nodesFrom: result
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels where: whereClauseBuilder orderBy: orderByClause skip: skip limit: limit [
	| node query result |
	node := 'n' asCypherIdentifier.
	query := CyQuery
		match: (CyNode name: node labels: (self labelsFor: labelOrLabels))
		where: (whereClauseBuilder value: node)
		return: node
		orderBy: orderByClause
		skip: skip
		limit: limit.
	result := self runCypher: query.
	^ self nodesFrom: result
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels where: whereClauseBuilder skip: skip limit: limit [
	| node query result |
	node := 'n' asCypherIdentifier.
	query := CyQuery
		match: (CyNode name: node labels: (self labelsFor: labelOrLabels))
		where: (whereClauseBuilder value: node)
		return: node
		skip: skip
		limit: limit.
	result := self runCypher: query.
	^ self nodesFrom: result
]

{ #category : 'private' }
FkGraphDb >> nodesFrom: aFkQueryResult [
	^ aFkQueryResult records collect: [ :record | FkGraphNode on: record first in: self ]
]

{ #category : 'private' }
FkGraphDb >> valuesArgumentsFor: argsDict [
	^ { 'values' -> argsDict asDictionary } asDictionary
]

{ #category : 'accessing' }
FkGraphDb >> settings [
	^ settings ifNil: [ settings := FkSettings default ]
]

{ #category : 'accessing' }
FkGraphDb >> settings: anObject [
	settings := anObject
]

{ #category : 'accessing' }
FkGraphDb >> stick [
	^ stick ifNil: [ stick := self createStick ]
]

{ #category : 'private' }
FkGraphDb >> stick: anObject [
	stick := anObject
]
