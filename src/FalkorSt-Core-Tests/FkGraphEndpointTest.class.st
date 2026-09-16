"
I test FkGraphEndpoint's command-level behavior against a real FalkorDB instance for commands
that are not primarily about FkQueryResult decoding: GRAPH.RO_QUERY, GRAPH.DELETE, GRAPH.INFO, and
GRAPH.CONFIG.

Coverage:
- graph-ro-query spec: read-only Cypher query execution, same result-set shape as GRAPH.QUERY
- graph-delete spec: deleting a graph answers a plain status string reply
- graph-info spec: server status query, with and without section options
- graph-config spec: getting one or all config parameters, and setting a runtime parameter
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
	| reply |
	self endpoint graphConfigSet: (Dictionary new at: 'TIMEOUT_DEFAULT' put: 5000; yourself).
	reply := self endpoint graphConfigGet: 'TIMEOUT_DEFAULT'.
	self assert: reply second equals: 5000.
	self endpoint graphConfigSet: (Dictionary new at: 'TIMEOUT_DEFAULT' put: 0; yourself)
]
