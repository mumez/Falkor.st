Extension { #name : 'FkGraphEndpoint' }

{ #category : '*FalkorSt-Objects' }
FkGraphEndpoint >> graphCallProcedure: graphName procedure: procedureName [
	"Call a stored procedure with no arguments, no YIELD clause, read-write (GRAPH.QUERY)."

	^ self graphCallProcedure: graphName procedure: procedureName arguments: #()
]

{ #category : '*FalkorSt-Objects' }
FkGraphEndpoint >> graphCallProcedure: graphName procedure: procedureName arguments: argumentsCollection [
	"Call a stored procedure with the given arguments, no YIELD clause, read-write (GRAPH.QUERY)."

	^ self
		graphCallProcedure: graphName
		procedure: procedureName
		arguments: argumentsCollection
		yield: nil
		readOnly: false
]

{ #category : '*FalkorSt-Objects' }
FkGraphEndpoint >> graphCallProcedure: graphName procedure: procedureName arguments: argumentsCollection yield: yieldNamesOrNil readOnly: aBoolean [
	"Call a stored procedure (equivalent to falkordb-py's call_procedure). Arguments are bound
	as query parameters ($param0, $param1, ...), never string-concatenated into the query.
	yieldNamesOrNil is nil (or empty) for no YIELD clause, a single column name String, or a
	collection of column names to YIELD.
	aBoolean true routes the call through GRAPH.RO_QUERY, false through GRAPH.QUERY."

	| cypherString params |
	cypherString := self
		procedureCallCypherFor: procedureName
		arguments: argumentsCollection
		yield: yieldNamesOrNil.
	params := self procedureCallParamsFor: argumentsCollection.
	^ aBoolean
		ifTrue: [ self graphRoQuery: graphName cypher: cypherString params: params ]
		ifFalse: [ self graphQuery: graphName cypher: cypherString params: params ]
]

{ #category : '*FalkorSt-Objects' }
FkGraphEndpoint >> procedureCallCypherFor: procedureName arguments: argumentsCollection yield: yieldNamesOrNil [
	"Answer the CALL <procedure>($param0, ...) [YIELD ...] Cypher fragment for a procedure call,
	referencing arguments by parameter name rather than embedding their values."

	| paramExpressions call yieldNames |
	paramExpressions := (1 to: argumentsCollection size)
		collect: [ :i | (self procedureCallParamNameAt: i) asCypherParameter ].
	call := CyCall of: procedureName arguments: paramExpressions asArray.
	yieldNames := yieldNamesOrNil isString
		ifTrue: [ { yieldNamesOrNil } ]
		ifFalse: [ yieldNamesOrNil ].
	yieldNames isEmptyOrNil ifFalse: [ call yield: (CyYield withAll: yieldNames asArray) ].
	^ call cypherString trimRight
]

{ #category : '*FalkorSt-Objects' }
FkGraphEndpoint >> procedureCallParamNameAt: oneBasedIndex [
	^ 'param' , (oneBasedIndex - 1) printString
]

{ #category : '*FalkorSt-Objects' }
FkGraphEndpoint >> procedureCallParamsFor: argumentsCollection [
	"Answer a param0 -> first arg, param1 -> second arg, ... Dictionary for binding a procedure
	call's arguments as query parameters."

	| params |
	params := Dictionary new.
	argumentsCollection doWithIndex: [ :argument :i |
		params at: (self procedureCallParamNameAt: i) put: argument ].
	^ params
]
