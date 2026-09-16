"
I am a decoded Cypher relationship value: an internal id, its type, the internal ids of its start
and end nodes, and its properties as a key/value mapping. I am produced by FkQueryResult while
decoding a GRAPH.QUERY reply; I never talk to FalkorDB myself.

Responsibility:
- Hold a relationship's id, type, start/end node ids, and properties as decoded from a GRAPH.QUERY
  reply

Collaborators:
- FkQueryResult: builds and owns instances of me while decoding query records

Public API and Key Messages:
- #id - the relationship's internal FalkorDB id (not guaranteed stable across graph mutations)
- #type - the relationship type String
- #startNodeId / #endNodeId - the internal ids of the nodes this relationship connects
- #properties - a Dictionary of property name Strings to their decoded values
"
Class {
	#name : 'FkRelationship',
	#superclass : 'Object',
	#instVars : [
		'id',
		'type',
		'startNodeId',
		'endNodeId',
		'properties'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkRelationship class >> id: anId type: aType startNodeId: aStartNodeId endNodeId: anEndNodeId properties: propertiesDictionary [
	^ self new
		id: anId;
		type: aType;
		startNodeId: aStartNodeId;
		endNodeId: anEndNodeId;
		properties: propertiesDictionary;
		yourself
]

{ #category : 'accessing' }
FkRelationship >> endNodeId [
	^ endNodeId
]

{ #category : 'private' }
FkRelationship >> endNodeId: anObject [
	endNodeId := anObject
]

{ #category : 'accessing' }
FkRelationship >> id [
	^ id
]

{ #category : 'private' }
FkRelationship >> id: anObject [
	id := anObject
]

{ #category : 'accessing' }
FkRelationship >> properties [
	^ properties
]

{ #category : 'private' }
FkRelationship >> properties: anObject [
	properties := anObject
]

{ #category : 'accessing' }
FkRelationship >> startNodeId [
	^ startNodeId
]

{ #category : 'private' }
FkRelationship >> startNodeId: anObject [
	startNodeId := anObject
]

{ #category : 'accessing' }
FkRelationship >> type [
	^ type
]

{ #category : 'private' }
FkRelationship >> type: anObject [
	type := anObject
]
