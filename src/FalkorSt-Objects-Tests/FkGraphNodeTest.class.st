"
I test FkGraphNode's delegating read accessors, its propertyAt:put: mutation, and its one-hop
relationship-navigation API (relationships/existence/paths/creation) against a real FalkorDB
instance.

Coverage:
- graph-object-api spec: ""Reading delegates to the wrapped node""
- graph-object-api spec: ""Writing a property updates the graph and refreshes local state""
- graph-object-api spec: ""No local-only mutation""
- graph-object-api spec: ""Mutating a node deleted elsewhere signals a meaningful error""
- graph-object-api spec: ""Fetching one-hop relationships/end nodes in either direction""
- graph-object-api spec: ""Filtering one-hop relationships by relationship/end-node property""
- graph-object-api spec: ""Checking one-hop relationship existence without fetching it""
- graph-object-api spec: ""Fetching one-hop paths in either direction""
- graph-object-api spec: ""Creating/merging an outgoing relationship to another node""
- graph-object-api spec: ""Collecting the distinct relationship types of a node""
"
Class {
	#name : 'FkGraphNodeTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Objects-Tests',
	#package : 'FalkorSt-Objects-Tests'
}

{ #category : 'accessing' }
FkGraphNodeTest >> db [
	^ FkGraphDb on: stick named: self graphName
]

{ #category : 'creating' }
FkGraphNodeTest >> createGraphNode [
	| rawNode |
	rawNode := self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person {name: ''Alice'', age: 30}) RETURN p'.
	^ FkGraphNode on: rawNode records first first in: self db
]

{ #category : 'creating' }
FkGraphNodeTest >> createAliceWithBobAndCarolIn: db [
	| alice bob carol |
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	carol := db createNodeLabeled: 'Person' properties: { 'name' -> 'Carol' }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'since' -> 2020 }.
	db createOutRelationshipTyped: 'LIKES' fromNodeId: carol id toNodeId: alice id properties: #().
	^ { alice. bob. carol }
]

{ #category : 'tests' }
FkGraphNodeTest >> testRelationshipsAnswersAllRelationshipsRegardlessOfDirection [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: alice relationships size equals: 2
]

{ #category : 'tests' }
FkGraphNodeTest >> testRelationshipsTypedFiltersByType [
	| alice knows |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	knows := alice relationshipsTyped: 'KNOWS'.
	self assert: knows size equals: 1.
	self assert: knows first class equals: FkGraphRelationship.
	self assert: knows first type equals: 'KNOWS'
]

{ #category : 'tests' }
FkGraphNodeTest >> testOutRelationshipsTypedAnswersOnlyOutgoingRelationshipsOfType [
	| people alice bob out |
	people := self createAliceWithBobAndCarolIn: self db.
	alice := people first.
	bob := people second.
	out := alice outRelationshipsTyped: 'KNOWS'.
	self assert: out size equals: 1.
	self assert: out first startNodeId equals: alice id.
	self assert: out first endNodeId equals: bob id.
	self assert: (alice outRelationshipsTyped: 'LIKES') isEmpty
]

{ #category : 'tests' }
FkGraphNodeTest >> testInRelationshipsTypedAnswersOnlyIncomingRelationshipsOfType [
	| people alice carol in |
	people := self createAliceWithBobAndCarolIn: self db.
	alice := people first.
	carol := people third.
	in := alice inRelationshipsTyped: 'LIKES'.
	self assert: in size equals: 1.
	self assert: in first startNodeId equals: carol id.
	self assert: in first endNodeId equals: alice id.
	self assert: (alice inRelationshipsTyped: 'KNOWS') isEmpty
]

{ #category : 'tests' }
FkGraphNodeTest >> testRelationshipsTypedHavingKeyValueFiltersByRelationshipProperty [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice relationshipsTyped: 'KNOWS' having: 'since' value: 2020) size equals: 1.
	self assert: (alice relationshipsTyped: 'KNOWS' having: 'since' value: 1999) isEmpty
]

{ #category : 'tests' }
FkGraphNodeTest >> testRelationshipsTypedEndNodeHavingKeyValueFiltersByEndNodeProperty [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice relationshipsTyped: 'KNOWS' endNodeHaving: 'name' value: 'Bob') size equals: 1.
	self assert: (alice relationshipsTyped: 'KNOWS' endNodeHaving: 'name' value: 'Nobody') isEmpty
]

{ #category : 'tests' }
FkGraphNodeTest >> testExistsRelationshipTypedAnswersTrueForExistingTypeAndFalseForMissingType [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice existsRelationshipTyped: 'KNOWS').
	self deny: (alice existsRelationshipTyped: 'MISSING')
]

{ #category : 'tests' }
FkGraphNodeTest >> testExistsOutRelationshipTypedAnswersTrueOnlyForOutgoingType [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice existsOutRelationshipTyped: 'KNOWS').
	self deny: (alice existsOutRelationshipTyped: 'LIKES')
]

{ #category : 'tests' }
FkGraphNodeTest >> testExistsInRelationshipTypedAnswersTrueOnlyForIncomingType [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice existsInRelationshipTyped: 'LIKES').
	self deny: (alice existsInRelationshipTyped: 'KNOWS')
]

{ #category : 'tests' }
FkGraphNodeTest >> testOneHopPathsTypedAnswersPathsWithCorrectEndpoints [
	| people alice bob paths |
	people := self createAliceWithBobAndCarolIn: self db.
	alice := people first.
	bob := people second.
	paths := alice oneHopPathsTyped: 'KNOWS' havingAll: #() endNodeWithLabels: #('Person') havingAll: #().
	self assert: paths size equals: 1.
	self assert: paths first class equals: FkGraphPath.
	self assert: paths first startNode id equals: alice id.
	self assert: paths first endNode id equals: bob id.
	self assert: paths first relationships first type equals: 'KNOWS'
]

{ #category : 'tests' }
FkGraphNodeTest >> testOutOneHopPathsTypedAnswersOutgoingPaths [
	| people alice bob paths |
	people := self createAliceWithBobAndCarolIn: self db.
	alice := people first.
	bob := people second.
	paths := alice outOneHopPathsTyped: 'KNOWS' havingAll: #() endNodeWithLabels: #('Person') havingAll: #().
	self assert: paths size equals: 1.
	self assert: paths first startNode id equals: alice id.
	self assert: paths first endNode id equals: bob id
]

{ #category : 'tests' }
FkGraphNodeTest >> testInOneHopPathsTypedAnswersIncomingPaths [
	| people alice carol paths |
	people := self createAliceWithBobAndCarolIn: self db.
	alice := people first.
	carol := people third.
	paths := alice inOneHopPathsTyped: 'LIKES' havingAll: #() endNodeWithLabels: #('Person') havingAll: #().
	self assert: paths size equals: 1.
	self assert: paths first startNode id equals: alice id.
	self assert: paths first endNode id equals: carol id.
	self assert: paths first relationships first startNodeId equals: carol id.
	self assert: paths first relationships first endNodeId equals: alice id
]

{ #category : 'tests' }
FkGraphNodeTest >> testRelateToTypedCreatesANewRelationshipEachTime [
	| db alice bob |
	db := self db.
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	alice relateTo: bob typed: 'FRIEND'.
	alice relateTo: bob typed: 'FRIEND'.
	self assert: (alice relationshipsTyped: 'FRIEND') size equals: 2
]

{ #category : 'tests' }
FkGraphNodeTest >> testRelateOneToTypedIsIdempotent [
	| db alice bob |
	db := self db.
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	alice relateOneTo: bob typed: 'FRIEND'.
	alice relateOneTo: bob typed: 'FRIEND'.
	self assert: (alice relationshipsTyped: 'FRIEND') size equals: 1
]

{ #category : 'tests' }
FkGraphNodeTest >> testTypesAnswersDistinctRelationshipTypeNames [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: alice types equals: #('KNOWS' 'LIKES') asSet
]

{ #category : 'tests' }
FkGraphNodeTest >> testMutatingANodeDeletedElsewhereSignalsANoSuchObjectError [
	| graphNode |
	graphNode := self createGraphNode.
	self endpoint graphQuery: self graphName cypher: 'MATCH (p) DELETE p'.
	self
		should: [ graphNode propertyAt: 'age' put: 31 ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #NoSuchObject ]
]

{ #category : 'tests' }
FkGraphNodeTest >> testNoLocalOnlyMutation [
	| graphNode originalRawNode |
	graphNode := self createGraphNode.
	originalRawNode := graphNode rawNode.
	graphNode propertyAt: 'age' put: 31.
	self deny: graphNode rawNode == originalRawNode.
	self assert: (originalRawNode properties at: 'age') equals: 30
]

{ #category : 'tests' }
FkGraphNodeTest >> testReadingDelegatesToTheWrappedNode [
	| graphNode |
	graphNode := self createGraphNode.
	self assert: graphNode id equals: graphNode rawNode id.
	self assertCollection: graphNode labels asArray equals: graphNode rawNode labels asArray.
	self assert: graphNode properties equals: graphNode rawNode properties.
	self assert: (graphNode propertyAt: 'name') equals: (graphNode rawNode properties at: 'name')
]

{ #category : 'tests' }
FkGraphNodeTest >> testWritingAPropertyUpdatesTheGraphAndRefreshesLocalState [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode propertyAt: 'age' put: 31.
	self assert: (graphNode propertyAt: 'age') equals: 31.
	self assert: ((self endpoint graphQuery: self graphName cypher: 'MATCH (p) RETURN p.age')
		records first first) equals: 31
]
