"
I am the connection/graph handle for the high-level FalkorDB object API: a named graph reachable
through an FkFalkorStick connection. I mirror RsStream (RediStick-Stream-Objects), which plays the
same role for a Redis stream, holding a stick/settings/name and lazily creating its stick from
settings the first time a connection is needed.

Responsibility:
- Hold a graph name together with the FkFalkorStick connection it is reached through
- Lazily fall back to a default graph name (#defaultName) when none was supplied (e.g. nil passed
  to #named:/#on:named:, or plain #new), mirroring how #stick lazily creates itself
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
- FkGraphDb class >> on:named: - uses an already-connected stick; nil graph name defaults to
  #defaultName ('default')
- #endpoint - self stick endpoint
- #name - the graph name, lazily defaulting to #defaultName ('default') when nil
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
  #nodesLabeled:where: with ORDER BY/SKIP/LIMIT applied; orderByClauseBuilder is a block invoked
  with the same 'n' identifier as whereClauseBuilder
- #nodeAt:propertyAt:put: - SET a single property by id without fetching the node first,
  answering the query's statistics
- #nodeAt:properties: / #nodeAt:mergeProperties: - SET a node's whole property map by id without
  fetching it first, bound as a single #runCypher:arguments: parameter (not inlined into the
  Cypher string), answering the query's statistics
- #deleteNodeAt: / #deleteNode: - MATCH a node by id (or by an FkGraphNode's id) and DELETE it,
  answering the query's statistics; #deleteNodeAt:withRelations: is the same but also detaches the
  node's relationships first when the argument is true (#deleteNodeAt: is an alias with false)
- #deleteNodesLabeled:havingAll: / #deleteNodesLabeled:where: - bulk-delete nodes matching a
  label plus a property-equality filter or an arbitrary where-clause block, answering the query's
  statistics
- #nodesLabeled:having:value: - shortcut for #nodesLabeled:where: with a single property-equality
  filter
- #nodeAt:removePropertyAt: - REMOVE a single property by id without fetching the node first,
  answering the query's statistics
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
- #relationshipAt:removePropertyAt: - REMOVE a single property by id without fetching the
  relationship first, answering the query's statistics
- #deleteRelationshipAt: - MATCH a relationship by id and DELETE it, answering the query's
  statistics
- #relationshipsTyped: / #relationshipsTyped:having:value: / #relationshipsTyped:havingAll: /
  #relationshipsTyped:where: - MATCH relationships of the given type(s) anywhere in the graph,
  optionally filtered by a single property-equality shortcut, property equality across a whole
  assoc array, or an arbitrary where-clause block, answering a collection of FkGraphRelationship
- #relationshipsTyped:where:orderBy:skip:limit: - like #relationshipsTyped:where: with
  ORDER BY/SKIP/LIMIT applied; orderByClauseBuilder is a block invoked with the same 'r' identifier
  as whereClauseBuilder
- #oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning: -
  MATCH one-hop paths of the given relationship type(s)/direction from a start node id to end nodes
  matching labels/properties, running the query and applying the given returner block to each
  FkGraphPath-wrapped result, answering the collection of returner results; a thin wrapper over
  #oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returnIn:returning:
  with returnIn: nil
- #oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returnIn:returning: -
  like the above, but also takes a returnIn: block that controls the shape of the underlying
  Cypher RETURN clause (default nil returns the whole path, aliased 'p'); the block is handed the
  query's CyReturn and may replace its #items to narrow the RETURN to the 's'/'e' (start/end node)
  or 'r' (relationship) Cypher variables instead. When returnIn: is nil the returner block receives
  an FkGraphPath as usual; when returnIn: narrows the RETURN, the record's first value is whatever
  Cypher actually returns, unwrapped, and the returner block is responsible for wrapping it into
  the matching Fk* type itself
- #existsOneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn: - like
  #oneHopPathsTyped:..., but answers a Boolean for whether at least one matching one-hop path
  exists, without building any FkGraphPath wrapper
- #existsOneHopPathsTyped:direction:from:whereIn: - convenience overload of the above with empty
  relationship-property/end-node-label/end-node-property filters
- #cypherStringFor: aCypherQueryOrString - answers a raw Cypher string unchanged, or renders a
  CyQuery with a FalkorDB-safe delimiter; called internally by #runCypher:/#runReadOnlyCypher: so
  callers can pass either a string or a CyQuery straight through
- #allLabels / #allRelationshipTypes - distinct list of every label / relationship type used
  anywhere in the graph, as an Array/OrderedCollection of Strings
- #countNodes / #countNodesLabeled: / #countRelationships / #countRelationshipsTyped: - total
  count of nodes/relationships, optionally filtered by label(s)/type(s)
- #deleteAll / #deleteAllNodes / #deleteAllRelationships - bulk-delete everything in the graph,
  only its nodes (detaching their relationships), or only its relationships, answering the query's
  statistics; #deleteAll is an alias for #deleteAllNodes since FalkorDB's plain DELETE already
  detaches a node's relationships (see Implementation Points)
- #deleteRelationshipsTyped: / #deleteRelationshipsTyped:havingAll: / #deleteRelationshipsTyped:where: -
  bulk-delete relationships of the given type(s) anywhere in the graph, optionally filtered by
  property equality across a whole assoc array or an arbitrary where-clause block, answering the
  query's statistics
- #orphanedNodes - MATCH nodes with no relationships at all, answering a collection of FkGraphNode

Implementation Points:
- Unlike Neo4j, FalkorDB's plain DELETE on a node auto-detaches its relationships instead of
  raising - verified empirically against a real instance. #deleteNodeAt: (and #deleteNodesLabeled:...)
  therefore already remove a connected node's relationships even without DETACH DELETE, and
  #deleteAll is simply an alias for #deleteAllNodes rather than a separate DETACH-DELETE query.
  #deleteNodeAt:withRelations: exists purely for API parity with N4GraphDb; its argument has no
  observable effect on FalkorDB today.
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
- #existsOneHopPathsTyped:... and the returnIn:-taking #oneHopPathsTyped:...returnIn:returning:
  mirror N4GraphDb (../Neo4reSt, reference-only): both delegate their query-building to the
  private #oneHopPathsQueryResultFor:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:
  pathProcessIn:returnIn:, which wraps SCypher's CyQuery class >>
  matchPathWithRelationshipsOfTypes:havingAll:fromNodeAt:endNodeIn:pathIn:whereIn:pathProcessIn:
  returnIn: and runs it - the direction-block selection and query construction live in that one
  place so both callers stay in sync. #existsOneHopPathsTyped:... passes
  pathProcessIn: [:path | path count > 0] and returnIn: [:r | r] so FalkorDB answers a bare
  Boolean as the first (and only) record value. #oneHopPathsTyped:...returnIn:returning: passes
  pathProcessIn: nil and exposes returnIn: to the caller instead, relying on the query builder's
  fixed 's'/'r'/'e'/'p' Cypher variable-naming convention (start node/relationship/end node/whole
  path) for the caller's returnIn: block to target.
- #relationshipsTyped:where:orderBy:skip:limit: mirrors N4GraphDb's method of the same name
  (../Neo4reSt, reference-only): MATCH an anonymous directed pattern (unnamed start/end nodes,
  named relationship 'r'), apply the where-clause block and RETURN r directly (not a whole path),
  then wrap each raw result relationship as an FkGraphRelationship via the private
  #relationshipsFrom: helper - analogous to #nodesFrom: for nodes. Like
  #nodesLabeled:where:orderBy:skip:limit:, orderByClauseBuilder is a block invoked with the same
  'r' identifier as whereClauseBuilder, matching N4GraphDb's convention, so callers never need to
  build their own 'r' asCypherIdentifier for ordering. CyQuery class >>
  match:where:return:orderBy:skip:limit: itself still takes a raw order-by clause expression (e.g.
  built with CyExpression's #asc/#desc), not a block - CyQuery's builder only applies orderBy when
  it is neither nil nor a block, so the block is evaluated here before being passed through.
- #orphanedNodes builds its WHERE clause with CyExpression's #not rather than #exists not: FalkorDB's
  Cypher parser rejects exists() wrapped around an anonymous pattern expression ('Unable to resolve
  filtered alias'), even though NOT applied directly to the bare pattern is accepted - unlike
  Neo4j/SCypherGraph, which use #exists not for this same pattern-existence check.
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
FkGraphDb >> countRelationshipsTyped: typeOrTypes [
	| r rel query result |
	r := 'r' asCypherIdentifier.
	rel := r rel: typeOrTypes props: #().
	query := CyQuery match: ('' asCypherIdentifier asNode - rel -> '' asCypherIdentifier asNode).
	query addReturn: r count.
	result := self runReadOnlyCypher: query.
	^ result oneValueIfNone: [ FkGraphDbError invalidQuery signal: 'Expected a count query to answer one record' ]
]

{ #category : 'actions-relationships' }
FkGraphDb >> deleteRelationshipsTyped: typeOrTypes [
	^ self deleteRelationshipsTyped: typeOrTypes havingAll: #()
]

{ #category : 'actions-relationships' }
FkGraphDb >> deleteRelationshipsTyped: typeOrTypes havingAll: assocArray [
	^ self deleteRelationshipsTyped: typeOrTypes where: [ :r | r havingAll: assocArray ]
]

{ #category : 'actions-relationships' }
FkGraphDb >> deleteRelationshipsTyped: typeOrTypes where: whereClauseBuilder [
	| r rel query result |
	r := 'r' asCypherIdentifier.
	rel := r rel: typeOrTypes props: #().
	query := CyQuery
		match: ('' asCypherIdentifier asNode - rel - '' asCypherIdentifier asNode)
		where: (whereClauseBuilder value: r)
		delete: r.
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipsTyped: typeOrTypes [
	^ self relationshipsTyped: typeOrTypes havingAll: #()
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipsTyped: typeOrTypes having: key value: value [
	^ self relationshipsTyped: typeOrTypes where: [ :r | (r @ key) equals: value ]
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipsTyped: typeOrTypes havingAll: assocArray [
	^ self relationshipsTyped: typeOrTypes where: [ :r | r havingAll: assocArray ]
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipsTyped: typeOrTypes where: whereClauseBuilder [
	^ self relationshipsTyped: typeOrTypes where: whereClauseBuilder orderBy: nil skip: nil limit: nil
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipsTyped: typeOrTypes where: whereClauseBuilder orderBy: orderByClauseBuilder skip: skip limit: limit [
	| r rel query result |
	r := 'r' asCypherIdentifier.
	rel := r rel: typeOrTypes props: #().
	query := CyQuery
		match: ('' asCypherIdentifier asNode - rel -> '' asCypherIdentifier asNode)
		where: (whereClauseBuilder value: r)
		return: r
		orderBy: (orderByClauseBuilder ifNotNil: [ orderByClauseBuilder value: r ])
		skip: skip
		limit: limit.
	result := self runCypher: query.
	^ self relationshipsFrom: result
]

{ #category : 'actions-relationships' }
FkGraphDb >> relationshipAt: systemId removePropertyAt: key [
	| s e r rel query result |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	r := 'r' asCypherIdentifier.
	rel := CyRelationship start: s end: e name: r.
	query := CyQuery match: rel where: (r getId equals: systemId) remove: (r @ key).
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
	^ result oneValueDo: [ :rawRelationship | FkGraphRelationship on: rawRelationship in: self ]
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
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: direction
		from: startNodeId
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: whereClauseBuilder
		returnIn: nil
		returning: returner
]

{ #category : 'actions-paths' }
FkGraphDb >> oneHopPathsTyped: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder returnIn: returnBlock returning: returner [
	"returnBlock controls the shape of the underlying Cypher RETURN clause: it is handed the
	query's CyReturn (default items: the whole path, aliased 'p') and may replace #items to
	narrow the RETURN to the start/end node ('s'/'e') or relationship ('r') Cypher variables
	instead - see the class comment for the full s/r/e/p variable-naming convention. The
	returner block must be written to match whatever returnBlock actually returns: nil (the
	default) returns the whole path, so returner receives an FkGraphPath as usual; a narrowed
	returnBlock changes what the record's first value actually is, and returner must wrap that
	value into the appropriate Fk* type itself."

	| result |
	result := self
		oneHopPathsQueryResultFor: typeOrTypes
		direction: direction
		from: startNodeId
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: whereClauseBuilder
		pathProcessIn: nil
		returnIn: returnBlock.
	returnBlock ifNil: [ ^ result firstColumnValues collect: [ :rawPath | returner value: (FkGraphPath on: rawPath in: self direction: direction) ] ].
	^ result firstColumnValues collect: returner
]

{ #category : 'private' }
FkGraphDb >> oneHopPathsQueryResultFor: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder pathProcessIn: processBlock returnIn: returnBlock [
	| pathBlock query |
	pathBlock := [ :startNode :rel :endNode | startNode - rel - endNode ].
	direction == #in ifTrue: [ pathBlock := [ :startNode :rel :endNode | startNode <- rel - endNode ] ].
	direction == #out ifTrue: [ pathBlock := [ :startNode :rel :endNode | startNode - rel -> endNode ] ].
	query := CyQuery
		matchPathWithRelationshipsOfTypes: typeOrTypes
		havingAll: relProps
		fromNodeAt: startNodeId
		endNodeIn: [ :e | e node: labels props: endNodeProps ]
		pathIn: pathBlock
		whereIn: whereClauseBuilder
		pathProcessIn: processBlock
		returnIn: returnBlock.
	^ self runCypher: query
]

{ #category : 'actions-paths' }
FkGraphDb >> existsOneHopPathsTyped: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder [
	| result |
	result := self
		oneHopPathsQueryResultFor: typeOrTypes
		direction: direction
		from: startNodeId
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: whereClauseBuilder
		pathProcessIn: [ :path | path count > 0 ]
		returnIn: [ :r | r ].
	^ result oneValueIfNone: [ false ]
]

{ #category : 'actions-paths' }
FkGraphDb >> existsOneHopPathsTyped: typeOrTypes direction: direction from: startNodeId whereIn: whereClauseBuilder [
	^ self
		existsOneHopPathsTyped: typeOrTypes
		direction: direction
		from: startNodeId
		havingAll: #()
		endNodeWithLabels: #()
		havingAll: #()
		whereIn: whereClauseBuilder
]

{ #category : 'private' }
FkGraphDb >> firstRelationshipOrNilFrom: aFkQueryResult [
	^ aFkQueryResult oneValueDo: [ :path | FkGraphRelationship on: path relationships first in: self ]
]

{ #category : 'private' }
FkGraphDb >> relationshipsFrom: aFkQueryResult [
	^ aFkQueryResult firstColumnValues collect: [ :rawRelationship | FkGraphRelationship on: rawRelationship in: self ]
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
	^ result oneValueDo: [ :rawRelationship | FkGraphRelationship on: rawRelationship in: self ]
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

{ #category : 'global operations' }
FkGraphDb >> allLabels [
	| n query labels label result |
	n := 'n' asCypherIdentifier.
	query := CyQuery match: n asNode.
	labels := 'labels' asCypherIdentifier.
	(query addWith: (n labels as: labels)) beDistinct.
	label := 'label' asCypherIdentifier.
	query addUnwind: (labels deepCopy as: label).
	(query addReturn: label) beDistinct.
	result := self runReadOnlyCypher: query.
	^ result firstColumnValues
]

{ #category : 'global operations' }
FkGraphDb >> allRelationshipTypes [
	| r query result |
	r := 'r' asCypherIdentifier.
	query := CyQuery match: ('' asCypherIdentifier asNode - r asRelationship - '' asCypherIdentifier asNode).
	(query addReturn: r type) beDistinct.
	result := self runReadOnlyCypher: query.
	^ result firstColumnValues
]

{ #category : 'global operations' }
FkGraphDb >> countNodes [
	^ self countNodesLabeled: #()
]

{ #category : 'global operations' }
FkGraphDb >> countRelationships [
	^ self countRelationshipsTyped: #()
]

{ #category : 'global operations' }
FkGraphDb >> deleteAll [
	"FalkorDB's plain DELETE already detaches a node's relationships (see the class comment's
	Implementation Points), so deleting all nodes already deletes all relationships too."

	^ self deleteAllNodes
]

{ #category : 'global operations' }
FkGraphDb >> deleteAllNodes [
	^ self deleteNodesLabeled: #() havingAll: #()
]

{ #category : 'global operations' }
FkGraphDb >> deleteAllRelationships [
	^ self deleteRelationshipsTyped: #() havingAll: #()
]

{ #category : 'global operations' }
FkGraphDb >> orphanedNodes [
	"FalkorDB's Cypher parser rejects exists() wrapped around an anonymous pattern expression
	('Unable to resolve filtered alias') - NOT applied to the bare pattern works, so #not is used
	here instead of the #exists not spelling that Neo4j/SCypherGraph would use."

	| n query result |
	n := 'n' asCypherIdentifier.
	query := CyQuery
		match: n asNode
		where: (n asNode -- '' asCypherIdentifier asNode) not
		return: n.
	result := self runReadOnlyCypher: query.
	^ self nodesFrom: result
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNode: aFkGraphNode [
	^ self deleteNodeAt: aFkGraphNode id
]

{ #category : 'actions-nodes' }
FkGraphDb >> countNodesLabeled: labelOrLabels [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n labels: (self labelsFor: labelOrLabels).
	query := CyQuery match: node.
	query addReturn: n count.
	result := self runReadOnlyCypher: query.
	^ result oneValueIfNone: [ FkGraphDbError invalidQuery signal: 'Expected a count query to answer one record' ]
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNodeAt: systemId [
	^ self deleteNodeAt: systemId withRelations: false
]

{ #category : 'actions-nodes' }
FkGraphDb >> deleteNodeAt: systemId withRelations: withRelations [
	"withRelations has no observable effect on FalkorDB today - plain DELETE already detaches a
	node's relationships (see the class comment's Implementation Points). Kept for API parity with
	N4GraphDb's deleteNodeAt:withRelations:."

	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery
		match: node
		where: (n getId equals: systemId)
		delete: node
		in: [ :del | del withRelations: withRelations ].
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
	^ aFkQueryResult oneValueDo: [ :rawNode | FkGraphNode on: rawNode in: self ]
]

{ #category : 'private' }
FkGraphDb >> labelsFor: labelOrLabels [
	^ labelOrLabels isArray ifTrue: [ labelOrLabels ] ifFalse: [ Array with: labelOrLabels ]
]

{ #category : 'accessing' }
FkGraphDb >> name [
	^ name ifNil: [ self defaultName ]
]

{ #category : 'private' }
FkGraphDb >> defaultName [
	^ 'default'
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
FkGraphDb >> nodeAt: systemId removePropertyAt: key [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) remove: (n @ key).
	result := self runCypher: query.
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels [
	^ self nodesLabeled: labelOrLabels havingAll: #()
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodesLabeled: labelOrLabels having: key value: value [
	^ self nodesLabeled: labelOrLabels where: [ :node | (node @ key) equals: value ]
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
FkGraphDb >> nodesLabeled: labelOrLabels where: whereClauseBuilder orderBy: orderByClauseBuilder skip: skip limit: limit [
	| node query result |
	node := 'n' asCypherIdentifier.
	query := CyQuery
		match: (CyNode name: node labels: (self labelsFor: labelOrLabels))
		where: (whereClauseBuilder value: node)
		return: node
		orderBy: (orderByClauseBuilder value: node)
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
	^ aFkQueryResult firstColumnValues collect: [ :rawNode | FkGraphNode on: rawNode in: self ]
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
