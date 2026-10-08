"
I test FkBenchDatasetGenerator: determinism by seed, counts per FkBenchScale, and the structural
invariants of the generated social-network dataset. No database is needed.

Coverage:
- performance-benchmark spec: ""Same seed, same dataset""
- performance-benchmark spec: ""Counts follow the scale""
- performance-benchmark spec: ""Structural invariants""
"
Class {
	#name : 'FkBenchDatasetGeneratorTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Benchmarks-Tests',
	#package : 'FalkorSt-Benchmarks-Tests'
}

{ #category : 'private' }
FkBenchDatasetGeneratorTest >> endpointPairsOf: edges [
	^ edges collect: [ :each | { each fromId. each toId } ]
]

{ #category : 'private' }
FkBenchDatasetGeneratorTest >> generateSmallWithSeed: seed [
	^ FkBenchDatasetGenerator new
		scale: FkBenchScale small;
		seed: seed;
		generate
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testCountsFollowScale [
	| dataset |
	dataset := self generateSmallWithSeed: 42.
	self assert: dataset persons size equals: 1000.
	self assert: dataset posts size equals: 2000.
	self assert: dataset friendships size equals: 5000.
	self assert: dataset postings size equals: 2000.
	self assert: dataset likes size equals: 5000
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testDifferentSeedProducesDifferentDataset [
	self
		deny: (self generateSmallWithSeed: 1) friendships
		equals: (self generateSmallWithSeed: 2) friendships
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testEveryPostHasExactlyOneAuthor [
	| dataset authoredPostIds |
	dataset := self generateSmallWithSeed: 42.
	authoredPostIds := dataset postings collect: [ :each | each toId ].
	self assert: authoredPostIds asSet size equals: authoredPostIds size.
	self
		assert: authoredPostIds asSet
		equals: (dataset posts collect: [ :each | each at: 'id' ]) asSet
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testFriendshipsHaveNoSelfLoopOrDuplicate [
	| friendships |
	friendships := (self generateSmallWithSeed: 42) friendships.
	self assert: (friendships noneSatisfy: [ :each | each fromId = each toId ]).
	self assert: (self endpointPairsOf: friendships) asSet size equals: friendships size
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testLikesHaveNoDuplicate [
	| likes |
	likes := (self generateSmallWithSeed: 42) likes.
	self assert: (self endpointPairsOf: likes) asSet size equals: likes size
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testPropertiesStayInRange [
	| dataset |
	dataset := self generateSmallWithSeed: 42.
	self assert: (dataset persons allSatisfy: [ :each |
			 (each at: 'age') between: 18 and: 80 ]).
	self assert: (dataset friendships allSatisfy: [ :each |
			 (each fromId between: 1 and: 1000) and: [ each toId between: 1 and: 1000 ] ]).
	self assert: (dataset likes allSatisfy: [ :each | each toId between: 1 and: 2000 ])
]

{ #category : 'tests' }
FkBenchDatasetGeneratorTest >> testSameSeedProducesEqualDataset [
	| first second |
	first := self generateSmallWithSeed: 42.
	second := self generateSmallWithSeed: 42.
	self assert: first persons equals: second persons.
	self assert: first posts equals: second posts.
	self assert: first friendships equals: second friendships.
	self assert: first postings equals: second postings.
	self assert: first likes equals: second likes
]
