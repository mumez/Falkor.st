"
I am a test FkBenchTarget backed by an FkBenchRecordingDb, so FkBenchRunner and FkBenchReport can be
tested without a database. Preparing and closing do nothing.
"
Class {
	#name : 'FkBenchRecordingTarget',
	#superclass : 'FkBenchTarget',
	#instVars : [
		'label'
	],
	#category : 'FalkorSt-Benchmarks-Tests',
	#package : 'FalkorSt-Benchmarks-Tests'
}

{ #category : 'instance creation' }
FkBenchRecordingTarget class >> labeled: aString [
	^ self new
		label: aString;
		yourself
]

{ #category : 'connecting' }
FkBenchRecordingTarget >> close [
]

{ #category : 'private' }
FkBenchRecordingTarget >> createDb [
	^ FkBenchRecordingDb new
]

{ #category : 'preparing' }
FkBenchRecordingTarget >> createIndexes [
]

{ #category : 'accessing' }
FkBenchRecordingTarget >> label [
	^ label ifNil: [ label := 'Recording' ]
]

{ #category : 'accessing' }
FkBenchRecordingTarget >> label: aString [
	label := aString
]

{ #category : 'preparing' }
FkBenchRecordingTarget >> resetGraph [
]

{ #category : 'accessing' }
FkBenchRecordingTarget >> serverVersion [
	^ self label , ' 1.0'
]
