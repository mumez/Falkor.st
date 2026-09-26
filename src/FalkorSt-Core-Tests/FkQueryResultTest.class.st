"
I test FkQueryResult's decoding of verbose GRAPH.QUERY replies against a real FalkorDB instance.

Coverage:
- graph-query-execution spec: ""Query with a RETURN clause"" / ""Query without a RETURN clause""
  (header/records/statistics envelope)
- graph-query-execution spec: ""Node value"" / ""Relationship value""
- graph-query-execution spec: ""Mixed scalar row"" - partially: null, string, and integer only.
  Boolean, double, list, and map verbose scalars are not decoded to typed Smalltalk values
  (FalkorDB serializes them as plain strings in verbose mode, indistinguishable from a genuine
  Cypher string on the wire - see FkQueryResult's class comment); that decoding, and Path value
  decoding, are covered instead by FkCompactQueryResultTest via the compact format.
- Safe record accessors (#recordsDo:, #firstRecordDo:[ifNone:], #oneValueDo:[ifNone:], #oneValue)
  on both non-empty and empty results
"
Class {
	#name : 'FkQueryResultTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkQueryResultTest >> testDecodesNodeValue [
	| result node |
	result := self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person:Employee {name: ''Alice'', age: 30}) RETURN p'.
	node := result records first first.
	self assert: node class equals: FkNode.
	self assert: node id equals: 0.
	self assertCollection: node labels asArray equals: #('Person' 'Employee').
	self
		assert: node properties
		equals: (Dictionary new at: 'name' put: 'Alice'; at: 'age' put: 30; yourself)
]

{ #category : 'tests' }
FkQueryResultTest >> testDecodesNullStringAndIntegerScalars [
	| result row |
	result := self endpoint
		graphQuery: self graphName
		cypher: 'RETURN null AS n, ''hello'' AS s, 42 AS i'.
	row := result records first.
	self assert: row first isNil.
	self assert: row second equals: 'hello'.
	self assert: row third equals: 42
]

{ #category : 'tests' }
FkQueryResultTest >> testDecodesRelationshipValue [
	| result rel |
	result := self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (a:Person)-[r:KNOWS {since: 2020}]->(b:Person) RETURN r'.
	rel := result records first first.
	self assert: rel class equals: FkRelationship.
	self assert: rel id equals: 0.
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: 0.
	self assert: rel endNodeId equals: 1.
	self assert: rel properties equals: (Dictionary new at: 'since' put: 2020; yourself)
]

{ #category : 'tests' }
FkQueryResultTest >> testQueryWithoutReturnClauseExposesOnlyStatistics [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'CREATE (:Foo)'.
	self assert: result header isEmpty.
	self assert: result records isEmpty.
	self assert: result statistics notEmpty
]

{ #category : 'tests' }
FkQueryResultTest >> testQueryWithReturnClauseExposesHeaderRecordsAndStatistics [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'MATCH (a) RETURN a'.
	self assertCollection: result header asArray equals: #('a').
	self assert: result records isEmpty.
	self assert: result statistics notEmpty
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testFirstRecordDoAnswersBlockValueForFirstRecord [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'UNWIND [1, 2] AS x RETURN x, x * 10'.
	self assert: (result firstRecordDo: [ :record | record second ]) equals: 10
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testFirstRecordDoAnswersNilWhenNoRecords [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'MATCH (a) RETURN a'.
	self assert: (result firstRecordDo: [ :record | self fail ]) isNil
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testFirstRecordDoIfNoneAnswersNoneBlockValueWhenNoRecords [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'MATCH (a) RETURN a'.
	self assert: (result firstRecordDo: [ :record | self fail ] ifNone: [ #none ]) equals: #none
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testOneValueAnswersFirstCellOfFirstRecord [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'UNWIND [1, 2] AS x RETURN x, x * 10'.
	self assert: result oneValue equals: 1
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testOneValueAnswersNilWhenNoRecords [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'CREATE (:Foo)'.
	self assert: result oneValue isNil
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testOneValueDoAnswersBlockValueForFirstCell [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'RETURN 41'.
	self assert: (result oneValueDo: [ :value | value + 1 ]) equals: 42
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testOneValueDoIfNoneAnswersNoneBlockValueWhenNoRecords [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'MATCH (a) RETURN a'.
	self assert: (result oneValueDo: [ :value | self fail ] ifNone: [ #none ]) equals: #none
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testRecordsDoEvaluatesBlockForEachRecord [
	| result visited |
	result := self endpoint graphQuery: self graphName cypher: 'UNWIND [1, 2, 3] AS x RETURN x'.
	visited := OrderedCollection new.
	result recordsDo: [ :record | visited add: record first ].
	self assertCollection: visited asArray equals: #( 1 2 3 )
]

{ #category : 'tests - accessing' }
FkQueryResultTest >> testRecordsDoEvaluatesNothingWhenNoRecords [
	| result |
	result := self endpoint graphQuery: self graphName cypher: 'CREATE (:Foo)'.
	result recordsDo: [ :record | self fail ]
]
