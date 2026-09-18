# Falkor.st

[![smalltalkCI](https://github.com/mumez/falkor.st/actions/workflows/main.yml/badge.svg)](https://github.com/mumez/falkor.st/actions/workflows/main.yml)

A [FalkorDB](https://github.com/FalkorDB/falkordb) client for Pharo, built on top of [RediStick](https://github.com/mumez/RediStick) (Redis client) and [SCypher](https://github.com/mumez/SCypher) (Cypher query builder).

FalkorDB is a Redis module that lets Redis interpret Cypher queries over a property graph, so falkor.st talks to it as a Redis extension rather than a separate protocol.

## Installation

```smalltalk
Metacello new
  baseline: 'FalkorSt';
  repository: 'github://mumez/falkor.st/src';
  load.
```

## Basic Usage

```smalltalk
stick := FkFalkorStick targetUrl: 'sync://localhost:6379'.
stick connect.

result := stick endpoint graphQuery: 'social' cypher: 'CREATE (p:Person {name: ''Alice''}) RETURN p'.
node := result records first first.
node properties at: #name. "'Alice'"

stick close.
```

`graphQuery:cypher:` runs `GRAPH.QUERY` and decodes the reply (compact format by default) into an
`FkQueryResult`, whose `records` are rows of decoded values (`FkNode`, `FkRelationship`, `FkPath`, or
native scalars). See `FkGraphEndpoint` for the full command set (`GRAPH.RO_QUERY`, `GRAPH.DELETE`,
`GRAPH.INFO`, `GRAPH.CONFIG`, `GRAPH.CONSTRAINT CREATE`/`DROP`, `GRAPH.EXPLAIN`, `GRAPH.PROFILE`,
`GRAPH.LIST`, `GRAPH.COPY`, `GRAPH.MEMORY`, `GRAPH.SLOWLOG`, and more).

## High-Level Object API

`FkGraphDb` (modeled on [SCypherGraph's `SgGraphDb`](https://github.com/mumez/SCypherGraph#examples)) wraps
a named graph plus its connection, and answers `FkGraphNode`/`FkGraphRelationship`/`FkGraphPath` instead of
raw query results.

### Basic

```smalltalk
db := FkGraphDb named: 'social'.

db createNodeLabeled: 'Person' properties: { 'name'->'Alice'. 'age'->30 }.

"Print 'Person' node properties"
(db nodesLabeled: 'Person')
   do: [ :each | Transcript showCr: each properties printString ].
```

### Get node with where:

```smalltalk
alice := (db nodesLabeled: 'Person' where: [ :n | (n @ 'name') = 'Alice' ]) first.
alice properties.
```

### Create relationships

```smalltalk
bob := db createNodeLabeled: 'Person' properties: { 'name'->'Bob' }.

db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: { 'since'->2020 }.
```

### Traverse one-hop paths

```smalltalk
(db
   oneHopPathsTyped: 'KNOWS'
   direction: #out
   from: alice id
   havingAll: #()
   endNodeWithLabels: #('Person')
   havingAll: #()
   whereIn: [ :s :r :e | nil ]
   returning: [ :path | path endNode propertyAt: 'name' ]).
"an OrderedCollection('Bob')"
```

### Execute Cypher directly

```smalltalk
db runCypher: 'UNWIND range(1, 5) AS n RETURN n*n'. "inspect it"

db runCypher: 'UNWIND range($from, $to) AS n RETURN n*n'
   arguments: { 'from'->2. 'to'->4 } asDictionary. "inspect it"
```

### Execute dynamically generated Cypher

```smalltalk
p := 'p' asCypherIdentifier.

query := CyQuery
   match: (CyNode name: p labels: #('Person'))
   where: ((p @ 'age') greaterThan: 'minAge' asCypherParameter)
   return: (p @ 'name').

db runCypher: query arguments: { 'minAge' -> 18 } asDictionary. "inspect it"
```

## Status

Commands are implemented, except for administrative ACL commands. A high-level object-graph API
(`FkGraphDb`) covering node/relationship CRUD and path traversal is also in place; see examples above.
