"
I test FkQueryResult's decoding of compact GRAPH.QUERY replies against a real FalkorDB instance,
including label/relationship-type/property-key id resolution on FkGraphEndpoint.

Coverage:
- graph-query-compact-format spec: ""Compact query execution""
- graph-query-compact-format spec: ""Node labels and property keys resolved"" / ""Relationship type
  resolved"" / ""Previously unseen identifier"" (cache-miss refresh)
- graph-query-execution spec: ""Mixed scalar row"" - fully, via compact (verbose cannot; see
  FkQueryResultTest and design.md Decision 6)
- graph-query-execution spec: ""Path value"" - via compact (verbose cannot decode paths at all)
"
Class {
	#name : 'FkCompactQueryResultTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesAllScalarTypes [
	| result row |
	result := self endpoint
		graphQuery: self graphName
		cypher: 'RETURN null AS n, ''hello'' AS s, 42 AS i, true AS b, 3.14 AS d, [1, 2, 3] AS l, {a: 1, b: 2} AS m'
		compact: true.
	row := result records first.
	self assert: row first isNil.
	self assert: row second equals: 'hello'.
	self assert: row third equals: 42.
	self assert: row fourth equals: true.
	self assert: row fifth equals: 3.14.
	self assertCollection: row sixth asArray equals: #(1 2 3).
	self assert: (row at: 7) equals: (Dictionary new at: 'a' put: 1; at: 'b' put: 2; yourself)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesPathValue [
	| result path |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (a:Person {name: ''A''})-[:KNOWS]->(b:Person {name: ''B''})-[:KNOWS]->(c:Person {name: ''C''})'
		compact: true.
	result := self endpoint
		graphQuery: self graphName
		cypher: 'MATCH p = (a:Person {name: ''A''})-[*]->(c:Person {name: ''C''}) RETURN p'
		compact: true.
	path := result records first first.
	self assert: path class equals: FkPath.
	self assertCollection: (path nodes collect: [ :n | n properties at: 'name' ]) asArray equals: #('A' 'B' 'C').
	self assertCollection: (path relationships collect: [ :r | r type ]) asArray equals: #('KNOWS' 'KNOWS')
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testRefreshesIdCacheOnPreviouslyUnseenLabel [
	| firstNode secondNode |
	firstNode := (self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person) RETURN p'
		compact: true) records first first.
	secondNode := (self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (c:Company {name: ''Acme''}) RETURN c'
		compact: true) records first first.
	self assertCollection: firstNode labels asArray equals: #('Person').
	self assertCollection: secondNode labels asArray equals: #('Company')
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testResolvesNodeLabelsAndProperties [
	| node |
	node := (self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person:Employee {name: ''Alice'', age: 30}) RETURN p'
		compact: true) records first first.
	self assert: node class equals: FkNode.
	self assertCollection: node labels asArray equals: #('Person' 'Employee').
	self
		assert: node properties
		equals: (Dictionary new at: 'name' put: 'Alice'; at: 'age' put: 30; yourself)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testResolvesRelationshipType [
	| rel |
	rel := (self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (a:Person)-[r:KNOWS {since: 2020}]->(b:Person) RETURN r'
		compact: true) records first first.
	self assert: rel class equals: FkRelationship.
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: 0.
	self assert: rel endNodeId equals: 1.
	self assert: rel properties equals: (Dictionary new at: 'since' put: 2020; yourself)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testVerboseAndCompactDecodeEquivalently [
	| verboseResult compactResult vNode cNode |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person:Employee {name: ''Alice'', age: 30})'
		compact: true.
	verboseResult := self endpoint graphQuery: self graphName cypher: 'MATCH (p:Person) RETURN p' compact: false.
	compactResult := self endpoint graphQuery: self graphName cypher: 'MATCH (p:Person) RETURN p' compact: true.
	vNode := verboseResult records first first.
	cNode := compactResult records first first.
	self assertCollection: verboseResult header asArray equals: compactResult header asArray.
	self assert: vNode id equals: cNode id.
	self assertCollection: vNode labels asArray equals: cNode labels asArray.
	self assert: vNode properties equals: cNode properties
]
