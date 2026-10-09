"
I am the high-level counterpart to FkPath: a decoded path plus the FkGraphDb it came from. I mirror
SgPath (../SCypherGraph, reference-only), but unlike FkGraphNode/FkGraphRelationship I am not an
FkGraphObject subclass - a path has no id, no #propertyAt:put:, and nothing to DELETE, so
FkGraphObject's CRUD API (and its subclassResponsibility #cypherElementWithIdentifier:) does not apply to me.

Responsibility:
- Hold a decoded FkPath together with the FkGraphDb it was fetched through
- Wrap the raw FkPath's nodes and relationships as FkGraphNode/FkGraphRelationship, so callers never
  see raw FkNode/FkRelationship values off a path
- For a one-hop path fetched anchored at one node, give its single wrapped FkGraphRelationship that
  node as its navigation origin, so #ownNode/#otherNode can resolve

Collaborators:
- FkPath: the decoded path I wrap, held as my #rawPath
- FkGraphNode / FkGraphRelationship: what my #nodes / #relationships wrap the raw path's elements
  into
- FkGraphDb: the handle I and my wrapped nodes/relationships were fetched through
- FkGraphDbError: signaled by #on:in:navigatedFrom: when the given path has more than one hop, since
  that constructor is only for one-hop paths

Public API and Key Messages:
- FkGraphPath class >> on:in: - wraps a raw FkPath with the FkGraphDb it was fetched through;
  #relationships wraps the raw relationships with no navigation origin
- FkGraphPath class >> on:in:navigatedFrom: - for one-hop paths: wraps the raw path's single
  relationship with the given navigation origin node id at construction time
- #nodes - an OrderedCollection of FkGraphNode, in path order
- #relationships - an OrderedCollection of FkGraphRelationship, in path order
- #startNode / #endNode - the first/last element of #nodes
- #rawPath - the wrapped FkPath

Implementation Points:
- A navigation origin is only meaningful for a path fetched anchored at one node (today, always a
  one-hop path with exactly one relationship, unambiguously anchored) - see FkGraphDb's class comment
  for the #in/#out/nil query-direction convention this is built from.
"
Class {
	#name : 'FkGraphPath',
	#superclass : 'Object',
	#instVars : [
		'rawPath',
		'db',
		'relationships'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphPath class >> on: aFkPath in: aFkGraphDb [
	^ self new
		rawPath: aFkPath;
		db: aFkGraphDb;
		relationships: (aFkPath relationships collect: [ :each | FkGraphRelationship on: each in: aFkGraphDb ]);
		yourself
]

{ #category : 'instance creation' }
FkGraphPath class >> on: aFkPath in: aFkGraphDb navigatedFrom: aNavigationOriginNodeId [
	"A navigation origin is only unambiguous for a one-hop path"

	aFkPath relationships size > 1 ifTrue: [
		^ FkGraphDbError multiHopPathNotAllowed
			signal: 'Cannot navigate a multi-hop path from a single origin: one-hop paths only' ].
	^ self new
		rawPath: aFkPath;
		db: aFkGraphDb;
		relationships: (aFkPath relationships collect: [ :each |
			FkGraphRelationship on: each in: aFkGraphDb navigatedFrom: aNavigationOriginNodeId ]);
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
	^ relationships
]

{ #category : 'private' }
FkGraphPath >> relationships: anObject [
	relationships := anObject
]

{ #category : 'accessing' }
FkGraphPath >> startNode [
	^ self nodes first
]
