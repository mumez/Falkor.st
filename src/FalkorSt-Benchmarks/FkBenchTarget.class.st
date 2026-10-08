"
I am the abstract database a benchmark runs against. I only cover what genuinely differs between
databases - connecting, wiping the graph, creating the benchmark indexes, and reporting the server
version. The workload itself is sent by FkBenchRunner directly to my #db, using selectors shared by
FkGraphDb and N4GraphDb.

Responsibility:
- Lazily create the high-level graph handle (#db) through #createDb
- Prepare an empty graph with range indexes on Person(id) and Post(id) (#prepare)

Collaborators:
- FkBenchRunner: drives the workload through my #db
- FkBenchFalkorTarget / FkBenchNeo4jTarget: my concrete subclasses

Public API and Key Messages:
- #db / #label / #serverVersion / #prepare / #close
"
Class {
	#name : 'FkBenchTarget',
	#superclass : 'Object',
	#instVars : [
		'db'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'connecting' }
FkBenchTarget >> close [
	self subclassResponsibility
]

{ #category : 'private' }
FkBenchTarget >> createDb [
	self subclassResponsibility
]

{ #category : 'preparing' }
FkBenchTarget >> createIndexes [
	self subclassResponsibility
]

{ #category : 'accessing' }
FkBenchTarget >> db [
	^ db ifNil: [ db := self createDb ]
]

{ #category : 'constants' }
FkBenchTarget >> indexedLabels [
	^ #( 'Person' 'Post' )
]

{ #category : 'accessing' }
FkBenchTarget >> label [
	self subclassResponsibility
]

{ #category : 'preparing' }
FkBenchTarget >> prepare [
	self resetGraph.
	self createIndexes
]

{ #category : 'printing' }
FkBenchTarget >> printOn: aStream [
	aStream nextPutAll: self label
]

{ #category : 'preparing' }
FkBenchTarget >> resetGraph [
	self subclassResponsibility
]

{ #category : 'accessing' }
FkBenchTarget >> serverVersion [
	self subclassResponsibility
]
