"
I am one relationship of a generated benchmark dataset, expressed with dataset ids (not database ids):
the 'id' property of my start and end nodes, plus my own properties.

Responsibility:
- Hold fromId, toId, and a properties collection of associations
- Compare equal to another edge with the same values, so datasets can be compared and de-duplicated

Collaborators:
- FkBenchDatasetGenerator: creates me
- FkBenchRunner: maps my ids to database ids when inserting me

Public API and Key Messages:
- FkBenchEdge class >> from:to:properties:
- #fromId / #toId / #properties
"
Class {
	#name : 'FkBenchEdge',
	#superclass : 'Object',
	#instVars : [
		'fromId',
		'toId',
		'properties'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'instance creation' }
FkBenchEdge class >> from: startId to: endId properties: assocArray [
	^ self new
		fromId: startId;
		toId: endId;
		properties: assocArray;
		yourself
]

{ #category : 'comparing' }
FkBenchEdge >> = anObject [
	self == anObject ifTrue: [ ^ true ].
	self class = anObject class ifFalse: [ ^ false ].
	^ self fromId = anObject fromId and: [
		  self toId = anObject toId and: [ self properties = anObject properties ] ]
]

{ #category : 'accessing' }
FkBenchEdge >> fromId [
	^ fromId
]

{ #category : 'accessing' }
FkBenchEdge >> fromId: anInteger [
	fromId := anInteger
]

{ #category : 'comparing' }
FkBenchEdge >> hash [
	^ (self fromId hash bitXor: self toId hash) bitXor: self properties hash
]

{ #category : 'printing' }
FkBenchEdge >> printOn: aStream [
	aStream
		print: self fromId;
		nextPutAll: '->';
		print: self toId
]

{ #category : 'accessing' }
FkBenchEdge >> properties [
	^ properties
]

{ #category : 'accessing' }
FkBenchEdge >> properties: assocArray [
	properties := assocArray
]

{ #category : 'accessing' }
FkBenchEdge >> toId [
	^ toId
]

{ #category : 'accessing' }
FkBenchEdge >> toId: anInteger [
	toId := anInteger
]
