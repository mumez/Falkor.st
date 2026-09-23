# E2E Scenario: Reproducing "Interacting with Neo4j from Pharo Smalltalk" with FalkorDB

Source: https://umejava.wordpress.com/2021/03/01/528/ (SCypherGraph + Neo4j).

This reproduces the same scenario against FalkorDB using `FalkorSt-Objects`'
high-level API (`FkGraphDb` / `FkGraphNode` / `FkGraphRelationship`). Every
snippet below is meant to be run in order, top to bottom, via `st-eval`
against a real FalkorDB instance (see `.github/workflows/main.yml` for the
`falkordb/falkordb:latest` service used in CI).

Differences from the Neo4j-based original, and why:

- Neo4j's own "Movie" demo dataset (`:play movie-graph`) doesn't exist in a
  fresh FalkorDB graph, so step 1 seeds an equivalent minimal movie graph
  first, using `mergeNodeLabeled:properties:` / `mergeOutRelationshipTyped:...`.
- `db settings username:/password:` from the original has no FalkorDB
  equivalent yet (`FkSettings` only exposes `targetUrl`); connection is
  implicit via `FkGraphDb named:`, which lazily connects through
  `FkSettings default`.
- The blog's `matrix inRelationshipsTyped: 'ACTED_IN' collect: [:each | each
  endNode @ 'name']` reads the *actor's* name off a relationship incoming to
  `matrix` - i.e. the end *relative to the node the relationship was fetched
  from*, not the Cypher-absolute end node (which for `ACTED_IN` is always the
  movie). `FkGraphRelationship` makes this distinction explicit via
  `#ownNode`/`#otherNode` (anchor-relative) vs. `#startNode`/`#endNode`
  (Cypher-absolute) - see its class comment. The snippets below use
  `otherNode` wherever the original relies on that relative reading.
- `db runCypher: aCypherQuery` (raw string) and `db runCypher: aCyQuery` (a
  built `CyQuery`) both work, but named-parameter binding takes a plain
  `Dictionary` of `name -> value` directly (`FkGraphEndpoint`'s CYPHER-prefix
  convention), not a `Dictionary` wrapped in a `'values'` key (that wrapping
  is `FkGraphDb`'s own private convention for whole-property-map SET/MERGE
  calls, e.g. `nodeAt:properties:`).
- `FkQueryResult` (what `runCypher:`/`runReadOnlyCypher:` answer) has no
  `#fieldValues` - that's `SgGraphDb`'s reference-only result API. Use
  `#records` (an `OrderedCollection` of per-record value arrays) directly,
  e.g. `result records groupedBy: [:each | each at: 1]`.
- Unlike Neo4j, FalkorDB (C engine, as of 4.20.4) does not enforce Cypher's
  relationship uniqueness within a single `MATCH` pattern: in
  `(p)-[act1:ACTED_IN]->(m)<-[act2:ACTED_IN]-(o)` the same relationship can
  bind to both `act1` and `act2`, so an actor shows up as their own co-actor
  (e.g. `Keanu Reeves, Keanu Reeves, The Matrix`). This is not documented in
  the FalkorDB docs and is tracked upstream as a bug
  ([#1944](https://github.com/FalkorDB/FalkorDB/issues/1944); see also
  [#2441](https://github.com/FalkorDB/FalkorDB/issues/2441),
  [#2307](https://github.com/FalkorDB/FalkorDB/issues/2307)). Step 8 therefore
  adds an explicit `act1 <> act2` condition to the `WHERE` clause.

## 0. Setup

```smalltalk
db := FkGraphDb named: 'e2e_movies'.
```

## 1. Seed a minimal movie graph

```smalltalk
tom := db mergeNodeLabeled: 'Person' properties: { 'name' -> 'Tom Hanks'. 'born' -> 1956 }.
keanu := db mergeNodeLabeled: 'Person' properties: { 'name' -> 'Keanu Reeves'. 'born' -> 1964 }.
carrie := db mergeNodeLabeled: 'Person' properties: { 'name' -> 'Carrie-Anne Moss'. 'born' -> 1967 }.
matrix := db mergeNodeLabeled: 'Movie' properties: { 'title' -> 'The Matrix'. 'released' -> 1999 }.
forrest := db mergeNodeLabeled: 'Movie' properties: { 'title' -> 'Forrest Gump'. 'released' -> 1994 }.

db mergeOutRelationshipTyped: 'ACTED_IN' fromNodeId: keanu id toNodeId: matrix id properties: { 'roles' -> #('Neo') }.
db mergeOutRelationshipTyped: 'ACTED_IN' fromNodeId: carrie id toNodeId: matrix id properties: { 'roles' -> #('Trinity') }.
db mergeOutRelationshipTyped: 'ACTED_IN' fromNodeId: tom id toNodeId: forrest id properties: { 'roles' -> #('Forrest') }.
```

## 2. Database connection and global operations

```smalltalk
db allLabels. "print it -- #('Person' 'Movie')"
db allRelationshipTypes. "print it -- #('ACTED_IN')"
```

## 3. Retrieving nodes

```smalltalk
(db nodesLabeled: 'Movie')
   do: [ :each | Transcript showCr: each properties printString ].
```

```smalltalk
matrix := (db nodesLabeled: 'Movie' having: 'title' value: 'The Matrix') first.
matrix properties. "a Dictionary('released'->1999 'title'->'The Matrix' )"
```

## 4. Accessing relationships

```smalltalk
matrix inRelationships. "print it"
matrix outRelationships. "print it (empty)"
(matrix inRelationshipsTyped: 'ACTED_IN')
  collect: [ :each | each otherNode @ 'name' ]. "print it -- an OrderedCollection('Keanu Reeves' 'Carrie-Anne Moss')"
```

```smalltalk
(matrix inRelationshipsTyped: 'ACTED_IN' having: 'roles' value: #('Neo'))
  collect: [ :each | each otherNode properties ]. "print it -- an OrderedCollection(a Dictionary('born'->1964 'name'->'Keanu Reeves' ))"
```

## 5. Creating nodes

```smalltalk
sf := db mergeNodeLabeled: 'Genre' properties: { 'name' -> 'SF'. 'description' -> 'Science Fiction' }. "inspect it"
action := db mergeNodeLabeled: 'Genre' properties: { 'name' -> 'Action'. 'description' -> 'Exciting Actions' }. "inspect it"
```

## 6. Creating relationships

```smalltalk
matrixToSf := matrix relateOneTo: sf typed: 'HAS_GENRE' properties: { 'score' -> 6 }.
matrixToAction := matrix relateTo: action typed: 'HAS_GENRE' properties: { 'score' -> 7 }. "do it"
```

```smalltalk
{ matrixToSf startNode @ 'title'. matrixToSf endNode @ 'name' }. "print it -- #('The Matrix' 'SF')"
matrix outRelationships. "print it"
```

## 7. Raw Cypher queries

```smalltalk
db runCypher: 'UNWIND range(1, 10) AS n RETURN n*n'. "inspect it"
db runCypher: 'UNWIND range($from, $to) AS n RETURN n*n' arguments: { 'from' -> 2. 'to' -> 5 } asDictionary. "inspect it"
```

## 8. Dynamic Cypher generation with SCypher

```smalltalk
p := 'p' asCypherObject.
m := 'm' asCypherObject.
o := 'o' asCypherObject.
act1 := 'act1' asCypherObject.
act2 := 'act2' asCypherObject.

pathPattern := (p node: 'Person') - (act1 rel: 'ACTED_IN') -> (m node: 'Movie')
  <- (act2 rel: 'ACTED_IN') - (o node: 'Person').

actorNameParam := 'actorName' asCypherParameter.
"act1 <> act2: FalkorDB does not enforce relationship uniqueness within a pattern (see notes above)"
where := ((p @ 'name') starts: actorNameParam) & (act1 ~= act2).

return := (p @ 'name'), (o @ 'name'), (m @ 'title').

query := CyQuery match: pathPattern where: where return: return orderBy: (p @ 'name') skip: 0 limit: 100. "print it"

result := db runCypher: query arguments: { 'actorName' -> 'Keanu' } asDictionary.
(result records groupedBy: [ :each | each at: 1 ]). "inspect it"
```

## Cleanup

```smalltalk
db deleteAll.
```
