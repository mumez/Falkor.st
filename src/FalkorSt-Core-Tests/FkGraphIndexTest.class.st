"
I test the CREATE INDEX and DROP INDEX Cypher that FkGraphIndex renders, without a FalkorDB
connection. Each index kind is covered for both a node label and a relationship type, including
vector OPTIONS on create, their absence on drop, and backtick quoting of names.
"
Class {
	#name : 'FkGraphIndexTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'private' }
FkGraphIndexTest >> cypherBuiltBy: aBlock [
	| index |
	index := FkGraphIndex new.
	aBlock value: index.
	^ index createCypher
]

{ #category : 'private' }
FkGraphIndexTest >> dropCypherBuiltBy: aBlock [
	| index |
	index := FkGraphIndex new.
	aBlock value: index.
	^ index dropCypher
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForNodeFulltextIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index fulltext; node: 'Person'; props: #('name' 'bio') ].
	self
		assert: cypher
		equals: 'CREATE FULLTEXT INDEX FOR (e:`Person`) ON (e.`name`, e.`bio`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForNodeRangeIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index range; node: 'Person'; props: #('email') ].
	self assert: cypher equals: 'CREATE INDEX FOR (e:`Person`) ON (e.`email`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForNodeVectorIndexIncludesOptions [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index
			vector;
			node: 'Doc';
			props: #('embedding');
			dimension: 128;
			similarityFunction: 'euclidean' ].
	self
		assert: cypher
		equals: 'CREATE VECTOR INDEX FOR (e:`Doc`) ON (e.`embedding`) OPTIONS {dimension: 128, similarityFunction: ''euclidean''}'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForRelationshipFulltextIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index fulltext; relationship: 'KNOWS'; props: #('note') ].
	self
		assert: cypher
		equals: 'CREATE FULLTEXT INDEX FOR ()-[e:`KNOWS`]->() ON (e.`note`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForRelationshipRangeIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index range; relationship: 'KNOWS'; props: #('since') ].
	self
		assert: cypher
		equals: 'CREATE INDEX FOR ()-[e:`KNOWS`]->() ON (e.`since`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForRelationshipVectorIndexIncludesOptions [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index
			vector;
			relationship: 'SIMILAR';
			props: #('embedding');
			dimension: 3;
			similarityFunction: 'cosine' ].
	self
		assert: cypher
		equals: 'CREATE VECTOR INDEX FOR ()-[e:`SIMILAR`]->() ON (e.`embedding`) OPTIONS {dimension: 3, similarityFunction: ''cosine''}'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherQuotesNamesThatWouldBreakUnquotedCypher [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index
			range;
			node: 'Person) RETURN 1';
			props: #('email`hack') ].
	self
		assert: cypher
		equals: 'CREATE INDEX FOR (e:`Person) RETURN 1`) ON (e.`email``hack`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherQuotesSimilarityFunctionString [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index
			vector;
			node: 'Doc';
			props: #('embedding');
			dimension: 2;
			similarityFunction: 'eucl''idean' ].
	self
		assert: cypher
		equals: 'CREATE VECTOR INDEX FOR (e:`Doc`) ON (e.`embedding`) OPTIONS {dimension: 2, similarityFunction: ''eucl''''idean''}'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForOneFulltextProperty [
	| cypher |
	cypher := (FkGraphIndex new
		fulltext;
		node: 'Person';
		props: #('name' 'bio');
		yourself) dropCypherForProperty: 'bio'.
	self assert: cypher equals: 'DROP FULLTEXT INDEX FOR (e:`Person`) ON (e.`bio`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeFulltextIndex [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index fulltext; node: 'Person'; props: #('name' 'bio') ].
	self
		assert: cypher
		equals: 'DROP FULLTEXT INDEX FOR (e:`Person`) ON (e.`name`, e.`bio`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeRangeIndex [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index range; node: 'Person'; props: #('email') ].
	self assert: cypher equals: 'DROP INDEX FOR (e:`Person`) ON (e.`email`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeVectorIndexOmitsOptions [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index
			vector;
			node: 'Doc';
			props: #('embedding');
			dimension: 128;
			similarityFunction: 'euclidean' ].
	self assert: cypher equals: 'DROP VECTOR INDEX FOR (e:`Doc`) ON (e.`embedding`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipFulltextIndex [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index fulltext; relationship: 'KNOWS'; props: #('note') ].
	self
		assert: cypher
		equals: 'DROP FULLTEXT INDEX FOR ()-[e:`KNOWS`]->() ON (e.`note`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipRangeIndex [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index range; relationship: 'KNOWS'; props: #('since') ].
	self
		assert: cypher
		equals: 'DROP INDEX FOR ()-[e:`KNOWS`]->() ON (e.`since`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipVectorIndexOmitsOptions [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index
			vector;
			relationship: 'SIMILAR';
			props: #('embedding');
			dimension: 3;
			similarityFunction: 'cosine' ].
	self
		assert: cypher
		equals: 'DROP VECTOR INDEX FOR ()-[e:`SIMILAR`]->() ON (e.`embedding`)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherQuotesNamesThatWouldBreakUnquotedCypher [
	| cypher |
	cypher := self dropCypherBuiltBy: [ :index |
		index range; node: 'Person) RETURN 1'; props: #('email`hack') ].
	self
		assert: cypher
		equals: 'DROP INDEX FOR (e:`Person) RETURN 1`) ON (e.`email``hack`)'
]
