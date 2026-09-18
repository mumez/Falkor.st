"
I test FkGraphPath's wrapping of a hand-built FkPath's nodes and relationships. No live FalkorDB
connection is needed - FkGraphPath only wraps raw values it is handed, it never queries.

Coverage:
- graph-object-api spec: ""Wrapping a path's nodes and relationships""
"
Class {
	#name : 'FkGraphPathTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Objects-Tests',
	#package : 'FalkorSt-Objects-Tests'
}

{ #category : 'creating' }
FkGraphPathTest >> createGraphPath [
	| rawStart rawEnd rawRel rawPath |
	rawStart := FkNode id: 1 labels: #('Person') properties: { 'name' -> 'Alice' } asDictionary.
	rawEnd := FkNode id: 2 labels: #('Person') properties: { 'name' -> 'Bob' } asDictionary.
	rawRel := FkRelationship
		id: 10
		type: 'KNOWS'
		startNodeId: 1
		endNodeId: 2
		properties: Dictionary new.
	rawPath := FkPath nodes: (OrderedCollection with: rawStart with: rawEnd)
		relationships: (OrderedCollection with: rawRel).
	^ FkGraphPath on: rawPath in: nil
]

{ #category : 'tests' }
FkGraphPathTest >> testEndNodeAnswersTheLastWrappedNode [
	| graphPath |
	graphPath := self createGraphPath.
	self assert: graphPath endNode id equals: 2
]

{ #category : 'tests' }
FkGraphPathTest >> testNodesAnswersEachElementWrappedAsAFkGraphNode [
	| graphPath nodes |
	graphPath := self createGraphPath.
	nodes := graphPath nodes.
	self assert: nodes size equals: 2.
	self assert: (nodes allSatisfy: [ :each | each class == FkGraphNode ]).
	self assert: nodes first id equals: 1.
	self assert: nodes last id equals: 2
]

{ #category : 'tests' }
FkGraphPathTest >> testRawPathAnswersTheWrappedRawPath [
	| rawPath graphPath |
	rawPath := FkPath nodes: OrderedCollection new relationships: OrderedCollection new.
	graphPath := FkGraphPath on: rawPath in: nil.
	self assert: graphPath rawPath == rawPath
]

{ #category : 'tests' }
FkGraphPathTest >> testRelationshipsAnswersEachElementWrappedAsAFkGraphRelationship [
	| graphPath relationships |
	graphPath := self createGraphPath.
	relationships := graphPath relationships.
	self assert: relationships size equals: 1.
	self assert: relationships first class equals: FkGraphRelationship.
	self assert: relationships first id equals: 10.
	self assert: relationships first type equals: 'KNOWS'
]

{ #category : 'tests' }
FkGraphPathTest >> testStartNodeAnswersTheFirstWrappedNode [
	| graphPath |
	graphPath := self createGraphPath.
	self assert: graphPath startNode id equals: 1
]
