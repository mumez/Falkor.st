"
I test FkGraphEndpoint's GRAPH.UDF extension API (#graphUdfLoad:*, #graphUdfList*, #graphUdfDelete:,
#graphUdfFlush) against a real FalkorDB instance. UDF libraries are server-wide rather than per
graph, so I name each library after the running test and delete only those on tearDown, leaving
any other library on the server untouched.
"
Class {
	#name : 'FkGraphEndpointUdfTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Udf-Tests',
	#package : 'FalkorSt-Udf-Tests'
}

{ #category : 'private' }
FkGraphEndpointUdfTest >> callUpOn: libraryName [
	^ (self endpoint
		graphQuery: self graphName
		cypher: ('RETURN {1}.Up(''abc'')' format: { libraryName })) oneValue
]

{ #category : 'private' }
FkGraphEndpointUdfTest >> echoLibraryCode [
	^ 'falkor.register(''Up'', function (s) { return s; });'
]

{ #category : 'private' }
FkGraphEndpointUdfTest >> libraryName [
	^ 'FkUdfTest_' , self selector asString
]

{ #category : 'private' }
FkGraphEndpointUdfTest >> otherLibraryName [
	^ self libraryName , '_other'
]

{ #category : 'running' }
FkGraphEndpointUdfTest >> tearDown [
	{ self libraryName. self otherLibraryName } do: [ :each |
		[ self endpoint graphUdfDelete: each ] on: RsGenericError do: [ :ex |  ] ].
	super tearDown
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testDeleteMissingLibrarySignalsRsGenericError [
	self should: [ self endpoint graphUdfDelete: self libraryName ] raise: RsGenericError
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testDeleteRemovesLibrary [
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	self assert: (self endpoint graphUdfDelete: self libraryName) equals: 'OK'.
	self assert: (self endpoint graphUdfList: self libraryName) isEmpty
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testFlushRemovesAllLibraries [
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	(self endpoint graphUdfList allSatisfy: [ :each | each name = self libraryName ])
		ifFalse: [ ^ self skip: 'other UDF libraries exist on the server; not flushing them' ].
	self assert: self endpoint graphUdfFlush equals: 'OK'.
	self assert: self endpoint graphUdfList isEmpty
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testListFiltersByLibraryName [
	| infos |
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	self endpoint graphUdfLoad: self otherLibraryName code: self echoLibraryCode.
	infos := self endpoint graphUdfList: self libraryName.
	self assert: (infos collect: [ :each | each name ]) asArray equals: { self libraryName }
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testListIncludesLoadedLibraryWithoutCode [
	| info |
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	info := (self endpoint graphUdfList detect: [ :each | each name = self libraryName ]).
	self assert: info functions asArray equals: #('Up').
	self assert: info code isNil
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testListWithCodeIncludesSource [
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	self
		assert: (self endpoint graphUdfListWithCode: self libraryName) first code
		equals: self upperCaseLibraryCode.
	self assert: ((self endpoint graphUdfListWithCode
			detect: [ :each | each name = self libraryName ]) code)
		equals: self upperCaseLibraryCode
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testLoadExistingLibrarySignalsRsGenericError [
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	self
		should: [ self endpoint graphUdfLoad: self libraryName code: self echoLibraryCode ]
		raise: RsGenericError
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testLoadFromFileRegistersFunctions [
	| file |
	file := FileSystem memory root / 'upper.js'.
	file writeStreamDo: [ :stream | stream nextPutAll: self upperCaseLibraryCode ].
	self assert: (self endpoint graphUdfLoad: self libraryName file: file) equals: 'OK'.
	self assert: (self callUpOn: self libraryName) equals: 'ABC'
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testLoadFromFileWithReplaceOverwritesLibrary [
	| file |
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	file := FileSystem memory root / 'echo.js'.
	file writeStreamDo: [ :stream | stream nextPutAll: self echoLibraryCode ].
	self endpoint graphUdfLoad: self libraryName file: file replace: true.
	self assert: (self callUpOn: self libraryName) equals: 'abc'
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testLoadInvalidScriptSignalsRsGenericError [
	self
		should: [ self endpoint graphUdfLoad: self libraryName code: 'this is not js(' ]
		raise: RsGenericError
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testLoadRegistersFunctionsCallableFromCypher [
	self
		assert: (self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode)
		equals: 'OK'.
	self assert: (self callUpOn: self libraryName) equals: 'ABC'
]

{ #category : 'tests' }
FkGraphEndpointUdfTest >> testLoadWithReplaceOverwritesLibrary [
	self endpoint graphUdfLoad: self libraryName code: self upperCaseLibraryCode.
	self
		assert: (self endpoint graphUdfLoad: self libraryName code: self echoLibraryCode replace: true)
		equals: 'OK'.
	self assert: (self callUpOn: self libraryName) equals: 'abc'
]

{ #category : 'private' }
FkGraphEndpointUdfTest >> upperCaseLibraryCode [
	^ 'function up(s) { return s.toUpperCase(); } falkor.register(''Up'', up);'
]
