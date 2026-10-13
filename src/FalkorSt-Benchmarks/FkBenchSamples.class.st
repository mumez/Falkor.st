"
I collect the latency samples of one benchmark operation on one target and answer their statistics.
Samples are added in microseconds; every statistic is answered in milliseconds except #count and
#opsPerSecond.

Responsibility:
- Hold the operation name, target label, and raw microsecond samples
- Answer count, mean, median (average of the middle pair for an even count), nearest-rank
  percentiles (p95, p99), min, max, total, and ops/sec (count divided by the summed latency;
  nil when that sum is zero)

Collaborators:
- FkBenchRunner: creates and fills me
- FkBenchReport: renders my statistics

Public API and Key Messages:
- FkBenchSamples class >> operation:target:
- #addMicroseconds:
- #count / #mean / #median / #p95 / #p99 / #percentile: / #min / #max / #totalMilliseconds / #opsPerSecond
"
Class {
	#name : 'FkBenchSamples',
	#superclass : 'Object',
	#instVars : [
		'operationName',
		'targetLabel',
		'microseconds'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'instance creation' }
FkBenchSamples class >> operation: operationName target: targetLabel [
	^ self new
		operationName: operationName;
		targetLabel: targetLabel;
		yourself
]

{ #category : 'adding' }
FkBenchSamples >> addMicroseconds: anInteger [
	self microseconds add: anInteger
]

{ #category : 'statistics' }
FkBenchSamples >> count [
	^ self microseconds size
]

{ #category : 'statistics' }
FkBenchSamples >> max [
	^ self millisecondsFrom: self microseconds max
]

{ #category : 'statistics' }
FkBenchSamples >> mean [
	^ self totalMilliseconds / self count
]

{ #category : 'statistics' }
FkBenchSamples >> median [
	| sorted middle |
	sorted := self sortedMicroseconds.
	middle := sorted size + 1 // 2.
	sorted size even ifTrue: [
		^ self millisecondsFrom: ((sorted at: middle) + (sorted at: middle + 1)) / 2 ].
	^ self millisecondsFrom: (sorted at: middle)
]

{ #category : 'accessing' }
FkBenchSamples >> microseconds [
	^ microseconds ifNil: [ microseconds := OrderedCollection new ]
]

{ #category : 'private' }
FkBenchSamples >> millisecondsFrom: microsecondValue [
	^ microsecondValue / 1000
]

{ #category : 'statistics' }
FkBenchSamples >> min [
	^ self millisecondsFrom: self microseconds min
]

{ #category : 'accessing' }
FkBenchSamples >> operationName [
	^ operationName
]

{ #category : 'accessing' }
FkBenchSamples >> operationName: aString [
	operationName := aString
]

{ #category : 'statistics' }
FkBenchSamples >> opsPerSecond [
	"Answer nil when the samples sum to zero time (no meaningful rate)"

	self totalMilliseconds isZero ifTrue: [ ^ nil ].
	^ self count * 1000 / self totalMilliseconds
]

{ #category : 'statistics' }
FkBenchSamples >> p95 [
	^ self percentile: 95
]

{ #category : 'statistics' }
FkBenchSamples >> p99 [
	^ self percentile: 99
]

{ #category : 'statistics' }
FkBenchSamples >> percentile: percent [
	"Nearest-rank percentile"

	| sorted rank |
	sorted := self sortedMicroseconds.
	rank := (percent / 100 * sorted size) ceiling max: 1.
	^ self millisecondsFrom: (sorted at: rank)
]

{ #category : 'private' }
FkBenchSamples >> sortedMicroseconds [
	^ self microseconds asSortedCollection asArray
]

{ #category : 'accessing' }
FkBenchSamples >> targetLabel [
	^ targetLabel
]

{ #category : 'accessing' }
FkBenchSamples >> targetLabel: aString [
	targetLabel := aString
]

{ #category : 'statistics' }
FkBenchSamples >> totalMilliseconds [
	^ self millisecondsFrom: self microseconds sum
]
