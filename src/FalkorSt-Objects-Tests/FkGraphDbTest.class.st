"
I test FkGraphDb's two constructors and its #endpoint accessor against a real FalkorDB instance.

Coverage:
- graph-object-api spec: ""Creating a handle that owns its connection""
- graph-object-api spec: ""Creating a handle over an existing connection""
- graph-object-api spec: ""Graph name is required""
- graph-object-api spec: ""Exposing the low-level endpoint""
- graph-object-api spec: ""Running raw Cypher through the handle""
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

{ #category : 'running' }
FkGraphDbTest >> tearDown [
	ownStick ifNotNil: [ ownStick close ].
	super tearDown
]

{ #category : 'tests' }
FkGraphDbTest >> testEndpointAnswersFkGraphEndpoint [
	| db |
	db := FkGraphDb on: stick named: self graphName.
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
	db := FkGraphDb on: stick named: self graphName.
	self assert: db stick == stick
]

{ #category : 'tests' }
FkGraphDbTest >> testRunCypherRunsAWriteQuery [
	| db |
	db := FkGraphDb on: stick named: self graphName.
	self assert: (db runCypher: 'RETURN 1') records first first equals: 1
]

{ #category : 'tests' }
FkGraphDbTest >> testRunReadOnlyCypherRunsAReadQuery [
	| db |
	db := FkGraphDb on: stick named: self graphName.
	db runCypher: 'CREATE (:Person)'.
	self assert: (db runReadOnlyCypher: 'MATCH (p:Person) RETURN count(p)') records first first equals: 1
]
