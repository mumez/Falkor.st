"
I test FkGraphDb's two constructors, its #endpoint accessor, and its node-CRUD convenience API
against a real FalkorDB instance.

Coverage:
- graph-object-api spec: ""Creating a handle that owns its connection""
- graph-object-api spec: ""Creating a handle over an existing connection""
- graph-object-api spec: ""Graph name is required""
- graph-object-api spec: ""Exposing the low-level endpoint""
- graph-object-api spec: ""Running raw Cypher through the handle""
- graph-object-api spec: ""Creating and merging nodes""
- graph-object-api spec: ""Finding nodes by id or label""
- graph-object-api spec: ""Mutating and deleting nodes by id or label""
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
		orderBy: (('n' asCypherIdentifier @ 'age') asc)
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
FkGraphDbTest >> testDeleteNodeAtRemovesTheNode [
	| db created |
	db := self db.
	created := db createNodeLabeled: 'Person'.
	db deleteNodeAt: created id.
	self assert: (db nodeAt: created id) isNil
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
