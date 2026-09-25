"
I am the error class for logical failures in the high-level FalkorDB object API (FkGraphDb,
FkGraphObject and its subclasses) - things like a tracked graph object no longer existing in
FalkorDB. I am not a Stick/RediStick connection-level error, so I don't subclass SkError; I carry my
own #kind, following the same shape (a symbolic category plus a class-side factory) as SkError/RsError.

Responsibility:
- Identify the category of error via #kind (e.g. #NoSuchObject when a graph object I was tracking
  no longer exists in FalkorDB)

Public API and Key Messages:
- FkGraphDbError class >> kind: aSymbol - creates an instance with the given #kind
- FkGraphDbError class >> noSuchObject - a #NoSuchObject-kind error, signaled when a MATCH-by-id
  query answers no records for a graph object expected to still exist
- FkGraphDbError class >> invalidQuery - an #InvalidQuery-kind error, signaled when a CyQuery built
  by the high-level API is not shaped as expected (e.g. a missing trailing CyReturn)
- FkGraphDbError class >> unknownDirection - an #UnknownDirection-kind error, signaled by
  FkGraphRelationship's #ownNodeId/#otherNodeId when the relationship has no known traversal anchor
  (direction) to resolve own/other against
- FkGraphDbError class >> alreadyDeleted - an #AlreadyDeleted-kind error, signaled by
  FkGraphObject's property getters once the object has been #delete-d
- #kind / #kind: - the symbolic error category
"
Class {
	#name : 'FkGraphDbError',
	#superclass : 'Error',
	#instVars : [
		'kind'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphDbError class >> kind: aSymbol [
	^ self new
		kind: aSymbol;
		yourself
]

{ #category : 'instance creation' }
FkGraphDbError class >> noSuchObject [
	^ self kind: #NoSuchObject
]

{ #category : 'instance creation' }
FkGraphDbError class >> invalidQuery [
	^ self kind: #InvalidQuery
]

{ #category : 'instance creation' }
FkGraphDbError class >> unknownDirection [
	^ self kind: #UnknownDirection
]

{ #category : 'instance creation' }
FkGraphDbError class >> alreadyDeleted [
	^ self kind: #AlreadyDeleted
]

{ #category : 'accessing' }
FkGraphDbError >> kind [
	^ kind
]

{ #category : 'accessing' }
FkGraphDbError >> kind: anObject [
	kind := anObject
]
