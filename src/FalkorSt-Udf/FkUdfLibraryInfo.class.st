"
I am one entry of GRAPH.UDF LIST: a JavaScript UDF library registered in FalkorDB, with the names
of the functions it exposes and, when listed WITHCODE, its source. I am produced by
FkGraphEndpoint>>graphUdfList and its variants; I never talk to FalkorDB myself.

Responsibility:
- Map one raw GRAPH.UDF LIST entry (flat key/value pairs) into read-only accessors
- Treat the library name as required (a missing key signals KeyNotFound rather than hiding a reply
  format change), while the source code is optional (nil unless listed WITHCODE) and the function
  names default to empty
- Retain the raw entry so an unexpected or renamed key is still inspectable

Collaborators:
- FkGraphEndpoint: builds instances of me from GRAPH.UDF LIST entries

Public API and Key Messages:
- #name / #functions / #code
- FkUdfLibraryInfo class >> fromListEntry: - build one instance from a raw LIST entry
"
Class {
	#name : 'FkUdfLibraryInfo',
	#superclass : 'Object',
	#instVars : [
		'rawLibraryInfo'
	],
	#category : 'FalkorSt-Udf',
	#package : 'FalkorSt-Udf'
}

{ #category : 'instance creation' }
FkUdfLibraryInfo class >> fromListEntry: flatPairs [
	^ self new
		rawLibraryInfo: (Dictionary newFromPairs: flatPairs);
		yourself
]

{ #category : 'accessing' }
FkUdfLibraryInfo >> code [
	^ self rawLibraryInfo at: 'library_code' ifAbsent: []
]

{ #category : 'accessing' }
FkUdfLibraryInfo >> functions [
	^ self rawLibraryInfo at: 'functions' ifAbsent: [ #() ]
]

{ #category : 'accessing' }
FkUdfLibraryInfo >> name [
	^ self rawLibraryInfo at: 'library_name'
]

{ #category : 'printing' }
FkUdfLibraryInfo >> printOn: aStream [
	super printOn: aStream.
	aStream print: self rawLibraryInfo associations
]

{ #category : 'private-accessing' }
FkUdfLibraryInfo >> rawLibraryInfo [
	^ rawLibraryInfo
]

{ #category : 'private-accessing' }
FkUdfLibraryInfo >> rawLibraryInfo: aDictionary [
	rawLibraryInfo := aDictionary
]
