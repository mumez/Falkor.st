"
I test FkGraphIndexInfo class >> allFromQueryResult:, the single place CALL db.indexes() records
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
FkGraphIndexInfoTest >> testAllFromQueryResultMapsEachRecord [
	| result infos |
	result := FkQueryResult new
		setHeader: #('label' 'entitytype')
		records: #(#('Person' 'NODE') #('KNOWS' 'RELATIONSHIP'))
		statistics: #().
	infos := FkGraphIndexInfo allFromQueryResult: result.
	self assert: (infos collect: [ :each | each class ]) asArray equals: { FkGraphIndexInfo. FkGraphIndexInfo }.
	self assert: (infos collect: [ :each | each label ]) asArray equals: #('Person' 'KNOWS').
	self assert: infos second entityType equals: 'RELATIONSHIP'
]

{ #category : 'tests' }
FkGraphIndexInfoTest >> testAllFromQueryResultOnEmptyResultAnswersEmpty [
	self assert: (FkGraphIndexInfo allFromQueryResult: (FkQueryResult new setHeader: #() records: #() statistics: #())) isEmpty
]
