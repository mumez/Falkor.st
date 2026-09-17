"
I test FkGraphEndpoint's command-level behavior against a real FalkorDB instance for commands
that are not primarily about FkQueryResult decoding: GRAPH.RO_QUERY, GRAPH.DELETE, GRAPH.INFO,
GRAPH.CONFIG, GRAPH.CONSTRAINT, GRAPH.EXPLAIN, and GRAPH.PROFILE.

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
