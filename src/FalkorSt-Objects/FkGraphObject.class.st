"
I am the shared CRUD-capable counterpart to graph-object wrappers like FkGraphNode: a decoded raw
graph value (an FkNode today, an FkRelationship once FkGraphRelationship exists) plus the FkGraphDb
it came from. I mirror SgGraphObject (../SCypherGraph, reference-only), holding what's common to
every wrapped graph value so subclasses only add what's specific to their own kind.

Responsibility:
- Hold a raw decoded graph value together with the FkGraphDb it was fetched through
- Delegate #id, #properties, #propertyAt: to the wrapped raw value
- Run a Cypher SET/DELETE against my FkGraphDb for #propertyAt:put: / #delete, then reload the
  wrapped raw value from FalkorDB so local state never diverges from what was actually committed
- Require subclasses to supply the CyNode/CyRelationship pattern element used to match myself by id
  (#matchElementNamed:) - everything else about the match/set/delete/return Cypher is generic

Collaborators:
- FkGraphDb: runs the Cypher (built with SCypher's CyQuery plus my subclass's pattern element) my
  mutating operations need

Public API and Key Messages:
- FkGraphObject class >> on:in: - wraps a raw graph value with the FkGraphDb it was fetched through
- #id / #properties / #propertyAt: - delegate to the wrapped raw value
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped raw value
- #delete - DELETEs myself in FalkorDB

Implementation Points:
- #matchElementNamed: is subclassResponsibility - it answers the CyNode/CyRelationship built with
  the given identifier that #delete/#propertyAt:put:/#reload match myself by id through.
"
Class {
	#name : 'FkGraphObject',
	#superclass : 'Object',
	#instVars : [
		'rawGraphObject',
		'db'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphObject class >> on: aRawGraphObject in: aFkGraphDb [
	^ self new
		rawGraphObject: aRawGraphObject;
		db: aFkGraphDb;
		yourself
]

{ #category : 'private' }
FkGraphObject >> cypherStringFor: aCyQuery [
	"CyQuery's default delimiter is a bare carriage return, which FalkorDB's Cypher parser
	rejects between clauses - use a space instead."

	aCyQuery delimiter: ' '.
	^ aCyQuery cypherString
]

{ #category : 'accessing' }
FkGraphObject >> db [
	^ db
]

{ #category : 'private' }
FkGraphObject >> db: anObject [
	db := anObject
]

{ #category : 'actions' }
FkGraphObject >> delete [
	| n element query |
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery match: element where: (n getId equals: self id) delete: element.
	self db runCypher: (self cypherStringFor: query)
]

{ #category : 'accessing' }
FkGraphObject >> id [
	^ self rawGraphObject id
]

{ #category : 'private' }
FkGraphObject >> matchElementNamed: anIdentifier [
	^ self subclassResponsibility
]

{ #category : 'accessing' }
FkGraphObject >> properties [
	^ self rawGraphObject properties
]

{ #category : 'accessing' }
FkGraphObject >> propertyAt: key [
	^ self rawGraphObject properties at: key ifAbsent: [ nil ]
]

{ #category : 'actions' }
FkGraphObject >> propertyAt: key put: value [
	| n element query |
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery
		match: element
		where: (n getId equals: self id)
		set: { (n @ key) to: value }.
	self db runCypher: (self cypherStringFor: query).
	self reload
]

{ #category : 'accessing' }
FkGraphObject >> rawGraphObject [
	^ rawGraphObject
]

{ #category : 'private' }
FkGraphObject >> rawGraphObject: anObject [
	rawGraphObject := anObject
]

{ #category : 'private' }
FkGraphObject >> reload [
	| n element query result |
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery match: element where: (n getId equals: self id) return: n.
	result := self db runCypher: (self cypherStringFor: query).
	rawGraphObject := result records first first
]
