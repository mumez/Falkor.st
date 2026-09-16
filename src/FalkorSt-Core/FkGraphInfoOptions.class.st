"
I am the options object for FkGraphEndpoint>>#graphInfo:, collecting which GRAPH.INFO sections
(RunningQueries, WaitingQueries, ObjectPool) to request. Omitting all sections is a valid request
that means ""all sections"" server-side, so I don't default any of my three flags - I only ever
add a section name to #asArray when its flag is explicitly true.

Responsibility:
- Hold nilable Boolean flags for the three GRAPH.INFO sections
- Render the flags set to true as the ordered list of section name strings GRAPH.INFO expects

Collaborators:
- FkGraphEndpoint: creates me, evaluates the caller's options block against me, then appends
  #asArray to the GRAPH.INFO command args

Public API and Key Messages:
- #runningQueries: / #waitingQueries: / #objectPool: - set a section flag
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
	self runningQueries = true ifTrue: [ sections add: 'RunningQueries' ].
	self waitingQueries = true ifTrue: [ sections add: 'WaitingQueries' ].
	self objectPool = true ifTrue: [ sections add: 'ObjectPool' ].
	^ sections
]

{ #category : 'accessing' }
FkGraphInfoOptions >> objectPool [
	^ objectPool
]

{ #category : 'accessing' }
FkGraphInfoOptions >> objectPool: anObject [
	objectPool := anObject
]

{ #category : 'accessing' }
FkGraphInfoOptions >> runningQueries [
	^ runningQueries
]

{ #category : 'accessing' }
FkGraphInfoOptions >> runningQueries: anObject [
	runningQueries := anObject
]

{ #category : 'accessing' }
FkGraphInfoOptions >> waitingQueries [
	^ waitingQueries
]

{ #category : 'accessing' }
FkGraphInfoOptions >> waitingQueries: anObject [
	waitingQueries := anObject
]
