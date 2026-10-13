"
I test FkGraphConstraintInfo class >> allFromQueryResult:, the single place CALL db.constraints()
records are mapped to FkGraphConstraintInfo. I need no FalkorDB instance; listing real constraints
is covered by FkGraphEndpointTest.
"
Class {
	#name : 'FkGraphConstraintInfoTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkGraphConstraintInfoTest >> testAllFromQueryResultMapsEachRecord [
	| result infos |
	result := FkQueryResult new
		setHeader: #('type' 'label')
		records: #(#('UNIQUE' 'Person') #('MANDATORY' 'KNOWS'))
		statistics: #().
	infos := FkGraphConstraintInfo allFromQueryResult: result.
	self assert: (infos collect: [ :each | each class ]) asArray equals: { FkGraphConstraintInfo. FkGraphConstraintInfo }.
	self assert: (infos collect: [ :each | each entityName ]) asArray equals: #('Person' 'KNOWS').
	self assert: infos second constraintType equals: 'MANDATORY'
]

{ #category : 'tests' }
FkGraphConstraintInfoTest >> testAllFromQueryResultOnEmptyResultAnswersEmpty [
	self assert: (FkGraphConstraintInfo allFromQueryResult: (FkQueryResult new setHeader: #() records: #() statistics: #())) isEmpty
]
