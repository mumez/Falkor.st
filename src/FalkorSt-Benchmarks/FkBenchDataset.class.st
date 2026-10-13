"
I am a generated social-network benchmark dataset as plain Smalltalk data, independent of any
database. Nodes are property Dictionaries keyed by 'id' (1-based within their label); relationships
are FkBenchEdge instances referring to those ids.

Responsibility:
- Hold Person and Post property dictionaries and the FRIEND, POSTED, and LIKES edges

Collaborators:
- FkBenchDatasetGenerator: creates me
- FkBenchRunner: inserts my contents into a target database

Public API and Key Messages:
- #persons / #posts - Arrays of property Dictionaries
- #friendships (Person->Person) / #postings (Person->Post) / #likes (Person->Post) - Arrays of FkBenchEdge
"
Class {
	#name : 'FkBenchDataset',
	#superclass : 'Object',
	#instVars : [
		'persons',
		'posts',
		'friendships',
		'postings',
		'likes'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'accessing' }
FkBenchDataset >> friendships [
	^ friendships
]

{ #category : 'accessing' }
FkBenchDataset >> friendships: edges [
	friendships := edges
]

{ #category : 'accessing' }
FkBenchDataset >> likes [
	^ likes
]

{ #category : 'accessing' }
FkBenchDataset >> likes: edges [
	likes := edges
]

{ #category : 'accessing' }
FkBenchDataset >> persons [
	^ persons
]

{ #category : 'accessing' }
FkBenchDataset >> persons: propertyDictionaries [
	persons := propertyDictionaries
]

{ #category : 'accessing' }
FkBenchDataset >> postings [
	^ postings
]

{ #category : 'accessing' }
FkBenchDataset >> postings: edges [
	postings := edges
]

{ #category : 'accessing' }
FkBenchDataset >> posts [
	^ posts
]

{ #category : 'accessing' }
FkBenchDataset >> posts: propertyDictionaries [
	posts := propertyDictionaries
]
