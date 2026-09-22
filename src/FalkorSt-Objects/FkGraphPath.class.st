"
I am the high-level counterpart to FkPath: a decoded path plus the FkGraphDb it came from. I mirror
SgPath (../SCypherGraph, reference-only), but unlike FkGraphNode/FkGraphRelationship I am not an
FkGraphObject subclass - a path has no id, no #propertyAt:put:, and nothing to DELETE, so
FkGraphObject's CRUD API (and its subclassResponsibility #matchElementNamed:) does not apply to me.

Responsibility:
- Hold a decoded FkPath together with the FkGraphDb it was fetched through
- Wrap the raw FkPath's nodes and relationships as FkGraphNode/FkGraphRelationship, so callers never
  see raw FkNode/FkRelationship values off a path
- Hold an optional traversal #direction (#in / #out / nil), passed through to each wrapped
  FkGraphRelationship so its #ownNodeId/#otherNodeId can resolve

Collaborators:
- FkPath: the decoded path I wrap, held as my #rawPath
- FkGraphNode / FkGraphRelationship: what my #nodes / #relationships wrap the raw path's elements
  into
- FkGraphDb: the handle I and my wrapped nodes/relationships were fetched through

Public API and Key Messages:
- FkGraphPath class >> on:in: - wraps a raw FkPath with the FkGraphDb it was fetched through,
  #direction left unknown (nil)
- FkGraphPath class >> on:in:direction: - same, with an explicit #direction
- #nodes - an OrderedCollection of FkGraphNode, in path order
- #relationships - an OrderedCollection of FkGraphRelationship, in path order, each given my
  #direction
- #startNode / #endNode - the first/last element of #nodes
- #direction - #in/#out/nil, the traversal anchor this path was fetched relative to
- #rawPath - the wrapped FkPath

Implementation Points:
- #direction is only meaningful for a path fetched anchored at one node (today, always a one-hop
  path with exactly one relationship, unambiguously anchored) - see FkGraphDb's class comment for
  the #in/#out/nil convention.
"
Class {
	#name : 'FkGraphPath',
	#superclass : 'Object',
	#instVars : [
		'rawPath',
		'db',
		'direction'
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

{ #category : 'instance creation' }
FkGraphPath class >> on: aFkPath in: aFkGraphDb direction: aSymbolOrNil [
	^ (self on: aFkPath in: aFkGraphDb)
		direction: aSymbolOrNil;
		yourself
]

{ #category : 'accessing' }
FkGraphPath >> db [
	^ db
]

{ #category : 'accessing' }
FkGraphPath >> direction [
	^ direction
]

{ #category : 'private' }
FkGraphPath >> direction: anObject [
	direction := anObject
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
	^ self rawPath relationships
		collect: [ :each | FkGraphRelationship on: each in: self db direction: self direction ]
]

{ #category : 'accessing' }
FkGraphPath >> startNode [
	^ self nodes first
]
