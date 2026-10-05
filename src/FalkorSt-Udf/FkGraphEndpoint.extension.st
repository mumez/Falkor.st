Extension { #name : 'FkGraphEndpoint' }

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfDelete: libraryName [
	^ self unifiedCommand: { 'GRAPH.UDF'. 'DELETE'. libraryName }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfFlush [
	^ self unifiedCommand: { 'GRAPH.UDF'. 'FLUSH' }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfList [
	^ self graphUdfListArgs: #()
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfList: libraryName [
	^ self graphUdfListArgs: { libraryName }
]

{ #category : '*FalkorSt-Udf-private' }
FkGraphEndpoint >> graphUdfListArgs: optionalArgs [
	^ (self unifiedCommand: { 'GRAPH.UDF'. 'LIST' } , optionalArgs) collect: [ :rawEntry |
		FkUdfLibraryInfo fromDictionary: (self dictionaryFromFlatPairs: rawEntry) ]
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfListWithCode [
	^ self graphUdfListArgs: #('WITHCODE')
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfListWithCode: libraryName [
	^ self graphUdfListArgs: { libraryName. 'WITHCODE' }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName code: jsString [
	^ self graphUdfLoad: libraryName code: jsString replace: false
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName code: jsString replace: aBoolean [
	| args |
	args := OrderedCollection with: 'GRAPH.UDF' with: 'LOAD'.
	aBoolean ifTrue: [ args add: 'REPLACE' ].
	args add: libraryName; add: jsString.
	^ self unifiedCommand: args
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName file: aFileReference [
	^ self graphUdfLoad: libraryName file: aFileReference replace: false
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName file: aFileReference replace: aBoolean [
	^ self graphUdfLoad: libraryName code: aFileReference contents replace: aBoolean
]
