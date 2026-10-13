"
I am the Neo4j benchmark target: an N4GraphDb (Neo4reSt, HTTP transactional API). Neo4j Community
has a single user database, so resetting deletes every node in it - never point me at a database
whose data matters. Defaults match scripts/benchmark/docker-compose.yml.

Responsibility:
- Connect to #rootUri (default 'http://localhost:17474/') as #username / #password
  (default 'neo4j' / 'benchmark')
- Reset with N4GraphDb>>deleteAll, then create range indexes with raw Cypher and wait for them
- Answer the Neo4j kernel version from dbms.components()

Collaborators:
- N4GraphDb, N4Settings

Public API and Key Messages:
- #rootUri: / #username: / #password: - override the defaults before first use of #db
"
Class {
	#name : 'FkBenchNeo4jTarget',
	#superclass : 'FkBenchTarget',
	#instVars : [
		'rootUri',
		'username',
		'password'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'connecting' }
FkBenchNeo4jTarget >> close [
	self db close
]

{ #category : 'private' }
FkBenchNeo4jTarget >> createDb [
	^ N4GraphDb settings: (N4Settings new
			   rootUri: self rootUri;
			   username: self username;
			   password: self password;
			   yourself)
]

{ #category : 'preparing' }
FkBenchNeo4jTarget >> createIndexes [
	self indexedLabels do: [ :each |
		self runCypher: ('CREATE INDEX bench_{1}_id IF NOT EXISTS FOR (n:{2}) ON (n.id)'
				 format: { each asLowercase. each }) ].
	self runCypher: 'CALL db.awaitIndexes()'
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> label [
	^ 'Neo4j'
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> password [
	^ password ifNil: [ password := 'benchmark' ]
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> password: aString [
	password := aString
]

{ #category : 'preparing' }
FkBenchNeo4jTarget >> resetGraph [
	self db deleteAll
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> rootUri [
	^ rootUri ifNil: [ rootUri := 'http://localhost:17474/' ]
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> rootUri: aString [
	rootUri := aString
]

{ #category : 'private' }
FkBenchNeo4jTarget >> runCypher: cypherString [
	^ (self db queryByCypher: cypherString) signalIfError
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> serverVersion [
	^ (self runCypher:
		   'CALL dbms.components() YIELD name, versions, edition RETURN name + '' '' + versions[0] + '' '' + edition')
		  oneValue
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> username [
	^ username ifNil: [ username := 'neo4j' ]
]

{ #category : 'accessing' }
FkBenchNeo4jTarget >> username: aString [
	username := aString
]
