"
I test FkGraphNode's delegating read accessors and its propertyAt:put: mutation against a real
FalkorDB instance.

Coverage:
- graph-object-api spec: ""Reading delegates to the wrapped node""
- graph-object-api spec: ""Writing a property updates the graph and refreshes local state""
- graph-object-api spec: ""No local-only mutation""
"
Class {
	#name : 'FkGraphNodeTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Objects-Tests',
	#package : 'FalkorSt-Objects-Tests'
}

{ #category : 'accessing' }
FkGraphNodeTest >> db [
	^ FkGraphDb on: stick named: self graphName
]

{ #category : 'creating' }
FkGraphNodeTest >> createGraphNode [
	| rawNode |
	rawNode := self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person {name: ''Alice'', age: 30}) RETURN p'.
	^ FkGraphNode on: rawNode records first first in: self db
]

{ #category : 'tests' }
FkGraphNodeTest >> testNoLocalOnlyMutation [
	| graphNode originalRawNode |
	graphNode := self createGraphNode.
	originalRawNode := graphNode rawNode.
	graphNode propertyAt: 'age' put: 31.
	self deny: graphNode rawNode == originalRawNode.
	self assert: (originalRawNode properties at: 'age') equals: 30
]

{ #category : 'tests' }
FkGraphNodeTest >> testReadingDelegatesToTheWrappedNode [
	| graphNode |
	graphNode := self createGraphNode.
	self assert: graphNode id equals: graphNode rawNode id.
	self assertCollection: graphNode labels asArray equals: graphNode rawNode labels asArray.
	self assert: graphNode properties equals: graphNode rawNode properties.
	self assert: (graphNode propertyAt: 'name') equals: (graphNode rawNode properties at: 'name')
]

{ #category : 'tests' }
FkGraphNodeTest >> testWritingAPropertyUpdatesTheGraphAndRefreshesLocalState [
	| graphNode |
	graphNode := self createGraphNode.
	graphNode propertyAt: 'age' put: 31.
	self assert: (graphNode propertyAt: 'age') equals: 31.
	self assert: ((self endpoint graphQuery: self graphName cypher: 'MATCH (p) RETURN p.age')
		records first first) equals: 31
]
