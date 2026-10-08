"
I am the FalkorDB benchmark target: an FkGraphDb on a dedicated graph, reached through my own sticky
FkFalkorStick. Defaults match scripts/benchmark/docker-compose.yml.

Responsibility:
- Connect to #targetUrl (default 'sync://localhost:16379') and use graph #graphName (default
  'falkorst-bench')
- Reset by dropping the whole graph key, then create range indexes through #createIndexBy:
- Answer the FalkorDB module version from MODULE LIST

Collaborators:
- FkGraphDb, FkFalkorStick

Public API and Key Messages:
- #targetUrl: / #graphName: - override the defaults before first use of #db
"
Class {
	#name : 'FkBenchFalkorTarget',
	#superclass : 'FkBenchTarget',
	#instVars : [
		'targetUrl',
		'graphName'
	],
	#category : 'FalkorSt-Benchmarks',
	#package : 'FalkorSt-Benchmarks'
}

{ #category : 'connecting' }
FkBenchFalkorTarget >> close [
	self db stick close
]

{ #category : 'private' }
FkBenchFalkorTarget >> createDb [
	| stick |
	stick := FkFalkorStick targetUrl: self targetUrl.
	stick beSticky.
	stick connect.
	^ FkGraphDb on: stick named: self graphName
]

{ #category : 'preparing' }
FkBenchFalkorTarget >> createIndexes [
	self indexedLabels do: [ :each |
		self db createIndexBy: [ :index |
			index
				range;
				node: each;
				props: #( 'id' ) ] ]
]

{ #category : 'accessing' }
FkBenchFalkorTarget >> graphName [
	^ graphName ifNil: [ graphName := 'falkorst-bench' ]
]

{ #category : 'accessing' }
FkBenchFalkorTarget >> graphName: aString [
	graphName := aString
]

{ #category : 'accessing' }
FkBenchFalkorTarget >> label [
	^ 'FalkorDB'
]

{ #category : 'preparing' }
FkBenchFalkorTarget >> resetGraph [
	self db exists ifTrue: [ self db drop ]
]

{ #category : 'accessing' }
FkBenchFalkorTarget >> serverVersion [
	"MODULE LIST answers the graph module version as an integer such as 60001 (= 6.0.1)"

	| graphModule version |
	graphModule := (self db endpoint unifiedCommand: #( 'MODULE' 'LIST' )) detect: [ :each |
		               (each at: (each indexOf: 'name') + 1) = 'graph' ].
	version := graphModule at: (graphModule indexOf: 'ver') + 1.
	^ 'FalkorDB {1}.{2}.{3}' format: {
			  (version // 10000).
			  (version // 100 \\ 100).
			  (version \\ 100) }
]

{ #category : 'accessing' }
FkBenchFalkorTarget >> targetUrl [
	^ targetUrl ifNil: [ targetUrl := 'sync://localhost:16379' ]
]

{ #category : 'accessing' }
FkBenchFalkorTarget >> targetUrl: aString [
	targetUrl := aString
]
