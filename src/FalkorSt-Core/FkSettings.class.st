"
I hold the tunable configuration for the high-level FalkorDB object API: the target URL used to
create a new connection, and the default GRAPH.QUERY/GRAPH.RO_QUERY TIMEOUT. I live in
FalkorSt-Core (rather than FalkorSt-Objects) because FkGraphEndpoint needs my default. I mirror
RsStreamSettings (RediStick-Stream-Objects), which plays the same role for RsStream.

Responsibility:
- Hold #targetUrl, defaulting to 'sync://localhost:6379' when not explicitly set
- Hold #queryTimeoutMsecs, defaulting to 0 (no TIMEOUT argument sent) when not explicitly set

Collaborators:
- FkGraphDb: reads #targetUrl (via FkSettings class >> default) to lazily create its stick
- FkGraphEndpoint: reads #queryTimeoutMsecs (via FkSettings class >> default) as its own default

Public API and Key Messages:
- #default - class-side accessor for the shared, lazily-created instance (inherited from SkSettings)
- #targetUrl / #targetUrl: - the Redis/FalkorDB connection URL
- #queryTimeoutMsecs / #queryTimeoutMsecs: - the default GRAPH.QUERY/GRAPH.RO_QUERY TIMEOUT in
  milliseconds
"
Class {
	#name : 'FkSettings',
	#superclass : 'SkSettings',
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'accessing' }
FkSettings >> targetUrl [
	^ self at: #targetUrl ifAbsentPut: [ 'sync://localhost:6379' ]
]

{ #category : 'accessing' }
FkSettings >> targetUrl: aString [
	self at: #targetUrl put: aString
]

{ #category : 'accessing' }
FkSettings >> queryTimeoutMsecs [
	^ self at: #queryTimeoutMsecs ifAbsentPut: [ 0 ]
]

{ #category : 'accessing' }
FkSettings >> queryTimeoutMsecs: anInteger [
	self at: #queryTimeoutMsecs put: anInteger
]
