"
I generate a deterministic social-network FkBenchDataset for an FkBenchScale. All randomness comes
from a single Random seeded with #seed, so the same scale and seed always answer an equal dataset.

Model:
- (:Person {id, name, age, city}) and (:Post {id, text, createdAt})
- (:Person)-[:FRIEND {since}]->(:Person) - no self-loops, no duplicate pairs
- (:Person)-[:POSTED]->(:Post) - exactly one author per Post
- (:Person)-[:LIKES {at}]->(:Post) - no duplicate pairs
- #generate signals an Error when the scale is too small for the unique FRIEND pairs (< 6 Persons)

Collaborators:
- FkBenchScale: supplies the counts
- FkBenchDataset, FkBenchEdge: what I answer

Public API and Key Messages:
- #scale: / #seed: (default 42)
- #generate - answers a new FkBenchDataset
"
Class {
	#name : 'FkBenchDatasetGenerator',
	#superclass : 'Object',
	#instVars : [
		'scale',
		'seed',
		'random'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'constants' }
FkBenchDatasetGenerator >> baseEpochSeconds [
	"2024-01-01T00:00:00Z"

	^ 1704067200
]

{ #category : 'constants' }
FkBenchDatasetGenerator >> cityNames [
	^ #( 'Tokyo' 'Osaka' 'Nagoya' 'Sapporo' 'Fukuoka' 'Kyoto' 'Kobe' 'Sendai'
	     'Hiroshima' 'Yokohama' 'London' 'Paris' 'Berlin' 'Madrid' 'Rome'
	     'New York' 'Boston' 'Chicago' 'Seattle' 'Toronto' )
]

{ #category : 'private' }
FkBenchDatasetGenerator >> ensureUniqueEdges: count fitFromIdsUpTo: maxFromId toIdsUpTo: maxToId allowingSameIds: allowsSameIds [
	"Fail fast instead of looping forever when the scale is too small for the requested unique pairs"

	| possiblePairCount |
	possiblePairCount := maxFromId * maxToId.
	allowsSameIds ifFalse: [ possiblePairCount := possiblePairCount - (maxFromId min: maxToId) ].
	count > possiblePairCount ifTrue: [
		Error signal: ('Cannot generate {1} unique edges from only {2} possible pairs; use a larger scale'
				 format: { count. possiblePairCount }) ]
]

{ #category : 'constants' }
FkBenchDatasetGenerator >> firstNames [
	^ #( 'Alice' 'Bob' 'Carol' 'Dave' 'Eve' 'Frank' 'Grace' 'Heidi' 'Ivan' 'Judy'
	     'Ken' 'Mallory' 'Naomi' 'Oscar' 'Peggy' 'Rupert' 'Sybil' 'Trent' 'Victor' 'Wendy' )
]

{ #category : 'generating' }
FkBenchDatasetGenerator >> generate [
	self random: (Random seed: self seed).
	^ FkBenchDataset new
		  persons: self generatePersons;
		  posts: self generatePosts;
		  friendships: self generateFriendships;
		  postings: self generatePostings;
		  likes: self generateLikes;
		  yourself
]

{ #category : 'generating' }
FkBenchDatasetGenerator >> generateFriendships [
	^ self
		  uniqueEdges: self scale friendshipCount
		  fromIdsUpTo: self scale personCount
		  toIdsUpTo: self scale personCount
		  allowingSameIds: false
		  properties: [ { ('since' -> (self randomIntegerFrom: 2000 to: 2025)) } ]
]

{ #category : 'generating' }
FkBenchDatasetGenerator >> generateLikes [
	^ self
		  uniqueEdges: self scale likeCount
		  fromIdsUpTo: self scale personCount
		  toIdsUpTo: self scale postCount
		  allowingSameIds: true
		  properties: [ { ('at' -> self randomEpochSeconds) } ]
]

{ #category : 'generating' }
FkBenchDatasetGenerator >> generatePersons [
	^ (1 to: self scale personCount) collect: [ :id |
		  Dictionary new
			  at: 'id' put: id;
			  at: 'name' put: self randomName;
			  at: 'age' put: (self randomIntegerFrom: 18 to: 80);
			  at: 'city' put: (self pick: self cityNames);
			  yourself ]
]

{ #category : 'generating' }
FkBenchDatasetGenerator >> generatePostings [
	^ (1 to: self scale postCount) collect: [ :postId |
		  FkBenchEdge
			  from: (self random nextInteger: self scale personCount)
			  to: postId
			  properties: #(  ) ]
]

{ #category : 'generating' }
FkBenchDatasetGenerator >> generatePosts [
	^ (1 to: self scale postCount) collect: [ :id |
		  Dictionary new
			  at: 'id' put: id;
			  at: 'text' put: self randomText;
			  at: 'createdAt' put: self randomEpochSeconds;
			  yourself ]
]

{ #category : 'constants' }
FkBenchDatasetGenerator >> lastNames [
	^ #( 'Sato' 'Suzuki' 'Takahashi' 'Tanaka' 'Watanabe' 'Ito' 'Yamamoto' 'Nakamura'
	     'Kobayashi' 'Kato' 'Smith' 'Johnson' 'Brown' 'Taylor' 'Miller' )
]

{ #category : 'private' }
FkBenchDatasetGenerator >> pick: aSequenceableCollection [
	^ aSequenceableCollection at: (self random nextInteger: aSequenceableCollection size)
]

{ #category : 'private' }
FkBenchDatasetGenerator >> randomEpochSeconds [
	^ self baseEpochSeconds + (self randomIntegerFrom: 0 to: 365 * 86400 - 1)
]

{ #category : 'private' }
FkBenchDatasetGenerator >> randomIntegerFrom: min to: max [
	^ min - 1 + (self random nextInteger: max - min + 1)
]

{ #category : 'private' }
FkBenchDatasetGenerator >> randomName [
	^ (self pick: self firstNames) , ' ' , (self pick: self lastNames)
]

{ #category : 'private' }
FkBenchDatasetGenerator >> randomText [
	^ ' ' join: ((1 to: 5) collect: [ :each | self pick: self words ])
]

{ #category : 'accessing' }
FkBenchDatasetGenerator >> random [
	^ random
]

{ #category : 'accessing' }
FkBenchDatasetGenerator >> random: aRandom [
	random := aRandom
]

{ #category : 'accessing' }
FkBenchDatasetGenerator >> scale [
	^ scale
]

{ #category : 'accessing' }
FkBenchDatasetGenerator >> scale: aFkBenchScale [
	scale := aFkBenchScale
]

{ #category : 'accessing' }
FkBenchDatasetGenerator >> seed [
	^ seed ifNil: [ seed := 42 ]
]

{ #category : 'accessing' }
FkBenchDatasetGenerator >> seed: anInteger [
	seed := anInteger
]

{ #category : 'private' }
FkBenchDatasetGenerator >> uniqueEdges: count fromIdsUpTo: maxFromId toIdsUpTo: maxToId allowingSameIds: allowsSameIds properties: propertiesBlock [
	| seenPairs edges |
	self ensureUniqueEdges: count fitFromIdsUpTo: maxFromId toIdsUpTo: maxToId allowingSameIds: allowsSameIds.
	seenPairs := Set new.
	edges := OrderedCollection new.
	[ edges size < count ] whileTrue: [
		| pair |
		pair := { (self random nextInteger: maxFromId). (self random nextInteger: maxToId) }.
		((allowsSameIds or: [ pair first ~= pair second ]) and: [
			 (seenPairs includes: pair) not ]) ifTrue: [
			seenPairs add: pair.
			edges add: (FkBenchEdge from: pair first to: pair second properties: propertiesBlock value) ] ].
	^ edges asArray
]

{ #category : 'constants' }
FkBenchDatasetGenerator >> words [
	^ #( 'graph' 'node' 'edge' 'query' 'pharo' 'smalltalk' 'redis' 'cypher' 'index'
	     'path' 'friend' 'coffee' 'music' 'travel' 'book' 'code' 'night' 'morning'
	     'weekend' 'idea' )
]
