"
I am a decoded Cypher node value: an internal id, the labels attached to the node, and its
properties as a key/value mapping. I am produced by FkQueryResult while decoding a GRAPH.QUERY
reply; I never talk to FalkorDB myself.

Responsibility:
- Hold a node's id, labels, and properties as decoded from a GRAPH.QUERY reply

Collaborators:
- FkQueryResult: builds and owns instances of me while decoding query records

Public API and Key Messages:
- #id - the node's internal FalkorDB id (not guaranteed stable across graph mutations)
- #labels - an OrderedCollection of label name Strings
- #properties - a Dictionary of property name Strings to their decoded values
"
Class {
	#name : 'FkNode',
	#superclass : 'Object',
	#instVars : [
		'id',
		'labels',
		'properties'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkNode class >> id: anId labels: labelsCollection properties: propertiesDictionary [
	^ self new
		id: anId;
		labels: labelsCollection;
		properties: propertiesDictionary;
		yourself
]

{ #category : 'accessing' }
FkNode >> id [
	^ id
]

{ #category : 'private' }
FkNode >> id: anObject [
	id := anObject
]

{ #category : 'accessing' }
FkNode >> labels [
	^ labels
]

{ #category : 'private' }
FkNode >> labels: anObject [
	labels := anObject
]

{ #category : 'accessing' }
FkNode >> properties [
	^ properties
]

{ #category : 'private' }
FkNode >> properties: anObject [
	properties := anObject
]
