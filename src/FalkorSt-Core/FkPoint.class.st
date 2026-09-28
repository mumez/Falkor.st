"
I am a decoded Cypher point value: a geographic coordinate given as latitude and longitude. I am
produced by FkQueryResult while decoding a compact GRAPH.QUERY reply.

Responsibility:
- Hold a point's latitude and longitude, compared by value

Collaborators:
- FkQueryResult: builds instances of me while decoding compact point cells
- Point: converts to and from me via #asFkPoint / #asPoint (x = longitude, y = latitude)

Public API and Key Messages:
- #latitude, #longitude - the coordinate as Floats
- #asPoint - answer longitude@latitude; (139.69@35.68) asFkPoint builds me from a Point
"
Class {
	#name : 'FkPoint',
	#superclass : 'Object',
	#instVars : [
		'latitude',
		'longitude'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkPoint class >> latitude: aLatitude longitude: aLongitude [
	^ self new
		latitude: aLatitude;
		longitude: aLongitude;
		yourself
]

{ #category : 'comparing' }
FkPoint >> = other [
	self == other ifTrue: [ ^ true ].
	self class = other class ifFalse: [ ^ false ].
	^ self latitude = other latitude and: [ self longitude = other longitude ]
]

{ #category : 'converting' }
FkPoint >> asPoint [
	^ self longitude @ self latitude
]

{ #category : 'comparing' }
FkPoint >> hash [
	^ self latitude hash bitXor: self longitude hash
]

{ #category : 'accessing' }
FkPoint >> latitude [
	^ latitude
]

{ #category : 'private' }
FkPoint >> latitude: aNumber [
	latitude := aNumber
]

{ #category : 'accessing' }
FkPoint >> longitude [
	^ longitude
]

{ #category : 'private' }
FkPoint >> longitude: aNumber [
	longitude := aNumber
]

{ #category : 'printing' }
FkPoint >> printOn: aStream [
	aStream
		nextPutAll: 'point({latitude:';
		print: self latitude;
		nextPutAll: ', longitude:';
		print: self longitude;
		nextPutAll: '})'
]
