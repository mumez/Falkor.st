"
I am a fluent builder for a FalkorDB CREATE INDEX statement: the index kind (range, fulltext, or
vector), the entity it covers (a node label or relationship type), the property names, and, for a
vector index, the dimension and similarity function. I don't know which graph the index is created
on. FkGraphEndpoint supplies that when it runs the Cypher from #createCypher.

Responsibility:
- Hold the index kind, entity, properties, and optional vector options
- Render CREATE INDEX Cypher whose label and property names are backtick-quoted, so a name cannot
  break out of the identifier

Collaborators:
- FkGraphEndpoint: builds or receives me, then sends #createCypher through GRAPH.QUERY

Public API and Key Messages:
- #range / #fulltext / #vector - set the index kind
- #node: / #relationship: - set the entity
- #props: - set the property names
- #dimension: / #similarityFunction: - vector OPTIONS
- #createCypher - the CREATE INDEX statement
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
	self indexType: 'FULLTEXT'.
	^ self
]

{ #category : 'accessing' }
FkGraphIndex >> indexType [
	^ indexType
]

{ #category : 'building' }
FkGraphIndex >> node: aLabel [
	self entityType: 'NODE'.
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
	self indexType: 'RANGE'.
	^ self
]

{ #category : 'building' }
FkGraphIndex >> relationship: aRelType [
	self entityType: 'RELATIONSHIP'.
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
	self indexType: 'VECTOR'.
	^ self
]

{ #category : 'cypher' }
FkGraphIndex >> createCypher [
	"Answer CREATE INDEX Cypher. Range omits a type keyword. Vector appends OPTIONS when set."

	^ String streamContents: [ :stream |
		stream
			nextPutAll: self createIndexPrefix;
			nextPutAll: self entityPattern;
			nextPutAll: ' ON (';
			nextPutAll: self propertyList;
			nextPut: $).
		self optionsClause ifNotNil: [ :clause | stream space; nextPutAll: clause ] ]
]

{ #category : 'private' }
FkGraphIndex >> createIndexPrefix [
	self indexType = 'RANGE' ifTrue: [ ^ 'CREATE INDEX FOR ' ].
	^ 'CREATE ' , self indexType , ' INDEX FOR '
]

{ #category : 'private' }
FkGraphIndex >> entityName: aString [
	entityName := aString
]

{ #category : 'private' }
FkGraphIndex >> entityPattern [
	| quotedName |
	quotedName := self quotedName: self entityName.
	self entityType = 'NODE' ifTrue: [ ^ '(e:' , quotedName , ')' ].
	^ '()-[e:' , quotedName , ']->()'
]

{ #category : 'private' }
FkGraphIndex >> entityType: aString [
	entityType := aString
]

{ #category : 'private' }
FkGraphIndex >> indexType: aString [
	indexType := aString
]

{ #category : 'private' }
FkGraphIndex >> optionsClause [
	| parts |
	self indexType = 'VECTOR' ifFalse: [ ^ nil ].
	parts := OrderedCollection new.
	self dimension ifNotNil: [ :dim | parts add: 'dimension: ' , dim printString ].
	self similarityFunction ifNotNil: [ :fn |
		parts add: 'similarityFunction: ' , (self quotedString: fn) ].
	parts ifEmpty: [ ^ nil ].
	^ 'OPTIONS {' , (', ' join: parts) , '}'
]

{ #category : 'private' }
FkGraphIndex >> properties: aCollection [
	properties := aCollection
]

{ #category : 'private' }
FkGraphIndex >> propertyList [
	^ String streamContents: [ :stream |
		self properties
			do: [ :each |
				stream
					nextPutAll: 'e.';
					nextPutAll: (self quotedName: each) ]
			separatedBy: [ stream nextPutAll: ', ' ] ]
]

{ #category : 'private' }
FkGraphIndex >> quotedName: aString [
	"Backtick-quote a Cypher identifier, doubling any backtick already in the name."

	^ '`' , (aString copyReplaceAll: '`' with: '``') , '`'
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
