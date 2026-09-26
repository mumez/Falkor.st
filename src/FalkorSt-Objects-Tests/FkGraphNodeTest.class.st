"
I test FkGraphNode's delegating read accessors, its propertyAt:put: mutation, and its one-hop
relationship-navigation API (relationships/existence/paths/creation) against a real FalkorDB
instance.

Coverage:
- graph-object-api spec: ""Reading delegates to the wrapped node""
- graph-object-api spec: ""Writing a property updates the graph and refreshes local state""
- graph-object-api spec: ""No local-only mutation""
- graph-object-api spec: ""Mutating a node deleted elsewhere signals a meaningful error""
- graph-object-api spec: ""Property access/mutation after local delete signals a meaningful error""
- graph-object-api spec: ""Delete is idempotent""
- graph-object-api spec: ""Fetching one-hop relationships/end nodes in either direction""
- graph-object-api spec: ""Filtering one-hop relationships by relationship/end-node property""
- graph-object-api spec: ""Checking one-hop relationship existence without fetching it""
- graph-object-api spec: ""Fetching one-hop paths in either direction""
- graph-object-api spec: ""Creating/merging an outgoing relationship to another node""
- graph-object-api spec: ""Collecting the distinct relationship types of a node""
- graph-object-api spec: ""Adding/removing labels and re-querying them from the database""
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
FkGraphNodeTest >> testRelationshipsTypedWhereFiltersUsingAnArbitraryWhereClauseBuilder [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice relationshipsTyped: 'KNOWS' where: [ :start :rel :end | (rel @ 'since') equals: 2020 ]) size equals: 1.
	self assert: (alice relationshipsTyped: 'KNOWS' where: [ :start :rel :end | (rel @ 'since') equals: 1999 ]) isEmpty
]

{ #category : 'tests' }
FkGraphNodeTest >> testExistsRelationshipTypedAnswersTrueForExistingTypeAndFalseForMissingType [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice existsRelationshipTyped: 'KNOWS').
	self deny: (alice existsRelationshipTyped: 'MISSING')
]

{ #category : 'tests' }
FkGraphNodeTest >> testExistsRelationshipTypedHavingKeyValueFiltersByRelationshipProperty [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice existsRelationshipTyped: 'KNOWS' having: 'since' value: 2020).
	self deny: (alice existsRelationshipTyped: 'KNOWS' having: 'since' value: 1999)
]

{ #category : 'tests' }
FkGraphNodeTest >> testExistsRelationshipTypedEndNodeHavingKeyValueFiltersByEndNodeProperty [
	| alice |
	alice := (self createAliceWithBobAndCarolIn: self db) first.
	self assert: (alice existsRelationshipTyped: 'KNOWS' endNodeHaving: 'name' value: 'Bob').
	self deny: (alice existsRelationshipTyped: 'KNOWS' endNodeHaving: 'name' value: 'Nobody')
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
FkGraphNodeTest >> testDeleteMarksTheGraphObjectAsDeleted [
	| graphNode |
	graphNode := self createGraphNode.
	self deny: graphNode isDeleted.
	graphNode delete.
	self assert: graphNode isDeleted
]

{ #category : 'tests' }
FkGraphNodeTest >> testPropertyAccessAfterDeleteSignalsAnAlreadyDeletedError [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode delete.
	self
		should: [ graphNode propertyAt: 'name' ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #AlreadyDeleted ].
	self
		should: [ graphNode properties ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #AlreadyDeleted ]
]

{ #category : 'tests' }
FkGraphNodeTest >> testPropertyMutationAfterDeleteSignalsAnAlreadyDeletedError [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode delete.
	self
		should: [ graphNode propertyAt: 'age' put: 31 ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #AlreadyDeleted ].
	self
		should: [ graphNode removePropertyAt: 'age' ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #AlreadyDeleted ]
]

{ #category : 'tests' }
FkGraphNodeTest >> testLabelMutationAfterDeleteSignalsAnAlreadyDeletedError [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode delete.
	self
		should: [ graphNode addLabel: 'Employee' ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #AlreadyDeleted ].
	self
		should: [ graphNode removeLabel: 'Person' ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #AlreadyDeleted ]
]

{ #category : 'tests' }
FkGraphNodeTest >> testDeleteIsIdempotent [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode delete.
	self shouldnt: [ graphNode delete ] raise: Error.
	self assert: graphNode isDeleted
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

{ #category : 'tests' }
FkGraphNodeTest >> testPropertiesReplacesTheWholePropertyMap [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode properties: { 'city' -> 'Berlin' }.
	self assert: graphNode properties equals: { 'city' -> 'Berlin' } asDictionary
]

{ #category : 'tests' }
FkGraphNodeTest >> testMergePropertiesAddsWithoutDroppingExistingKeys [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode mergeProperties: { 'city' -> 'Berlin' }.
	self assert: (graphNode propertyAt: 'name') equals: 'Alice'.
	self assert: (graphNode propertyAt: 'age') equals: 30.
	self assert: (graphNode propertyAt: 'city') equals: 'Berlin'
]

{ #category : 'tests' }
FkGraphNodeTest >> testRemovePropertyAtRemovesOneKey [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode removePropertyAt: 'age'.
	self assert: (graphNode propertyAt: 'age') isNil.
	self assert: (graphNode propertyAt: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphNodeTest >> testDeleteWithRelationsDeletesTheNodeAndItsRelationships [
	| people alice |
	people := self createAliceWithBobAndCarolIn: self db.
	alice := people first.
	alice deleteWithRelations.
	self assert: (self db nodeAt: alice id) isNil.
	self assert: (self db countRelationships) equals: 0.
	self assert: alice isDeleted
]

{ #category : 'tests' }
FkGraphNodeTest >> testAddLabelAddsASingleLabelVisibleViaLabelsAndLabelsFromDb [
	| db person |
	db := self db.
	person := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	person addLabel: 'Employee'.
	self assertCollection: person labels asArray equals: #('Person' 'Employee').
	self assertCollection: person labelsFromDb asArray equals: #('Person' 'Employee')
]

{ #category : 'tests' }
FkGraphNodeTest >> testAddLabelsAddsMultipleLabelsVisibleViaLabelsAndLabelsFromDb [
	| db person |
	db := self db.
	person := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	person addLabels: #('Employee' 'Manager').
	self assertCollection: person labels asArray equals: #('Person' 'Employee' 'Manager').
	self assertCollection: person labelsFromDb asArray equals: #('Person' 'Employee' 'Manager')
]

{ #category : 'tests' }
FkGraphNodeTest >> testRemoveLabelRemovesASingleLabelVisibleViaLabelsAndLabelsFromDb [
	| db person |
	db := self db.
	person := db createNodeLabeled: #('Person' 'Employee') properties: { 'name' -> 'Alice' }.
	person removeLabel: 'Employee'.
	self assertCollection: person labels asArray equals: #('Person').
	self assertCollection: person labelsFromDb asArray equals: #('Person')
]

{ #category : 'tests' }
FkGraphNodeTest >> testRemoveLabelsRemovesMultipleLabelsVisibleViaLabelsAndLabelsFromDb [
	| db person |
	db := self db.
	person := db createNodeLabeled: #('Person' 'Employee' 'Manager') properties: { 'name' -> 'Alice' }.
	person removeLabels: #('Employee' 'Manager').
	self assertCollection: person labels asArray equals: #('Person').
	self assertCollection: person labelsFromDb asArray equals: #('Person')
]

{ #category : 'tests' }
FkGraphNodeTest >> testLabelAnswersTheFirstLabelWhenLabelsExist [
	| db person |
	db := self db.
	person := db createNodeLabeled: #('Person' 'Employee') properties: { 'name' -> 'Alice' }.
	self assert: person label equals: 'Person'
]

{ #category : 'tests' }
FkGraphNodeTest >> testLabelAnswersNilWhenNoLabelsExist [
	| db person |
	db := self db.
	person := db createNodeLabeled: #() properties: { 'name' -> 'Alice' }.
	self assert: person label isNil
]

{ #category : 'tests' }
FkGraphNodeTest >> testLabelsFromDbOnANodeDeletedElsewhereSignalsANoSuchObjectError [
	| graphNode |
	graphNode := self createGraphNode.
	self endpoint graphQuery: self graphName cypher: 'MATCH (p) DELETE p'.
	self
		should: [ graphNode labelsFromDb ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #NoSuchObject ]
]

{ #category : 'tests' }
FkGraphNodeTest >> testLabelsFromDbAnswersEmptyCollectionWhenNoLabelsExist [
	| db person |
	db := self db.
	person := db createNodeLabeled: #() properties: { 'name' -> 'Alice' }.
	self assert: person labelsFromDb isNotNil.
	self assert: person labelsFromDb isEmpty
]

{ #category : 'tests' }
FkGraphNodeTest >> testEqualityAnswersTrueForTwoWrappersAroundTheSameNode [
	| db created firstWrapper secondWrapper |
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	firstWrapper := db nodeAt: created id.
	secondWrapper := db nodeAt: created id.
	self assert: firstWrapper = secondWrapper.
	self assert: firstWrapper hash equals: secondWrapper hash
]

{ #category : 'tests' }
FkGraphNodeTest >> testEqualityAnswersFalseForWrappersAroundDifferentNodes [
	| db alice bob |
	db := self db.
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	self deny: alice = bob
]

{ #category : 'tests' }
FkGraphNodeTest >> testAtAndPropertyAtAnswerTheSameValue [
	| graphNode |
	graphNode := self createGraphNode.
	self assert: (graphNode @ 'name') equals: (graphNode propertyAt: 'name').
	self assert: (graphNode at: 'name') equals: (graphNode propertyAt: 'name')
]

{ #category : 'tests' }
FkGraphNodeTest >> testAtPutBehavesLikePropertyAtPut [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode at: 'age' put: 31.
	self assert: (graphNode propertyAt: 'age') equals: 31.
	self assert: ((self endpoint graphQuery: self graphName cypher: 'MATCH (p) RETURN p.age')
		records first first) equals: 31
]

{ #category : 'tests' }
FkGraphNodeTest >> testNameAnswersTheNamePropertyValue [
	| graphNode |
	graphNode := self createGraphNode.
	self assert: graphNode name equals: (graphNode propertyAt: 'name')
]

{ #category : 'tests' }
FkGraphNodeTest >> testNameColonUpdatesTheNamePropertyValue [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode name: 'NewName'.
	self assert: graphNode name equals: 'NewName'.
	self assert: (graphNode propertyAt: 'name') equals: 'NewName'
]
