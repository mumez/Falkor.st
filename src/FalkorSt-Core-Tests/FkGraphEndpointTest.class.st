"
I test FkGraphEndpoint's command-level behavior against a real FalkorDB instance for commands
that are not primarily about FkQueryResult decoding: GRAPH.RO_QUERY, GRAPH.DELETE, GRAPH.INFO,
GRAPH.CONFIG, GRAPH.CONSTRAINT, GRAPH.EXPLAIN, GRAPH.PROFILE, GRAPH.LIST, GRAPH.COPY, GRAPH.MEMORY,
and GRAPH.SLOWLOG.

Coverage:
- graph-ro-query spec: read-only Cypher query execution, same result-set shape as GRAPH.QUERY
- graph-delete spec: deleting a graph answers a plain status string reply
- graph-info spec: server status query, with and without section options
- graph-config spec: getting one or all config parameters, and setting a runtime parameter
- graph-constraint spec: creating and dropping MANDATORY/UNIQUE constraints on node labels and
  relationship types, via the positional API, the FkGraphConstraint fluent builder, and the
  FkGraphConstraint object-based #graphConstraintCreateWith:on:/#graphConstraintCreateBy:on:/
  #graphConstraintDropWith:on:/#graphConstraintDropBy:on: methods
- graph-explain spec: constructing a query plan without executing it, with and without bound
  parameters, answering the raw undecoded plan reply
- graph-profile spec: executing a query and answering the raw undecoded plan reply augmented with
  per-operation metrics, with and without bound parameters
- graph-list spec: listing graph names present in the keyspace
- graph-copy spec: copying a graph's data into a new graph name
- graph-memory spec: reporting per-graph memory usage statistics, decoded into a Dictionary
- graph-slowlog spec: reporting the graph's slowest queries, decoded into FkSlowLogEntry instances,
  and clearing them via #graphResetLog:
- graph-index spec: creating and dropping range, fulltext, and vector indexes on node labels and
  relationship types, and listing them as FkGraphIndexInfo via #graphIndexes:
- graph-constraints-listing spec: creating UNIQUE and MANDATORY constraints on a node label and a
  relationship type, and listing them as FkGraphConstraintInfo via #graphConstraints:, tolerating
  the asynchronous PENDING/UNDER CONSTRUCTION -> OPERATIONAL transition
"
Class {
	#name : 'FkGraphEndpointTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphCommandArgsOmitsTimeoutWhenNil [
	| args |
	args := self endpoint
		graphCommandArgsFor: 'GRAPH.QUERY'
		graph: self graphName
		cypher: 'RETURN 1'
		compact: true
		timeout: nil.
	self deny: (args includes: 'TIMEOUT')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphCommandArgsOmitsTimeoutWhenZero [
	| args |
	args := self endpoint
		graphCommandArgsFor: 'GRAPH.QUERY'
		graph: self graphName
		cypher: 'RETURN 1'
		compact: true
		timeout: 0.
	self deny: (args includes: 'TIMEOUT')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphCommandArgsIncludesTimeoutAndValueWhenPositive [
	| args |
	args := self endpoint
		graphCommandArgsFor: 'GRAPH.QUERY'
		graph: self graphName
		cypher: 'RETURN 1'
		compact: true
		timeout: 1000.
	self
		assert: args asArray
		equals: { 'GRAPH.QUERY'. self graphName. 'RETURN 1'. 'TIMEOUT'. '1000'. '--compact' }
]

{ #category : 'tests' }
FkGraphEndpointTest >> testQueryTimeoutMsecsDefaultsToFkSettingsDefault [
	| originalDefault endpoint |
	originalDefault := FkSettings default queryTimeoutMsecs.
	[
		FkSettings default queryTimeoutMsecs: 4242.
		endpoint := FkGraphEndpoint new.
		self assert: endpoint queryTimeoutMsecs equals: 4242 ]
		ensure: [ FkSettings default queryTimeoutMsecs: originalDefault ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testQueryTimeoutMsecsFollowsLaterFkSettingsChanges [
	| originalDefault endpoint |
	originalDefault := FkSettings default queryTimeoutMsecs.
	[
		endpoint := FkGraphEndpoint new.
		FkSettings default queryTimeoutMsecs: 100.
		self assert: endpoint queryTimeoutMsecs equals: 100.
		FkSettings default queryTimeoutMsecs: 200.
		self assert: endpoint queryTimeoutMsecs equals: 200 ]
		ensure: [ FkSettings default queryTimeoutMsecs: originalDefault ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testQueryTimeoutMsecsCanBeOverriddenPerEndpoint [
	| endpoint |
	endpoint := FkGraphEndpoint new.
	endpoint queryTimeoutMsecs: 999.
	self assert: endpoint queryTimeoutMsecs equals: 999
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryWithTinyTimeoutSignalsRsGenericError [
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	self should: [
		self endpoint
			graphRoQuery: self graphName
			cypher: 'UNWIND range(1, 1000000) AS x RETURN count(x)'
			compact: true
			timeout: 1 ]
		raise: RsGenericError
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphQueryWithTinyTimeoutSignalsRsGenericError [
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	self should: [
		self endpoint
			graphQuery: self graphName
			cypher: 'UNWIND range(1, 1000000) AS x RETURN count(x)'
			compact: true
			timeout: 1 ]
		raise: RsGenericError
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryWithGenerousTimeoutSucceeds [
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	self assert:
		((self endpoint
			graphRoQuery: self graphName
			cypher: 'MATCH (p:Person) RETURN count(p)'
			compact: true
			timeout: 10000) records first first) equals: 1
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphQueryWithGenerousTimeoutSucceeds [
	self assert:
		((self endpoint
			graphQuery: self graphName
			cypher: 'RETURN 1'
			compact: true
			timeout: 10000) records first first) equals: 1
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryDecodesNodeValue [
	| result node |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person {name: ''Alice''})'.
	result := self endpoint
		graphRoQuery: self graphName
		cypher: 'MATCH (p:Person) RETURN p'.
	node := result records first first.
	self assert: node class equals: FkNode.
	self assertCollection: node labels asArray equals: #('Person').
	self assert: (node properties at: 'name') equals: 'Alice'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryWithParams [
	| result |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (p:Person {name: ''Alice''})'.
	result := self endpoint
		graphRoQuery: self graphName
		cypher: 'MATCH (p:Person {name: $name}) RETURN p.name'
		params: (Dictionary new at: 'name' put: 'Alice'; yourself).
	self assert: result records first first equals: 'Alice'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphQueryWithParamsBindsAWholeDictionaryAsAMapLiteral [
	| result values |
	values := Dictionary new
		at: 'name' put: 'She said "hi" \ bye';
		at: 'age' put: 40;
		yourself.
	self endpoint graphQuery: self graphName cypher: 'CREATE (p:Person)'.
	result := self endpoint
		graphQuery: self graphName
		cypher: 'MATCH (p:Person) SET p += $values RETURN p.name, p.age'
		params: (Dictionary new at: 'values' put: values; yourself).
	self assert: result records first first equals: (values at: 'name').
	self assert: result records first second equals: (values at: 'age')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphRoQueryVerbose [
	| result |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)'.
	result := self endpoint
		graphRoQuery: self graphName
		cypher: 'MATCH (p:Person) RETURN p'
		compact: false.
	self assert: result records size equals: 1
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphDeleteAnswersStatusString [
	| reply |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)'.
	reply := self endpoint graphDelete: self graphName.
	self assert: reply equals: 'OK'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphInfoWithoutOptionsAnswersReply [
	| reply |
	reply := self endpoint graphInfo.
	self assert: reply notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphInfoWithOptionsAnswersReply [
	| reply |
	reply := self endpoint graphInfo: [ :opts | opts runningQueries: true ].
	self assert: reply notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConfigGetAnswersValueForKnownParam [
	| reply |
	reply := self endpoint graphConfigGet: 'TIMEOUT_DEFAULT'.
	self assert: reply notNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConfigGetAllAnswersNonEmptyReply [
	| reply |
	reply := self endpoint graphConfigGet: '*'.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConfigSetUpdatesParamValue [
	| reply originalValue |
	originalValue := (self endpoint graphConfigGet: 'TIMEOUT_DEFAULT') second.
	[
		self endpoint graphConfigSet: (Dictionary new at: 'TIMEOUT_DEFAULT' put: 5000; yourself).
		reply := self endpoint graphConfigGet: 'TIMEOUT_DEFAULT'.
		self assert: reply second equals: 5000 ]
		ensure: [
			self endpoint
				graphConfigSet: (Dictionary new at: 'TIMEOUT_DEFAULT' put: originalValue; yourself) ]
]

{ #category : 'private' }
FkGraphEndpointTest >> createConstraintType: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	^ self endpoint
		graphConstraintCreate: self graphName
		type: constraintType
		entityType: entityType
		entityName: entityName
		properties: propertiesCollection
]

{ #category : 'private' }
FkGraphEndpointTest >> dropConstraintType: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	^ self endpoint
		graphConstraintDrop: self graphName
		type: constraintType
		entityType: entityType
		entityName: entityName
		properties: propertiesCollection
]

{ #category : 'private' }
FkGraphEndpointTest >> dropConstraintIgnoringErrorsType: constraintType entityType: entityType entityName: entityName properties: propertiesCollection [
	[
		self
			dropConstraintType: constraintType
			entityType: entityType
			entityName: entityName
			properties: propertiesCollection ]
		on: Error
		do: [ :ex |  ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateMandatoryOnNodeSucceeds [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self
		createConstraintType: 'MANDATORY'
		entityType: 'NODE'
		entityName: 'Person'
		properties: #('name').
	self assert: reply equals: 'PENDING'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateUniqueOnNodeSucceeds [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {email: ''alice@example.com''})'.
	self endpoint graphQuery: self graphName cypher: 'CREATE INDEX FOR (n:Person) ON (n.email)'.
	reply := self createConstraintType: 'UNIQUE' entityType: 'NODE' entityName: 'Person' properties: #('email').
	self assert: reply equals: 'PENDING'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintDropRemovesConstraint [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	self createConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name').
	reply := self
		dropConstraintType: 'MANDATORY'
		entityType: 'NODE'
		entityName: 'Person'
		properties: #('name').
	self assert: reply equals: 'OK'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphExplainAnswersNonEmptyPlan [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphExplain: self graphName cypher: 'MATCH (p:Person) RETURN p'.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphExplainWithParamsAnswersNonEmptyPlan [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint
		graphExplain: self graphName
		cypher: 'MATCH (p:Person {name: $name}) RETURN p'
		params: (Dictionary new at: 'name' put: 'Alice'; yourself).
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphProfileAnswersNonEmptyReply [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphProfile: self graphName cypher: 'MATCH (p:Person) RETURN p'.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphProfileWithParamsAnswersNonEmptyReply [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint
		graphProfile: self graphName
		cypher: 'MATCH (p:Person {name: $name}) RETURN p'
		params: (Dictionary new at: 'name' put: 'Alice'; yourself).
	self deny: reply isEmpty
]

{ #category : 'private' }
FkGraphEndpointTest >> deleteGraphIgnoringErrors: graphName [
	[ self endpoint graphDelete: graphName ] on: Error do: [ :ex |  ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphListIncludesCreatedGraph [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	reply := self endpoint graphList.
	self assert: (reply includes: self graphName)
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphCopyCopiesGraphData [
	| destGraphName reply result |
	destGraphName := self graphName , '_copyDest'.
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	[
		self endpoint graphCopy: self graphName to: destGraphName.
		reply := self endpoint graphList.
		self assert: (reply includes: destGraphName).
		result := self endpoint graphQuery: destGraphName cypher: 'MATCH (p:Person) RETURN p.name'.
		self assert: result records first first equals: 'Alice' ]
		ensure: [ self deleteGraphIgnoringErrors: destGraphName ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphMemoryUsageAnswersDictionaryWithData [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphMemoryUsage: self graphName.
	self assert: reply class equals: Dictionary.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphMemoryUsageWithSamplesAnswersDictionaryWithData [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphMemoryUsage: self graphName samples: 5.
	self assert: reply class equals: Dictionary.
	self deny: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphSlowLogAnswersEntriesForSlowQuery [
	| reply entry |
	self endpoint graphQuery: self graphName cypher: 'UNWIND range(1, 2000000) AS x RETURN sum(x)'.
	reply := self endpoint graphSlowLog: self graphName.
	self assert: reply class equals: OrderedCollection.
	self deny: reply isEmpty.
	entry := reply first.
	self assert: entry class equals: FkSlowLogEntry.
	self assert: entry command equals: 'GRAPH.QUERY'.
	self assert: entry query equals: 'UNWIND range(1, 2000000) AS x RETURN sum(x)'.
	self assert: entry executionTimeMs > 0.
	self assert: entry timestamp notNil.
	self assert: entry parameters isNil
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphSlowLogDecodesParametersWhenQueryWasBoundWithThem [
	| reply entry |
	self endpoint
		graphQuery: self graphName
		cypher: 'UNWIND range(1, $n) AS x RETURN sum(x)'
		params: (Dictionary new at: 'n' put: 2000000; yourself).
	reply := self endpoint graphSlowLog: self graphName.
	self deny: reply isEmpty.
	entry := reply first.
	self assert: entry parameters notNil.
	self assert: (entry parameters includesSubstring: 'n=2000000')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphSlowLogAnswersEmptyForGraphWithoutSlowQueries [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	reply := self endpoint graphSlowLog: self graphName.
	self assert: reply class equals: OrderedCollection.
	self assert: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphResetLogClearsEntries [
	| resetReply reply |
	self endpoint graphQuery: self graphName cypher: 'UNWIND range(1, 2000000) AS x RETURN sum(x)'.
	self deny: (self endpoint graphSlowLog: self graphName) isEmpty.
	resetReply := self endpoint graphResetLog: self graphName.
	self assert: resetReply equals: 'OK'.
	reply := self endpoint graphSlowLog: self graphName.
	self assert: reply class equals: OrderedCollection.
	self assert: reply isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testFkGraphConstraintFluentBuilderUniqueOnNode [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint unique; node: 'Person'; props: #('email').
	self assert: constraint constraintType equals: 'UNIQUE'.
	self assert: constraint entityType equals: 'NODE'.
	self assert: constraint entityName equals: 'Person'.
	self assertCollection: constraint properties asArray equals: #('email')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testFkGraphConstraintFluentBuilderMandatoryOnRelationship [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint mandatory; relationship: 'KNOWS'; props: #('since').
	self assert: constraint constraintType equals: 'MANDATORY'.
	self assert: constraint entityType equals: 'RELATIONSHIP'.
	self assert: constraint entityName equals: 'KNOWS'.
	self assertCollection: constraint properties asArray equals: #('since')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateWithSucceeds [
	| constraint reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	constraint := FkGraphConstraint new.
	constraint mandatory; node: 'Person'; props: #('name').
	[
		reply := self endpoint graphConstraintCreateWith: constraint on: self graphName.
		self assert: reply equals: 'PENDING' ]
		ensure: [ self dropConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name') ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateBySucceeds [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	[
		reply := self endpoint
			graphConstraintCreateBy: [ :c | c mandatory; node: 'Person'; props: #('name') ]
			on: self graphName.
		self assert: reply equals: 'PENDING' ]
		ensure: [ self dropConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name') ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintDropWithRemovesConstraint [
	| constraint reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	self createConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name').
	constraint := FkGraphConstraint new.
	constraint mandatory; node: 'Person'; props: #('name').
	[
		reply := self endpoint graphConstraintDropWith: constraint on: self graphName.
		self assert: reply equals: 'OK' ]
		ensure: [ self dropConstraintIgnoringErrorsType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name') ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintDropBySucceeds [
	| reply |
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person {name: ''Alice''})'.
	self createConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name').
	[
		reply := self endpoint
			graphConstraintDropBy: [ :c | c mandatory; node: 'Person'; props: #('name') ]
			on: self graphName.
		self assert: reply equals: 'OK' ]
		ensure: [ self dropConstraintIgnoringErrorsType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name') ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintCreateWithRaisesWhenConstraintIncomplete [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint node: 'Person'; props: #('name').
	self
		should: [ self endpoint graphConstraintCreateWith: constraint on: self graphName ]
		raise: RsError
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintDropWithRaisesWhenConstraintIncomplete [
	| constraint |
	constraint := FkGraphConstraint new.
	constraint node: 'Person'; props: #('name').
	self
		should: [ self endpoint graphConstraintDropWith: constraint on: self graphName ]
		raise: RsError
]

{ #category : 'private' }
FkGraphEndpointTest >> assertIndexCreated: result [
	self assert: result class equals: FkQueryResult.
	self assert: (result statistics anySatisfy: [ :line | line includesSubstring: 'Indices created' ])
]

{ #category : 'private' }
FkGraphEndpointTest >> assertIndexDropped: result [
	self assert: result class equals: FkQueryResult.
	self assert: (result statistics anySatisfy: [ :line | line includesSubstring: 'Indices deleted' ])
]

{ #category : 'private' }
FkGraphEndpointTest >> indexInfoLabeled: aLabel entityType: anEntityType [
	^ (self endpoint graphIndexes: self graphName)
		detect: [ :each | each label = aLabel and: [ each entityType = anEntityType ] ]
]

{ #category : 'private' }
FkGraphEndpointTest >> assertListedProperty: aProperty type: aType label: aLabel entityType: anEntityType [
	| info |
	info := self indexInfoLabeled: aLabel entityType: anEntityType.
	self assert: info class equals: FkGraphIndexInfo.
	self assert: ((info types at: aProperty) includes: aType)
]

{ #category : 'private' }
FkGraphEndpointTest >> indexCreateSpecs [
	^ {
		[ :index | index range; node: 'Person'; props: #('email') ].
		[ :index | index fulltext; node: 'Person'; props: #('name' 'bio') ].
		[ :index | index vector; node: 'Doc'; props: #('embedding'); dimension: 4; similarityFunction: 'euclidean' ].
		[ :index | index range; relationship: 'KNOWS'; props: #('since') ].
		[ :index | index fulltext; relationship: 'KNOWS'; props: #('note') ].
		[ :index | index vector; relationship: 'SIMILAR'; props: #('embedding'); dimension: 4; similarityFunction: 'cosine' ] }
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexCreateBySucceedsForEachKindAndEntity [
	self indexCreateSpecs do: [ :spec |
		self assertIndexCreated: (self endpoint graphIndexCreateBy: spec on: self graphName) ]
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexCreateWithSucceeds [
	| index result |
	index := FkGraphIndex new.
	self indexCreateSpecs first value: index.
	result := self endpoint graphIndexCreateWith: index on: self graphName.
	self assertIndexCreated: result
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexCreateByQuotesLabelThatWouldBreakUnquotedCypher [
	| result |
	result := self endpoint
		graphIndexCreateBy: [ :index | index range; node: 'A)B'; props: #('p') ]
		on: self graphName.
	self assertIndexCreated: result
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexesEmptyWhenGraphHasNoIndexes [
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	self assert: (self endpoint graphIndexes: self graphName) isEmpty
]

{ #category : 'private' }
FkGraphEndpointTest >> assertCreatedIndexSpecsAreListed [
	self assertListedProperty: 'email' type: 'RANGE' label: 'Person' entityType: 'NODE'.
	self assertListedProperty: 'name' type: 'FULLTEXT' label: 'Person' entityType: 'NODE'.
	self assertListedProperty: 'bio' type: 'FULLTEXT' label: 'Person' entityType: 'NODE'.
	self
		assertVectorProperty: 'embedding'
		label: 'Doc'
		entityType: 'NODE'
		similarityFunction: 'euclidean'.
	self assertListedProperty: 'since' type: 'RANGE' label: 'KNOWS' entityType: 'RELATIONSHIP'.
	self assertListedProperty: 'note' type: 'FULLTEXT' label: 'KNOWS' entityType: 'RELATIONSHIP'.
	self
		assertVectorProperty: 'embedding'
		label: 'SIMILAR'
		entityType: 'RELATIONSHIP'
		similarityFunction: 'cosine'
]

{ #category : 'private' }
FkGraphEndpointTest >> assertVectorProperty: aProperty label: aLabel entityType: anEntityType similarityFunction: aFunction [
	| info options |
	self
		assertListedProperty: aProperty
		type: 'VECTOR'
		label: aLabel
		entityType: anEntityType.
	info := self indexInfoLabeled: aLabel entityType: anEntityType.
	options := info options at: aProperty.
	self assert: (options at: 'dimension') equals: 4.
	self assert: (options at: 'similarityFunction') equals: aFunction
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexesListsCreatedIndexesAndDropRemovesThem [
	self indexCreateSpecs do: [ :spec |
		self assertIndexCreated: (self endpoint graphIndexCreateBy: spec on: self graphName) ].
	self assertCreatedIndexSpecsAreListed.
	self indexCreateSpecs do: [ :spec |
		self assertIndexDropped: (self endpoint graphIndexDropBy: spec on: self graphName) ].
	self assert: (self endpoint graphIndexes: self graphName) isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexDropWithRemovesIndex [
	| index |
	index := FkGraphIndex new.
	self indexCreateSpecs first value: index.
	self assertIndexCreated: (self endpoint graphIndexCreateWith: index on: self graphName).
	self assertListedProperty: 'email' type: 'RANGE' label: 'Person' entityType: 'NODE'.
	self assertIndexDropped: (self endpoint graphIndexDropWith: index on: self graphName).
	self assert: (self endpoint graphIndexes: self graphName) isEmpty
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphIndexDropByRemovesQuotedLabel [
	| spec |
	spec := [ :index | index range; node: 'A)B'; props: #('p') ].
	self assertIndexCreated: (self endpoint graphIndexCreateBy: spec on: self graphName).
	self assertListedProperty: 'p' type: 'RANGE' label: 'A)B' entityType: 'NODE'.
	self assertIndexDropped: (self endpoint graphIndexDropBy: spec on: self graphName).
	self assert: (self endpoint graphIndexes: self graphName) isEmpty
]

{ #category : 'private' }
FkGraphEndpointTest >> constraintInfoOfType: aType entityType: anEntityType entityName: anEntityName [
	^ (self endpoint graphConstraints: self graphName)
		detect: [ :each |
			each constraintType = aType
				and: [ each entityType = anEntityType and: [ each entityName = anEntityName ] ] ]
		ifNone: [ nil ]
]

{ #category : 'private' }
FkGraphEndpointTest >> waitForConstraintSettledType: aType entityType: anEntityType entityName: anEntityName [
	"Constraint creation is asynchronous: status starts as PENDING/UNDER CONSTRUCTION before
	becoming OPERATIONAL (or FAILED). Poll briefly rather than asserting immediately."

	| info |
	20 timesRepeat: [
		info := self constraintInfoOfType: aType entityType: anEntityType entityName: anEntityName.
		(info notNil and: [ info status = 'OPERATIONAL' or: [ info status = 'FAILED' ] ])
			ifTrue: [ ^ info ].
		(Delay forMilliseconds: 250) wait ].
	^ info
]

{ #category : 'private' }
FkGraphEndpointTest >> assertConstraintOperationalType: aType entityType: anEntityType entityName: anEntityName properties: aPropertiesCollection [
	| info |
	info := self waitForConstraintSettledType: aType entityType: anEntityType entityName: anEntityName.
	self assert: info notNil.
	self assert: info class equals: FkGraphConstraintInfo.
	self assert: info status equals: 'OPERATIONAL'.
	self assertCollection: info properties asArray equals: aPropertiesCollection asArray
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintsEmptyWhenGraphHasNoConstraints [
	self endpoint graphQuery: self graphName cypher: 'CREATE (:Person)'.
	self assert: (self endpoint graphConstraints: self graphName) isEmpty
]

{ #category : 'private' }
FkGraphEndpointTest >> createAndAssertConstraintType: aType entityType: anEntityType entityName: anEntityName properties: aPropertiesCollection [
	self
		createConstraintType: aType
		entityType: anEntityType
		entityName: anEntityName
		properties: aPropertiesCollection.
	self
		assertConstraintOperationalType: aType
		entityType: anEntityType
		entityName: anEntityName
		properties: aPropertiesCollection
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintsListsCreatedConstraintsOnNode [
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person {name: ''Alice'', email: ''alice@example.com''})'.
	self endpoint graphIndexCreateBy: [ :i | i range; node: 'Person'; props: #('email') ] on: self graphName.
	self createAndAssertConstraintType: 'UNIQUE' entityType: 'NODE' entityName: 'Person' properties: #('email').
	self createAndAssertConstraintType: 'MANDATORY' entityType: 'NODE' entityName: 'Person' properties: #('name')
]

{ #category : 'private' }
FkGraphEndpointTest >> createAndAssertRelationshipConstraintType: aType [
	self
		createAndAssertConstraintType: aType
		entityType: 'RELATIONSHIP'
		entityName: 'KNOWS'
		properties: #('since')
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintsListsCreatedConstraintsOnRelationship [
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)-[:KNOWS {since: 2020}]->(:Person)'.
	self endpoint
		graphIndexCreateBy: [ :i | i range; relationship: 'KNOWS'; props: #('since') ]
		on: self graphName.
	self createAndAssertRelationshipConstraintType: 'UNIQUE'.
	self createAndAssertRelationshipConstraintType: 'MANDATORY'
]

{ #category : 'tests' }
FkGraphEndpointTest >> testGraphConstraintOnRelationshipTypeCreateAndDrop [
	| createReply dropReply |
	self endpoint
		graphQuery: self graphName
		cypher: 'CREATE (:Person)-[:KNOWS {since: 2020}]->(:Person)'.
	createReply := self createConstraintType: 'MANDATORY' entityType: 'RELATIONSHIP' entityName: 'KNOWS' properties: #('since').
	self assert: createReply equals: 'PENDING'.
	dropReply := self dropConstraintType: 'MANDATORY' entityType: 'RELATIONSHIP' entityName: 'KNOWS' properties: #('since').
	self assert: dropReply equals: 'OK'
]
