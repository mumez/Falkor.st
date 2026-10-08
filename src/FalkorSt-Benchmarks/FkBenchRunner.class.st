"
I run the benchmark workload against one FkBenchTarget, sending the selectors shared by FkGraphDb and
N4GraphDb directly to the target's #db, and collect an FkBenchSamples per operation.

The load and query phases are separate messages so that a container-memory snapshot
(scripts/benchmark/memory-snapshot.sh) can be taken between them. Query arguments are drawn from a
Random seeded with #seed, so runners with the same configuration issue the same workload on any target.

Responsibility:
- #loadPhase - prepare the target (reset + unmeasured indexes), insert the generated dataset one call
  at a time (C-node, C-rel samples) and record the total elapsed time
- #queryPhase - run R-id, R-prop, R-where, R-hop, R-count, U-prop, U-merge, then D-node, each with
  #warmup unmeasured and #iterations measured calls. D-node deletes distinct Persons, so its counts
  are capped to the Person count.

Collaborators:
- FkBenchDatasetGenerator / FkBenchScale: the dataset
- FkBenchTarget: the database
- FkBenchSamples: per-operation results, read by FkBenchReport

Public API and Key Messages:
- #scale: / #seed: (default 42) / #warmup: (default 100) / #iterations: (default 1000) / #target:
- #loadPhase / #queryPhase
- #samples / #loadElapsedMicroseconds / #loadOperationCount / #serverVersion
"
Class {
	#name : 'FkBenchRunner',
	#superclass : 'Object',
	#instVars : [
		'scale',
		'seed',
		'warmup',
		'iterations',
		'target',
		'samples',
		'personDbIds',
		'random',
		'loadElapsedMicroseconds',
		'serverVersion'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'private-loading' }
FkBenchRunner >> generateDataset [
	^ FkBenchDatasetGenerator new
		  scale: self scale;
		  seed: self seed;
		  generate
]

{ #category : 'accessing' }
FkBenchRunner >> db [
	^ self target db
]

{ #category : 'private-loading' }
FkBenchRunner >> insertEdges: edges typed: relationshipType from: startDbIds to: endDbIds [
	| relationshipSamples |
	relationshipSamples := self samplesNamed: 'C-rel'.
	edges do: [ :each |
		self time: [
			self db
				createOutRelationshipTyped: relationshipType
				fromNodeId: (startDbIds at: each fromId)
				toNodeId: (endDbIds at: each toId)
				properties: each properties ] into: relationshipSamples ]
]

{ #category : 'private-loading' }
FkBenchRunner >> insertNodes: propertyDictionaries labeled: label [
	"Answer the database ids, indexed by the dataset 'id'"

	| nodeSamples |
	nodeSamples := self samplesNamed: 'C-node'.
	^ propertyDictionaries collect: [ :each |
		  (self time: [ self db createNodeLabeled: label properties: each ] into: nodeSamples) id ]
]

{ #category : 'accessing' }
FkBenchRunner >> iterations [
	^ iterations ifNil: [ iterations := 1000 ]
]

{ #category : 'accessing' }
FkBenchRunner >> iterations: anInteger [
	iterations := anInteger
]

{ #category : 'accessing' }
FkBenchRunner >> loadElapsedMicroseconds [
	^ loadElapsedMicroseconds
]

{ #category : 'accessing' }
FkBenchRunner >> loadElapsedMicroseconds: anInteger [
	loadElapsedMicroseconds := anInteger
]

{ #category : 'accessing' }
FkBenchRunner >> loadOperationCount [
	^ (self samplesNamed: 'C-node') count + (self samplesNamed: 'C-rel') count
]

{ #category : 'running' }
FkBenchRunner >> loadPhase [
	| dataset startMicroseconds postDbIds |
	dataset := self generateDataset.
	self target prepare.
	self serverVersion: self target serverVersion.
	startMicroseconds := Time microsecondClockValue.
	self personDbIds: (self insertNodes: dataset persons labeled: 'Person').
	postDbIds := self insertNodes: dataset posts labeled: 'Post'.
	self insertEdges: dataset friendships typed: 'FRIEND' from: self personDbIds to: self personDbIds.
	self insertEdges: dataset postings typed: 'POSTED' from: self personDbIds to: postDbIds.
	self insertEdges: dataset likes typed: 'LIKES' from: self personDbIds to: postDbIds.
	self loadElapsedMicroseconds: Time microsecondClockValue - startMicroseconds
]

{ #category : 'private-querying' }
FkBenchRunner >> measure: operationName warmup: warmupCount times: measuredCount do: aBlock [
	| operationSamples |
	operationSamples := self samplesNamed: operationName.
	warmupCount timesRepeat: [ aBlock value ].
	measuredCount timesRepeat: [ self time: aBlock into: operationSamples ]
]

{ #category : 'private-querying' }
FkBenchRunner >> measure: operationName do: aBlock [
	self measure: operationName warmup: self warmup times: self iterations do: aBlock
]

{ #category : 'private-querying' }
FkBenchRunner >> measureDeletes [
	| deletableDbIds deleteWarmup |
	deletableDbIds := (self personDbIds copy shuffleBy: self random) readStream.
	deleteWarmup := self warmup min: deletableDbIds size.
	self
		measure: 'D-node'
		warmup: deleteWarmup
		times: (self iterations min: deletableDbIds size - deleteWarmup)
		do: [ self db deleteNodeAt: deletableDbIds next withRelations: true ]
]

{ #category : 'private-querying' }
FkBenchRunner >> measureReads [
	self measure: 'R-id' do: [ self db nodeAt: self randomPersonDbId ].
	self measure: 'R-prop' do: [
		self db nodesLabeled: 'Person' havingAll: { ('id' -> self randomPersonId) } ].
	self measure: 'R-where' do: [
		| minimumAge |
		minimumAge := self randomAge.
		self db nodesLabeled: 'Person' where: [ :n | (n @ 'age') >= minimumAge ] skip: 0 limit: 20 ].
	self measure: 'R-hop' do: [ self oneHopFriendsOf: self randomPersonDbId ].
	self measure: 'R-count' do: [ self db countNodesLabeled: 'Person' ]
]

{ #category : 'private-querying' }
FkBenchRunner >> measureUpdates [
	self measure: 'U-prop' do: [
		self db nodeAt: self randomPersonDbId propertyAt: 'age' put: self randomAge ].
	self measure: 'U-merge' do: [
		self db nodeAt: self randomPersonDbId mergeProperties: (Dictionary new
				 at: 'nickname' put: 'bench';
				 at: 'score' put: (self random nextInteger: 100);
				 yourself) ]
]

{ #category : 'private-querying' }
FkBenchRunner >> oneHopFriendsOf: personDbId [
	^ self db
		  oneHopPathsTyped: 'FRIEND'
		  direction: #out
		  from: personDbId
		  havingAll: #(  )
		  endNodeWithLabels: #(  )
		  havingAll: #(  )
		  whereIn: [ :start :rel :end |  ]
		  returnIn: nil
		  returning: [ :each | each ]
]

{ #category : 'accessing' }
FkBenchRunner >> personDbIds [
	^ personDbIds
]

{ #category : 'accessing' }
FkBenchRunner >> personDbIds: dbIds [
	personDbIds := dbIds
]

{ #category : 'running' }
FkBenchRunner >> queryPhase [
	self random: (Random seed: self seed).
	self measureReads.
	self measureUpdates.
	self measureDeletes
]

{ #category : 'accessing' }
FkBenchRunner >> random [
	^ random
]

{ #category : 'accessing' }
FkBenchRunner >> random: aRandom [
	random := aRandom
]

{ #category : 'private-querying' }
FkBenchRunner >> randomAge [
	^ 17 + (self random nextInteger: 63)
]

{ #category : 'private-querying' }
FkBenchRunner >> randomPersonDbId [
	^ self personDbIds at: self randomPersonId
]

{ #category : 'private-querying' }
FkBenchRunner >> randomPersonId [
	^ self random nextInteger: self scale personCount
]

{ #category : 'accessing' }
FkBenchRunner >> samples [
	"Answer the FkBenchSamples of every operation run so far, in run order"

	^ samples ifNil: [ samples := OrderedDictionary new ]
]

{ #category : 'accessing' }
FkBenchRunner >> samplesNamed: operationName [
	^ self samples
		  at: operationName
		  ifAbsentPut: [ FkBenchSamples operation: operationName target: self target label ]
]

{ #category : 'accessing' }
FkBenchRunner >> scale [
	^ scale ifNil: [ scale := FkBenchScale small ]
]

{ #category : 'accessing' }
FkBenchRunner >> scale: aFkBenchScale [
	scale := aFkBenchScale
]

{ #category : 'accessing' }
FkBenchRunner >> seed [
	^ seed ifNil: [ seed := 42 ]
]

{ #category : 'accessing' }
FkBenchRunner >> seed: anInteger [
	seed := anInteger
]

{ #category : 'accessing' }
FkBenchRunner >> serverVersion [
	^ serverVersion
]

{ #category : 'accessing' }
FkBenchRunner >> serverVersion: aString [
	serverVersion := aString
]

{ #category : 'accessing' }
FkBenchRunner >> target [
	^ target
]

{ #category : 'accessing' }
FkBenchRunner >> target: aFkBenchTarget [
	target := aFkBenchTarget
]

{ #category : 'private' }
FkBenchRunner >> time: aBlock into: aFkBenchSamples [
	| startMicroseconds result |
	startMicroseconds := Time microsecondClockValue.
	result := aBlock value.
	aFkBenchSamples addMicroseconds: Time microsecondClockValue - startMicroseconds.
	^ result
]

{ #category : 'accessing' }
FkBenchRunner >> warmup [
	^ warmup ifNil: [ warmup := 100 ]
]

{ #category : 'accessing' }
FkBenchRunner >> warmup: anInteger [
	warmup := anInteger
]
