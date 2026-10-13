"
I define the size of a benchmark dataset by its Person count; every other count is derived from it
with fixed ratios (Post 2N, FRIEND 5N, POSTED 2N, LIKES 5N).

Responsibility:
- Name a scale (S / M / L) and answer the node and relationship counts for it

Collaborators:
- FkBenchDatasetGenerator: reads my counts
- FkBenchReport: prints my name

Public API and Key Messages:
- FkBenchScale class >> small / medium / large - 1,000 / 10,000 / 100,000 Persons
- FkBenchScale class >> named:personCount: - a custom scale
- #personCount and the counts derived from it
"
Class {
	#name : 'FkBenchScale',
	#superclass : 'Object',
	#instVars : [
		'name',
		'personCount'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'instance creation' }
FkBenchScale class >> large [
	^ self named: 'L' personCount: 100000
]

{ #category : 'instance creation' }
FkBenchScale class >> medium [
	^ self named: 'M' personCount: 10000
]

{ #category : 'instance creation' }
FkBenchScale class >> named: aString personCount: anInteger [
	^ self new
		name: aString;
		personCount: anInteger;
		yourself
]

{ #category : 'instance creation' }
FkBenchScale class >> small [
	^ self named: 'S' personCount: 1000
]

{ #category : 'accessing' }
FkBenchScale >> friendshipCount [
	^ self personCount * 5
]

{ #category : 'accessing' }
FkBenchScale >> likeCount [
	^ self personCount * 5
]

{ #category : 'accessing' }
FkBenchScale >> name [
	^ name
]

{ #category : 'accessing' }
FkBenchScale >> name: aString [
	name := aString
]

{ #category : 'accessing' }
FkBenchScale >> personCount [
	^ personCount
]

{ #category : 'accessing' }
FkBenchScale >> personCount: anInteger [
	personCount := anInteger
]

{ #category : 'accessing' }
FkBenchScale >> postCount [
	^ self personCount * 2
]

{ #category : 'accessing' }
FkBenchScale >> postingCount [
	^ self postCount
]

{ #category : 'printing' }
FkBenchScale >> printOn: aStream [
	aStream
		nextPutAll: self name;
		nextPutAll: ' (';
		print: self personCount;
		nextPutAll: ' persons)'
]
