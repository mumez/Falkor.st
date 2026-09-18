"
I am the Redis endpoint FkFalkorStick creates for talking to FalkorDB. I add GRAPH.QUERY,
GRAPH.RO_QUERY, GRAPH.DELETE, GRAPH.INFO, GRAPH.CONFIG, GRAPH.CONSTRAINT, GRAPH.EXPLAIN,
GRAPH.PROFILE, GRAPH.LIST, GRAPH.COPY, GRAPH.MEMORY, and GRAPH.SLOWLOG command execution on top of
RsRedisEndpoint's RESP transport, including FalkorDB's
`CYPHER param=val ...`
parameter-passing convention and the `--compact` result format, and decode GRAPH.QUERY/
GRAPH.RO_QUERY replies into FkQueryResult (see FkQueryResult for the verbose/compact decoding
rules). For compact decoding I also own the per-graph label/relationship-type/property-key id
caches, since resolving those ids requires per-connection state that a stateless RsRedisEndpoint
extension method couldn't hold.

Responsibility:
- Send GRAPH.QUERY and GRAPH.RO_QUERY commands (with or without bound parameters, verbose or
  compact) via #unifiedCommand:
- Send GRAPH.DELETE, GRAPH.INFO, GRAPH.CONFIG GET/SET, GRAPH.CONSTRAINT CREATE/DROP, GRAPH.EXPLAIN,
  GRAPH.PROFILE, GRAPH.LIST, and GRAPH.COPY commands via #unifiedCommand:, answering their raw
  replies undecoded (GRAPH.DELETE's status string, GRAPH.INFO's ad-hoc section data,
  GRAPH.CONFIG's parameter list, GRAPH.CONSTRAINT's PENDING/OK status string,
  GRAPH.EXPLAIN/GRAPH.PROFILE's plain-text plan, GRAPH.LIST's array of graph names, and
  GRAPH.COPY's status string are not FkQueryResult-shaped)
- Send GRAPH.MEMORY USAGE and GRAPH.SLOWLOG commands via #unifiedCommand:, decoding their flat/
  nested raw replies into a usable Dictionary and OrderedCollection of FkSlowLogEntry respectively
- Render Smalltalk parameter values as Cypher literals for the CYPHER prefix convention
- Decode GRAPH.QUERY/GRAPH.RO_QUERY raw replies into an FkQueryResult before answering them
- Cache and resolve label/relationship-type/property-key ids to names for compact decoding, one
  cache per graph name, refreshed on cache miss

Collaborators:
- RsRedisEndpoint: I inherit RESP command execution and reply parsing
- FkFalkorStick: creates me as its endpoint class
- FkQueryResult: decodes the raw reply I obtain into a structured result, calling back into me
  (#labelNameAt:inGraph:, #relationshipTypeNameAt:inGraph:, #propertyKeyNameAt:inGraph:) to
  resolve compact ids
- FkGraphInfoOptions: collects which GRAPH.INFO sections to request, evaluated against a caller's
  block in #graphInfo:
- FkGraphConstraint: collects a constraint's type/entity/properties for the
  #graphConstraintCreateWith:on: / #graphConstraintCreateBy:on: / #graphConstraintDropWith:on: /
  #graphConstraintDropBy:on: object-based API, built by the caller or evaluated against a caller's
  block
- FkSlowLogEntry: the decoded value object I build one per raw GRAPH.SLOWLOG entry in #graphSlowLog:

Public API and Key Messages:
- #graphQuery:cypher: - run a verbose Cypher query, answering an FkQueryResult
- #graphQuery:cypher:params: - like #graphQuery:cypher: with named parameters bound via the CYPHER
  prefix convention (e.g. CYPHER name='Alice' MATCH ... )
- #graphQuery:cypher:compact: - like #graphQuery:cypher: but decodes via the compact reply format
  when the boolean is true
- #graphQuery:cypher:params:compact: - combines both of the above
- #rawGraphQuery:cypher: / #rawGraphQuery:cypher:compact: - like the above but answer the
  undecoded raw reply
- #graphRoQuery:cypher: / #graphRoQuery:cypher:params: / #graphRoQuery:cypher:compact: /
  #graphRoQuery:cypher:params:compact: / #rawGraphRoQuery:cypher:compact: - read-only counterparts
  of the #graphQuery:cypher:* family, sending GRAPH.RO_QUERY instead of GRAPH.QUERY
- #graphDelete: - delete an entire graph, answering the raw status string reply
- #graphInfo - query server status for all GRAPH.INFO sections, answering the raw reply
- #graphInfo: - like #graphInfo but restricted to the sections set true on the
  FkGraphInfoOptions passed to the block, e.g. [ :opts | opts runningQueries: true ]
- #graphConfigGet: - query one runtime config parameter, or all of them when passed '*',
  answering the raw reply
- #graphConfigGetAll - shortcut for #graphConfigGet: '*', answering all runtime config parameters
- #graphConfigSet: - set one or more runtime config parameters from a Dictionary (not persisted
  across a server restart), answering the raw reply
- #graphConstraintCreate:type:entityType:entityName:properties: - create a MANDATORY or UNIQUE
  schema constraint on a NODE label or RELATIONSHIP type's properties, answering the raw reply
- #graphConstraintDrop:type:entityType:entityName:properties: - remove a previously created
  constraint, same argument shape as #graphConstraintCreate:type:entityType:entityName:properties:
- #graphConstraintCreateWith:on: - create a constraint from an FkGraphConstraint against the named
  graph, delegating to #graphConstraintCreate:type:entityType:entityName:properties:
- #graphConstraintCreateBy:on: - like #graphConstraintCreateWith:on: but builds the FkGraphConstraint
  by evaluating the caller's block against a fresh instance, e.g.
  [ :c | c unique; node: 'Person'; props: #('email') ]
- #graphConstraintDropWith:on: - drop a constraint from an FkGraphConstraint against the named
  graph, delegating to #graphConstraintDrop:type:entityType:entityName:properties:
- #graphConstraintDropBy:on: - block-based counterpart of #graphConstraintDropWith:on:, mirroring
  #graphConstraintCreateBy:on:
- #graphExplain:cypher: - construct a query execution plan without running it, answering the raw
  plan reply
- #graphExplain:cypher:params: - like #graphExplain:cypher: with named parameters bound via the
  CYPHER prefix convention
- #graphProfile:cypher: - execute a query and answer the raw reply representing its execution
  plan augmented with per-operation metrics
- #graphProfile:cypher:params: - like #graphProfile:cypher: with named parameters bound via the
  CYPHER prefix convention
- #graphList - list all graph names currently present in the keyspace, answering the raw reply
- #graphCopy:to: - duplicate the graph named by the first argument into a new graph named by the
  second argument, answering the raw reply
- #graphMemoryUsage: - report memory usage statistics for a graph, decoding the flat key/value
  reply into a Dictionary
- #graphMemoryUsage:samples: - like #graphMemoryUsage: but requests a specific sample count for
  the estimation
- #graphSlowLog: - report the graph's slowest queries (up to 10), decoding each raw entry into an
  FkSlowLogEntry and answering an OrderedCollection of them

Implementation Points:
- Query errors surface as raised RsGenericError exceptions (see FkFalkorStick>>defaultRedisGenericErrorHandingBlock),
  not as nil/partial replies
- Parameter values are rendered as Cypher literals: scalars/nil/Array go through SCypher's
  CyObject class>>jsonStringFrom: (JSON happens to match Cypher literal syntax for these), while a
  Dictionary is rendered as a genuine Cypher map literal with unquoted keys via
  #cypherMapLiteralFor:, since FalkorDB's CYPHER-prefix parameter parser rejects JSON's quoted
  keys even though the full query parser accepts them inline - this lets a whole property map be
  bound as a single named parameter, not just scalars
- Id caches are Dictionaries of graphName -> Array of names, indexed by id (0-based); a lookup
  past the end of the cached array triggers one refresh via CALL db.labels()/relationshipTypes()/
  propertyKeys() before resolving (see design.md Decision 4)
- GRAPH.SLOWLOG's raw entry is always 5 elements on the FalkorDB versions this was verified
  against (timestamp, command, query, execution time ms, CYPHER-prefix parameters string or nil);
  #slowLogEntryFrom: relies on that fixed shape and normalizes the timestamp/execution-time
  strings to Numbers before building the FkSlowLogEntry
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
FkGraphEndpoint >> constraintCommandArgsFor: graphName type: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	| args |
	args := OrderedCollection
		with: graphName
		with: constraintType
		with: entityType
		with: entityName
		with: 'PROPERTIES'
		with: propertiesCollection size.
	args addAll: propertiesCollection.
	^ args
]

{ #category : 'private' }
FkGraphEndpoint >> cypherLiteralFor: aValue [
	"CyObject jsonStringFrom: renders any Smalltalk value as a JSON literal, which FalkorDB's
	Cypher parser accepts as a literal expression inside a query body - but not as a CYPHER-prefix
	parameter value, whose map syntax requires unquoted keys, unlike JSON's quoted keys, so
	a Dictionary needs its own Cypher-map-literal rendering here."

	aValue isDictionary ifTrue: [ ^ self cypherMapLiteralFor: aValue ].
	^ CyObject jsonStringFrom: aValue
]

{ #category : 'private' }
FkGraphEndpoint >> cypherMapLiteralFor: aDictionary [
	^ String streamContents: [ :s |
		s nextPut: ${.
		aDictionary associations
			do: [ :assoc |
				s
					nextPutAll: assoc key asString;
					nextPut: $:;
					nextPutAll: (self cypherLiteralFor: assoc value) ]
			separatedBy: [ s nextPut: $, ].
		s nextPut: $} ]
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
FkGraphEndpoint >> dictionaryFromFlatPairs: flatCollection [
	| result |
	result := Dictionary new.
	1 to: flatCollection size by: 2 do: [ :i |
		result at: (flatCollection at: i) put: (flatCollection at: i + 1) ].
	^ result
]

{ #category : 'private' }
FkGraphEndpoint >> executeGraphCommand: commandName graph: graphName cypher: cypherString compact: useCompact [
	| rawReply |
	rawReply := self rawGraphCommand: commandName graph: graphName cypher: cypherString compact: useCompact.
	useCompact ifFalse: [ ^ FkQueryResult fromVerboseReply: rawReply ].
	^ FkQueryResult
		fromCompactReply: rawReply
		resolvedBy: self
		graph: graphName
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConfigGet: paramName [
	^ self unifiedCommand: { 'GRAPH.CONFIG'. 'GET'. paramName }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConfigGetAll [
	^ self graphConfigGet: '*'
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConfigSet: paramsDictionary [
	| args |
	args := OrderedCollection with: 'GRAPH.CONFIG' with: 'SET'.
	paramsDictionary keysAndValuesDo: [ :key :value |
		args add: key; add: value ].
	^ self unifiedCommand: args
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConstraintCreate: graphName type: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	| args |
	args := OrderedCollection with: 'GRAPH.CONSTRAINT' with: 'CREATE'.
	args addAll:
		(self
			constraintCommandArgsFor: graphName
			type: constraintType
			entityType: entityType
			entityName: entityName
			properties: propertiesCollection).
	^ self unifiedCommand: args
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConstraintCreateBy: aBlock on: graphName [
	| constraint |
	constraint := FkGraphConstraint new.
	aBlock value: constraint.
	^ self graphConstraintCreateWith: constraint on: graphName
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConstraintCreateWith: aFkGraphConstraint on: graphName [
	^ self
		graphConstraintCreate: graphName
		type: aFkGraphConstraint constraintType
		entityType: aFkGraphConstraint entityType
		entityName: aFkGraphConstraint entityName
		properties: aFkGraphConstraint properties
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConstraintDrop: graphName type: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	| args |
	args := OrderedCollection with: 'GRAPH.CONSTRAINT' with: 'DROP'.
	args addAll:
		(self
			constraintCommandArgsFor: graphName
			type: constraintType
			entityType: entityType
			entityName: entityName
			properties: propertiesCollection).
	^ self unifiedCommand: args
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConstraintDropBy: aBlock on: graphName [
	| constraint |
	constraint := FkGraphConstraint new.
	aBlock value: constraint.
	^ self graphConstraintDropWith: constraint on: graphName
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphConstraintDropWith: aFkGraphConstraint on: graphName [
	^ self
		graphConstraintDrop: graphName
		type: aFkGraphConstraint constraintType
		entityType: aFkGraphConstraint entityType
		entityName: aFkGraphConstraint entityName
		properties: aFkGraphConstraint properties
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphCopy: srcGraphName to: destGraphName [
	^ self unifiedCommand: { 'GRAPH.COPY'. srcGraphName. destGraphName }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphDelete: graphName [
	^ self unifiedCommand: { 'GRAPH.DELETE'. graphName }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphExplain: graphName cypher: cypherString [
	^ self unifiedCommand: { 'GRAPH.EXPLAIN'. graphName. cypherString }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphExplain: graphName cypher: cypherString params: paramsDictionary [
	^ self graphExplain: graphName cypher: (self prependParams: paramsDictionary to: cypherString)
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphInfo [
	^ self unifiedCommand: { 'GRAPH.INFO' }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphInfo: optionsBlock [
	| options args |
	options := FkGraphInfoOptions new.
	optionsBlock value: options.
	args := OrderedCollection with: 'GRAPH.INFO'.
	args addAll: options asArray.
	^ self unifiedCommand: args
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphList [
	^ self unifiedCommand: { 'GRAPH.LIST' }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphMemoryUsage: graphName [
	^ self dictionaryFromFlatPairs: (self unifiedCommand: (self graphMemoryUsageArgsFor: graphName samples: nil))
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphMemoryUsage: graphName samples: sampleCount [
	^ self dictionaryFromFlatPairs:
		(self unifiedCommand: (self graphMemoryUsageArgsFor: graphName samples: sampleCount))
]

{ #category : 'private' }
FkGraphEndpoint >> graphMemoryUsageArgsFor: graphName samples: sampleCountOrNil [
	| args |
	args := OrderedCollection with: 'GRAPH.MEMORY' with: 'USAGE' with: graphName.
	sampleCountOrNil ifNotNil: [ args add: 'SAMPLES'; add: sampleCountOrNil ].
	^ args
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphProfile: graphName cypher: cypherString [
	^ self unifiedCommand: { 'GRAPH.PROFILE'. graphName. cypherString }
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphProfile: graphName cypher: cypherString params: paramsDictionary [
	^ self graphProfile: graphName cypher: (self prependParams: paramsDictionary to: cypherString)
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphSlowLog: graphName [
	^ (self unifiedCommand: { 'GRAPH.SLOWLOG'. graphName })
		collect: [ :rawEntry | self slowLogEntryFrom: rawEntry ]
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString [
	^ self graphQuery: graphName cypher: cypherString compact: true
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphQuery: graphName cypher: cypherString compact: useCompact [
	^ self
		executeGraphCommand: 'GRAPH.QUERY'
		graph: graphName
		cypher: cypherString
		compact: useCompact
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

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphRoQuery: graphName cypher: cypherString [
	^ self graphRoQuery: graphName cypher: cypherString compact: true
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphRoQuery: graphName cypher: cypherString compact: useCompact [
	^ self
		executeGraphCommand: 'GRAPH.RO_QUERY'
		graph: graphName
		cypher: cypherString
		compact: useCompact
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphRoQuery: graphName cypher: cypherString params: paramsDictionary [
	^ self graphRoQuery: graphName cypher: (self prependParams: paramsDictionary to: cypherString)
]

{ #category : 'commands-graph' }
FkGraphEndpoint >> graphRoQuery: graphName cypher: cypherString params: paramsDictionary compact: useCompact [
	^ self
		graphRoQuery: graphName
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

{ #category : 'private' }
FkGraphEndpoint >> rawGraphCommand: commandName graph: graphName cypher: cypherString compact: useCompact [
	| args |
	args := OrderedCollection with: commandName with: graphName with: cypherString.
	useCompact ifTrue: [ args add: '--compact' ].
	^ self unifiedCommand: args
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

{ #category : 'private-commands-graph' }
FkGraphEndpoint >> rawGraphQuery: graphName cypher: cypherString compact: useCompact [
	^ self rawGraphCommand: 'GRAPH.QUERY' graph: graphName cypher: cypherString compact: useCompact
]

{ #category : 'private-commands-graph' }
FkGraphEndpoint >> rawGraphRoQuery: graphName cypher: cypherString compact: useCompact [
	^ self rawGraphCommand: 'GRAPH.RO_QUERY' graph: graphName cypher: cypherString compact: useCompact
]

{ #category : 'private' }
FkGraphEndpoint >> refreshCache: cachesDict graph: graphName procedure: procedureName [
	| rawReply names |
	rawReply := self rawGraphQuery: graphName cypher: 'CALL ' , procedureName , '()' compact: true.
	names := (rawReply second collect: [ :rawRow | rawRow first second ]) asArray.
	cachesDict at: graphName put: names.
	^ names
]

{ #category : 'private' }
FkGraphEndpoint >> slowLogEntryFrom: rawEntry [
	^ FkSlowLogEntry
		timestamp: rawEntry first asNumber
		command: rawEntry second
		query: rawEntry third
		executionTimeMs: rawEntry fourth asNumber
		parameters: rawEntry fifth
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
