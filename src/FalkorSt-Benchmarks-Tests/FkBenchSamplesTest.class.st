"
I test FkBenchSamples' latency statistics on known inputs. No database is needed.

Coverage:
- performance-benchmark spec: ""Known samples""
- performance-benchmark spec: ""Single sample""
"
Class {
	#name : 'FkBenchSamplesTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Benchmarks-Tests',
	#package : 'FalkorSt-Benchmarks-Tests'
}

{ #category : 'private' }
FkBenchSamplesTest >> samplesOfMilliseconds: milliseconds [
	| samples |
	samples := FkBenchSamples operation: 'R-id' target: 'FalkorDB'.
	milliseconds do: [ :each | samples addMicroseconds: each * 1000 ].
	^ samples
]

{ #category : 'tests' }
FkBenchSamplesTest >> testEvenCountMedianAveragesMiddlePair [
	self assert: (self samplesOfMilliseconds: #( 4 1 3 2 )) median equals: 2.5
]

{ #category : 'tests' }
FkBenchSamplesTest >> testKnownSamples [
	| samples |
	samples := self samplesOfMilliseconds: #( 3 1 5 2 4 ).
	self assert: samples count equals: 5.
	self assert: samples mean equals: 3.
	self assert: samples median equals: 3.
	self assert: samples min equals: 1.
	self assert: samples max equals: 5.
	self assert: samples totalMilliseconds equals: 15.
	self assert: (samples opsPerSecond closeTo: 333.333 precision: 0.001)
]

{ #category : 'tests' }
FkBenchSamplesTest >> testLabels [
	| samples |
	samples := self samplesOfMilliseconds: #( 1 ).
	self assert: samples operationName equals: 'R-id'.
	self assert: samples targetLabel equals: 'FalkorDB'
]

{ #category : 'tests' }
FkBenchSamplesTest >> testOpsPerSecondIsNilForZeroTotal [
	self assert: (self samplesOfMilliseconds: #( 0 0 )) opsPerSecond isNil
]

{ #category : 'tests' }
FkBenchSamplesTest >> testPercentilesUseNearestRank [
	| samples |
	samples := self samplesOfMilliseconds: (1 to: 100).
	self assert: samples p95 equals: 95.
	self assert: samples p99 equals: 99.
	self assert: (samples percentile: 100) equals: 100
]

{ #category : 'tests' }
FkBenchSamplesTest >> testSingleSample [
	| samples |
	samples := self samplesOfMilliseconds: #( 7 ).
	self assert: samples mean equals: 7.
	self assert: samples median equals: 7.
	self assert: samples p95 equals: 7.
	self assert: samples p99 equals: 7
]
