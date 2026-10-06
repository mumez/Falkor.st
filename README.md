# Falkor.st

[![smalltalkCI](https://github.com/mumez/falkor.st/actions/workflows/main.yml/badge.svg)](https://github.com/mumez/falkor.st/actions/workflows/main.yml)

A [FalkorDB](https://github.com/FalkorDB/falkordb) client for Pharo, built on top of
[RediStick](https://github.com/mumez/RediStick) (Redis client) and
[SCypher](https://github.com/mumez/SCypher) (Cypher query builder).

FalkorDB is a low-latency property graph database built for knowledge graphs and LLM applications
such as GraphRAG. It stores the graph as sparse adjacency matrices and runs queries as linear
algebra (via GraphBLAS). Queries are written in OpenCypher, and FalkorDB adds its own extensions,
such as full-text and vector indexes. Falkor.st lets you use FalkorDB from Smalltalk.

## Features

- Every `GRAPH.*` command: query, read-only query, explain, profile, slow log, memory usage, config,
  info, constraints, copy, delete, list, and UDFs.
- Query results decoded into Smalltalk objects: nodes, relationships, paths, points, temporal values,
  lists, and maps.
- A high-level object API (`FkGraphDb`) for node/relationship CRUD, one-hop traversal, indexes,
  constraints, and diagnostics. You don't have to write Cypher for these.
- Safe parameter binding. You can also build queries dynamically with SCypher.

## Requirements

- Pharo 12, 13, or 14
- A running FalkorDB server. The quickest way to get one is Docker:

```bash
docker run -p 6379:6379 -it --rm falkordb/falkordb:latest
```

## Installation

```smalltalk
Metacello new
  baseline: 'FalkorSt';
  repository: 'github://mumez/falkor.st/src';
  load.
```

This loads everything, including the tests. To load only what you need, pass one or more groups
(see [Package Layers](#package-layers)):

```smalltalk
Metacello new
  baseline: 'FalkorSt';
  repository: 'github://mumez/falkor.st/src';
  load: #('Core' 'Objects').
```

## Package Layers

Falkor.st has three layers. Each one builds on the layer below it.

| Group     | Package            | Main classes                           | Use it for                                                               |
|-----------|--------------------|----------------------------------------|--------------------------------------------------------------------------|
| `Core`    | `FalkorSt-Core`    | `FkFalkorStick`, `FkGraphEndpoint`, `FkQueryResult` | Low-level access to every `GRAPH.*` command and result decoding |
| `Objects` | `FalkorSt-Objects` | `FkGraphDb`, `FkGraphNode`, `FkGraphRelationship`, `FkGraphPath` | Object-oriented CRUD and traversal on one named graph |
| `Udf`     | `FalkorSt-Udf`     | `FkGraphEndpoint` extensions, `FkUdfLibraryInfo` | Managing JavaScript user-defined functions (`GRAPH.UDF`)   |

- **Core** sits directly on RediStick. `FkFalkorStick` is the connection, and its `endpoint` (an
  `FkGraphEndpoint`) takes the graph name as an argument on every call. Results come back as
  `FkQueryResult` objects holding plain value objects (`FkNode`, `FkRelationship`, `FkPath`, ...).
- **Objects** wraps one named graph in an `FkGraphDb`. Each node or relationship it returns knows
  which graph it came from, so you can update, delete, or traverse it directly. Most applications only
  need this layer.
- **Udf** adds the `GRAPH.UDF` commands to `FkGraphEndpoint`. It is a separate package because UDFs
  are optional and only server-wide.

The `FkGraphDb` API is modeled on [SCypherGraph](https://github.com/mumez/SCypherGraph) and
[Neo4reSt](https://github.com/mumez/Neo4reSt).

## Quick Start

```smalltalk
db := FkGraphDb named: 'social'.

alice := db createNodeLabeled: 'Person' properties: { 'name'->'Alice'. 'age'->30 }.
bob := db createNodeLabeled: 'Person' properties: { 'name'->'Bob'. 'age'->25 }.
alice relateTo: bob typed: 'KNOWS' properties: { 'since'->2020 }.

(alice outRelationshipsTyped: 'KNOWS') collect: [ :rel | rel endNode name ].
"an OrderedCollection('Bob')"
```

`FkGraphDb named:` connects to `sync://localhost:6379` by default. See
[Connection and Settings](#connection-and-settings) to change the connection.

## High-Level API (`FkGraphDb`)

### Connection and Settings

`FkSettings default` holds the shared configuration. `FkGraphDb named:` uses it to create its own
connection the first time one is needed.

```smalltalk
FkSettings default targetUrl: 'sync://falkordb.example.com:6379'.
FkSettings default queryTimeoutMsecs: 5000. "default TIMEOUT for queries; 0 = server default"

db := FkGraphDb named: 'social'.
```

To share one connection between several graphs, connect a stick yourself and pass it in:

```smalltalk
stick := FkFalkorStick targetUrl: 'sync://localhost:6379'.
stick connect.

social := FkGraphDb on: stick named: 'social'.
movies := FkGraphDb on: stick named: 'movies'.
```

You can also give one graph its own settings, without touching the shared defaults:

```smalltalk
db := FkGraphDb named: 'social'.
db settings: (FkSettings new queryTimeoutMsecs: 1000; yourself).
```

### Nodes

```smalltalk
"Create"
alice := db createNodeLabeled: 'Person' properties: { 'name'->'Alice'. 'age'->30 }.
db createNodeLabeled: #('Person' 'Employee') properties: { 'name'->'Carol' }.

"Create only if no identical node exists yet (MERGE)"
db mergeNodeLabeled: 'Person' properties: { 'name'->'Alice'. 'age'->30 }.

"Read"
alice id.
alice labels.          "an OrderedCollection('Person')"
alice properties.
alice @ 'name'.        "'Alice' - shortcut for #propertyAt:"
db nodeAt: alice id.   "answers nil if there is no such node"

"Find"
db nodesLabeled: 'Person'.
db nodesLabeled: 'Person' having: 'name' value: 'Alice'.
db nodesLabeled: 'Person' havingAll: { 'name'->'Alice'. 'age'->30 }.
db nodesLabeled: 'Person' where: [ :n | (n @ 'age') > 20 ].
db nodesLabeled: 'Person'
   where: [ :n | (n @ 'age') > 20 ]
   orderBy: [ :n | (n @ 'age') asc ]
   skip: 0
   limit: 10.
db countNodesLabeled: 'Person'.

"Update"
alice propertyAt: 'age' put: 31.
alice mergeProperties: { 'city'->'Tokyo' }.             "add or overwrite some properties"
alice properties: { 'name'->'Alice'. 'age'->31 }.       "replace all properties"
alice removePropertyAt: 'city'.
alice addLabel: 'Employee'.
alice removeLabel: 'Employee'.

"Delete"
alice delete.
db deleteNodesLabeled: 'Person' where: [ :n | (n @ 'age') < 18 ].
```

Each mutator on a node runs right away and then reloads the node, so its local state always
matches what was committed. Updating by id without fetching the node first is also possible
(`db nodeAt: id propertyAt: 'age' put: 31`, `db nodeAt: id mergeProperties: ...`,
`db deleteNodeAt: id`).

### Relationships

```smalltalk
alice := (db nodesLabeled: 'Person' having: 'name' value: 'Alice') first.
bob := (db nodesLabeled: 'Person' having: 'name' value: 'Bob') first.

"Create (CREATE) or create-if-absent (MERGE) an outgoing relationship"
knows := alice relateTo: bob typed: 'KNOWS' properties: { 'since'->2020 }.
alice relateOneTo: bob typed: 'FOLLOWS'.

"The same, by node id"
db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().

"Read and update"
knows type.            "'KNOWS'"
knows startNode name.  "'Alice'"
knows endNode name.    "'Bob'"
knows propertyAt: 'since' put: 2021.

"Find"
db relationshipsTyped: 'KNOWS'.
db relationshipsTyped: 'KNOWS' where: [ :r | (r @ 'since') >= 2020 ].
db countRelationshipsTyped: 'KNOWS'.

"Delete"
knows delete.
db deleteRelationshipsTyped: 'FOLLOWS'.
```

### Traversal

Every node can navigate its one-hop neighborhood. `out...`, `in...`, and the plain (either
direction) variants share the same set of filters:

```smalltalk
alice outRelationships.
alice outRelationshipsTyped: 'KNOWS'.
alice outRelationshipsTyped: 'KNOWS' endNodeHaving: 'name' value: 'Bob'.
alice inRelationshipsTyped: 'KNOWS'.
alice relationshipsTyped: 'KNOWS' where: [ :s :r :e | (r @ 'since') > 2019 ].

alice existsOutRelationshipTyped: 'KNOWS'.  "true / false, nothing is fetched"
alice types.                                "a Set of relationship types"

"Whole one-hop paths (FkGraphPath: startNode, relationships, endNode)"
(alice outOneHopPathsTyped: 'KNOWS' where: [ :s :r :e | (e @ 'age') < 30 ])
   collect: [ :path | path endNode name ].
```

When you need full control over the query, `FkGraphDb` exposes the underlying query directly:

```smalltalk
db
   oneHopPathsTyped: 'KNOWS'
   direction: #out
   from: alice id
   havingAll: #()
   endNodeWithLabels: #('Person')
   havingAll: #()
   whereIn: [ :s :r :e | nil ]
   returning: [ :path | path endNode propertyAt: 'name' ].
"an OrderedCollection('Bob')"
```

### Running Cypher

For anything the object API doesn't cover, run Cypher directly. Always pass values as parameters
(`$name`) rather than concatenating them into the query string.

```smalltalk
db runCypher: 'UNWIND range(1, 5) AS n RETURN n*n'.

db runCypher: 'MATCH (p:Person) WHERE p.age > $minAge RETURN p.name, p.age'
   arguments: { 'minAge'->20 } asDictionary.

"GRAPH.RO_QUERY - rejected by the server if the query tries to write"
db runReadOnlyCypher: 'MATCH (p:Person) RETURN count(p)'.

"Override the query timeout (milliseconds) for this call only"
db runCypher: 'MATCH (a)-[*]->(b) RETURN count(b)'
   arguments: Dictionary new
   timeout: 1000.
```

Queries can also be built with SCypher. Any `CyQuery` is accepted wherever a Cypher string is:

```smalltalk
p := 'p' asCypherIdentifier.

query := CyQuery
   match: (CyNode name: p labels: #('Person'))
   where: ((p @ 'age') greaterThan: 'minAge' asCypherParameter)
   return: (p @ 'name').

db runCypher: query arguments: { 'minAge'->18 } asDictionary.
```

### Query Results

`runCypher:` and friends answer an `FkQueryResult`:

```smalltalk
result := db runCypher: 'MATCH (p:Person) RETURN p.name AS name, p.age AS age'.

result header.             "an OrderedCollection('name' 'age')"
result records.            "rows: each an OrderedCollection of values"
result mappedRecords.      "rows as column name -> value Dictionaries"
result valuesAt: 'name'.   "all values of one column"
result firstColumnValues.
result statistics.         "e.g. 'Nodes created: 1', 'Query internal execution time: ...'"

(db runCypher: 'MATCH (p:Person) RETURN count(p)') oneValue.  "a single value, or nil"
```

Values are decoded as follows:

| FalkorDB type                     | Smalltalk value                                 |
|-----------------------------------|-------------------------------------------------|
| integer, double, string, boolean  | `Integer`, `Float`, `String`, `Boolean`         |
| null                              | `nil`                                           |
| list / map                        | `OrderedCollection` / `Dictionary`              |
| node / relationship / path        | `FkNode` / `FkRelationship` / `FkPath`          |
| point                             | `FkPoint`                                       |
| vector                            | `Array` of `Float`s                             |
| datetime / date / time / duration | `DateAndTime` (UTC) / `Date` / `Time` / `Duration` |

Results from `runCypher:` contain the raw `FkNode`/`FkRelationship` values. Methods like
`nodesLabeled:` wrap them as `FkGraphNode`/`FkGraphRelationship`, which add CRUD and traversal.

### Indexes

Indexes are described with a builder block. Choose a kind (`range`, `fulltext`, `vector`, or
`cch`), an entity (`node:` or `relationship:`), and properties:

```smalltalk
db createIndexBy: [ :i | i range; node: 'Person'; props: #('name') ].
db createIndexBy: [ :i | i fulltext; node: 'Article'; props: #('title' 'body') ].
db createIndexBy: [ :i |
   i vector; node: 'Doc'; props: #('embedding');
     dimension: 128; similarityFunction: 'euclidean' ].

db indexes.   "a collection of FkGraphIndexInfo (label, properties, types, status, ...)"

db dropIndexBy: [ :i | i range; node: 'Person'; props: #('name') ].
```

If a required part (kind, entity, or properties, plus `dimension:` for a vector index) is missing,
an `RsError` is signaled before anything is sent to the server.

### Constraints

Constraints use the same builder style. Choose `unique` or `mandatory`:

```smalltalk
"A UNIQUE constraint requires a range index on the same properties"
db createIndexBy: [ :i | i range; node: 'Person'; props: #('email') ].
db createConstraintBy: [ :c | c unique; node: 'Person'; props: #('email') ].
db createConstraintBy: [ :c | c mandatory; relationship: 'KNOWS'; props: #('since') ].

db constraints.  "a collection of FkGraphConstraintInfo (label, properties, status, ...)"

db dropConstraintBy: [ :c | c unique; node: 'Person'; props: #('email') ].
```

FalkorDB creates constraints asynchronously. `createConstraintBy:` answers `'PENDING'`, and the
constraint's `status` in `db constraints` becomes `'OPERATIONAL'` once existing data has been
validated (or `'FAILED'` if the data violates it).

### Procedures

```smalltalk
db callReadOnlyProcedure: 'db.labels'.
db callProcedure: 'db.idx.fulltext.queryNodes' arguments: #('Article' 'graph').
db callReadOnlyProcedure: 'db.indexes' arguments: #() yield: #('label' 'properties').
```

Arguments are bound as query parameters, never inlined into the Cypher string.

### Diagnostics and Monitoring

```smalltalk
"Execution plan, without running the query (GRAPH.EXPLAIN)"
db explain: 'MATCH (p:Person) WHERE p.age > $minAge RETURN p'
   arguments: { 'minAge'->20 } asDictionary.

"Run the query and report per-operation records and timings (GRAPH.PROFILE)"
db profile: 'MATCH (p:Person) RETURN p'.

"Queries that took longer than ~10 ms (GRAPH.SLOWLOG)"
db slowLog do: [ :entry |
   Transcript showCr: entry executionTimeMs printString, ' ms: ', entry query ].
db resetSlowLog.

"Memory used by this graph, as a Dictionary (GRAPH.MEMORY USAGE)"
db memoryUsage.
db memoryUsageSamples: 100.   "more samples = more accurate, slower"
```

### Graph Management

```smalltalk
db exists.                 "is there a graph with this name on the server?"
db countNodes.
db countRelationships.
db allLabels.
db allRelationshipTypes.
db allPropertyKeys.
db orphanedNodes.          "nodes with no relationships"

backup := db copyTo: 'social-backup'.   "answers an FkGraphDb for the copy"

db deleteAll.   "delete all nodes and relationships; indexes and constraints remain"
db drop.        "delete the whole graph, including indexes and constraints"
```

## Low-Level API (`FkGraphEndpoint`)

`FkGraphEndpoint` maps directly onto FalkorDB's
[commands](https://docs.falkordb.com/commands/). Use it for server-wide commands, or when you
want to work with graph names directly.

```smalltalk
stick := FkFalkorStick targetUrl: 'sync://localhost:6379'.
stick connect.
endpoint := stick endpoint.

result := endpoint graphQuery: 'social' cypher: 'CREATE (p:Person {name: ''Alice''}) RETURN p'.
result records first first.   "an FkNode"

endpoint graphQuery: 'social'
   cypher: 'MATCH (p:Person {name: $name}) RETURN p'
   params: { 'name'->'Alice' } asDictionary.
endpoint graphRoQuery: 'social' cypher: 'MATCH (p) RETURN count(p)'.

stick close.
```

Results use the compact reply format by default. Pass `compact: false` to request the verbose
format. Verbose replies don't include type information, so booleans, doubles, lists, maps, paths,
points, vectors, and temporal values arrive as `String`s.

Server-wide commands:

```smalltalk
endpoint graphList.                                   "all graph names"
endpoint graphConfigGet: 'TIMEOUT_DEFAULT'.
endpoint graphConfigGetAll.
endpoint graphConfigSet: { 'TIMEOUT_DEFAULT'->5000 } asDictionary.
endpoint graphInfo.
endpoint graphInfo: [ :opts | opts showRunningQueries; showWaitingQueries ].
```

All graph-scoped commands are also available here, with the graph name as an argument (for
example `graphExplain:cypher:`, `graphProfile:cypher:`, `graphSlowLog:`,
`graphMemoryUsage:`, `graphIndexCreateBy:on:`, `graphConstraintCreateBy:on:`, `graphCopy:to:`, and
`graphDelete:`).

## User-Defined Functions (`FalkorSt-Udf`)

FalkorDB can run user-defined functions written in JavaScript. A library registers its functions
with `falkor.register`, and Cypher calls them as `<library>.<function>(...)`:

```smalltalk
endpoint graphUdfLoad: 'strings'
   code: 'function up(s) { return s.toUpperCase(); } falkor.register(''Up'', up);'.

(endpoint graphQuery: 'social' cypher: 'RETURN strings.Up(''abc'')') oneValue.  "'ABC'"

"Load from a file, replacing an existing library with the same name"
endpoint graphUdfLoad: 'strings' file: 'strings.js' asFileReference replace: true.

endpoint graphUdfList.                       "a collection of FkUdfLibraryInfo (name, functions)"
endpoint graphUdfListWithCode: 'strings'.    "the same, including source (#code)"

endpoint graphUdfDelete: 'strings'.
endpoint graphUdfFlush.                      "delete every library on the server"
```

UDF libraries are server-wide. They are not scoped to a single graph.

## Running the Tests

The tests need a real FalkorDB server on `localhost:6379` (see [Requirements](#requirements)).
Load the default group, then run the `FalkorSt-*-Tests` packages with the Test Runner. CI runs
the same tests with [smalltalkCI](https://github.com/hpi-swa/smalltalkCI) against Pharo 12–14
(see `.github/workflows/main.yml`).

## License

MIT. See [LICENSE](LICENSE).
