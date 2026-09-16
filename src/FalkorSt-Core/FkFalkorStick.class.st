"
I am the entry point for connecting to FalkorDB over Redis. I subclass RsRediStick only to
answer FkGraphEndpoint as my endpoint class, and to make Redis-level errors (including FalkorDB
GRAPH.QUERY errors) raise as catchable Smalltalk exceptions by default, rather than being logged
and swallowed as RsRediStick does for general-purpose Redis usage.

Responsibility:
- Create FkGraphEndpoint instances for GRAPH.* command execution
- Surface Redis/FalkorDB errors as raised exceptions by default

Collaborators:
- FkGraphEndpoint: the endpoint class I create for GRAPH.* commands

Public API and Key Messages:
- #targetUrl:, #connect - inherited from RsRediStick/SkStick
- #endpoint - answers my FkGraphEndpoint

Implementation Points:
- #endpointClassForScheme: answers FkGraphEndpoint regardless of scheme
- #defaultRedisGenericErrorHandingBlock always re-raises (ex pass), since a FalkorDB client has
  no use for query errors being silently swallowed
"
Class {
	#name : 'FkFalkorStick',
	#superclass : 'RsRediStick',
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'defaults' }
FkFalkorStick >> defaultRedisGenericErrorHandingBlock [
	^ [ :ex |
		self logger error: ex.
		ex pass ]
]

{ #category : 'factory' }
FkFalkorStick >> endpointClassForScheme: schemeName [
	^ FkGraphEndpoint
]
