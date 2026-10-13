"
I render the results of one or more FkBenchRunners as Markdown: a header naming the configuration
(taken from the first runner; runners are expected to share scale, seed, warmup, and iterations) and
the server version of each target, a load-phase summary table, and a latency table with one row per
(operation, target), targets adjacent. Numbers have 3 decimals; an undefined rate prints as n/a.

Collaborators:
- FkBenchRunner: supplies configuration, load totals, and FkBenchSamples

Public API and Key Messages:
- FkBenchReport class >> fromRunners:
- #asMarkdown
"
Class {
	#name : 'FkBenchReport',
	#superclass : 'Object',
	#instVars : [
		'runners'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'instance creation' }
FkBenchReport class >> fromRunners: aCollection [
	^ self new
		runners: aCollection;
		yourself
]

{ #category : 'rendering' }
FkBenchReport >> asMarkdown [
	^ String streamContents: [ :stream |
		  self printHeaderOn: stream.
		  self printLoadTableOn: stream.
		  self printLatencyTableOn: stream ]
]

{ #category : 'formatting' }
FkBenchReport >> formatNumber: aNumberOrNil [
	aNumberOrNil ifNil: [ ^ 'n/a' ].
	^ aNumberOrNil printShowingDecimalPlaces: 3
]

{ #category : 'private' }
FkBenchReport >> loadOpsPerSecondOf: aFkBenchRunner [
	aFkBenchRunner loadElapsedMicroseconds isZero ifTrue: [ ^ nil ].
	^ aFkBenchRunner loadOperationCount * 1000000 / aFkBenchRunner loadElapsedMicroseconds
]

{ #category : 'private' }
FkBenchReport >> operationNames [
	"Every operation name in first-run order across all runners"

	| names |
	names := OrderedCollection new.
	self runners do: [ :each |
		each samples keysDo: [ :name | names addIfNotPresent: name ] ].
	^ names asArray
]

{ #category : 'rendering' }
FkBenchReport >> printHeaderOn: aStream [
	| first |
	first := self runners first.
	aStream
		nextPutAll: ('## Scale {1}, seed {2}, warmup {3}, iterations {4}' format: {
						 first scale printString.
						 first seed.
						 first warmup.
						 first iterations });
		cr;
		cr;
		nextPutAll: 'Targets: ';
		nextPutAll: (', ' join: (self runners collect: [ :each |
						   each target label , ' (' , each serverVersion asString , ')' ]));
		cr
]

{ #category : 'rendering' }
FkBenchReport >> printLatencyTableOn: aStream [
	aStream
		cr;
		nextPutAll: '### Latency (ms)';
		cr;
		cr;
		nextPutAll: '| Operation | Target | Count | Mean | Median | p95 | p99 | ops/sec |';
		cr;
		nextPutAll: '|---|---|---:|---:|---:|---:|---:|---:|';
		cr.
	self operationNames do: [ :operationName |
		self runners do: [ :each |
			each samples at: operationName ifPresent: [ :samples | self printSamples: samples on: aStream ] ] ]
]

{ #category : 'rendering' }
FkBenchReport >> printLoadTableOn: aStream [
	aStream
		cr;
		nextPutAll: '### Load phase';
		cr;
		cr;
		nextPutAll: '| Target | Operations | Total (s) | ops/sec |';
		cr;
		nextPutAll: '|---|---:|---:|---:|';
		cr.
	self runners do: [ :each |
		self printRow: {
				each target label.
				each loadOperationCount printString.
				(self formatNumber: each loadElapsedMicroseconds / 1000000).
				(self formatNumber: (self loadOpsPerSecondOf: each)) } on: aStream ]
]

{ #category : 'rendering' }
FkBenchReport >> printRow: cellStrings on: aStream [
	aStream
		nextPutAll: '| ';
		nextPutAll: (' | ' join: cellStrings);
		nextPutAll: ' |';
		cr
]

{ #category : 'rendering' }
FkBenchReport >> printSamples: aFkBenchSamples on: aStream [
	self
		printRow: {
				aFkBenchSamples operationName.
				aFkBenchSamples targetLabel.
				aFkBenchSamples count printString } , ({
				 aFkBenchSamples mean.
				 aFkBenchSamples median.
				 aFkBenchSamples p95.
				 aFkBenchSamples p99.
				 aFkBenchSamples opsPerSecond } collect: [ :each | self formatNumber: each ])
		on: aStream
]

{ #category : 'accessing' }
FkBenchReport >> runners [
	^ runners
]

{ #category : 'accessing' }
FkBenchReport >> runners: aCollection [
	runners := aCollection
]
