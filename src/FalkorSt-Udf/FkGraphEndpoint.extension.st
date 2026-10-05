Extension { #name : 'FkGraphEndpoint' }

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfDelete: libraryName [
	^ self unifiedCommand: { 'GRAPH.UDF'. 'DELETE'. libraryName }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfFlush [
	^ self unifiedCommand: { 'GRAPH.UDF'. 'FLUSH' }
]

{ #category : '*FalkorSt-Udf-private' }
FkGraphEndpoint >> graphUdfLibrariesWithListOptions: listOptions [
	^ (self unifiedCommand: { 'GRAPH.UDF'. 'LIST' } , listOptions) collect: [ :rawEntry |
		FkUdfLibraryInfo fromListEntry: rawEntry ]
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfList [
	^ self graphUdfLibrariesWithListOptions: #()
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfList: libraryName [
	^ self graphUdfLibrariesWithListOptions: { libraryName }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfListWithCode [
	^ self graphUdfLibrariesWithListOptions: #('WITHCODE')
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfListWithCode: libraryName [
	^ self graphUdfLibrariesWithListOptions: { libraryName. 'WITHCODE' }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName code: jsString [
	^ self graphUdfLoad: libraryName code: jsString replace: false
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName code: jsString replace: aBoolean [
	| replaceOption |
	replaceOption := aBoolean ifTrue: [ #('REPLACE') ] ifFalse: [ #() ].
	^ self unifiedCommand: { 'GRAPH.UDF'. 'LOAD' } , replaceOption , { libraryName. jsString }
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName file: aFileReference [
	^ self graphUdfLoad: libraryName file: aFileReference replace: false
]

{ #category : '*FalkorSt-Udf' }
FkGraphEndpoint >> graphUdfLoad: libraryName file: aFileReference replace: aBoolean [
	^ self graphUdfLoad: libraryName code: aFileReference contents replace: aBoolean
]
