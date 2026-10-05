"
I am a fluent builder for a FalkorDB CREATE INDEX statement: the index kind (range, fulltext, vector,
or cch), the entity it covers (a node label or relationship type), the property names, and, for a
vector index, the dimension and similarity function. I don't know which graph the index is created
on. FkGraphEndpoint supplies that when it runs the Cypher from #createCypher. Entity/properties
state and the common completeness check live on my superclass FkGraphEntityBuilder.

Responsibility:
- Hold the index kind and optional vector options (entity and properties are inherited)
- Render CREATE INDEX Cypher, and DROP INDEX Cypher for a single property, via SCypher - entity and
  property names come out backtick-quoted because SCypher quotes identifiers itself

Collaborators:
- FkGraphEndpoint: builds or receives me, then sends #createCypher through GRAPH.QUERY
- SCypher's CyCreateIndex/CyDropIndex: assemble and render the Cypher statement itself; vector OPTIONS
  have no SCypher equivalent, so FkGraphIndex appends that clause itself

Public API and Key Messages:
- #range / #fulltext / #vector / #cch - set the index kind
- #node: / #relationship: - set the entity. A cch index only applies to a relationship type -
  FalkorDB itself rejects a cch index built against a node label
- #props: - set the property names. A cch index takes exactly one property, the edge weight
- #dimension: / #similarityFunction: - vector OPTIONS
- #createCypher - the CREATE INDEX statement. Raises RsError invalidArguments (via #validate) when
  indexType, entity, or properties was never set, or (vector only, create-only - DROP never emits
  OPTIONS) when dimension: was never set
- #dropCypherForProperty: - the DROP INDEX statement for one property. FalkorDB removes one property
  per DROP, so a multi-property spec is dropped by calling this once per property. Raises RsError
  invalidArguments (via #validate) when indexType, entity, or properties was never set
"
Class {
	#name : 'FkGraphIndex',
	#superclass : 'FkGraphEntityBuilder',
	#instVars : [
		'indexType',
		'dimension',
		'similarityFunction'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'constants-index' }
FkGraphIndex class >> cchIndexType [
	^ #cch
]

{ #category : 'constants-index' }
FkGraphIndex class >> fulltextIndexType [
	^ #fulltext
]

{ #category : 'constants-entity' }
FkGraphIndex class >> nodeEntityType [
	^ #node
]

{ #category : 'constants-index' }
FkGraphIndex class >> rangeIndexType [
	^ #range
]

{ #category : 'constants-entity' }
FkGraphIndex class >> relationshipEntityType [
	^ #relationship
]

{ #category : 'constants-index' }
FkGraphIndex class >> vectorIndexType [
	^ #vector
]

{ #category : 'building' }
FkGraphIndex >> cch [
	self indexType: self class cchIndexType.
	^ self
]

{ #category : 'accessing' }
FkGraphIndex >> dimension [
	^ dimension
]

{ #category : 'building' }
FkGraphIndex >> dimension: anInteger [
	self setDimension: anInteger.
	^ self
]

{ #category : 'building' }
FkGraphIndex >> fulltext [
	self indexType: self class fulltextIndexType.
	^ self
]

{ #category : 'accessing' }
FkGraphIndex >> indexType [
	^ indexType
]

{ #category : 'building' }
FkGraphIndex >> range [
	self indexType: self class rangeIndexType.
	^ self
]

{ #category : 'accessing' }
FkGraphIndex >> similarityFunction [
	^ similarityFunction
]

{ #category : 'building' }
FkGraphIndex >> similarityFunction: aString [
	self setSimilarityFunction: aString.
	^ self
]

{ #category : 'building' }
FkGraphIndex >> vector [
	self indexType: self class vectorIndexType.
	^ self
]

{ #category : 'cypher' }
FkGraphIndex >> createCypher [
	"Answer CREATE INDEX Cypher. Range omits a type keyword. Vector appends OPTIONS when set."

	| cypher |
	self validateDimensionForCreate.
	cypher := (self cyCommand: CyCreateIndex forProperties: self properties)
		cypherString trimRight.
	self optionsClause ifNotNil: [ :clause | cypher := cypher , ' ' , clause ].
	^ cypher
]

{ #category : 'cypher' }
FkGraphIndex >> dropCypherForProperty: aPropertyName [
	"Answer DROP INDEX Cypher for one property. FalkorDB removes one property per DROP statement."

	^ (self cyCommand: CyDropIndex forProperties: { aPropertyName })
		cypherString trimRight
]

{ #category : 'validation' }
FkGraphIndex >> incompleteBuilderMessage [
	^ 'FkGraphIndex requires indexType, entity (node:/relationship:), and props: to be set'
]

{ #category : 'validation' }
FkGraphIndex >> kindIsMissing [
	^ self indexType isNil
]

{ #category : 'private' }
FkGraphIndex >> applyIndexTypeTo: aCyIndexCommand [
	"Range has no type keyword; every other kind uses its uppercased name (FULLTEXT, VECTOR, CCH)."

	self indexType = self class rangeIndexType ifFalse: [
		aCyIndexCommand spec: [ :specifier | specifier type: self indexType asString asUppercase ] ]
]

{ #category : 'private' }
FkGraphIndex >> cyCommand: aCyIndexCommandClass forProperties: aCollection [
	| entity command |
	self validate.
	entity := self entityCyObject.
	command := aCyIndexCommandClass
		target: entity
		props: (CyObjects withAll: (aCollection collect: [ :each | entity @ each ])).
	self applyIndexTypeTo: command.
	^ command
]

{ #category : 'private' }
FkGraphIndex >> entityCyObject [
	"Answer the CyNode or CyRelationship used both as the FOR target and as the receiver of
	property accessors. A relationship index targets an undirected ()-[r:TYPE]-() pattern - FalkorDB
	has no notion of relationship direction for CREATE/DROP INDEX."

	self entityType = self class nodeEntityType
		ifTrue: [ ^ self entityVariableName asCypherIdentifier node: { self entityName } ].
	^ (CyNode empty)
		- (self entityVariableName asCypherIdentifier rel: { self entityName })
		- CyNode empty
]

{ #category : 'private' }
FkGraphIndex >> entityVariableName [
	^ self entityType = self class nodeEntityType
		ifTrue: [ 'n' ]
		ifFalse: [ 'r' ]
]

{ #category : 'private' }
FkGraphIndex >> indexType: aString [
	indexType := aString
]

{ #category : 'private' }
FkGraphIndex >> optionsClause [
	| parts |
	self indexType = self class vectorIndexType ifFalse: [ ^ nil ].
	parts := OrderedCollection new.
	self dimension ifNotNil: [ :dim | parts add: 'dimension: ' , dim printString ].
	self similarityFunction ifNotNil: [ :fn |
		parts add: 'similarityFunction: ' , (self quotedString: fn) ].
	parts ifEmpty: [ ^ nil ].
	^ 'OPTIONS {' , (parts joinUsing: ', ') , '}'
]

{ #category : 'private' }
FkGraphIndex >> quotedString: aString [
	"Single-quote a Cypher string literal, doubling any embedded single quote."

	^ '''' , (aString copyReplaceAll: '''' with: '''''') , ''''
]

{ #category : 'private' }
FkGraphIndex >> setDimension: anInteger [
	dimension := anInteger
]

{ #category : 'private' }
FkGraphIndex >> setSimilarityFunction: aString [
	similarityFunction := aString
]

{ #category : 'private' }
FkGraphIndex >> validateDimensionForCreate [
	"Vector OPTIONS, including dimension:, are only ever rendered by #createCypher - DROP INDEX
	never emits them - so this check must not run on the #dropCypherForProperty: path."

	(self indexType = self class vectorIndexType and: [ self dimension isNil ])
		ifTrue: [
			^ self signalInvalidArguments:
				'FkGraphIndex requires dimension: to be set for a vector index' ]
]
