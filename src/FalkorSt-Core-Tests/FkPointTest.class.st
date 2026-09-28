"
I test FkPoint's value semantics and its conversion to and from Point. I need no FalkorDB instance;
compact decoding of point cells is covered by FkCompactQueryResultTest.
"
Class {
	#name : 'FkPointTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkPointTest >> testAsFkPointReadsXAsLongitudeAndYAsLatitude [
	| point |
	point := (139.69 @ 35.68) asFkPoint.
	self assert: point latitude equals: 35.68.
	self assert: point longitude equals: 139.69
]

{ #category : 'tests' }
FkPointTest >> testAsPointAnswersLongitudeAtLatitude [
	self
		assert: (FkPoint latitude: 35.68 longitude: 139.69) asPoint
		equals: 139.69 @ 35.68
]

{ #category : 'tests' }
FkPointTest >> testEqualityByValue [
	| point |
	point := FkPoint latitude: 35.68 longitude: 139.69.
	self assert: point equals: (FkPoint latitude: 35.68 longitude: 139.69).
	self assert: point hash equals: (FkPoint latitude: 35.68 longitude: 139.69) hash.
	self deny: point equals: (FkPoint latitude: 139.69 longitude: 35.68).
	self deny: point equals: 139.69 @ 35.68
]

{ #category : 'tests' }
FkPointTest >> testPrintsAsCypherPointLiteral [
	self
		assert: (FkPoint latitude: 35.68 longitude: 139.69) printString
		equals: 'point({latitude:35.68, longitude:139.69})'
]

{ #category : 'tests' }
FkPointTest >> testRoundTripsThroughPoint [
	self assert: (139.69 @ 35.68) asFkPoint asPoint equals: 139.69 @ 35.68
]
