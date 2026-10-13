"
I test FkBenchReport's Markdown rendering from runners driven against FkBenchRecordingTargets, so no
database is needed. Timings vary, so I check structure and formatting rather than values.

Coverage:
- performance-benchmark spec: ""Two-target comparison""
"
Class {
	#name : 'FkBenchReportTest',
	#superclass : 'TestCase',
	#instVars : [
		'markdownLines'
	],
	#category : 'FalkorSt-Benchmarks-Tests',
	#package : 'FalkorSt-Benchmarks-Tests'
}

{ #category : 'private' }
FkBenchReportTest >> linesStartingWith: prefix [
	^ self markdownLines select: [ :each | each beginsWith: prefix ]
]

{ #category : 'private' }
FkBenchReportTest >> runnerOn: targetLabel [
	^ FkBenchRunner new
		  scale: (FkBenchScale named: 'T' personCount: 10);
		  seed: 7;
		  warmup: 2;
		  iterations: 5;
		  target: (FkBenchRecordingTarget labeled: targetLabel);
		  loadPhase;
		  queryPhase;
		  yourself
]

{ #category : 'accessing' }
FkBenchReportTest >> markdownLines [
	^ markdownLines ifNil: [
		  markdownLines := (FkBenchReport fromRunners: {
				                    (self runnerOn: 'A').
				                    (self runnerOn: 'B') }) asMarkdown lines ]
]

{ #category : 'tests' }
FkBenchReportTest >> testFormatsNumbersWithThreeDecimals [
	self assert: (FkBenchReport new formatNumber: 1 / 3) equals: '0.333'.
	self assert: (FkBenchReport new formatNumber: 2) equals: '2.000'
]

{ #category : 'tests' }
FkBenchReportTest >> testHeaderNamesConfigurationAndTargets [
	self assert: self markdownLines first equals: '## Scale T (10 persons), seed 7, warmup 2, iterations 5'.
	self assert: (self markdownLines includes: 'Targets: A (A 1.0), B (B 1.0)')
]

{ #category : 'tests' }
FkBenchReportTest >> testLatencyRowsAreAdjacentPerOperation [
	| rIdRows |
	rIdRows := self linesStartingWith: '| R-id |'.
	self assert: rIdRows size equals: 2.
	self assert: (rIdRows first beginsWith: '| R-id | A | 5 | ').
	self assert: (rIdRows second beginsWith: '| R-id | B | 5 | ').
	self
		assert: (self markdownLines indexOf: rIdRows second)
		equals: (self markdownLines indexOf: rIdRows first) + 1
]

{ #category : 'tests' }
FkBenchReportTest >> testLatencyTableHasEveryOperationPerTarget [
	self
		assert: (self markdownLines includes: '| Operation | Target | Count | Mean | Median | p95 | p99 | ops/sec |').
	#( 'C-node' 'C-rel' 'R-id' 'R-prop' 'R-where' 'R-hop' 'R-count' 'U-prop' 'U-merge' 'D-node' )
		do: [ :each | self assert: (self linesStartingWith: '| ' , each , ' |') size equals: 2 ]
]

{ #category : 'tests' }
FkBenchReportTest >> testLoadTableHasOneRowPerTarget [
	self assert: (self markdownLines includes: '| Target | Operations | Total (s) | ops/sec |').
	self assert: (self linesStartingWith: '| A | 150 | ') size equals: 1.
	self assert: (self linesStartingWith: '| B | 150 | ') size equals: 1
]
