"
I test the CREATE INDEX and DROP INDEX Cypher that FkGraphIndex renders, without a FalkorDB
connection. Each index kind is covered for both a node label and a relationship type (cch is
relationship-only), including vector OPTIONS on create, their absence on drop, SCypher's
backtick quoting of names that would otherwise break the Cypher syntax, and #validate rejecting
an incomplete builder (missing kind, entity, properties, or a vector index without dimension:)
at conversion time.
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
FkGraphIndexTest >> dropCypherForProperty: aPropertyName builtBy: aBlock [
	| index |
	index := FkGraphIndex new.
	aBlock value: index.
	^ index dropCypherForProperty: aPropertyName
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForNodeFulltextIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index fulltext; node: 'Person'; props: #('name' 'bio') ].
	self
		assert: cypher
		equals: 'CREATE FULLTEXT INDEX FOR (n:Person) ON (n.name, n.bio)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForNodeRangeIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index range; node: 'Person'; props: #('email') ].
	self assert: cypher equals: 'CREATE INDEX FOR (n:Person) ON (n.email)'
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
		equals: 'CREATE VECTOR INDEX FOR (n:Doc) ON (n.embedding) OPTIONS {dimension: 128, similarityFunction: ''euclidean''}'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForRelationshipCchIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index cch; relationship: 'ROAD'; props: #('distance') ].
	self
		assert: cypher
		equals: 'CREATE CCH INDEX FOR ()-[r:ROAD]-() ON (r.distance)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForRelationshipFulltextIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index fulltext; relationship: 'KNOWS'; props: #('note') ].
	self
		assert: cypher
		equals: 'CREATE FULLTEXT INDEX FOR ()-[r:KNOWS]-() ON (r.note)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherForRelationshipRangeIndex [
	| cypher |
	cypher := self cypherBuiltBy: [ :index |
		index range; relationship: 'KNOWS'; props: #('since') ].
	self
		assert: cypher
		equals: 'CREATE INDEX FOR ()-[r:KNOWS]-() ON (r.since)'
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
		equals: 'CREATE VECTOR INDEX FOR ()-[r:SIMILAR]-() ON (r.embedding) OPTIONS {dimension: 3, similarityFunction: ''cosine''}'
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
		equals: 'CREATE INDEX FOR (n:`Person) RETURN 1`) ON (n.`email``hack`)'
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
		equals: 'CREATE VECTOR INDEX FOR (n:Doc) ON (n.embedding) OPTIONS {dimension: 2, similarityFunction: ''eucl''''idean''}'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeFulltextIndexIsOnePropertyPerStatement [
	| index |
	index := FkGraphIndex new.
	index fulltext; node: 'Person'; props: #('name' 'bio').
	self
		assert: (index dropCypherForProperty: 'name')
		equals: 'DROP FULLTEXT INDEX FOR (n:Person) ON (n.name)'.
	self
		assert: (index dropCypherForProperty: 'bio')
		equals: 'DROP FULLTEXT INDEX FOR (n:Person) ON (n.bio)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeRangeIndex [
	| cypher |
	cypher := self dropCypherForProperty: 'email' builtBy: [ :index |
		index range; node: 'Person'; props: #('email') ].
	self assert: cypher equals: 'DROP INDEX FOR (n:Person) ON (n.email)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeVectorIndexOmitsOptions [
	| cypher |
	cypher := self dropCypherForProperty: 'embedding' builtBy: [ :index |
		index
			vector;
			node: 'Doc';
			props: #('embedding');
			dimension: 128;
			similarityFunction: 'euclidean' ].
	self assert: cypher equals: 'DROP VECTOR INDEX FOR (n:Doc) ON (n.embedding)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForNodeVectorIndexDoesNotRequireDimension [
	"DROP INDEX never emits OPTIONS, so dropping a vector index must not demand dimension: -
	unlike #createCypher, which does."

	| cypher |
	cypher := self dropCypherForProperty: 'embedding' builtBy: [ :index |
		index vector; node: 'Doc'; props: #('embedding') ].
	self assert: cypher equals: 'DROP VECTOR INDEX FOR (n:Doc) ON (n.embedding)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipCchIndex [
	| cypher |
	cypher := self dropCypherForProperty: 'distance' builtBy: [ :index |
		index cch; relationship: 'ROAD'; props: #('distance') ].
	self
		assert: cypher
		equals: 'DROP CCH INDEX FOR ()-[r:ROAD]-() ON (r.distance)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipFulltextIndex [
	| cypher |
	cypher := self dropCypherForProperty: 'note' builtBy: [ :index |
		index fulltext; relationship: 'KNOWS'; props: #('note') ].
	self
		assert: cypher
		equals: 'DROP FULLTEXT INDEX FOR ()-[r:KNOWS]-() ON (r.note)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipRangeIndex [
	| cypher |
	cypher := self dropCypherForProperty: 'since' builtBy: [ :index |
		index range; relationship: 'KNOWS'; props: #('since') ].
	self
		assert: cypher
		equals: 'DROP INDEX FOR ()-[r:KNOWS]-() ON (r.since)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForRelationshipVectorIndexOmitsOptions [
	| cypher |
	cypher := self dropCypherForProperty: 'embedding' builtBy: [ :index |
		index
			vector;
			relationship: 'SIMILAR';
			props: #('embedding');
			dimension: 3;
			similarityFunction: 'cosine' ].
	self
		assert: cypher
		equals: 'DROP VECTOR INDEX FOR ()-[r:SIMILAR]-() ON (r.embedding)'
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherRaisesWhenIndexTypeNotSet [
	self
		should: [ self cypherBuiltBy: [ :index | index node: 'Person'; props: #('email') ] ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherRaisesWhenEntityNotSet [
	self
		should: [ self cypherBuiltBy: [ :index | index range; props: #('email') ] ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherRaisesWhenPropertiesNotSet [
	self
		should: [ self cypherBuiltBy: [ :index | index range; node: 'Person' ] ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherRaisesWhenPropertiesEmpty [
	self
		should: [ self cypherBuiltBy: [ :index | index range; node: 'Person'; props: #() ] ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphIndexTest >> testCreateCypherRaisesWhenVectorIndexHasNoDimension [
	self
		should: [
			self cypherBuiltBy: [ :index |
				index vector; node: 'Doc'; props: #('embedding') ] ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherForPropertyRaisesWhenIncomplete [
	self
		should: [
			self dropCypherForProperty: 'email' builtBy: [ :index | index node: 'Person'; props: #('email') ] ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphIndexTest >> testDropCypherQuotesNamesThatWouldBreakUnquotedCypher [
	| cypher |
	cypher := self dropCypherForProperty: 'email`hack' builtBy: [ :index |
		index range; node: 'Person) RETURN 1'; props: #('email`hack') ].
	self
		assert: cypher
		equals: 'DROP INDEX FOR (n:`Person) RETURN 1`) ON (n.`email``hack`)'
]
