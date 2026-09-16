"
I am the Redis endpoint FkFalkorStick creates for talking to FalkorDB. I add GRAPH.QUERY command
execution on top of RsRedisEndpoint's RESP transport, including FalkorDB's `CYPHER param=val ...`
parameter-passing convention and the `--compact` result format, and decode replies into
FkQueryResult (see FkQueryResult for the verbose/compact decoding rules). For compact decoding I
also own the per-graph label/relationship-type/property-key id caches, since resolving those ids
requires per-connection state that a stateless RsRedisEndpoint extension method couldn't hold.

Responsibility:
- Send GRAPH.QUERY commands (with or without bound parameters, verbose or compact) via #unifiedCommand:
- Render Smalltalk parameter values as Cypher literals for the CYPHER prefix convention
- Decode the raw reply into an FkQueryResult before answering it
- Cache and resolve label/relationship-type/property-key ids to names for compact decoding, one
  cache per graph name, refreshed on cache miss

Collaborators:
- RsRedisEndpoint: I inherit RESP command execution and reply parsing
- FkFalkorStick: creates me as its endpoint class
- FkQueryResult: decodes the raw reply I obtain into a structured result, calling back into me
  (#labelNameAt:inGraph:, #relationshipTypeNameAt:inGraph:, #propertyKeyNameAt:inGraph:) to
  resolve compact ids

Public API and Key Messages:
- #graphQuery:cypher: - run a verbose Cypher query, answering an FkQueryResult
- #graphQuery:cypher:params: - like #graphQuery:cypher: with named parameters bound via the CYPHER
  prefix convention (e.g. CYPHER name='Alice' MATCH ... )
- #graphQuery:cypher:compact: - like #graphQuery:cypher: but decodes via the compact reply format
  when the boolean is true
- #graphQuery:cypher:params:compact: - combines both of the above
- #rawGraphQuery:cypher: / #rawGraphQuery:cypher:compact: - like the above but answer the
  undecoded raw reply

Implementation Points:
- Query errors surface as raised RsGenericError exceptions (see FkFalkorStick>>defaultRedisGenericErrorHandingBlock),
  not as nil/partial replies
- Parameter values are rendered as Cypher literals: strings are quoted and escaped, nil becomes
  null, everything else (numbers, booleans) uses its Smalltalk #printString
- Id caches are Dictionaries of graphName -> Array of names, indexed by id (0-based); a lookup
  past the end of the cached array triggers one refresh via CALL db.labels()/relationshipTypes()/
  propertyKeys() before resolving (see design.md Decision 4)
"
Class {
	#name : 'FkGraphEndpoint',
	#superclass : 'RsRedisEndpoint',
	#instVars : [
		'labelCaches',
		'relTypeCaches',
		'propKeyCaches'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'private' }
FkGraphEndpoint >> cypherLiteralFor: aValue [
	aValue ifNil: [ ^ 'null' ].
	aValue isString ifTrue: [ ^ self cypherStringLiteralFor: aValue ].
	^ aValue printString
]

{ #category : 'private' }
FkGraphEndpoint >> cypherParamsClauseFor: paramsDictionary [
	^ String streamContents: [ :s |
		paramsDictionary keysAndValuesDo: [ :key :value |
			s
				nextPutAll: key;
				nextPut: $=;
				nextPutAll: (self cypherLiteralFor: value);
				nextPut: $  ] ]
]

{ #category : 'private' }
FkGraphEndpoint >> cypherStringLiteralFor: aString [
	| escaped |
	escaped := (aString copyReplaceAll: '\' with: '\\') copyReplaceAll: '"' with: '\"'.
	^ '"' , escaped , '"'
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString [
	^ FkQueryResult fromVerboseReply: (self rawGraphQuery: graphName cypher: cypherString)
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString compact: useCompact [
	useCompact ifFalse: [ ^ self graphQuery: graphName cypher: cypherString ].
	^ FkQueryResult
		fromCompactReply: (self rawGraphQuery: graphName cypher: cypherString compact: true)
		resolvedBy: self
		graph: graphName
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString params: paramsDictionary [
	^ self graphQuery: graphName cypher: (self prependParams: paramsDictionary to: cypherString)
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString params: paramsDictionary compact: useCompact [
	^ self
		graphQuery: graphName
		cypher: (self prependParams: paramsDictionary to: cypherString)
		compact: useCompact
]

{ #category : 'accessing' }
FkGraphEndpoint >> labelCaches [
	^ labelCaches ifNil: [ labelCaches := Dictionary new ]
]

{ #category : 'compact-id-resolution' }
FkGraphEndpoint >> labelNameAt: labelId inGraph: graphName [
	^ self nameAt: labelId graph: graphName caches: self labelCaches procedure: 'db.labels'
]

{ #category : 'private' }
FkGraphEndpoint >> nameAt: anId graph: graphName caches: cachesDict procedure: procedureName [
	| cache |
	cache := cachesDict at: graphName ifAbsent: [ nil ].
	(cache isNil or: [ anId >= cache size ])
		ifTrue: [ cache := self refreshCache: cachesDict graph: graphName procedure: procedureName ].
	anId >= cache size
		ifTrue: [
			(RsGenericError errorMessage: 'Cannot resolve compact id ' , anId printString , ' from ' , procedureName , ' in graph ' , graphName printString) signal ].
	^ cache at: anId + 1
]

{ #category : 'private' }
FkGraphEndpoint >> prependParams: paramsDictionary to: cypherString [
	paramsDictionary ifEmpty: [ ^ cypherString ].
	^ 'CYPHER ' , (self cypherParamsClauseFor: paramsDictionary) , cypherString
]

{ #category : 'accessing' }
FkGraphEndpoint >> propKeyCaches [
	^ propKeyCaches ifNil: [ propKeyCaches := Dictionary new ]
]

{ #category : 'compact-id-resolution' }
FkGraphEndpoint >> propertyKeyNameAt: propertyKeyId inGraph: graphName [
	^ self
		nameAt: propertyKeyId
		graph: graphName
		caches: self propKeyCaches
		procedure: 'db.propertyKeys'
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> rawGraphQuery: graphName cypher: cypherString [
	^ self rawGraphQuery: graphName cypher: cypherString compact: false
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> rawGraphQuery: graphName cypher: cypherString compact: useCompact [
	| args |
	args := OrderedCollection with: 'GRAPH.QUERY' with: graphName with: cypherString.
	useCompact ifTrue: [ args add: '--compact' ].
	^ self unifiedCommand: args
]

{ #category : 'private' }
FkGraphEndpoint >> refreshCache: cachesDict graph: graphName procedure: procedureName [
	| rawReply names |
	rawReply := self rawGraphQuery: graphName cypher: 'CALL ' , procedureName , '()' compact: true.
	names := (rawReply second collect: [ :rawRow | rawRow first second ]) asArray.
	cachesDict at: graphName put: names.
	^ names
]

{ #category : 'accessing' }
FkGraphEndpoint >> relTypeCaches [
	^ relTypeCaches ifNil: [ relTypeCaches := Dictionary new ]
]

{ #category : 'compact-id-resolution' }
FkGraphEndpoint >> relationshipTypeNameAt: relationshipTypeId inGraph: graphName [
	^ self
		nameAt: relationshipTypeId
		graph: graphName
		caches: self relTypeCaches
		procedure: 'db.relationshipTypes'
]
