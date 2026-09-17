"
I hold the tunable configuration for the high-level FalkorDB object API, currently just the
target URL used to create a new connection. I mirror RsStreamSettings (RediStick-Stream-Objects),
which plays the same role for RsStream.

Responsibility:
- Hold #targetUrl, defaulting to 'sync://localhost:6379' when not explicitly set

Collaborators:
- FkGraphDb: reads #targetUrl (via FkSettings class >> default) to lazily create its stick

Public API and Key Messages:
- #default - class-side accessor for the shared, lazily-created instance (inherited from SkSettings)
- #targetUrl / #targetUrl: - the Redis/FalkorDB connection URL
"
Class {
	#name : 'FkSettings',
	#superclass : 'SkSettings',
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'accessing' }
FkSettings >> targetUrl [
	^ self at: #targetUrl ifAbsentPut: [ 'sync://localhost:6379' ]
]

{ #category : 'accessing' }
FkSettings >> targetUrl: aString [
	self at: #targetUrl put: aString
]
