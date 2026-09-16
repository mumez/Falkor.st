"
I am the shared base test case for tests that connect to a real FalkorDB instance, following
RsRedisTestCase's pattern: connect on setUp, clean up on tearDown. Where RsRedisTestCase flushes
the whole (shared, numbered) Redis database, I instead delete only the single graph key my test
created, since FalkorDB graphs are ordinary Redis keys living alongside everything else in the
database the connection URL points at.

Responsibility:
- Connect an FkFalkorStick to a configurable FalkorDB URL for each test
- Give each test its own graph name (scoped to the test class and selector, so parallel test
  methods never collide on the same graph key)
- Delete that graph key on tearDown, tolerating it never having been created

Collaborators:
- FkFalkorStick / FkGraphEndpoint: the connection and endpoint each test runs against

Public API and Key Messages:
- FkGraphEndpointTestCase class >> urlString / urlString: - the FalkorDB connection URL tests use
  (defaults to 'sync://localhost:6379', matching the local FalkorDB Docker container and the CI
  service container)
- #endpoint - the connected FkGraphEndpoint
- #graphName - a graph name unique to the running test, safe to CREATE/MATCH against freely
"
Class {
	#name : 'FkGraphEndpointTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'stick'
	],
	#classVars : [
		'UrlString'
	],
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
}

{ #category : 'class initialization' }
FkGraphEndpointTestCase class >> initialize [
	"Before testing, you should set urlString to connect to FalkorDB"
	UrlString := 'sync://localhost:6379'
]

{ #category : 'accessing' }
FkGraphEndpointTestCase class >> urlString [
	^ UrlString
]

{ #category : 'accessing' }
FkGraphEndpointTestCase class >> urlString: anObject [
	UrlString := anObject
]

{ #category : 'accessing' }
FkGraphEndpointTestCase >> endpoint [
	^ stick endpoint
]

{ #category : 'accessing' }
FkGraphEndpointTestCase >> graphName [
	^ self class name , '_' , self selector asString
]

{ #category : 'running' }
FkGraphEndpointTestCase >> setUp [
	super setUp.
	stick := FkFalkorStick targetUrl: self class urlString.
	stick connect
]

{ #category : 'running' }
FkGraphEndpointTestCase >> tearDown [
	[ self endpoint unifiedCommand: { 'GRAPH.DELETE'. self graphName } ]
		on: Error
		do: [ :ex |  ].
	stick close.
	super tearDown
]
