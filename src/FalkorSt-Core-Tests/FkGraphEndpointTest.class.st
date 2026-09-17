"
I test FkGraphEndpoint's command-level behavior against a real FalkorDB instance for commands
that are not primarily about FkQueryResult decoding: GRAPH.RO_QUERY, GRAPH.DELETE, GRAPH.INFO,
GRAPH.CONFIG, GRAPH.CONSTRAINT, GRAPH.EXPLAIN, GRAPH.PROFILE, GRAPH.LIST, GRAPH.COPY, GRAPH.MEMORY,
and GRAPH.SLOWLOG.

Coverage:
- graph-ro-query spec: read-only Cypher query execution, same result-set shape as GRAPH.QUERY
- graph-delete spec: deleting a graph answers a plain status string reply
- graph-info spec: server status query, with and without section options
- graph-config spec: getting one or all config parameters, and setting a runtime parameter
- graph-constraint spec: creating and dropping MANDATORY/UNIQUE constraints on node labels and
  relationship types
- graph-explain spec: constructing a query plan without executing it, with and without bound
  parameters, answering the raw undecoded plan reply
- graph-profile spec: executing a query and answering the raw undecoded plan reply augmented with
  per-operation metrics, with and without bound parameters
- graph-list spec: listing graph names present in the keyspace
- graph-copy spec: copying a graph's data into a new graph name
- graph-memory spec: reporting per-graph memory usage statistics, decoded into a Dictionary
- graph-slowlog spec: reporting the graph's slowest queries, decoded into FkSlowLogEntry instances
"
Class {
	#name : 'FkGraphEndpointTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryDecodesNodeValue [
	| result node |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person {name: ''Alice''})'.
	result := self endpoint
		graphRoQuery: self graphName
		cypher: 'MATCH (p:Person) RETURN p'.
	node := result records first first.
	self assert: node class equals: FkNode.
	self assertCollection: node labels asArray equals: #('Person').
	self assert: (node properties at: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryWithParams [
	| result |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person {name: ''Alice''})'.
	result := self endpoint
		graphRoQuery: self graphName
		cypher: 'MATCH (p:Person {name: $name}) RETURN p.name'
		params: (Dictionary new at: 'name' put: 'Alice'; yourself).
	self assert: result records first first equals: 'Alice'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryVerbose [
	| result |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)'.
	result := self endpoint
		graphRoQuery: self graphName
		cypher: 'MATCH (p:Person) RETURN p'
		compact: false.
	self assert: result records size equals: 1
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphDeleteAnswersStatusString [
	| reply |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)'.
	reply := self endpoint graphDelete: self graphName.
	self assert: reply equals: 'OK'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphInfoWithoutOptionsAnswersReply [
	| reply |
	reply := self endpoint graphInfo.
	self assert: reply notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphInfoWithOptionsAnswersReply [
	| reply |
	reply := self endpoint graphInfo: [ :opts | opts runningQueries: true ].
	self assert: reply notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConfigGetAnswersValueForKnownParam [
	| reply |
	reply := self endpoint graphConfigGet: 'TIMEOUT_DEFAULT'.
	self assert: reply notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConfigGetAllAnswersNonEmptyReply [
	| reply |
	reply := self endpoint graphConfigGet: '*'.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConfigSetUpdatesParamValue [
	| reply originalValue |
	originalValue := (self endpoint graphConfigGet: 'TIMEOUT_DEFAULT') second.
	[
		self endpoint graphConfigSet: (Dictionary new at: 'TIMEOUT_DEFAULT' put: 5000; yourself).
		reply := self endpoint graphConfigGet: 'TIMEOUT_DEFAULT'.
		self assert: reply second equals: 5000 ]
		ensure: [
			self endpoint
				graphConfigSet: (Dictionary new at: 'TIMEOUT_DEFAULT' put: originalValue; yourself) ]
]

{ #category : 'private' }
FkGraphEndpointTest >> createConstraintType: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	^ self endpoint
		graphConstraintCreate: self graphName
		type: constraintType
		entityType: entityType
		entityName: entityName
		properties: propertiesCollection
]

{ #category : 'private' }
FkGraphEndpointTest >> dropConstraintType: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	^ self endpoint
		graphConstraintDrop: self graphName
		type: constraintType
		entityType: entityType
		entityName: entityName
		properties: propertiesCollection
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateMandatoryOnNodeSucceeds [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self
		createConstraintType: 'MANDATORY'
		entityType: 'NODE'
		entityName: 'Person'
		properties: #('name').
	self assert: reply equals: 'PENDING'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateUniqueOnNodeSucceeds [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {email: ''alice@example.com''})'.
	self endpoint graphQuery: self graphName cypher: 'CREATE INDEX FOR (n:Person) ON (n.email)'.
	reply := self createConstraintType: 'UNIQUE' entityType: 'NODE' entityName: 'Person' properties: #('email').
	self assert: reply equals: 'PENDING'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintDropRemovesConstraint [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	self createConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name').
	reply := self
		dropConstraintType: 'MANDATORY'
		entityType: 'NODE'
		entityName: 'Person'
		properties: #('name').
	self assert: reply equals: 'OK'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphExplainAnswersNonEmptyPlan [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphExplain: self graphName cypher: 'MATCH (p:Person) RETURN p'.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphExplainWithParamsAnswersNonEmptyPlan [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint
		graphExplain: self graphName
		cypher: 'MATCH (p:Person {name: $name}) RETURN p'
		params: (Dictionary new at: 'name' put: 'Alice'; yourself).
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphProfileAnswersNonEmptyReply [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphProfile: self graphName cypher: 'MATCH (p:Person) RETURN p'.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphProfileWithParamsAnswersNonEmptyReply [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint
		graphProfile: self graphName
		cypher: 'MATCH (p:Person {name: $name}) RETURN p'
		params: (Dictionary new at: 'name' put: 'Alice'; yourself).
	self deny: reply isEmpty
]

{ #category : 'private' }
FkGraphEndpointTest >> deleteGraphIgnoringErrors: graphName [
	[ self endpoint graphDelete: graphName ] on: Error do: [ :ex |  ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphListIncludesCreatedGraph [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	reply := self endpoint graphList.
	self assert: (reply includes: self graphName)
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphCopyCopiesGraphData [
	| destGraphName reply result |
	destGraphName := self graphName , '_copyDest'.
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	[
		self endpoint graphCopy: self graphName to: destGraphName.
		reply := self endpoint graphList.
		self assert: (reply includes: destGraphName).
		result := self endpoint graphQuery: destGraphName cypher: 'MATCH (p:Person) RETURN p.name'.
		self assert: result records first first equals: 'Alice' ]
		ensure: [ self deleteGraphIgnoringErrors: destGraphName ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphMemoryUsageAnswersDictionaryWithData [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphMemoryUsage: self graphName.
	self assert: reply class equals: Dictionary.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphMemoryUsageWithSamplesAnswersDictionaryWithData [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphMemoryUsage: self graphName samples: 5.
	self assert: reply class equals: Dictionary.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphSlowLogAnswersEntriesForSlowQuery [
	| reply entry |
	self endpoint graphQuery: self graphName cypher: 'UNWIND range(1, 200000) AS x RETURN sum(x)'.
	reply := self endpoint graphSlowLog: self graphName.
	self assert: reply class equals: OrderedCollection.
	self deny: reply isEmpty.
	entry := reply first.
	self assert: entry class equals: FkSlowLogEntry.
	self assert: entry command equals: 'GRAPH.QUERY'.
	self assert: entry query equals: 'UNWIND range(1, 200000) AS x RETURN sum(x)'.
	self assert: entry executionTimeMs asNumber > 0.
	self assert: entry timestamp notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphSlowLogAnswersEmptyForGraphWithoutSlowQueries [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphSlowLog: self graphName.
	self assert: reply class equals: OrderedCollection.
	self assert: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintOnRelationshipTypeCreateAndDrop [
	| createReply dropReply |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)-[:KNOWS {since: 2020}]->(:Person)'.
	createReply := self createConstraintType: 'MANDATORY' entityType: 'RELATIONSHIP' entityName: 'KNOWS' properties: #('since').
	self assert: createReply equals: 'PENDING'.
	dropReply := self dropConstraintType: 'MANDATORY' entityType: 'RELATIONSHIP' entityName: 'KNOWS' properties: #('since').
	self assert: dropReply equals: 'OK'
]
