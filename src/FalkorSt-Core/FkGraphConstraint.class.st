"
I am a fluent builder for GRAPH.CONSTRAINT CREATE/DROP arguments: a constraint type (UNIQUE or
MANDATORY), the entity it applies to (a NODE label or RELATIONSHIP type), and the property names
it covers. I don't know the graph name a constraint is applied to or dropped from - that's
supplied separately to FkGraphEndpoint's constraint methods, since the same constraint shape can
be built once and applied against different graphs.

Responsibility:
- Hold the constraint type, entity type/name, and property names a GRAPH.CONSTRAINT CREATE/DROP
  command needs
- Answer self from every mutator so sends can chain via cascade

Collaborators:
- FkGraphEndpoint: builds or receives me, then reads my fields to delegate to
  #graphConstraintCreate:type:entityType:entityName:properties: or
  #graphConstraintDrop:type:entityType:entityName:properties:

Public API and Key Messages:
- #unique / #mandatory - set the constraint type to 'UNIQUE' / 'MANDATORY'
- #node: aLabel - set the entity type to 'NODE' and the entity name to aLabel
- #relationship: aRelType - set the entity type to 'RELATIONSHIP' and the entity name to aRelType
- #props: aCollection - set the property names the constraint covers
- #constraintType / #entityType / #entityName / #properties - plain accessors
"
Class {
	#name : 'FkGraphConstraint',
	#superclass : 'Object',
	#instVars : [
		'constraintType',
		'entityType',
		'entityName',
		'properties'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'accessing' }
FkGraphConstraint >> constraintType [
	^ constraintType
]

{ #category : 'accessing' }
FkGraphConstraint >> entityName [
	^ entityName
]

{ #category : 'accessing' }
FkGraphConstraint >> entityType [
	^ entityType
]

{ #category : 'private' }
FkGraphConstraint >> constraintType: aString [
	constraintType := aString
]

{ #category : 'private' }
FkGraphConstraint >> entityName: aString [
	entityName := aString
]

{ #category : 'private' }
FkGraphConstraint >> entityType: aString [
	entityType := aString
]

{ #category : 'building' }
FkGraphConstraint >> mandatory [
	self constraintType: 'MANDATORY'.
	^ self
]

{ #category : 'building' }
FkGraphConstraint >> node: aLabel [
	self entityType: 'NODE'.
	self entityName: aLabel.
	^ self
]

{ #category : 'accessing' }
FkGraphConstraint >> properties [
	^ properties
]

{ #category : 'private' }
FkGraphConstraint >> properties: aCollection [
	properties := aCollection
]

{ #category : 'building' }
FkGraphConstraint >> props: aCollection [
	self properties: aCollection.
	^ self
]

{ #category : 'building' }
FkGraphConstraint >> relationship: aRelType [
	self entityType: 'RELATIONSHIP'.
	self entityName: aRelType.
	^ self
]

{ #category : 'building' }
FkGraphConstraint >> unique [
	self constraintType: 'UNIQUE'.
	^ self
]
