"
I am the high-level, CRUD-capable counterpart to FkRelationship: a decoded relationship plus the
FkGraphDb it came from. I mirror SgRelationship (../SCypherGraph, reference-only). Everything about
running Cypher against my FkGraphDb and delegating reads to my wrapped raw value is inherited from
FkGraphObject - I only add what's specific to relationships.

Responsibility:
- Delegate #type, #startNodeId, #endNodeId to my wrapped FkRelationship
- Supply the CyRelationship pattern element (#matchElementNamed:) that FkGraphObject's #delete /
  #propertyAt:put: / #reload use to match myself by id
- Fetch my start/end/head/tail node as an FkGraphNode via my FkGraphDb's #nodeAt:
- Hold an optional traversal #direction (#in / #out / nil) used to resolve #headNodeId/#tailNodeId
  relative to the anchor node a path or one-hop query was fetched from

Collaborators:
- FkRelationship: the decoded relationship I wrap, held as my inherited #rawGraphObject
- FkGraphObject: my superclass, running the Cypher (built with SCypher's CyQuery/CyRelationship) my
  mutating operations need
- FkGraphDbError: signaled by #headNodeId/#tailNodeId when #direction is unknown (nil)

Public API and Key Messages:
- FkGraphRelationship class >> on:in: - wraps an FkRelationship with the FkGraphDb it was fetched
  through, #direction left unknown (nil) (inherited from FkGraphObject)
- FkGraphRelationship class >> on:in:direction: - same, with an explicit #direction
- #id / #type / #startNodeId / #endNodeId / #properties / #propertyAt: - delegate to the wrapped
  FkRelationship
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped FkRelationship
- #properties: / #mergeProperties: / #removePropertyAt: - bulk property mutators (inherited from
  FkGraphObject)
- #delete - DELETEs the relationship in FalkorDB
- #rawRelationship - the wrapped FkRelationship (an alias for the inherited #rawGraphObject)
- #startNode / #endNode - the relationship's raw start/end node, fetched and wrapped as an
  FkGraphNode
- #direction - #in/#out/nil, the traversal anchor I was fetched relative to
- #headNodeId / #tailNodeId - the far/anchor node id relative to #direction (#out: tail=start,
  head=end; #in: tail=end, head=start); signal FkGraphDbError (#UnknownDirection) when #direction
  is nil, since head/tail have no defined meaning without an anchor
- #headNode / #tailNode - #headNodeId/#tailNodeId fetched and wrapped as an FkGraphNode

Implementation Points:
- #direction is nil unless explicitly supplied via #on:in:direction: - FkGraphDb's #relationshipAt:
  and the create*/merge*RelationshipTyped:... factories have no traversal anchor, so relationships
  they answer always have #direction nil; only relationships reached through a one-hop path/
  relationship query anchored at one node (FkGraphNode's relationship-navigation API) carry a
  #direction.
"
Class {
	#name : 'FkGraphRelationship',
	#superclass : 'FkGraphObject',
	#instVars : [
		'direction'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphRelationship class >> on: aFkRelationship in: aFkGraphDb direction: aSymbolOrNil [
	^ (self on: aFkRelationship in: aFkGraphDb)
		direction: aSymbolOrNil;
		yourself
]

{ #category : 'accessing' }
FkGraphRelationship >> direction [
	^ direction
]

{ #category : 'private' }
FkGraphRelationship >> direction: anObject [
	direction := anObject
]

{ #category : 'accessing' }
FkGraphRelationship >> endNode [
	^ self db nodeAt: self endNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> endNodeId [
	^ self rawGraphObject endNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> headNode [
	^ self db nodeAt: self headNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> headNodeId [
	self direction == #in ifTrue: [ ^ self startNodeId ].
	self direction == #out ifTrue: [ ^ self endNodeId ].
	^ FkGraphDbError unknownDirection
		signal: 'Cannot determine head node: relationship direction is unknown'
]

{ #category : 'private' }
FkGraphRelationship >> matchElementNamed: anIdentifier [
	| s e |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	^ CyRelationship start: s end: e name: anIdentifier
]

{ #category : 'accessing' }
FkGraphRelationship >> rawRelationship [
	^ self rawGraphObject
]

{ #category : 'accessing' }
FkGraphRelationship >> startNode [
	^ self db nodeAt: self startNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> startNodeId [
	^ self rawGraphObject startNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> tailNode [
	^ self db nodeAt: self tailNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> tailNodeId [
	self direction == #in ifTrue: [ ^ self endNodeId ].
	self direction == #out ifTrue: [ ^ self startNodeId ].
	^ FkGraphDbError unknownDirection
		signal: 'Cannot determine tail node: relationship direction is unknown'
]

{ #category : 'accessing' }
FkGraphRelationship >> type [
	^ self rawGraphObject type
]
