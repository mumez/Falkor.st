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
		cypher: 'RETURN null AS n, ''hello'' AS s, 42 AS i, true AS b, 3.14 AS d, [1, 2, 3] AS l, {a: 1, b: 2} AS m'.
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
FkCompactQueryResultTest >> testDecodesDoublesInScientificNotation [
	| result row |
	result := self endpoint
		graphQuery: self graphName
		cypher: 'RETURN 1e21 AS big, 1.5e300 AS huge, 1e-07 AS tiny'.
	row := result records first.
	self assert: row first equals: 1000000000000000000000.
	self assert: row second equals: 1.5e300.
	self assert: row third equals: 1.0e-7
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesPathValue [
	| result path |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (a:Person {name: ''A''})-[:KNOWS]->(b:Person {name: ''B''})-[:KNOWS]->(c:Person {name: ''C''})'.
	result := self endpoint
		graphQuery: self graphName
		cypher: 'MATCH p = (a:Person {name: ''A''})-[*]->(c:Person {name: ''C''}) RETURN p'.
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
		cypher: 'CREATE (p:Person) RETURN p') records first first.
	secondNode := (self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (c:Company {name: ''Acme''}) RETURN c') records first first.
	self assertCollection: firstNode labels asArray equals: #('Person').
	self assertCollection: secondNode labels asArray equals: #('Company')
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testResolvesNodeLabelsAndProperties [
	| node |
	node := (self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person:Employee {name: ''Alice'', age: 30}) RETURN p') records first first.
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
		cypher: 'CREATE (a:Person)-[r:KNOWS {since: 2020}]->(b:Person) RETURN r') records first first.
	self assert: rel class equals: FkRelationship.
	self assert: rel type equals: 'KNOWS'.
	self assert: rel startNodeId equals: 0.
	self assert: rel endNodeId equals: 1.
	self assert: rel properties equals: (Dictionary new at: 'since' put: 2020; yourself)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testRaisesErrorForUnresolvableCompactId [
	"Simulate a stale id (id past the schema's current size, as after a concurrent schema shrink)."
	| endpoint |
	endpoint := self endpoint.
	endpoint labelCaches at: self graphName put: #('Person').
	self should: [ endpoint labelNameAt: 9999 inGraph: self graphName ] raise: RsGenericError
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

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesPointValue [
	| point |
	point := (self endpoint
		graphQuery: self graphName
		cypher: 'RETURN point({latitude: 35.68, longitude: 139.69}) AS p') oneValue.
	self assert: point class equals: FkPoint.
	"FalkorDB stores point coordinates as 32-bit floats"
	self assert: (point latitude closeTo: 35.68 precision: 1.0e-5).
	self assert: (point longitude closeTo: 139.69 precision: 1.0e-5)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesPointAndVectorNestedInCollectionsAndProperties [
	| row node |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Place {location: point({latitude: 1.5, longitude: 2.5}), embedding: vecf32([0.5, 1.0])})'.
	row := (self endpoint
		graphQuery: self graphName
		cypher: 'MATCH (n:Place) RETURN n, [n.location], {e: n.embedding}') records first.
	node := row first.
	self assert: (node properties at: 'location') equals: (FkPoint latitude: 1.5 longitude: 2.5).
	self assert: (node properties at: 'embedding') equals: #(0.5 1.0).
	self assert: row second first equals: (FkPoint latitude: 1.5 longitude: 2.5).
	self assert: (row third at: 'e') equals: #(0.5 1.0)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesVectorValueAsFloats [
	| vector |
	vector := (self endpoint graphQuery: self graphName cypher: 'RETURN vecf32([1.5, 2.0, -3]) AS v') oneValue.
	self assert: vector equals: #(1.5 2.0 -3.0).
	self assert: (vector allSatisfy: [ :each | each isFloat ])
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesTemporalValues [
	| row |
	row := (self endpoint
		graphQuery: self graphName
		cypher: 'RETURN localdatetime(''2024-01-02T03:04:05''), date(''2024-01-02''), localtime(''03:04:05''), duration(''P1DT2H'')')
		records first.
	self assert: row first equals: (DateAndTime year: 2024 month: 1 day: 2 hour: 3 minute: 4 second: 5 offset: Duration zero).
	self assert: row first offset equals: Duration zero.
	self assert: row second equals: (Date year: 2024 month: 1 day: 2).
	self assert: row third equals: (Time hour: 3 minute: 4 second: 5).
	self assert: row fourth equals: (Duration days: 1 hours: 2 minutes: 0 seconds: 0)
]

{ #category : 'tests' }
FkCompactQueryResultTest >> testDecodesTemporalValuesBeforeUnixEpochAndStoredAsProperties [
	| properties |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Event {on: date(''1960-05-06''), at: localtime(''23:59:59'')})'.
	properties := (self endpoint graphQuery: self graphName cypher: 'MATCH (e:Event) RETURN e') oneValue properties.
	self assert: (properties at: 'on') equals: (Date year: 1960 month: 5 day: 6).
	self assert: (properties at: 'at') equals: (Time hour: 23 minute: 59 second: 59)
]
