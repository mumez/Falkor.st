"
I am one entry of GRAPH.UDF LIST: a JavaScript UDF library registered in FalkorDB, with the names
of the functions it exposes and, when listed WITHCODE, its source. I am produced by
FkGraphEndpoint>>graphUdfList and its variants; I never talk to FalkorDB myself.

Responsibility:
- Expose the library name, function names, and source code (nil unless listed WITHCODE) of one
  GRAPH.UDF LIST entry as read-only accessors over the raw entry
- Retain that raw entry so a missing or renamed key is still inspectable

Collaborators:
- FkGraphEndpoint: builds instances of me from GRAPH.UDF LIST entries

Public API and Key Messages:
- #libraryName / #functions / #code
- FkUdfLibraryInfo class >> fromDictionary: - build one instance from a LIST entry dictionary
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
FkUdfLibraryInfo class >> fromDictionary: aDictionary [
	^ self new
		rawLibraryInfo: aDictionary;
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
FkUdfLibraryInfo >> libraryName [
	^ self rawLibraryInfo at: 'library_name' ifAbsent: []
]

{ #category : 'printing' }
FkUdfLibraryInfo >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; print: self libraryName; nextPut: $)
]

{ #category : 'private-accessing' }
FkUdfLibraryInfo >> rawLibraryInfo [
	^ rawLibraryInfo
]

{ #category : 'private-accessing' }
FkUdfLibraryInfo >> rawLibraryInfo: aDictionary [
	rawLibraryInfo := aDictionary
]
