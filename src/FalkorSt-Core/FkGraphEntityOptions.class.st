"
I am an abstract base for options that target a graph entity (a node label or a relationship
type) and a set of property names - the shared shape behind FkGraphIndex and FkGraphConstraint.
I am not the builder myself: callers configure me inside the block passed to FkGraphDb's
#createIndexBy: / #createConstraintBy: (and their drop counterparts). Each concrete subclass
additionally tracks its own ""kind"" (index kind / constraint type) and renders a different
command from the same entity/properties state.

Responsibility:
- Hold the entity type/name and the property names a conversion needs
- Answer self from #node:/#relationship:/#props: so sends can chain via cascade
- Fail fast via #validate (RsError invalidArguments) when entity or properties was never set, or
  when a subclass's own #kindIsMissing answers true - called at conversion time, not from the
  fluent setters

Collaborators:
- FkGraphIndex / FkGraphConstraint: concrete subclasses. Each defines class-side #nodeEntityType /
  #relationshipEntityType (the entityType representation #node:/#relationship: store - a Symbol
  for FkGraphIndex, an uppercase String for FkGraphConstraint, since each is consumed
  differently downstream) and overrides #kindIsMissing / #incompleteOptionsMessage for its own
  kind field

Public API and Key Messages:
- #node: aLabel / #relationship: aRelType - set the entity type (via the receiving subclass's
  #nodeEntityType / #relationshipEntityType) and entity name
- #props: aCollection - set the property names
- #entityType / #entityName / #properties - plain accessors
- #validate - raises RsError invalidArguments when a subclass reports #kindIsMissing, or when
  entity or properties was never set
- #kindIsMissing - answers false here; subclasses override to check their own kind field
- #incompleteOptionsMessage - subclassResponsibility; the error message #validate signals
"
Class {
	#name : 'FkGraphEntityOptions',
	#superclass : 'Object',
	#instVars : [
		'entityType',
		'entityName',
		'properties'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'accessing' }
FkGraphEntityOptions >> entityName [
	^ entityName
]

{ #category : 'accessing' }
FkGraphEntityOptions >> entityType [
	^ entityType
]

{ #category : 'validation' }
FkGraphEntityOptions >> incompleteOptionsMessage [
	^ self subclassResponsibility
]

{ #category : 'validation' }
FkGraphEntityOptions >> kindIsMissing [
	^ false
]

{ #category : 'building' }
FkGraphEntityOptions >> node: aLabel [
	self entityType: self class nodeEntityType.
	self entityName: aLabel.
	^ self
]

{ #category : 'accessing' }
FkGraphEntityOptions >> properties [
	^ properties
]

{ #category : 'building' }
FkGraphEntityOptions >> props: aCollection [
	self properties: aCollection.
	^ self
]

{ #category : 'building' }
FkGraphEntityOptions >> relationship: aRelType [
	self entityType: self class relationshipEntityType.
	self entityName: aRelType.
	^ self
]

{ #category : 'private' }
FkGraphEntityOptions >> entityName: aString [
	entityName := aString
]

{ #category : 'private' }
FkGraphEntityOptions >> entityType: aString [
	entityType := aString
]

{ #category : 'private' }
FkGraphEntityOptions >> properties: aCollection [
	properties := aCollection
]

{ #category : 'error signaling' }
FkGraphEntityOptions >> signalInvalidArguments: aMessageString [
	"RsError invalidArguments, not FkGraphDbError (FalkorSt-Objects' high-level-API error), is
	intentional here: FkGraphIndex/FkGraphConstraint live in FalkorSt-Core, which FalkorSt-Objects
	depends on, not the other way around, so FkGraphDbError isn't reachable from this layer. Using
	RsError also matches the precedent this feature follows - RediStick's RsVectorSetSimQuery
	signals the identical RsError invalidArguments for the same 'fail fast on an incomplete
	builder, at the conversion boundary' shape."

	^ RsError invalidArguments signal: aMessageString
]

{ #category : 'validation' }
FkGraphEntityOptions >> validate [
	(self kindIsMissing or: [
		self entityType isNil or: [ self properties isNil or: [ self properties isEmpty ] ] ])
		ifTrue: [ ^ self signalInvalidArguments: self incompleteOptionsMessage ]
]
