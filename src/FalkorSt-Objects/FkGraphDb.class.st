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
- #runCypher: cypherString - ^ self endpoint graphQuery: self name cypher: cypherString
- #runReadOnlyCypher: cypherString - ^ self endpoint graphRoQuery: self name cypher: cypherString
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
- #nodeAt:propertyAt:put: / #nodeAt:properties: / #nodeAt:mergeProperties: - SET a node's
  property(ies) by id without fetching it first, answering the query's statistics
- #deleteNodeAt: / #deleteNode: - MATCH a node by id (or by an FkGraphNode's id) and DELETE it,
  answering the query's statistics
- #deleteNodesLabeled:havingAll: / #deleteNodesLabeled:where: - bulk-delete nodes matching a
  label plus a property-equality filter or an arbitrary where-clause block, answering the query's
  statistics
- #cypherStringFor: aCyQuery - renders a CyQuery with a FalkorDB-safe delimiter; used by every
  Cypher-building method here and by FkGraphObject's mutating operations

Implementation Points:
- Closing/disconnecting the stick is the caller's responsibility in both cases; I never disconnect
  it myself (matches RsStream - no release/disconnect method is provided).
- Node-CRUD methods mirror SgGraphDb (../SCypherGraph, reference-only), building Cypher with
  SCypher's CyNode/CyQuery/CyCreate/CyMerge/CyReturn, but answer FkGraphNode-wrapped results
  instead of SgGraphDb's #objectFromCypherResult: raw-record wrapping
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
	result := self runCypher: (self cypherStringFor: query).
	^ self firstNodeOrNilFrom: result
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
	result := self runCypher: (self cypherStringFor: query).
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
	result := self runCypher: (self cypherStringFor: query).
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
FkGraphDb >> cypherStringFor: aCyQuery [
	"CyQuery's default delimiter is a bare carriage return, which FalkorDB's Cypher parser
	rejects between clauses - use a space instead."

	aCyQuery delimiter: ' '.
	^ aCyQuery cypherString
]

{ #category : 'querying' }
FkGraphDb >> runCypher: cypherString [
	^ self endpoint graphQuery: self name cypher: cypherString
]

{ #category : 'querying' }
FkGraphDb >> runReadOnlyCypher: cypherString [
	^ self endpoint graphRoQuery: self name cypher: cypherString
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
	result := self runCypher: (self cypherStringFor: query).
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
	result := self runCypher: (self cypherStringFor: query).
	^ self firstNodeOrNilFrom: result
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId mergeProperties: argsDict [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) set: (n addAll: argsDict).
	result := self runCypher: (self cypherStringFor: query).
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId properties: argsDict [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) set: (n to: argsDict).
	result := self runCypher: (self cypherStringFor: query).
	^ result statistics
]

{ #category : 'actions-nodes' }
FkGraphDb >> nodeAt: systemId propertyAt: key put: value [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: systemId) set: { (n @ key) to: value }.
	result := self runCypher: (self cypherStringFor: query).
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
	result := self runCypher: (self cypherStringFor: query).
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
	result := self runCypher: (self cypherStringFor: query).
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
	result := self runCypher: (self cypherStringFor: query).
	^ self nodesFrom: result
]

{ #category : 'private' }
FkGraphDb >> nodesFrom: aFkQueryResult [
	^ aFkQueryResult records collect: [ :record | FkGraphNode on: record first in: self ]
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
