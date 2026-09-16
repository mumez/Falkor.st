"
I am a decoded Cypher path value: the ordered sequence of nodes and relationships that make up
the path. I am produced by FkQueryResult while decoding a GRAPH.QUERY reply; I never talk to
FalkorDB myself.

Responsibility:
- Hold a path's ordered nodes and relationships as decoded from a GRAPH.QUERY reply

Collaborators:
- FkQueryResult: builds and owns instances of me while decoding query records
- FkNode / FkRelationship: the elements making up my #nodes and #relationships

Public API and Key Messages:
- #nodes - an OrderedCollection of FkNode, in path order
- #relationships - an OrderedCollection of FkRelationship, in path order (one fewer than #nodes)

Implementation Points:
- Only decodable from the compact result format; FalkorDB's verbose format represents a path as a
  bare id-notation string with no way to recover labels/types/properties (see FkQueryResult's
  class comment)
"
Class {
	#name : 'FkPath',
	#superclass : 'Object',
	#instVars : [
		'nodes',
		'relationships'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkPath class >> nodes: nodesCollection relationships: relationshipsCollection [
	^ self new
		nodes: nodesCollection;
		relationships: relationshipsCollection;
		yourself
]

{ #category : 'accessing' }
FkPath >> nodes [
	^ nodes
]

{ #category : 'private' }
FkPath >> nodes: anObject [
	nodes := anObject
]

{ #category : 'accessing' }
FkPath >> relationships [
	^ relationships
]

{ #category : 'private' }
FkPath >> relationships: anObject [
	relationships := anObject
]
