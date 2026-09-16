"
I am the Redis endpoint FkFalkorStick creates for talking to FalkorDB. I add GRAPH.QUERY command
execution on top of RsRedisEndpoint's RESP transport, including FalkorDB's `CYPHER param=val ...`
parameter-passing convention, and decode replies into FkQueryResult (see FkQueryResult for the
verbose decoding rules and their current limitations).

Responsibility:
- Send GRAPH.QUERY commands (with or without bound parameters) via #unifiedCommand:
- Render Smalltalk parameter values as Cypher literals for the CYPHER prefix convention
- Decode the raw reply into an FkQueryResult before answering it

Collaborators:
- RsRedisEndpoint: I inherit RESP command execution and reply parsing
- FkFalkorStick: creates me as its endpoint class
- FkQueryResult: decodes the raw reply I obtain into a structured result

Public API and Key Messages:
- #graphQuery:cypher: - run a Cypher query against a named graph, no parameters, answering an FkQueryResult
- #graphQuery:cypher:params: - run a Cypher query with a dictionary of named parameters bound via
  the CYPHER prefix convention (e.g. CYPHER name='Alice' MATCH ... ), answering an FkQueryResult
- #rawGraphQuery:cypher: - like #graphQuery:cypher: but answers the undecoded raw reply

Implementation Points:
- Query errors surface as raised RsGenericError exceptions (see FkFalkorStick>>defaultRedisGenericErrorHandingBlock),
  not as nil/partial replies
- Parameter values are rendered as Cypher literals: strings are quoted and escaped, nil becomes
  null, everything else (numbers, booleans) uses its Smalltalk #printString
"
Class {
	#name : 'FkGraphEndpoint',
	#superclass : 'RsRedisEndpoint',
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
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString params: paramsDictionary [
	^ FkQueryResult
		fromVerboseReply:
			(self
				rawGraphQuery: graphName
				cypher: (self prependParams: paramsDictionary to: cypherString))
]

{ #category : 'private' }
FkGraphEndpoint >> prependParams: paramsDictionary to: cypherString [
	paramsDictionary ifEmpty: [ ^ cypherString ].
	^ 'CYPHER ' , (self cypherParamsClauseFor: paramsDictionary) , cypherString
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> rawGraphQuery: graphName cypher: cypherString [
	^ self unifiedCommand: { 'GRAPH.QUERY'. graphName. cypherString }
]
