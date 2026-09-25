"
I test FkGraphDb's two constructors, its #endpoint accessor, and its node-CRUD and
relationship-CRUD convenience API against a real FalkorDB instance.

Coverage:
- graph-object-api spec: ""Creating a handle that owns its connection""
- graph-object-api spec: ""Creating a handle over an existing connection""
- graph-object-api spec: ""Graph name is required""
- graph-object-api spec: ""Graph name defaults when nil/unset""
- graph-object-api spec: ""Exposing the low-level endpoint""
- graph-object-api spec: ""Running raw Cypher through the handle""
- graph-object-api spec: ""Creating and merging nodes""
- graph-object-api spec: ""Finding nodes by id or label""
- graph-object-api spec: ""Mutating and deleting nodes by id or label""
- graph-object-api spec: ""Creating and merging relationships""
- graph-object-api spec: ""Finding relationships by id""
- graph-object-api spec: ""Mutating and deleting relationships by id""
- graph-object-api spec: ""Counting nodes/relationships and listing distinct labels/types""
- graph-object-api spec: ""Bulk-deleting nodes, relationships, or the whole graph""
- graph-object-api spec: ""Finding orphaned nodes""
"
Class {
	#name : 'FkGraphDbTest',
	#superclass : 'FkGraphEndpointTestCase',
	#instVars : [
		'ownStick'
	],
	#category : 'FalkorSt-Objects-Tests',
	#package : 'FalkorSt-Objects-Tests'
}

{ #category : 'accessing' }
FkGraphDbTest >> db [
	^ FkGraphDb on: stick named: self graphName
]

{ #category : 'running' }
FkGraphDbTest >> tearDown [
	ownStick ifNotNil: [ ownStick close ].
	super tearDown
]

{ #category : 'tests' }
FkGraphDbTest >> testEndpointAnswersFkGraphEndpoint [
	| db |
	db := self db.
	self assert: db endpoint class equals: FkGraphEndpoint
]

{ #category : 'tests' }
FkGraphDbTest >> testGraphNameIsRequired [
	self deny: (FkGraphDb class canUnderstand: #on:)
]

{ #category : 'tests' }
FkGraphDbTest >> testNameDefaultsWhenNotSupplied [
	self assert: FkGraphDb new name equals: 'default'
]

{ #category : 'tests' }
FkGraphDbTest >> testNameDefaultsWhenNilIsPassedExplicitly [
	self assert: (FkGraphDb named: nil) name equals: 'default'
]

{ #category : 'tests' }
FkGraphDbTest >> testNamedLazilyCreatesAndConnectsAStick [
	| db |
	db := FkGraphDb named: self graphName.
	self assert: db name equals: self graphName.
	self assert: (db endpoint graphQuery: self graphName cypher: 'RETURN 1') records first first equals: 1.
	ownStick := db stick
]

{ #category : 'tests' }
FkGraphDbTest >> testOnNamedUsesGivenStickDirectly [
	| db |
	db := self db.
	self assert: db stick == stick
]

{ #category : 'tests' }
FkGraphDbTest >> testRunCypherRunsAWriteQuery [
	| db |
	db := self db.
	self assert: (db runCypher: 'RETURN 1') records first first equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testRunReadOnlyCypherRunsAReadQuery [
	| db |
	db := self db.
	db runCypher: 'CREATE (:Person)'.
	self assert: (db runReadOnlyCypher: 'MATCH (p:Person) RETURN count(p)') records first first equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testCreateNodeLabeledCreatesANodeWithNoProperties [
	| db node |
	db := self db.
	node := db createNodeLabeled: 'Person'.
	self assertCollection: node labels asArray equals: #('Person').
	self assert: node properties equals: Dictionary new
]

{ #category : 'tests' }
FkGraphDbTest >> testCreateNodeLabeledPropertiesCreatesANodeWithProperties [
	| db node |
	db := self db.
	node := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	self assertCollection: node labels asArray equals: #('Person').
	self assert: (node propertyAt: 'name') equals: 'Alice'.
	self assert: (node propertyAt: 'age') equals: 30
]

{ #category : 'tests' }
FkGraphDbTest >> testMergeNodeLabeledIsIdempotent [
	| db first second count |
	db := self db.
	first := db mergeNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	second := db mergeNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	self assert: first id equals: second id.
	count := (db runCypher: 'MATCH (p:Person) RETURN count(p)') records first first.
	self assert: count equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtFindsAnExistingNode [
	| db created found |
	db := self db.
	created := db createNodeLabeled: 'Person'.
	found := db nodeAt: created id.
	self assert: found id equals: created id
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtAnswersNilWhenNotFound [
	| db |
	db := self db.
	self assert: (db nodeAt: 999999) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testNodesLabeledAnswersAllNodesWithTheLabel [
	| db nodes |
	db := self db.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Company'.
	nodes := db nodesLabeled: 'Person'.
	self assert: nodes size equals: 2
]

{ #category : 'tests' }
FkGraphDbTest >> testNodesLabeledHavingAllFiltersByProperties [
	| db nodes |
	db := self db.
	db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob'. 'age' -> 25 }.
	nodes := db nodesLabeled: 'Person' havingAll: { 'name' -> 'Alice' }.
	self assert: nodes size equals: 1.
	self assert: (nodes first propertyAt: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphDbTest >> testNodesLabeledWhereFiltersByAnArbitraryClause [
	| db nodes |
	db := self db.
	db createNodeLabeled: 'Person' properties: { 'age' -> 30 }.
	db createNodeLabeled: 'Person' properties: { 'age' -> 20 }.
	nodes := db nodesLabeled: 'Person' where: [ :n | (n @ 'age') greaterThan: 25 ].
	self assert: nodes size equals: 1.
	self assert: (nodes first propertyAt: 'age') equals: 30
]

{ #category : 'tests' }
FkGraphDbTest >> testNodesLabeledWhereOrderBySkipLimitOrdersAndPagesResults [
	| db nodes |
	db := self db.
	db createNodeLabeled: 'Person' properties: { 'age' -> 30 }.
	db createNodeLabeled: 'Person' properties: { 'age' -> 10 }.
	db createNodeLabeled: 'Person' properties: { 'age' -> 20 }.
	nodes := db
		nodesLabeled: 'Person'
		where: [ :n | (n @ 'age') greaterThan: 0 ]
		orderBy: [ :n | (n @ 'age') asc ]
		skip: 1
		limit: 1.
	self assert: nodes size equals: 1.
	self assert: (nodes first propertyAt: 'age') equals: 20
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtPropertyAtPutMutatesTheProperty [
	| db created reloaded |
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'age' -> 30 }.
	db nodeAt: created id propertyAt: 'age' put: 31.
	reloaded := db nodeAt: created id.
	self assert: (reloaded propertyAt: 'age') equals: 31
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtPropertiesReplacesAllProperties [
	| db created reloaded |
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	db nodeAt: created id properties: { 'age' -> 40 } asDictionary.
	reloaded := db nodeAt: created id.
	self assert: (reloaded propertyAt: 'age') equals: 40.
	self assert: (reloaded propertyAt: 'name') isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtMergePropertiesMergesProperties [
	| db created reloaded |
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	db nodeAt: created id mergeProperties: { 'age' -> 40 } asDictionary.
	reloaded := db nodeAt: created id.
	self assert: (reloaded propertyAt: 'age') equals: 40.
	self assert: (reloaded propertyAt: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtPropertiesEscapesQuotesAndBackslashesInStringValues [
	| db created reloaded awkward |
	awkward := 'She said "hi" \ bye'.
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	db nodeAt: created id properties: { 'name' -> awkward } asDictionary.
	reloaded := db nodeAt: created id.
	self assert: (reloaded propertyAt: 'name') equals: awkward
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtMergePropertiesEscapesQuotesAndBackslashesInStringValues [
	| db created reloaded awkward |
	awkward := 'She said "hi" \ bye'.
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	db nodeAt: created id mergeProperties: { 'name' -> awkward } asDictionary.
	reloaded := db nodeAt: created id.
	self assert: (reloaded propertyAt: 'name') equals: awkward.
	self assert: (reloaded propertyAt: 'age') equals: 30
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteNodeAtRemovesTheNode [
	| db created |
	db := self db.
	created := db createNodeLabeled: 'Person'.
	db deleteNodeAt: created id.
	self assert: (db nodeAt: created id) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteNodeAtWithRelationsRemovesTheNodeAndItsRelationships [
	| db aliceAndBob alice |
	db := self db.
	aliceAndBob := self createAliceKnowsBobIn: db.
	alice := aliceAndBob first.
	db deleteNodeAt: alice id withRelations: true.
	self assert: (db nodeAt: alice id) isNil.
	self assert: db countRelationships equals: 0
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteNodeRemovesTheGivenGraphNode [
	| db created |
	db := self db.
	created := db createNodeLabeled: 'Person'.
	db deleteNode: created.
	self assert: (db nodeAt: created id) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteNodesLabeledHavingAllRemovesOnlyMatchingNodes [
	| db alice bob |
	db := self db.
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	db deleteNodesLabeled: 'Person' havingAll: { 'name' -> 'Alice' }.
	self assert: (db nodeAt: alice id) isNil.
	self deny: (db nodeAt: bob id) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteNodesLabeledWhereRemovesOnlyMatchingNodes [
	| db young old |
	db := self db.
	young := db createNodeLabeled: 'Person' properties: { 'age' -> 10 }.
	old := db createNodeLabeled: 'Person' properties: { 'age' -> 40 }.
	db deleteNodesLabeled: 'Person' where: [ :n | (n @ 'age') greaterThan: 25 ].
	self assert: (db nodeAt: old id) isNil.
	self deny: (db nodeAt: young id) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testCreateRelationshipTypedCreatesADirectedOutRelationshipWithProperties [
	"FalkorDB's CREATE rejects undirected patterns, so createRelationshipTyped: is an alias for
	createOutRelationshipTyped: - this test asserts that alias behavior (direction included), not
	just type/properties, so it can't silently pass if the two methods diverge."

	| db alice bob rel |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	rel := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: { 'since' -> 2020 }.
	self assert: rel type equals: 'KNOWS'.
	self assert: (rel propertyAt: 'since') equals: 2020.
	self assert: rel startNodeId equals: alice id.
	self assert: rel endNodeId equals: bob id
]

{ #category : 'tests' }
FkGraphDbTest >> testCreateInRelationshipTypedCreatesARelationshipIntoTheStartNode [
	| db alice bob rel |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	rel := db createInRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: bob id.
	self assert: rel endNodeId equals: alice id
]

{ #category : 'tests' }
FkGraphDbTest >> testCreateOutRelationshipTypedCreatesARelationshipOutOfTheStartNode [
	| db alice bob rel |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	rel := db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: alice id.
	self assert: rel endNodeId equals: bob id
]

{ #category : 'tests' }
FkGraphDbTest >> testMergeRelationshipTypedIsIdempotent [
	| db alice bob first second count |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	first := db mergeRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	second := db mergeRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	self assert: first id equals: second id.
	count := (db runCypher: 'MATCH ()-[r:KNOWS]-() RETURN count(r)') records first first.
	self assert: count equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testMergeInRelationshipTypedCreatesARelationshipIntoTheStartNode [
	| db alice bob rel |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	rel := db mergeInRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: bob id.
	self assert: rel endNodeId equals: alice id
]

{ #category : 'tests' }
FkGraphDbTest >> testMergeOutRelationshipTypedCreatesARelationshipOutOfTheStartNode [
	| db alice bob rel |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	rel := db mergeOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: alice id.
	self assert: rel endNodeId equals: bob id
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtFindsAnExistingRelationship [
	| db alice bob created found |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	created := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: #().
	found := db relationshipAt: created id.
	self assert: found id equals: created id.
	self assert: found type equals: 'KNOWS'
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtAnswersNilWhenNotFound [
	| db |
	db := self db.
	self assert: (db relationshipAt: 999999) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtPropertyAtPutMutatesTheProperty [
	| db alice bob created reloaded |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	created := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: { 'since' -> 2020 }.
	db relationshipAt: created id propertyAt: 'since' put: 2021.
	reloaded := db relationshipAt: created id.
	self assert: (reloaded propertyAt: 'since') equals: 2021
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtPropertiesReplacesAllProperties [
	| db alice bob created reloaded |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	created := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: { 'since' -> 2020. 'weight' -> 5 }.
	db relationshipAt: created id properties: { 'weight' -> 9 } asDictionary.
	reloaded := db relationshipAt: created id.
	self assert: (reloaded propertyAt: 'weight') equals: 9.
	self assert: (reloaded propertyAt: 'since') isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtMergePropertiesMergesProperties [
	| db alice bob created reloaded |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	created := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: { 'since' -> 2020. 'weight' -> 5 }.
	db relationshipAt: created id mergeProperties: { 'weight' -> 9 } asDictionary.
	reloaded := db relationshipAt: created id.
	self assert: (reloaded propertyAt: 'weight') equals: 9.
	self assert: (reloaded propertyAt: 'since') equals: 2020
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtPropertiesOnMissingRelationshipCreatesNothing [
	| db |
	db := self db.
	db relationshipAt: 999999 properties: { 'weight' -> 9 } asDictionary.
	self assert: (db relationshipAt: 999999) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtMergePropertiesOnMissingRelationshipCreatesNothing [
	| db |
	db := self db.
	db relationshipAt: 999999 mergeProperties: { 'weight' -> 9 } asDictionary.
	self assert: (db relationshipAt: 999999) isNil
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipAtRemovePropertyAtRemovesTheProperty [
	| db alice bob created reloaded |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	created := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: { 'since' -> 2020. 'weight' -> 5 }.
	db relationshipAt: created id removePropertyAt: 'weight'.
	reloaded := db relationshipAt: created id.
	self assert: (reloaded propertyAt: 'weight') isNil.
	self assert: (reloaded propertyAt: 'since') equals: 2020
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipsTypedAnswersAllRelationshipsOfTheType [
	| db alice bob carol |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	carol := db createNodeLabeled: 'Person'.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: bob id toNodeId: carol id properties: #().
	db createOutRelationshipTyped: 'LIKES' fromNodeId: alice id toNodeId: carol id properties: #().
	self assert: (db relationshipsTyped: 'KNOWS') size equals: 2
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipsTypedHavingValueFiltersByASingleProperty [
	| db alice bob carol |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	carol := db createNodeLabeled: 'Person'.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'since' -> 2020 }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: bob id toNodeId: carol id properties: { 'since' -> 2021 }.
	self assert: (db relationshipsTyped: 'KNOWS' having: 'since' value: 2020) size equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipsTypedHavingAllFiltersByProperties [
	| db alice bob carol |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	carol := db createNodeLabeled: 'Person'.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'since' -> 2020. 'weight' -> 1 }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: bob id toNodeId: carol id properties: { 'since' -> 2020. 'weight' -> 2 }.
	self assert: (db relationshipsTyped: 'KNOWS' havingAll: { 'since' -> 2020. 'weight' -> 1 }) size equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipsTypedWhereFiltersByAnArbitraryClause [
	| db alice bob carol rels |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	carol := db createNodeLabeled: 'Person'.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'weight' -> 5 }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: bob id toNodeId: carol id properties: { 'weight' -> 15 }.
	rels := db relationshipsTyped: 'KNOWS' where: [ :r | (r @ 'weight') greaterThan: 10 ].
	self assert: rels size equals: 1.
	self assert: (rels first propertyAt: 'weight') equals: 15
]

{ #category : 'tests' }
FkGraphDbTest >> testRelationshipsTypedWhereOrderBySkipLimitOrdersAndPagesResults [
	| db alice bob carol dave rels |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	carol := db createNodeLabeled: 'Person'.
	dave := db createNodeLabeled: 'Person'.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'weight' -> 30 }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: bob id toNodeId: carol id properties: { 'weight' -> 10 }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: carol id toNodeId: dave id properties: { 'weight' -> 20 }.
	rels := db
		relationshipsTyped: 'KNOWS'
		where: [ :r | (r @ 'weight') greaterThan: 0 ]
		orderBy: [ :r | (r @ 'weight') asc ]
		skip: 1
		limit: 1.
	self assert: rels size equals: 1.
	self assert: (rels first propertyAt: 'weight') equals: 20
]

{ #category : 'tests' }
FkGraphDbTest >> testNodesLabeledHavingValueFiltersByASingleProperty [
	| db nodes |
	db := self db.
	db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob'. 'age' -> 25 }.
	nodes := db nodesLabeled: 'Person' having: 'name' value: 'Alice'.
	self assert: nodes size equals: 1.
	self assert: (nodes first propertyAt: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphDbTest >> testNodeAtRemovePropertyAtRemovesTheProperty [
	| db created reloaded |
	db := self db.
	created := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice'. 'age' -> 30 }.
	db nodeAt: created id removePropertyAt: 'age'.
	reloaded := db nodeAt: created id.
	self assert: (reloaded propertyAt: 'age') isNil.
	self assert: (reloaded propertyAt: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteRelationshipAtRemovesTheRelationship [
	| db alice bob created |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	created := db
		createRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: #().
	db deleteRelationshipAt: created id.
	self assert: (db relationshipAt: created id) isNil
]

{ #category : 'creating' }
FkGraphDbTest >> createAliceKnowsBobIn: db [
	| alice bob |
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	^ { alice. bob }
]

{ #category : 'tests' }
FkGraphDbTest >> testOneHopPathsTypedDirectionOutReturningThePathAnswersMatchingPaths [
	| aliceAndBob alice bob paths |
	aliceAndBob := self createAliceKnowsBobIn: self db.
	alice := aliceAndBob first.
	bob := aliceAndBob last.
	paths := self db
		oneHopPathsTyped: 'KNOWS'
		direction: #out
		from: alice id
		havingAll: #()
		endNodeWithLabels: #('Person')
		havingAll: #()
		whereIn: [ :s :r :e | nil ]
		returning: [ :path | path ].
	self assert: paths size equals: 1.
	self assertPath: paths first goesFrom: alice to: bob
]

{ #category : 'asserting' }
FkGraphDbTest >> assertPath: aPath goesFrom: startNode to: endNode [
	self assert: aPath class equals: FkGraphPath.
	self assert: aPath startNode id equals: startNode id.
	self assert: aPath endNode id equals: endNode id.
	self assert: aPath relationships first type equals: 'KNOWS'
]

{ #category : 'tests' }
FkGraphDbTest >> testOneHopPathsTypedDirectionOutReturningEndNodeAnswersWrappedEndNodes [
	| db alice endNodes |
	db := self db.
	alice := (self createAliceKnowsBobIn: db) first.
	endNodes := db
		oneHopPathsTyped: 'KNOWS'
		direction: #out
		from: alice id
		havingAll: #()
		endNodeWithLabels: #('Person')
		havingAll: #()
		whereIn: [ :s :r :e | nil ]
		returning: [ :path | path endNode ].
	self assert: endNodes size equals: 1.
	self assert: endNodes first class equals: FkGraphNode.
	self assert: (endNodes first propertyAt: 'name') equals: 'Bob'
]

{ #category : 'tests' }
FkGraphDbTest >> testExistsOneHopPathsTypedDirectionOutAnswersTrueWhenMatchingPathExists [
	| aliceAndBob alice |
	aliceAndBob := self createAliceKnowsBobIn: self db.
	alice := aliceAndBob first.
	self assert: (self db
		existsOneHopPathsTyped: 'KNOWS'
		direction: #out
		from: alice id
		havingAll: #()
		endNodeWithLabels: #('Person')
		havingAll: #()
		whereIn: [ :s :r :e | nil ])
]

{ #category : 'tests' }
FkGraphDbTest >> testExistsOneHopPathsTypedDirectionOutAnswersFalseWhenNoMatchingPathExists [
	| alice |
	alice := (self db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }).
	self deny: (self db
		existsOneHopPathsTyped: 'KNOWS'
		direction: #out
		from: alice id
		havingAll: #()
		endNodeWithLabels: #('Person')
		havingAll: #()
		whereIn: [ :s :r :e | nil ])
]

{ #category : 'tests' }
FkGraphDbTest >> testExistsOneHopPathsTypedDirectionOutAnswersFalseWhenWhereClauseExcludesMatch [
	| aliceAndBob alice |
	aliceAndBob := self createAliceKnowsBobIn: self db.
	alice := aliceAndBob first.
	self deny: (self db
		existsOneHopPathsTyped: 'KNOWS'
		direction: #out
		from: alice id
		havingAll: #()
		endNodeWithLabels: #('Person')
		havingAll: #()
		whereIn: [ :s :r :e | (e @ 'name') equals: 'Nobody' ])
]

{ #category : 'tests' }
FkGraphDbTest >> testExistsOneHopPathsTypedDirectionFromWhereInConvenienceMatchesFullVersionWithEmptyFilters [
	| aliceAndBob alice |
	aliceAndBob := self createAliceKnowsBobIn: self db.
	alice := aliceAndBob first.
	self assert: (self db existsOneHopPathsTyped: 'KNOWS' direction: #out from: alice id whereIn: [ :s :r :e | nil ]).
	self deny: (self db existsOneHopPathsTyped: 'MISSING' direction: #out from: alice id whereIn: [ :s :r :e | nil ])
]

{ #category : 'tests' }
FkGraphDbTest >> testOneHopPathsTypedReturnInNarrowedToEndNodeAnswersWrappedEndNodes [
	| db endNodes |
	db := self db.
	endNodes := db
		oneHopPathsTyped: 'KNOWS'
		direction: #out
		from: (self createAliceKnowsBobIn: db) first id
		havingAll: #()
		endNodeWithLabels: #('Person')
		havingAll: #()
		whereIn: [ :s :r :e | nil ]
		returnIn: [ :ret | ret items: (CyObjects withAll: { 'e' asCypherIdentifier }) ]
		returning: [ :endNode | FkGraphNode on: endNode in: db ].
	self assert: endNodes size equals: 1.
	self assert: endNodes first class equals: FkGraphNode.
	self assert: (endNodes first propertyAt: 'name') equals: 'Bob'
]

{ #category : 'tests' }
FkGraphDbTest >> testAllLabelsAnswersEveryDistinctLabelInTheGraph [
	| db labels |
	db := self db.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Company'.
	labels := db allLabels.
	self assert: labels asSet equals: #('Person' 'Company') asSet
]

{ #category : 'tests' }
FkGraphDbTest >> testAllRelationshipTypesAnswersEveryDistinctTypeInTheGraph [
	| db aliceAndBob carol |
	db := self db.
	aliceAndBob := self createAliceKnowsBobIn: db.
	carol := db createNodeLabeled: 'Person' properties: { 'name' -> 'Carol' }.
	db createOutRelationshipTyped: 'LIKES' fromNodeId: aliceAndBob first id toNodeId: carol id properties: #().
	self assert: db allRelationshipTypes asSet equals: #('KNOWS' 'LIKES') asSet
]

{ #category : 'tests' }
FkGraphDbTest >> testCountNodesAnswersTheTotalNodeCount [
	| db |
	db := self db.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Company'.
	self assert: db countNodes equals: 2
]

{ #category : 'tests' }
FkGraphDbTest >> testCountNodesLabeledAnswersTheCountForTheGivenLabel [
	| db |
	db := self db.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Person'.
	db createNodeLabeled: 'Company'.
	self assert: (db countNodesLabeled: 'Person') equals: 2
]

{ #category : 'tests' }
FkGraphDbTest >> testCountRelationshipsAnswersTheTotalRelationshipCount [
	| db aliceAndBob carol |
	db := self db.
	aliceAndBob := self createAliceKnowsBobIn: db.
	carol := db createNodeLabeled: 'Person' properties: { 'name' -> 'Carol' }.
	db createOutRelationshipTyped: 'LIKES' fromNodeId: aliceAndBob first id toNodeId: carol id properties: #().
	self assert: db countRelationships equals: 2
]

{ #category : 'tests' }
FkGraphDbTest >> testCountRelationshipsTypedAnswersTheCountForTheGivenType [
	| db aliceAndBob carol |
	db := self db.
	aliceAndBob := self createAliceKnowsBobIn: db.
	carol := db createNodeLabeled: 'Person' properties: { 'name' -> 'Carol' }.
	db createOutRelationshipTyped: 'LIKES' fromNodeId: aliceAndBob first id toNodeId: carol id properties: #().
	self assert: (db countRelationshipsTyped: 'KNOWS') equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteAllRemovesAllNodesAndRelationships [
	| db |
	db := self db.
	self createAliceKnowsBobIn: db.
	db deleteAll.
	self assert: db countNodes equals: 0.
	self assert: db countRelationships equals: 0
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteAllNodesRemovesAllNodesAndTheirRelationships [
	| db |
	db := self db.
	self createAliceKnowsBobIn: db.
	db deleteAllNodes.
	self assert: db countNodes equals: 0.
	self assert: db countRelationships equals: 0
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteAllRelationshipsRemovesRelationshipsButKeepsNodes [
	| db |
	db := self db.
	self createAliceKnowsBobIn: db.
	db deleteAllRelationships.
	self assert: db countNodes equals: 2.
	self assert: db countRelationships equals: 0
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteRelationshipsTypedRemovesOnlyMatchingTypeRelationships [
	| db aliceAndBob carol |
	db := self db.
	aliceAndBob := self createAliceKnowsBobIn: db.
	carol := db createNodeLabeled: 'Person' properties: { 'name' -> 'Carol' }.
	db createOutRelationshipTyped: 'LIKES' fromNodeId: aliceAndBob first id toNodeId: carol id properties: #().
	db deleteRelationshipsTyped: 'KNOWS'.
	self assert: (db countRelationshipsTyped: 'KNOWS') equals: 0.
	self assert: (db countRelationshipsTyped: 'LIKES') equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testDeleteRelationshipsTypedHavingAllRemovesOnlyMatchingRelationships [
	| db alice bob carol |
	db := self db.
	alice := db createNodeLabeled: 'Person'.
	bob := db createNodeLabeled: 'Person'.
	carol := db createNodeLabeled: 'Person'.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'since' -> 2020 }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: bob id toNodeId: carol id properties: { 'since' -> 2021 }.
	db deleteRelationshipsTyped: 'KNOWS' havingAll: { 'since' -> 2020 }.
	self assert: (db countRelationshipsTyped: 'KNOWS') equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testOrphanedNodesAnswersOnlyNodesWithNoRelationships [
	| db aliceAndBob lonely |
	db := self db.
	aliceAndBob := self createAliceKnowsBobIn: db.
	lonely := db createNodeLabeled: 'Person' properties: { 'name' -> 'Lonely' }.
	self assert: db orphanedNodes size equals: 1.
	self assert: (db orphanedNodes first propertyAt: 'name') equals: 'Lonely'
]
