"
I test FkGraphConstraint's #validate, without a FalkorDB connection: a fully specified builder
passes, while one missing constraintType, entity, or properties raises RsError invalidArguments.
"
Class {
	#name : 'FkGraphConstraintTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkGraphConstraintTest >> testValidatePassesWhenFullySpecified [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint unique; node: 'Person'; props: #('email').
	self shouldnt: [ constraint validate ] raise: RsError
]

{ #category : 'tests' }
FkGraphConstraintTest >> testValidateRaisesWhenConstraintTypeNotSet [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint node: 'Person'; props: #('email').
	self should: [ constraint validate ] raise: RsError
]

{ #category : 'tests' }
FkGraphConstraintTest >> testValidateRaisesWhenEntityNotSet [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint unique; props: #('email').
	self should: [ constraint validate ] raise: RsError
]

{ #category : 'tests' }
FkGraphConstraintTest >> testValidateRaisesWhenPropertiesNotSet [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint unique; node: 'Person'.
	self should: [ constraint validate ] raise: RsError
]

{ #category : 'tests' }
FkGraphConstraintTest >> testValidateRaisesWhenPropertiesEmpty [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint unique; node: 'Person'; props: #().
	self should: [ constraint validate ] raise: RsError
]
