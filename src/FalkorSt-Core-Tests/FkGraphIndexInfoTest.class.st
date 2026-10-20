"
I test FkGraphIndexInfo class >> collectFromQueryResult:, the single place CALL db.indexes() records
are mapped to FkGraphIndexInfo. I need no FalkorDB instance; listing real indexes is covered by
FkGraphEndpointTest.
"
Class {
	#name : 'FkGraphIndexInfoTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkGraphIndexInfoTest >> testCollectFromQueryResultMapsEachRecord [
	| result infos |
	result := FkQueryResult new
		setHeader: #('label' 'entitytype')
		records: #(#('Person' 'NODE') #('KNOWS' 'RELATIONSHIP'))
		statistics: #().
	infos := FkGraphIndexInfo collectFromQueryResult: result.
	self assert: infos class equals: Array.
	self assert: (infos collect: [ :each | each class ]) asArray equals: { FkGraphIndexInfo. FkGraphIndexInfo }.
	self assert: (infos collect: [ :each | each label ]) asArray equals: #('Person' 'KNOWS').
	self assert: infos second entityType equals: 'RELATIONSHIP'
]

{ #category : 'tests' }
FkGraphIndexInfoTest >> testCollectFromQueryResultOnEmptyResultAnswersEmpty [
	self assert: (FkGraphIndexInfo collectFromQueryResult: FkQueryResult empty) isEmpty
]

{ #category : 'tests - printing' }
FkGraphIndexInfoTest >> testPrintStringShowsRawRecordAsSton [
	| info |
	info := FkGraphIndexInfo fromRecord: (Dictionary new at: 'label' put: 'Person'; yourself).
	self assert: info printString equals: 'a FkGraphIndexInfo({''label'':''Person''})'
]

{ #category : 'tests - printing' }
FkGraphIndexInfoTest >> testPrintStringToleratesNilRawRecord [
	self assert: FkGraphIndexInfo new printString equals: 'a FkGraphIndexInfo(nil)'
]
