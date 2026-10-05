"
I am a fluent builder for GRAPH.CONSTRAINT CREATE/DROP arguments: a constraint type (UNIQUE or
MANDATORY), the entity it applies to (a NODE label or RELATIONSHIP type), and the property names
it covers. I don't know the graph name a constraint is applied to or dropped from - that's
supplied separately to FkGraphEndpoint's constraint methods, since the same constraint shape can
be built once and applied against different graphs. Entity/properties state and the common
completeness check live on my superclass FkGraphEntityBuilder.

Responsibility:
- Hold the constraint type (entity type/name and properties are inherited)
- Answer self from every mutator so sends can chain via cascade

Collaborators:
- FkGraphEndpoint: builds or receives me, then reads my fields to delegate to
  #graphConstraintCreate:type:entityType:entityName:properties: or
  #graphConstraintDrop:type:entityType:entityName:properties:, calling #validate first

Public API and Key Messages:
- #unique / #mandatory - set the constraint type to 'UNIQUE' / 'MANDATORY'
- #node: aLabel - set the entity type to 'NODE' and the entity name to aLabel
- #relationship: aRelType - set the entity type to 'RELATIONSHIP' and the entity name to aRelType
- #props: aCollection - set the property names the constraint covers
- #constraintType / #entityType / #entityName / #properties - plain accessors
- #validate - raises RsError invalidArguments when constraintType, entity, or properties was
  never set. Called by FkGraphEndpoint at conversion time, not from the fluent setters
"
Class {
	#name : 'FkGraphConstraint',
	#superclass : 'FkGraphEntityBuilder',
	#instVars : [
		'constraintType'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'constants-entity' }
FkGraphConstraint class >> nodeEntityType [
	^ 'NODE'
]

{ #category : 'constants-entity' }
FkGraphConstraint class >> relationshipEntityType [
	^ 'RELATIONSHIP'
]

{ #category : 'accessing' }
FkGraphConstraint >> constraintType [
	^ constraintType
]

{ #category : 'validation' }
FkGraphConstraint >> incompleteBuilderMessage [
	^ 'FkGraphConstraint requires constraintType (unique/mandatory), entity (node:/relationship:), and props: to be set'
]

{ #category : 'validation' }
FkGraphConstraint >> kindIsMissing [
	^ self constraintType isNil
]

{ #category : 'building' }
FkGraphConstraint >> mandatory [
	self constraintType: 'MANDATORY'.
	^ self
]

{ #category : 'building' }
FkGraphConstraint >> unique [
	self constraintType: 'UNIQUE'.
	^ self
]

{ #category : 'private' }
FkGraphConstraint >> constraintType: aString [
	constraintType := aString
]
