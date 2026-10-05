"
I test FkUdfLibraryInfo's accessors over a GRAPH.UDF LIST entry, without a FalkorDB connection.
"
Class {
	#name : 'FkUdfLibraryInfoTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Udf-Tests',
	#package : 'FalkorSt-Udf-Tests'
}

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testAccessorsReadListEntry [
	| info |
	info := FkUdfLibraryInfo fromDictionary: {
		'library_name' -> 'StringUtils'.
		'functions' -> #('Up' 'Add') } asDictionary.
	self assert: info libraryName equals: 'StringUtils'.
	self assert: info functions asArray equals: #('Up' 'Add').
	self assert: info code isNil
]

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testCodeIsReadWhenListedWithCode [
	| info |
	info := FkUdfLibraryInfo fromDictionary: {
		'library_name' -> 'StringUtils'.
		'functions' -> #('Up').
		'library_code' -> 'falkor.register(''Up'', up);' } asDictionary.
	self assert: info code equals: 'falkor.register(''Up'', up);'
]

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testFunctionsDefaultToEmptyWhenAbsent [
	self assert: (FkUdfLibraryInfo fromDictionary: Dictionary new) functions isEmpty
]
