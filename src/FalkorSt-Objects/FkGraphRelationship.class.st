"
I am the high-level, CRUD-capable counterpart to FkRelationship: a decoded relationship plus the
FkGraphDb it came from. I mirror SgRelationship (../SCypherGraph, reference-only). Everything about
running Cypher against my FkGraphDb and delegating reads to my wrapped raw value is inherited from
FkGraphObject - I only add what's specific to relationships.

Responsibility:
- Delegate #type, #startNodeId, #endNodeId to my wrapped FkRelationship
- Supply the CyRelationship pattern element (#matchElementNamed:) that FkGraphObject's #delete /
  #propertyAt:put: / #reload use to match myself by id
- Override #baseQueryMatching:withId: to seek my start node by id first (FalkorDB has no
  relationship-by-id seek - see Implementation Points)
- Fetch my start/end/head/tail node as an FkGraphNode via my FkGraphDb's #nodeAt:
- Hold an optional #navigationOriginNodeId - the id of the node a path or one-hop query was fetched
  from - used to resolve #ownNode/#otherNode relative to that origin

Collaborators:
- FkRelationship: the decoded relationship I wrap, held as my inherited #rawGraphObject
- FkGraphObject: my superclass, running the Cypher (built with SCypher's CyQuery/CyRelationship) my
  mutating operations need
- FkGraphDbError: signaled by #ownNode/#otherNode when I have no navigation origin to resolve against

Public API and Key Messages:
- FkGraphRelationship class >> on:in: - wraps an FkRelationship with the FkGraphDb it was fetched
  through, with no navigation origin (inherited from FkGraphObject)
- FkGraphRelationship class >> on:in:navigatedFrom: - same, with an explicit navigation origin node id
- #id / #type / #startNodeId / #endNodeId / #properties / #propertyAt: - delegate to the wrapped
  FkRelationship
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped FkRelationship
- #properties: / #mergeProperties: / #removePropertyAt: - bulk property mutators (inherited from
  FkGraphObject)
- #delete - DELETEs the relationship in FalkorDB
- #rawRelationship - the wrapped FkRelationship (an alias for the inherited #rawGraphObject)
- #startNode / #endNode - the relationship's raw start/end node, fetched and wrapped as an
  FkGraphNode
- #navigationDirectionFrom: aNodeId - #out/#in/#unknown, aNodeId's relation to this relationship's
  start/end
- #ownNode / #otherNode - the node at #navigationOriginNodeId / the endpoint on the other side;
  signal FkGraphDbError (#UnknownDirection) when there is no navigation origin

Implementation Points:
- #navigationOriginNodeId is nil unless explicitly supplied via #on:in:navigatedFrom: - FkGraphDb's
  #relationshipAt: and the create*/merge*RelationshipTyped: factories have no traversal anchor, so
  relationships they answer always have a nil origin; only relationships reached through a one-hop
  path/relationship query anchored at one node (FkGraphNode's relationship-navigation API) carry one.
- #baseQueryMatching:withId: - FalkorDB has no relationship-by-id seek, so FkGraphObject's default
  (MATCH element WHERE id(n) = x) always scans every relationship matching the pattern. I override
  it to seek my own start node by id first - MATCH (s) WHERE id(s) = startNodeId WITH s MATCH
  (s)-[n]-(e) WHERE id(n) = x - which the FalkorDB planner turns into a NodeByIdSeek on s followed
  by a Conditional Traverse to n, bounded by s's degree rather than a full relationship scan;
  verified against a real instance for #delete/#propertyAt:put:/#reload (NodeByIdSeek -> Conditional
  Traverse, correct results). The WITH works around the same FalkorDB 6.0.1 planner bug documented
  on FkGraphDb's #oneHopPathsQueryFor:... and in Performance.md: without it, the first MATCH's
  WHERE is silently dropped once the second MATCH traverses from the same node. Using both
  endpoints' ids (MATCH (e) WHERE id(e) = endNodeId too) turns the traversal into an Expand Into
  instead of a Conditional Traverse - also verified, but not implemented, since seeking the start
  node alone already removes the full scan with no extra query-building complexity.
"
Class {
	#name : 'FkGraphRelationship',
	#superclass : 'FkGraphObject',
	#instVars : [
		'navigationOriginNodeId'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphRelationship class >> on: aFkRelationship in: aFkGraphDb navigatedFrom: aNavigationOriginNodeId [
	^ (self on: aFkRelationship in: aFkGraphDb)
		navigationOriginNodeId: aNavigationOriginNodeId;
		yourself
]

{ #category : 'accessing' }
FkGraphRelationship >> endNode [
	^ self db nodeAt: self endNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> endNodeId [
	^ self rawGraphObject endNodeId
]

{ #category : 'private' }
FkGraphRelationship >> matchElementNamed: anIdentifier [
	| s e |
	s := 's' asCypherIdentifier.
	e := 'e' asCypherIdentifier.
	^ CyRelationship start: s end: e name: anIdentifier
]

{ #category : 'private' }
FkGraphRelationship >> baseQueryMatching: element withId: id [
	"FalkorDB has no relationship-by-id seek, so a plain 'MATCH (s)-[n]-(e) WHERE id(n) = x' always
	scans every relationship of that pattern. I know my own start node's id already, so I seek that
	node by id first instead - MATCH (s) WHERE id(s) = startNodeId WITH s MATCH (s)-[n]-(e) WHERE
	id(n) = x - turning the scan into a NodeByIdSeek on s followed by a Conditional Traverse to n,
	bounded by s's degree rather than the whole graph's relationship count. The WITH is required:
	without it, FalkorDB's planner silently drops the first MATCH's WHERE once the second MATCH
	traverses from the same node (see FkGraphDb's oneHopPathsQueryFor:... comment and Performance.md
	for the same bug). element must reuse the identifier 's' for #matchElementNamed:'s pattern to
	bind to the node seeked here."

	| s query |
	s := 's' asCypherIdentifier.
	query := CyQuery match: s asNode where: (s getId equals: self startNodeId).
	query addWith: s.
	query addMatch: element.
	query addWhere: (id getId equals: self id).
	^ query
]

{ #category : 'accessing' }
FkGraphRelationship >> navigationDirectionFrom: aNodeId [
	aNodeId = self startNodeId ifTrue: [ ^ #out ].
	aNodeId = self endNodeId ifTrue: [ ^ #in ].
	^ #unknown
]

{ #category : 'private' }
FkGraphRelationship >> navigationDirectionForOrigin [
	^ self navigationDirectionFrom: self navigationOriginNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> navigationOriginNodeId [
	^ navigationOriginNodeId
]

{ #category : 'private' }
FkGraphRelationship >> navigationOriginNodeId: anObject [
	navigationOriginNodeId := anObject
]

{ #category : 'accessing' }
FkGraphRelationship >> otherNode [
	| direction |
	direction := self navigationDirectionForOrigin.
	direction == #out ifTrue: [ ^ self endNode ].
	direction == #in ifTrue: [ ^ self startNode ].
	^ self signalUnknownDirectionFor: 'other'
]

{ #category : 'accessing' }
FkGraphRelationship >> ownNode [
	| direction |
	direction := self navigationDirectionForOrigin.
	direction == #out ifTrue: [ ^ self startNode ].
	direction == #in ifTrue: [ ^ self endNode ].
	^ self signalUnknownDirectionFor: 'own'
]

{ #category : 'private' }
FkGraphRelationship >> signalUnknownDirectionFor: aString [
	^ FkGraphDbError unknownDirection
		signal: 'Cannot determine ' , aString , ' node: relationship navigation origin is unknown'
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
FkGraphRelationship >> type [
	^ self rawGraphObject type
]
