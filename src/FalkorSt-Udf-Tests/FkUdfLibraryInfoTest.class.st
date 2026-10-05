"
I test FkUdfLibraryInfo's accessors over a raw GRAPH.UDF LIST entry, without a FalkorDB connection.
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
	info := FkUdfLibraryInfo fromListEntry: #('library_name' 'StringUtils' 'functions' #('Up' 'Add')).
	self assert: info name equals: 'StringUtils'.
	self assert: info functions asArray equals: #('Up' 'Add').
	self assert: info code isNil
]

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testCodeIsReadWhenListedWithCode [
	| info |
	info := FkUdfLibraryInfo fromListEntry: #('library_name' 'StringUtils' 'functions' #('Up')
			'library_code' 'falkor.register(''Up'', up);').
	self assert: info code equals: 'falkor.register(''Up'', up);'
]

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testFunctionsDefaultToEmptyWhenAbsent [
	self assert: (FkUdfLibraryInfo fromListEntry: #('library_name' 'StringUtils')) functions isEmpty
]

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testPrintStringShowsAllRawEntries [
	| printed |
	printed := (FkUdfLibraryInfo fromListEntry: #('library_name' 'StringUtils' 'renamed_key' 42)) printString.
	self assert: (printed includesSubstring: 'StringUtils').
	self assert: (printed includesSubstring: 'renamed_key')
]

{ #category : 'tests' }
FkUdfLibraryInfoTest >> testMissingLibraryNameSignalsKeyNotFound [
	self
		should: [ (FkUdfLibraryInfo fromListEntry: #('functions' #('Up'))) name ]
		raise: KeyNotFound
]
