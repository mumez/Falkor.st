"
I am the high-level counterpart to FkPath: a decoded path plus the FkGraphDb it came from. I mirror
SgPath (../SCypherGraph, reference-only), but unlike FkGraphNode/FkGraphRelationship I am not an
FkGraphObject subclass - a path has no id, no #propertyAt:put:, and nothing to DELETE, so
FkGraphObject's CRUD API (and its subclassResponsibility #matchElementNamed:) does not apply to me.

Responsibility:
- Hold a decoded FkPath together with the FkGraphDb it was fetched through
- Wrap the raw FkPath's nodes and relationships as FkGraphNode/FkGraphRelationship, so callers never
  see raw FkNode/FkRelationship values off a path

Collaborators:
- FkPath: the decoded path I wrap, held as my #rawPath
- FkGraphNode / FkGraphRelationship: what my #nodes / #relationships wrap the raw path's elements
  into
- FkGraphDb: the handle I and my wrapped nodes/relationships were fetched through

Public API and Key Messages:
- FkGraphPath class >> on:in: - wraps a raw FkPath with the FkGraphDb it was fetched through
- #nodes - an OrderedCollection of FkGraphNode, in path order
- #relationships - an OrderedCollection of FkGraphRelationship, in path order
- #startNode / #endNode - the first/last element of #nodes
- #rawPath - the wrapped FkPath
"
Class {
	#name : 'FkGraphPath',
	#superclass : 'Object',
	#instVars : [
		'rawPath',
		'db'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphPath class >> on: aFkPath in: aFkGraphDb [
	^ self new
		rawPath: aFkPath;
		db: aFkGraphDb;
		yourself
]

{ #category : 'accessing' }
FkGraphPath >> db [
	^ db
]

{ #category : 'private' }
FkGraphPath >> db: anObject [
	db := anObject
]

{ #category : 'accessing' }
FkGraphPath >> endNode [
	^ self nodes last
]

{ #category : 'accessing' }
FkGraphPath >> nodes [
	^ self rawPath nodes collect: [ :each | FkGraphNode on: each in: self db ]
]

{ #category : 'accessing' }
FkGraphPath >> rawPath [
	^ rawPath
]

{ #category : 'private' }
FkGraphPath >> rawPath: anObject [
	rawPath := anObject
]

{ #category : 'accessing' }
FkGraphPath >> relationships [
	^ self rawPath relationships collect: [ :each | FkGraphRelationship on: each in: self db ]
]

{ #category : 'accessing' }
FkGraphPath >> startNode [
	^ self nodes first
]
