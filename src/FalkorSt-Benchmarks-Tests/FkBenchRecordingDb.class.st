"
I am a test stand-in for FkGraphDb / N4GraphDb: I record every message I receive (blocks dropped from
the arguments, since they cannot be compared) and answer myself. #id answers a number unique to the
latest recorded message, so created nodes get distinct ids.

Public API and Key Messages:
- #recordedMessages - Array of { selector. non-block arguments }
- #recordedSelectors
"
Class {
	#name : 'FkBenchRecordingDb',
	#superclass : 'Object',
	#instVars : [
		'recordedMessages'
	],
	#category : 'FalkorSt-Benchmarks-Tests',
	#package : 'FalkorSt-Benchmarks-Tests'
}

{ #category : 'reflective operations' }
FkBenchRecordingDb >> doesNotUnderstand: aMessage [
	self recordedMessages add: {
			aMessage selector.
			(aMessage arguments reject: [ :each | each isBlock ]) }.
	^ self
]

{ #category : 'accessing' }
FkBenchRecordingDb >> id [
	^ self recordedMessages size
]

{ #category : 'accessing' }
FkBenchRecordingDb >> recordedMessages [
	^ recordedMessages ifNil: [ recordedMessages := OrderedCollection new ]
]

{ #category : 'accessing' }
FkBenchRecordingDb >> recordedSelectors [
	^ self recordedMessages collect: [ :each | each first ]
]
