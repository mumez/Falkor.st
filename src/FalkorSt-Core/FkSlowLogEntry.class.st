"
I am a decoded entry from a GRAPH.SLOWLOG reply: one slow query FalkorDB recorded against a
graph, with its timestamp, the command that ran it, its Cypher text, execution time, and any
CYPHER-prefix parameters it was bound with. I am produced by FkGraphEndpoint while decoding a
GRAPH.SLOWLOG reply; I never talk to FalkorDB myself.

Responsibility:
- Hold one slowlog entry's timestamp, command name, query text, execution time in milliseconds,
  and parameters string as decoded from a GRAPH.SLOWLOG reply

Collaborators:
- FkGraphEndpoint: builds instances of me while decoding a GRAPH.SLOWLOG reply

Public API and Key Messages:
- #timestamp - the Unix timestamp (as reported by the server) when the entry was recorded
- #command - the command String that was run, e.g. 'GRAPH.QUERY'
- #query - the Cypher query text (without any CYPHER parameter prefix)
- #executionTimeMs - the execution time in milliseconds
- #parameters - the CYPHER-prefix parameters string the query was bound with, or nil if none
"
Class {
	#name : 'FkSlowLogEntry',
	#superclass : 'Object',
	#instVars : [
		'timestamp',
		'command',
		'query',
		'executionTimeMs',
		'parameters'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkSlowLogEntry class >> timestamp: aTimestamp command: aCommand query: aQuery executionTimeMs: anExecutionTimeMs parameters: aParametersStringOrNil [
	^ self new
		timestamp: aTimestamp;
		command: aCommand;
		query: aQuery;
		executionTimeMs: anExecutionTimeMs;
		parameters: aParametersStringOrNil;
		yourself
]

{ #category : 'accessing' }
FkSlowLogEntry >> command [
	^ command
]

{ #category : 'private' }
FkSlowLogEntry >> command: anObject [
	command := anObject
]

{ #category : 'accessing' }
FkSlowLogEntry >> executionTimeMs [
	^ executionTimeMs
]

{ #category : 'private' }
FkSlowLogEntry >> executionTimeMs: anObject [
	executionTimeMs := anObject
]

{ #category : 'accessing' }
FkSlowLogEntry >> parameters [
	^ parameters
]

{ #category : 'private' }
FkSlowLogEntry >> parameters: anObject [
	parameters := anObject
]

{ #category : 'accessing' }
FkSlowLogEntry >> query [
	^ query
]

{ #category : 'private' }
FkSlowLogEntry >> query: anObject [
	query := anObject
]

{ #category : 'accessing' }
FkSlowLogEntry >> timestamp [
	^ timestamp
]

{ #category : 'private' }
FkSlowLogEntry >> timestamp: anObject [
	timestamp := anObject
]
