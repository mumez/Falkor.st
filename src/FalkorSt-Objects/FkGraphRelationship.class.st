"
I am the high-level, CRUD-capable counterpart to FkRelationship: a decoded relationship plus the
FkGraphDb it came from. I mirror SgRelationship (../SCypherGraph, reference-only). Everything about
running Cypher against my FkGraphDb and delegating reads to my wrapped raw value is inherited from
FkGraphObject - I only add what's specific to relationships.

Responsibility:
- Delegate #type, #startNodeId, #endNodeId to my wrapped FkRelationship
- Supply the CyRelationship pattern element (#matchElementNamed:) that FkGraphObject's #delete /
  #propertyAt:put: / #reload use to match myself by id

Collaborators:
- FkRelationship: the decoded relationship I wrap, held as my inherited #rawGraphObject
- FkGraphObject: my superclass, running the Cypher (built with SCypher's CyQuery/CyRelationship) my
  mutating operations need

Public API and Key Messages:
- FkGraphRelationship class >> on:in: - wraps an FkRelationship with the FkGraphDb it was fetched
  through (inherited from FkGraphObject)
- #id / #type / #startNodeId / #endNodeId / #properties / #propertyAt: - delegate to the wrapped
  FkRelationship
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped FkRelationship
- #delete - DELETEs the relationship in FalkorDB
- #rawRelationship - the wrapped FkRelationship (an alias for the inherited #rawGraphObject)
"
Class {
	#name : 'FkGraphRelationship',
	#superclass : 'FkGraphObject',
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

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

{ #category : 'accessing' }
FkGraphRelationship >> rawRelationship [
	^ self rawGraphObject
]

{ #category : 'accessing' }
FkGraphRelationship >> startNodeId [
	^ self rawGraphObject startNodeId
]

{ #category : 'accessing' }
FkGraphRelationship >> type [
	^ self rawGraphObject type
]
