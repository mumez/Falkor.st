"
I am the connection/graph handle for the high-level FalkorDB object API: a named graph reachable
through an FkFalkorStick connection. I mirror RsStream (RediStick-Stream-Objects), which plays the
same role for a Redis stream, holding a stick/settings/name and lazily creating its stick from
settings the first time a connection is needed.

Responsibility:
- Hold a graph name together with the FkFalkorStick connection it is reached through
- Lazily create and connect an FkFalkorStick from FkSettings when none is supplied
- Answer the FkGraphEndpoint (#endpoint) that runs GRAPH.* commands for this graph
- Provide thin #runCypher:/#runReadOnlyCypher: wrappers so callers don't have to route
  through #endpoint and #name themselves

Collaborators:
- FkFalkorStick: the connection I hold or lazily create
- FkGraphEndpoint: answered by #endpoint, the entry point for GRAPH.* commands
- FkSettings: supplies #targetUrl when I lazily create my own stick

Public API and Key Messages:
- FkGraphDb class >> named: - lazily creates and connects a stick from FkSettings default targetUrl
- FkGraphDb class >> on:named: - uses an already-connected stick; graph name is required either way
- #endpoint - self stick endpoint
- #name - the graph name
- #runCypher: cypherString - ^ self endpoint graphQuery: self name cypher: cypherString
- #runReadOnlyCypher: cypherString - ^ self endpoint graphRoQuery: self name cypher: cypherString

Implementation Points:
- Closing/disconnecting the stick is the caller's responsibility in both cases; I never disconnect
  it myself (matches RsStream - no release/disconnect method is provided).
"
Class {
	#name : 'FkGraphDb',
	#superclass : 'Object',
	#instVars : [
		'stick',
		'settings',
		'name'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphDb class >> named: graphName [
	^ self new
		name: graphName;
		yourself
]

{ #category : 'instance creation' }
FkGraphDb class >> on: aFkFalkorStick named: graphName [
	^ self new
		stick: aFkFalkorStick;
		name: graphName;
		yourself
]

{ #category : 'factory' }
FkGraphDb >> createStick [
	| newStick |
	newStick := FkFalkorStick targetUrl: self settings targetUrl.
	newStick beSticky.
	newStick connect.
	^ newStick
]

{ #category : 'accessing' }
FkGraphDb >> endpoint [
	^ self stick endpoint
]

{ #category : 'accessing' }
FkGraphDb >> name [
	^ name
]

{ #category : 'querying' }
FkGraphDb >> runCypher: cypherString [
	^ self endpoint graphQuery: self name cypher: cypherString
]

{ #category : 'querying' }
FkGraphDb >> runReadOnlyCypher: cypherString [
	^ self endpoint graphRoQuery: self name cypher: cypherString
]

{ #category : 'private' }
FkGraphDb >> name: anObject [
	name := anObject
]

{ #category : 'accessing' }
FkGraphDb >> settings [
	^ settings ifNil: [ settings := FkSettings default ]
]

{ #category : 'accessing' }
FkGraphDb >> settings: anObject [
	settings := anObject
]

{ #category : 'accessing' }
FkGraphDb >> stick [
	^ stick ifNil: [ stick := self createStick ]
]

{ #category : 'private' }
FkGraphDb >> stick: anObject [
	stick := anObject
]
