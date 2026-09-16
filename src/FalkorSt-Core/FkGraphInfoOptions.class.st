"
I am the options object for FkGraphEndpoint>>#graphInfo:, collecting which GRAPH.INFO sections
(RunningQueries, WaitingQueries, ObjectPool) to request. Omitting all sections is a valid request
that means ""all sections"" server-side, so my three flags default to false - I only ever add a
section name to #asArray when its flag is explicitly set true.

Responsibility:
- Hold Boolean flags for the three GRAPH.INFO sections, defaulting to false
- Render the flags set to true as the ordered list of section name strings GRAPH.INFO expects

Collaborators:
- FkGraphEndpoint: creates me, evaluates the caller's options block against me, then appends
  #asArray to the GRAPH.INFO command args

Public API and Key Messages:
- #runningQueries: / #waitingQueries: / #objectPool: - set a section flag
- #showRunningQueries / #showWaitingQueries / #showObjectPool - shortcuts to set a section flag
  to true
- #asArray - answer the section name strings for every flag set to true, in RunningQueries,
  WaitingQueries, ObjectPool order
"
Class {
	#name : 'FkGraphInfoOptions',
	#superclass : 'Object',
	#instVars : [
		'runningQueries',
		'waitingQueries',
		'objectPool'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'converting' }
FkGraphInfoOptions >> asArray [
	| sections |
	sections := OrderedCollection new.
	self runningQueries ifTrue: [ sections add: 'RunningQueries' ].
	self waitingQueries ifTrue: [ sections add: 'WaitingQueries' ].
	self objectPool ifTrue: [ sections add: 'ObjectPool' ].
	^ sections asArray
]

{ #category : 'initialization' }
FkGraphInfoOptions >> initialize [
	super initialize.
	runningQueries := false.
	waitingQueries := false.
	objectPool := false
]

{ #category : 'accessing' }
FkGraphInfoOptions >> objectPool [
	^ objectPool
]

{ #category : 'convenience' }
FkGraphInfoOptions >> showObjectPool [
	self objectPool: true
]

{ #category : 'accessing' }
FkGraphInfoOptions >> objectPool: anObject [
	objectPool := anObject
]

{ #category : 'accessing' }
FkGraphInfoOptions >> runningQueries [
	^ runningQueries
]

{ #category : 'convenience' }
FkGraphInfoOptions >> showRunningQueries [
	self runningQueries: true
]

{ #category : 'accessing' }
FkGraphInfoOptions >> runningQueries: anObject [
	runningQueries := anObject
]

{ #category : 'accessing' }
FkGraphInfoOptions >> waitingQueries [
	^ waitingQueries
]

{ #category : 'convenience' }
FkGraphInfoOptions >> showWaitingQueries [
	self waitingQueries: true
]

{ #category : 'accessing' }
FkGraphInfoOptions >> waitingQueries: anObject [
	waitingQueries := anObject
]
