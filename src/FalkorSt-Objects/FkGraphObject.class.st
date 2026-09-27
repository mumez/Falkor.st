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
- Signal an FkGraphDbError (#NoSuchObject) instead of failing with SubscriptOutOfBounds when
  #reload's MATCH-by-id finds no record (e.g. the object was deleted by another session)
- Track whether #delete has been sent to me locally (#isDeleted) and signal an FkGraphDbError
  (#AlreadyDeleted) from my property getters/setters (and FkGraphNode's label mutators) once I
  have been deleted - #delete itself
  stays idempotent (a second #delete is a no-op, not an error)

Collaborators:
- FkGraphDb: runs the Cypher (built with SCypher's CyQuery plus my subclass's pattern element) my
  mutating operations need
- FkGraphDbError: signaled by #reload when the object I was tracking no longer exists

Public API and Key Messages:
- FkGraphObject class >> on:in: - wraps a raw graph value with the FkGraphDb it was fetched through
- #id / #properties / #propertyAt: - delegate to the wrapped raw value
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped raw value
- #properties: / #mergeProperties: - SET my whole property map (replacing / merging), bound as a
  single #runCypher:arguments: parameter via my FkGraphDb's #valuesArgumentsFor:, then reload
- #removePropertyAt: - REMOVEs a single property in FalkorDB, then reload
- #delete - DELETEs myself in FalkorDB
- #= / #hash - equal when same class and same #id, so wrappers refetched from the same underlying
  object compare and hash equal
- #isDeleted - answers whether I have been #delete-d locally
- #@ / #at: / #at:put: - shortcut aliases for #propertyAt: / #propertyAt:put:
- #name / #name: - shortcut accessors for the 'name' property

Implementation Points:
- #matchElementNamed: is subclassResponsibility - it answers the CyNode/CyRelationship built with
  the given identifier that #delete/#propertyAt:put:/#reload match myself by id through.
- #properties:/#mergeProperties:/#removePropertyAt: share their match/where/run/reload skeleton
  through the private #changeProperties:using: helper - mirrors FkGraphNode's #changeLabels:using:.
  The block passed in appends the SET/REMOVE statement to the query itself (query addSet:/addRemove:),
  since unlike labels the SET expression differs per case (#to: vs #addAll:) rather than sharing one
  expression. #removePropertyAt: passes nil for props since REMOVE binds no parameter.
"
Class {
	#name : 'FkGraphObject',
	#superclass : 'Object',
	#instVars : [
		'rawGraphObject',
		'db',
		'isDeleted'
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

{ #category : 'initialization' }
FkGraphObject >> initialize [
	super initialize.
	isDeleted := false
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
	self db runCypher: query.
	isDeleted := true
]

{ #category : 'comparing' }
FkGraphObject >> = other [
	^ self class = other class and: [ self id = other id ]
]

{ #category : 'accessing' }
FkGraphObject >> @ propName [
	^ self propertyAt: propName
]

{ #category : 'accessing' }
FkGraphObject >> at: propName [
	^ self propertyAt: propName
]

{ #category : 'accessing' }
FkGraphObject >> at: propName put: value [
	^ self propertyAt: propName put: value
]

{ #category : 'comparing' }
FkGraphObject >> hash [
	^ self id hash
]

{ #category : 'accessing' }
FkGraphObject >> id [
	^ self rawGraphObject id
]

{ #category : 'testing' }
FkGraphObject >> isDeleted [
	^ isDeleted
]

{ #category : 'accessing' }
FkGraphObject >> name [
	^ self propertyAt: 'name'
]

{ #category : 'accessing' }
FkGraphObject >> name: aString [
	^ self propertyAt: 'name' put: aString
]

{ #category : 'private' }
FkGraphObject >> matchElementNamed: anIdentifier [
	^ self subclassResponsibility
]

{ #category : 'accessing' }
FkGraphObject >> properties [
	self checkIsDeleted.
	^ self rawGraphObject properties
]

{ #category : 'accessing' }
FkGraphObject >> propertyAt: key [
	self checkIsDeleted.
	^ self rawGraphObject properties at: key ifAbsent: [ nil ]
]

{ #category : 'private' }
FkGraphObject >> checkIsDeleted [
	isDeleted ifTrue: [
		^ FkGraphDbError alreadyDeleted
			signal: ('Graph object {1} has already been deleted' format: {self id}) ]
]

{ #category : 'actions' }
FkGraphObject >> propertyAt: key put: value [
	| n element query |
	self checkIsDeleted.
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery
		match: element
		where: (n getId equals: self id)
		set: { (n @ key) to: value }.
	self db runCypher: query.
	self reload
]

{ #category : 'private' }
FkGraphObject >> changeProperties: propsOrNil using: aBlock [
	| n element query |
	self checkIsDeleted.
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery match: element where: (n getId equals: self id).
	aBlock value: query value: n.
	propsOrNil
		ifNil: [ self db runCypher: query ]
		ifNotNil: [ self db runCypher: query arguments: (self db valuesArgumentsFor: propsOrNil) ].
	self reload
]

{ #category : 'actions' }
FkGraphObject >> mergeProperties: props [
	^ self changeProperties: props using: [ :query :n | query addSet: (n addAll: 'values' asCypherParameter) ]
]

{ #category : 'actions' }
FkGraphObject >> properties: props [
	^ self changeProperties: props using: [ :query :n | query addSet: (n to: 'values' asCypherParameter) ]
]

{ #category : 'accessing' }
FkGraphObject >> rawGraphObject [
	^ rawGraphObject
]

{ #category : 'private' }
FkGraphObject >> rawGraphObject: anObject [
	rawGraphObject := anObject
]

{ #category : 'actions' }
FkGraphObject >> removePropertyAt: key [
	^ self changeProperties: nil using: [ :query :n | query addRemove: (n @ key) ]
]

{ #category : 'private' }
FkGraphObject >> reload [
	| n element query result |
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery match: element where: (n getId equals: self id) return: n.
	result := self db runCypher: query.
	rawGraphObject := result oneValueIfNone: [
		^ FkGraphDbError noSuchObject signal: 'No graph object found for id ' , self id printString ]
]
