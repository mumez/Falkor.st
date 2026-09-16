"
I test FkQueryResult's decoding of verbose GRAPH.QUERY replies against a real FalkorDB instance.

Coverage:
- graph-query-execution spec: ""Query with a RETURN clause"" / ""Query without a RETURN clause""
  (header/records/statistics envelope)
- graph-query-execution spec: ""Node value"" / ""Relationship value""
- graph-query-execution spec: ""Mixed scalar row"" - partially: null, string, and integer only.
  Boolean, double, list, and map verbose scalars are not yet decoded to typed Smalltalk values
  (FalkorDB serializes them as plain strings in verbose mode, indistinguishable from a genuine
  Cypher string on the wire - see FkQueryResult's class comment); that decoding, and Path value
  decoding, are deferred until compact-format decoding (change section 4) supplies unambiguous
  value-type tags.
"
Class {
	#name : 'FkQueryResultTest',
	#superclass : 'TestCase',
	#instVars : [
		'stick',
		'endpoint'
	],
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'private' }
FkQueryResultTest >> graphName [
	^ 'FkQueryResultTest_' , self selector asString
]

{ #category : 'running' }
FkQueryResultTest >> setUp [
	super setUp.
	stick := FkFalkorStick targetUrl: 'sync://localhost:6379'.
	stick connect.
	endpoint := stick endpoint
]

{ #category : 'running' }
FkQueryResultTest >> tearDown [
	[ endpoint unifiedCommand: { 'GRAPH.DELETE'. self graphName } ]
		on: Error
		do: [ :ex |  ].
	stick close.
	super tearDown
]

{ #category : 'tests' }
FkQueryResultTest >> testDecodesNodeValue [
	| result node |
	result := endpoint
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
	result := endpoint
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
	result := endpoint
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
	result := endpoint graphQuery: self graphName cypher: 'CREATE (:Foo)'.
	self assert: result header isEmpty.
	self assert: result records isEmpty.
	self assert: result statistics notEmpty
]

{ #category : 'tests' }
FkQueryResultTest >> testQueryWithReturnClauseExposesHeaderRecordsAndStatistics [
	| result |
	result := endpoint graphQuery: self graphName cypher: 'MATCH (a) RETURN a'.
	self assertCollection: result header asArray equals: #('a').
	self assert: result records isEmpty.
	self assert: result statistics notEmpty
]
