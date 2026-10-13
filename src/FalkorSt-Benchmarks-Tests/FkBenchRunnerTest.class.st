"
I test FkBenchRunner's workload against an FkBenchRecordingTarget, without a database.

Coverage:
- performance-benchmark spec: ""Load phase""
- performance-benchmark spec: ""Query phase""
- performance-benchmark spec: ""Identical workload across targets""
- performance-benchmark spec: ""Server warm-up""
"
Class {
	#name : 'FkBenchRunnerTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Benchmarks-Tests',
	#package : 'FalkorSt-Benchmarks-Tests'
}

{ #category : 'private' }
FkBenchRunnerTest >> runnerOn: aFkBenchTarget [
	^ FkBenchRunner new
		  scale: (FkBenchScale named: 'T' personCount: 20);
		  seed: 7;
		  warmup: 2;
		  iterations: 5;
		  target: aFkBenchTarget;
		  yourself
]

{ #category : 'private' }
FkBenchRunnerTest >> runnerRunOn: aFkBenchTarget [
	| runner |
	runner := self runnerOn: aFkBenchTarget.
	runner
		loadPhase;
		queryPhase.
	^ runner
]

{ #category : 'tests' }
FkBenchRunnerTest >> testDeleteRunsLastAndIsCappedToPersonCount [
	| runner selectors |
	runner := self runnerOn: FkBenchRecordingTarget new.
	runner iterations: 100.
	runner
		loadPhase;
		queryPhase.
	selectors := runner db recordedSelectors.
	self assert: selectors last equals: #deleteNodeAt:withRelations:.
	self assert: (selectors occurrencesOf: #deleteNodeAt:withRelations:) equals: 20.
	self assert: (runner samplesNamed: 'D-node') count equals: 18
]

{ #category : 'tests' }
FkBenchRunnerTest >> testDeletesDistinctPersons [
	| runner deletedIds |
	runner := self runnerRunOn: FkBenchRecordingTarget new.
	deletedIds := (runner db recordedMessages select: [ :each |
		               each first = #deleteNodeAt:withRelations: ]) collect: [ :each |
		              each second first ].
	self assert: deletedIds asSet size equals: deletedIds size.
	self assert: (deletedIds allSatisfy: [ :each | runner personDbIds includes: each ])
]

{ #category : 'tests' }
FkBenchRunnerTest >> testLoadPhaseInsertsWholeDataset [
	| runner |
	runner := self runnerOn: FkBenchRecordingTarget new.
	runner loadPhase.
	self assert: (runner samplesNamed: 'C-node') count equals: 20 + 40.
	self assert: (runner samplesNamed: 'C-rel') count equals: 100 + 40 + 100.
	self assert: runner loadOperationCount equals: 300.
	self assert: runner loadElapsedMicroseconds >= 0.
	self assert: runner serverVersion equals: 'Recording 1.0'
]

{ #category : 'tests' }
FkBenchRunnerTest >> testQueryPhaseRunsEveryOperation [
	| runner |
	runner := self runnerRunOn: FkBenchRecordingTarget new.
	self
		assert: runner samples keys asArray
		equals: #( 'C-node' 'C-rel' 'R-id' 'R-prop' 'R-where' 'R-hop' 'R-count' 'U-prop' 'U-merge' 'D-node' ).
	(runner samples values allButFirst: 2) do: [ :each | self assert: each count equals: 5 ].
	self assert: (runner db recordedSelectors occurrencesOf: #countNodesLabeled:) equals: 2 + 5
]

{ #category : 'tests' }
FkBenchRunnerTest >> testSameConfigurationIssuesSameWorkload [
	self
		assert: (self runnerRunOn: (FkBenchRecordingTarget labeled: 'A')) db recordedMessages
		equals: (self runnerRunOn: (FkBenchRecordingTarget labeled: 'B')) db recordedMessages
]

{ #category : 'tests' }
FkBenchRunnerTest >> testServerWarmupExercisesTargetWithoutRecordingSamples [
	| target runner |
	target := FkBenchRecordingTarget new.
	runner := self runnerOn: target.
	runner serverWarmupPhaseWithPersons: 10.
	self assert: runner samples isEmpty.
	self assert: (target db recordedSelectors includes: #createNodeLabeled:properties:).
	self assert: (target db recordedSelectors includes: #deleteNodeAt:withRelations:).
	self assert: target resetCount equals: 2
]

{ #category : 'tests' }
FkBenchRunnerTest >> testServerWarmupLeavesMeasuredWorkloadUnchanged [
	| warmedTarget warmedRunner coldRunner warmupMessageCount |
	warmedTarget := FkBenchRecordingTarget new.
	warmedRunner := self runnerOn: warmedTarget.
	warmedRunner serverWarmupPhaseWithPersons: 10.
	warmupMessageCount := warmedTarget db recordedMessages size.
	warmedRunner
		loadPhase;
		queryPhase.
	coldRunner := self runnerRunOn: FkBenchRecordingTarget new.
	self
		assert: (warmedTarget db recordedMessages allButFirst: warmupMessageCount) size
		equals: coldRunner db recordedMessages size.
	self assert: warmedRunner samples keys equals: coldRunner samples keys
]

{ #category : 'tests' }
FkBenchRunnerTest >> testSamplesCarryTargetLabel [
	| runner |
	runner := self runnerRunOn: (FkBenchRecordingTarget labeled: 'A').
	self assert: (runner samples values allSatisfy: [ :each | each targetLabel = 'A' ])
]
