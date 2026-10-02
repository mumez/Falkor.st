"
I test FkGraphEndpoint's procedure-call extension API (#graphCallProcedure:procedure:*),
covering both the Cypher/params it generates and its execution against a real FalkorDB instance.
"
Class {
	#name : 'FkGraphEndpointProcedureCallTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallCypherForNoArgumentsNoYield [
	self
		assert: (self endpoint procedureCallCypherFor: 'db.labels' arguments: #() yield: nil)
		equals: 'CALL db.labels()'
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallCypherForArgumentsReferencesParameters [
	self
		assert: (self endpoint procedureCallCypherFor: 'someProc' arguments: #('a' 'b') yield: nil)
		equals: 'CALL someProc($param0, $param1)'
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallCypherForSingleYieldName [
	self
		assert: (self endpoint procedureCallCypherFor: 'db.labels' arguments: #() yield: #('label'))
		equals: 'CALL db.labels() YIELD label'
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallCypherForMultipleYieldNames [
	self
		assert:
			(self endpoint
				procedureCallCypherFor: 'dbms.procedures'
				arguments: #()
				yield: #('name' 'mode'))
		equals: 'CALL dbms.procedures() YIELD name, mode'
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallCypherForYieldStringIsSingleName [
	self
		assert: (self endpoint procedureCallCypherFor: 'db.labels' arguments: #() yield: 'label')
		equals: 'CALL db.labels() YIELD label'
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallCypherForEmptyYieldOmitsYield [
	self
		assert: (self endpoint procedureCallCypherFor: 'db.labels' arguments: #() yield: #())
		equals: 'CALL db.labels()'
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallParamsForBuildsIndexedParamDictionary [
	self
		assert: (self endpoint procedureCallParamsFor: #('a' 'b'))
		equals: (Dictionary new at: 'param0' put: 'a'; at: 'param1' put: 'b'; yourself)
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testProcedureCallParamsForEmptyArgumentsIsEmpty [
	self assert: (self endpoint procedureCallParamsFor: #()) equals: Dictionary new
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testGraphCallProcedureProcedureAnswersLabelsInTheGraph [
	| result |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person), (:Company)'.
	result := self endpoint graphCallProcedure: self graphName procedure: 'db.labels'.
	self assert: (result records collect: [ :row | row first ]) asSet equals: #('Person' 'Company') asSet
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testGraphCallProcedureArgumentsWithQuotesPassesThroughSafely [
	| awkward result |
	awkward := self createFulltextIndexedPersonNamed: 'She said "hi" to O''Brien'.
	result := self endpoint
		graphCallProcedure: self graphName
		procedure: 'db.idx.fulltext.queryNodes'
		arguments: { 'Person'. '"hi" O''Brien' }
		yield: #('node')
		readOnly: false.
	self assert: (result records collect: [ :row | row first properties at: 'name' ]) asArray equals: { awkward }
]

{ #category : 'support' }
FkGraphEndpointProcedureCallTest >> createFulltextIndexedPersonNamed: aName [
	"Create a fulltext-indexed :Person node with the given name, and answer that name."

	self endpoint
		graphIndexCreateBy: [ :index | index fulltext; node: 'Person'; props: #('name') ]
		on: self graphName.
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person {name: $n})'
		params: { 'n' -> aName } asDictionary.
	^ aName
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testGraphCallProcedureYieldSubsetLimitsResultHeader [
	| result |
	result := self endpoint
		graphCallProcedure: self graphName
		procedure: 'dbms.procedures'
		arguments: #()
		yield: #('name' 'mode')
		readOnly: false.
	self assert: result header equals: #('name' 'mode') asOrderedCollection
]

{ #category : 'tests' }
FkGraphEndpointProcedureCallTest >> testGraphCallProcedureReadOnlyTrueUsesRoQuery [
	| result |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	result := self endpoint
		graphCallProcedure: self graphName
		procedure: 'db.labels'
		arguments: #()
		yield: nil
		readOnly: true.
	self assert: (result records collect: [ :row | row first ]) asSet equals: #('Person') asSet
]
