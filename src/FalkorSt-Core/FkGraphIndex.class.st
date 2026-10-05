"
I am a fluent builder for a FalkorDB CREATE INDEX statement: the index kind (range, fulltext, vector,
or cch), the entity it covers (a node label or relationship type), the property names, and, for a
vector index, the dimension and similarity function. I don't know which graph the index is created
on. FkGraphEndpoint supplies that when it runs the Cypher from #createCypher.

Responsibility:
- Hold the index kind, entity, properties, and optional vector options
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
- #createCypher - the CREATE INDEX statement
- #dropCypherForProperty: - the DROP INDEX statement for one property. FalkorDB removes one property per DROP, so a multi-property spec is dropped by calling this once per property
- #validate - raises RsError invalidArguments when indexType, entity, or properties was never set,
  or when a vector index has no dimension:. Called automatically at conversion time, not from the
  fluent setters
"
Class {
	#name : 'FkGraphIndex',
	#superclass : 'Object',
	#instVars : [
		'indexType',
		'entityType',
		'entityName',
		'properties',
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

{ #category : 'accessing' }
FkGraphIndex >> entityName [
	^ entityName
]

{ #category : 'accessing' }
FkGraphIndex >> entityType [
	^ entityType
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
FkGraphIndex >> node: aLabel [
	self entityType: self class nodeEntityType.
	self entityName: aLabel.
	^ self
]

{ #category : 'accessing' }
FkGraphIndex >> properties [
	^ properties
]

{ #category : 'building' }
FkGraphIndex >> props: aCollection [
	self properties: aCollection.
	^ self
]

{ #category : 'building' }
FkGraphIndex >> range [
	self indexType: self class rangeIndexType.
	^ self
]

{ #category : 'building' }
FkGraphIndex >> relationship: aRelType [
	self entityType: self class relationshipEntityType.
	self entityName: aRelType.
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
FkGraphIndex >> entityName: aString [
	entityName := aString
]

{ #category : 'private' }
FkGraphIndex >> entityType: aString [
	entityType := aString
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
FkGraphIndex >> properties: aCollection [
	properties := aCollection
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

{ #category : 'validation' }
FkGraphIndex >> validate [
	"Fail fast with RsError invalidArguments rather than letting #createCypher or
	#dropCypherForProperty: render an ill-formed statement."

	(self indexType isNil or: [
		self entityType isNil or: [ self properties isNil or: [ self properties isEmpty ] ] ])
		ifTrue: [
			^ self signalInvalidArguments:
				'FkGraphIndex requires indexType, entity (node:/relationship:), and props: to be set' ].
	(self indexType = self class vectorIndexType and: [ self dimension isNil ])
		ifTrue: [
			^ self signalInvalidArguments:
				'FkGraphIndex requires dimension: to be set for a vector index' ]
]

{ #category : 'error signaling' }
FkGraphIndex >> signalInvalidArguments: aMessageString [
	^ RsError invalidArguments signal: aMessageString
]
