# Read-only query audit (phase 1 inventory)

Scope: every call site of `#runCypher:`, `#runCypher:arguments:`, `#runCypher:arguments:timeout:`,
non-readOnly `#graphCallProcedure:*` and `#graphQuery:*` in `src/FalkorSt-Core`,
`src/FalkorSt-Objects` and `src/FalkorSt-Udf` (Benchmarks skipped). Each call site was traced to the
public method(s) that reach it. The classification is based on the Cypher each method actually
builds, not on its selector.

## 1. Problem and layering decision

### Problem

`GRAPH.QUERY` creates the graph key if it does not exist yet. `GRAPH.RO_QUERY` does not create it; on
a missing graph it fails with a generic `ERR` that RediStick raises as `RsGenericError`. Several
read methods still send `GRAPH.QUERY`, so reading from a missing graph creates an empty one:

```smalltalk
db := FkGraphDb named: 'aaa'.
db exists.   "false"
db indexes.  "empty collection"
db exists.   "true!"
```

`FkGraphDb` already has a safe read path. `#runReadOnlyCypher:*` and `#callReadOnlyProcedure:*` send
`GRAPH.RO_QUERY` inside `#answerEmptyResultIfGraphIsMissingDuring:`. That wrapper catches
`RsGenericError`. If `#exists` (GRAPH.LIST) is false, it answers
`FkQueryResult new setHeader: #() records: #() statistics: #()`. Otherwise it passes the error on.
This is already used by `countNodes*`, `countRelationships*`, `allLabels`, `allRelationshipTypes`,
`allPropertyKeys`, `orphanedNodes` and `FkGraphNode>>labelsFromDb`, and
`FkGraphDbTest>>testReadsOnAGraphThatDoesNotExistYetAnswerEmptyResults` covers it.

### Layering decision for `graphIndexes:` / `graphConstraints:`

Current code (`src/FalkorSt-Core/FkGraphEndpoint.class.st`):

```smalltalk
graphIndexes: graphName
    ^ (self graphCallProcedure: graphName procedure: 'db.indexes') mappedRecords collect: [ :record |
        FkGraphIndexInfo fromRecord: record ]          "GRAPH.QUERY"
```

`graphConstraints:` has the same shape, with `db.constraints` and `FkGraphConstraintInfo`.
`FkGraphDb>>indexes` / `>>constraints` simply delegate to these methods.

Decision. This is the recommended approach, checked against the code, plus one refinement to avoid
duplicating the mapping:

1. **Core: share the mapping.** Add `FkGraphIndexInfo class >> allFromQueryResult: aFkQueryResult`
   and `FkGraphConstraintInfo class >> allFromQueryResult: aFkQueryResult`. Each answers
   `aFkQueryResult mappedRecords collect: [ :record | self fromRecord: record ]`. This becomes the
   only place where procedure records are mapped to info objects.
2. **Endpoint: go read-only, keep the raw error.** `graphIndexes:` becomes
   `^ FkGraphIndexInfo allFromQueryResult: (self graphCallProcedure: graphName procedure: 'db.indexes' arguments: #() yield: nil readOnly: true)`.
   `graphConstraints:` gets the same change. The endpoint stays a thin protocol layer and does not
   know about missing graphs, matching `#graphRoQuery:*`.
3. **FkGraphDb: answer empty on a missing graph.** `indexes` becomes
   `^ FkGraphIndexInfo allFromQueryResult: (self callReadOnlyProcedure: 'db.indexes')`. `constraints`
   gets the same change. `#callReadOnlyProcedure:` already wraps the call in
   `#answerEmptyResultIfGraphIsMissingDuring:`, so a missing graph gives an empty FkQueryResult. Its
   header and records are both `#()`, so `mappedRecords` gives an empty collection and so does
   `allFromQueryResult:`.

Rejected alternative: wrapping `[ self endpoint graphIndexes: self name ]` directly in
`#answerEmptyResultIfGraphIsMissingDuring:`. On a missing graph that wrapper answers an
**FkQueryResult**, not a collection of FkGraphIndexInfo, so `indexes` would return the wrong type.
It would need a second, collection-flavoured wrapper. Going through `#callReadOnlyProcedure:` reuses
the existing wrapper unchanged and also makes `indexes` / `constraints` honour
`FkGraphDb>>settings queryTimeoutMsecs`, like every other FkGraphDb read. Before this change they
used the endpoint's `queryTimeoutMsecs`; both default to `FkSettings default queryTimeoutMsecs`.

**What a direct FkGraphEndpoint caller sees after the change:** on a missing graph,
`endpoint graphIndexes: 'nope'` and `endpoint graphConstraints: 'nope'` **raise `RsGenericError`**
(FalkorDB's `ERR` reply to `GRAPH.RO_QUERY`) and do not create the graph. Before the change they
answered an empty `OrderedCollection` and created the graph as a side effect. On an existing graph
the result is unchanged.

**Does anything depend on the old behaviour?** No:
- Within src/, the only callers of `graphIndexes:` / `graphConstraints:` are `FkGraphDb>>indexes` /
  `>>constraints`, and those switch to `callReadOnlyProcedure:`. Benchmarks and README never call
  the endpoint methods directly. README shows only `db indexes` / `db constraints`, which still
  answer an empty collection.
- `FkGraphEndpointTest`: every test that lists indexes or constraints creates the graph first.
  - `testGraphIndexesEmptyWhenGraphHasNoIndexes` and
    `testGraphConstraintsEmptyWhenGraphHasNoConstraints` send `CREATE (:Person)` first.
  - The index create/drop tests create the graph with `CREATE INDEX` over GRAPH.QUERY.
  - `testGraphConstraintsListsCreatedConstraintsOn{Node,Relationship}` send `CREATE ...` first.
  - The helpers `indexInfoLabeled:entityType:` and `constraintInfoOfType:entityType:entityName:`
    are only called after one of these setups.
- `FkGraphDbTest`: `testCreateIndexByListsTheIndex`, `testDropIndexByRemovesTheIndex`,
  `testCreateConstraintByListsTheConstraint` and `testDropConstraintByRemovesTheConstraint` all call
  `db runCypher: 'CREATE ...'` first.
- `FkGraphEndpointProcedureCallTest` (line 74) calls the read-write
  `graphCallProcedure:procedure:` directly. That method is not changed (see section 3, c4).

Doc follow-ups for phase 2 (done):
- `FkGraphEndpoint`'s class comment now has one combined entry for `#graphIndexes:` /
  `#graphConstraints:` that says they are read-only and signal on a missing graph.
- The FkGraphIndexInfo/FkGraphConstraintInfo comments now name FkQueryResult as the collaborator and
  `allFromQueryResult:` as the key message. They do not mention FkGraphDb, because FalkorSt-Core
  sits below FalkorSt-Objects. The class comments stay short (see CLAUDE.local.md).

### Change point for most other reads

Inside `FkGraphDb`, each read method ends in a single `self runCypher: query` line. Changing that
line to `self runReadOnlyCypher: query` is enough. For the one-hop family, the only change point is
the private `#oneHopPathsQueryResultFor:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:pathProcessIn:returnIn:`,
which all path, relationship-navigation and existence reads (in FkGraphDb and FkGraphNode) go
through. `#oneHopPathsQueryFor:...` only builds the query; it is also used by tests via `#explain:`
and is not affected.

## 2. Inventory table

Legend: (a) pure read, must move to GRAPH.RO_QUERY; (b) write, stays on GRAPH.QUERY; (c) ambiguous,
see section 3. "RO" means `runReadOnlyCypher:`.

None of the (a) items raise on zero records:
- `#firstNodeOrNilFrom:` and `#firstRelationshipOrNilFrom:` go through `#oneValueDo:`, which answers
  nil.
- `#nodesFrom:`, `#relationshipsFrom:` and `firstColumnValues collect:` answer an empty collection.
- `existsOneHopPathsTyped:` uses `#oneValueIfNone: [ false ]`.
- `allFromQueryResult:` answers an empty collection.

So no result-handling change is needed. No (a) method calls `records first` or
`firstColumnValues first` directly.

### (a) Pure reads: FkGraphDb (FalkorSt-Objects)

| Class | Selector | Current call | Cls | Planned change | Expected result on missing graph |
|---|---|---|---|---|---|
| FkGraphDb | `nodeAt:` | `runCypher:` (MATCH (n) WHERE id(n)=x RETURN n) → `#firstNodeOrNilFrom:` | a | `runReadOnlyCypher:` | `nil` |
| FkGraphDb | `nodesLabeled:` | → `nodesLabeled:havingAll:` | a | none (delegates) | empty collection |
| FkGraphDb | `nodesLabeled:having:value:` | → `nodesLabeled:where:` | a | none (delegates) | empty collection |
| FkGraphDb | `nodesLabeled:havingAll:` | → `nodesLabeled:where:` | a | none (delegates) | empty collection |
| FkGraphDb | `nodesLabeled:where:` | `runCypher:` (MATCH/WHERE/RETURN n) → `#nodesFrom:` | a | `runReadOnlyCypher:` | empty collection |
| FkGraphDb | `nodesLabeled:where:orderBy:skip:limit:` | `runCypher:` (MATCH/WHERE/RETURN/ORDER BY/SKIP/LIMIT) → `#nodesFrom:` | a | `runReadOnlyCypher:` | empty collection |
| FkGraphDb | `nodesLabeled:where:skip:limit:` | `runCypher:` (MATCH/WHERE/RETURN/SKIP/LIMIT) → `#nodesFrom:` | a | `runReadOnlyCypher:` | empty collection |
| FkGraphDb | `relationshipAt:` | `runCypher:` (MATCH (s)-[r]-(e) WHERE id(r)=x RETURN r) → `#oneValueDo:` | a | `runReadOnlyCypher:` | `nil` |
| FkGraphDb | `relationshipsTyped:` | → `relationshipsTyped:havingAll:` | a | none (delegates) | empty collection |
| FkGraphDb | `relationshipsTyped:having:value:` | → `relationshipsTyped:where:` | a | none (delegates) | empty collection |
| FkGraphDb | `relationshipsTyped:havingAll:` | → `relationshipsTyped:where:` | a | none (delegates) | empty collection |
| FkGraphDb | `relationshipsTyped:where:` | → `relationshipsTyped:where:orderBy:skip:limit:` | a | none (delegates) | empty collection |
| FkGraphDb | `relationshipsTyped:where:orderBy:skip:limit:` | `runCypher:` (MATCH ()-[r]->() WHERE/RETURN r ...) → `#relationshipsFrom:` | a | `runReadOnlyCypher:` | empty collection |
| FkGraphDb | `oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning:` | → `...returnIn: nil returning:` | a | none (delegates) | empty collection |
| FkGraphDb | `oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returnIn:returning:` | private `oneHopPathsQueryResultFor:...` → `runCypher:` (MATCH s WHERE id / WITH s / MATCH p=... / RETURN p) → `firstColumnValues collect:` | a | private `oneHopPathsQueryResultFor:...` → `runReadOnlyCypher:` | empty collection |
| FkGraphDb | `existsOneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:` | same private method (RETURN count(p) > 0) → `#oneValueIfNone: [ false ]` | a | covered by the private-method change | `false` |
| FkGraphDb | `existsOneHopPathsTyped:direction:from:whereIn:` | → the full `existsOneHopPathsTyped:...` | a | none (delegates) | `false` |
| FkGraphDb | `indexes` | `endpoint graphIndexes:` → non-RO `graphCallProcedure:procedure:` (CALL db.indexes()) | a | `FkGraphIndexInfo allFromQueryResult: (self callReadOnlyProcedure: 'db.indexes')` | empty collection |
| FkGraphDb | `constraints` | `endpoint graphConstraints:` → non-RO `graphCallProcedure:procedure:` (CALL db.constraints()) | a | `FkGraphConstraintInfo allFromQueryResult: (self callReadOnlyProcedure: 'db.constraints')` | empty collection |

### (a) Pure reads: FkGraphEndpoint (FalkorSt-Core)

| Class | Selector | Current call | Cls | Planned change | Expected result on missing graph |
|---|---|---|---|---|---|
| FkGraphEndpoint | `graphIndexes:` | `graphCallProcedure:procedure:` (GRAPH.QUERY, CALL db.indexes()) | a | `graphCallProcedure:procedure:arguments: #() yield: nil readOnly: true` + `FkGraphIndexInfo allFromQueryResult:` | **raises `RsGenericError`**, graph not created |
| FkGraphEndpoint | `graphConstraints:` | `graphCallProcedure:procedure:` (GRAPH.QUERY, CALL db.constraints()) | a | `...readOnly: true` + `FkGraphConstraintInfo allFromQueryResult:` | **raises `RsGenericError`**, graph not created |

### (a) Pure reads: FkGraphNode via its db (FalkorSt-Objects)

These reach the db through
`FkGraphNode>>oneHopPathsTyped:direction:havingAll:endNodeWithLabels:havingAll:whereIn:` (private),
`>>relationshipsTyped:direction:havingAll:endNodeWithLabels:havingAll:whereIn:` (private) or
`db existsOneHopPathsTyped:direction:from:whereIn:`. All of them end up in
`FkGraphDb>>oneHopPathsQueryResultFor:...`, so the single private-method change covers them; no
FkGraphNode code changes. A missing graph here means the node's graph was dropped after the node
was fetched (a stale FkGraphNode). Today these calls silently recreate an empty graph.

| Class | Selector | Current call | Cls | Planned change | Expected result on missing graph |
|---|---|---|---|---|---|
| FkGraphNode | `existsRelationshipTyped:` | db `existsOneHopPathsTyped:direction: nil from:whereIn:` | a | none (covered) | `false` |
| FkGraphNode | `existsRelationshipTyped:having:value:` | same | a | none (covered) | `false` |
| FkGraphNode | `existsRelationshipTyped:endNodeHaving:value:` | same | a | none (covered) | `false` |
| FkGraphNode | `existsInRelationshipTyped:` | same, direction `#in` | a | none (covered) | `false` |
| FkGraphNode | `existsInRelationshipTyped:having:value:` | same | a | none (covered) | `false` |
| FkGraphNode | `existsInRelationshipTyped:endNodeHaving:value:` | same | a | none (covered) | `false` |
| FkGraphNode | `existsOutRelationshipTyped:` | same, direction `#out` | a | none (covered) | `false` |
| FkGraphNode | `existsOutRelationshipTyped:having:value:` | same | a | none (covered) | `false` |
| FkGraphNode | `existsOutRelationshipTyped:endNodeHaving:value:` | same | a | none (covered) | `false` |
| FkGraphNode | `oneHopPathsTyped:havingAll:endNodeWithLabels:havingAll:` | db `oneHopPathsTyped:...returning:` | a | none (covered) | empty collection |
| FkGraphNode | `oneHopPathsTyped:where:` | same | a | none (covered) | empty collection |
| FkGraphNode | `inOneHopPathsTyped:havingAll:endNodeWithLabels:havingAll:` | same | a | none (covered) | empty collection |
| FkGraphNode | `inOneHopPathsTyped:where:` | same | a | none (covered) | empty collection |
| FkGraphNode | `outOneHopPathsTyped:havingAll:endNodeWithLabels:havingAll:` | same | a | none (covered) | empty collection |
| FkGraphNode | `outOneHopPathsTyped:where:` | same | a | none (covered) | empty collection |
| FkGraphNode | `relationships` | → `relationshipsTyped:` → db `oneHopPathsTyped:...returning:` → `inject:into:` | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `relationshipsTyped:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `relationshipsTyped:having:value:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `relationshipsTyped:endNodeHaving:value:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `relationshipsTyped:havingAll:endNodeWithLabels:havingAll:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `relationshipsTyped:where:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `inRelationships` | same, direction `#in` | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `inRelationshipsTyped:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `inRelationshipsTyped:having:value:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `inRelationshipsTyped:endNodeHaving:value:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `inRelationshipsTyped:havingAll:endNodeWithLabels:havingAll:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `inRelationshipsTyped:where:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `outRelationships` | same, direction `#out` | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `outRelationshipsTyped:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `outRelationshipsTyped:having:value:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `outRelationshipsTyped:endNodeHaving:value:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `outRelationshipsTyped:havingAll:endNodeWithLabels:havingAll:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `outRelationshipsTyped:where:` | same | a | none (covered) | empty `OrderedCollection` |
| FkGraphNode | `types` | → `relationships` | a | none (covered) | empty `Set` |

### (a) Pure reads: FkGraphRelationship via its db (FalkorSt-Objects)

| Class | Selector | Current call | Cls | Planned change | Expected result on missing graph |
|---|---|---|---|---|---|
| FkGraphRelationship | `startNode` | db `nodeAt:` | a | none (covered by `nodeAt:`) | `nil` |
| FkGraphRelationship | `endNode` | db `nodeAt:` | a | none (covered by `nodeAt:`) | `nil` |
| FkGraphRelationship | `otherNode` | → `startNode` / `endNode` (after the direction check) | a | none (covered) | `nil`; unknown origin still signals `FkGraphDbError unknownDirection` before any query |
| FkGraphRelationship | `ownNode` | → `startNode` / `endNode` (after the direction check) | a | none (covered) | `nil`; unknown origin still signals as above |

FkGraphPath only wraps already-decoded nodes and relationships (`nodes`, `relationships`) and sends
no queries, so it is not affected.

### Already read-only (reference only, unchanged)

`FkGraphDb>>countNodes`, `countNodesLabeled:`, `countRelationships`, `countRelationshipsTyped:`
(answer `0`); `allLabels`, `allRelationshipTypes`, `allPropertyKeys`, `orphanedNodes` (answer empty);
`FkGraphNode>>labelsFromDb` (signals `FkGraphDbError noSuchObject`, unchanged).

### (b) Writes: stay on GRAPH.QUERY

| Class | Selectors | Current call / Cypher | Cls | Planned change |
|---|---|---|---|---|
| FkGraphDb | `createNodeLabeled:`, `createNodeLabeled:properties:` | `runCypher:` CREATE … RETURN n | b | none |
| FkGraphDb | `createRelationshipTyped:fromNodeId:toNodeId:properties:`, `createInRelationshipTyped:...`, `createOutRelationshipTyped:...` | private `firstRelationshipFromCreatePathQuery:returning:` → `runCypher:` MATCH … CREATE … RETURN r | b | none |
| FkGraphDb | `deleteRelationshipAt:`, `deleteRelationshipsTyped:`, `deleteRelationshipsTyped:havingAll:`, `deleteRelationshipsTyped:where:`, `deleteAllRelationships` | `runCypher:` MATCH … DELETE r | b | none |
| FkGraphDb | `deleteNode:`, `deleteNodeAt:`, `deleteNodeAt:withRelations:`, `deleteNodesLabeled:havingAll:`, `deleteNodesLabeled:where:`, `deleteAllNodes`, `deleteAll` | `runCypher:` MATCH … DELETE n | b | none |
| FkGraphDb | `relationshipAt:propertyAt:put:`, `relationshipAt:properties:`, `relationshipAt:mergeProperties:`, `relationshipAt:removePropertyAt:` | `runCypher:` / `runCypher:arguments:` MATCH … SET / REMOVE | b | none |
| FkGraphDb | `nodeAt:propertyAt:put:`, `nodeAt:properties:`, `nodeAt:mergeProperties:`, `nodeAt:removePropertyAt:` | `runCypher:` / `runCypher:arguments:` MATCH … SET / REMOVE | b | none |
| FkGraphDb | `createIndexBy:`, `dropIndexBy:` | endpoint `graphIndexCreateWith:on:` / `graphIndexDropWith:on:` → `graphQuery:cypher:` CREATE/DROP INDEX | b | none |
| FkGraphObject | `delete`, `propertyAt:put:`, `at:put:`, `name:`, `properties:`, `mergeProperties:`, `removePropertyAt:` | `runCypher:` / `runCypher:arguments:` MATCH … DELETE / SET / REMOVE (then private `reload`, see c3) | b | none |
| FkGraphNode | `addLabel:`, `addLabels:`, `removeLabel:`, `removeLabels:` | private `changeLabels:using:` → `runCypher:` MATCH … SET n:L / REMOVE n:L | b | none |
| FkGraphNode | `deleteWithRelations`, `relateTo:typed:`, `relateTo:typed:properties:` | db `deleteNodeAt:withRelations:` / `createOutRelationshipTyped:...` | b | none |
| FkGraphEndpoint | `graphIndexCreateBy:on:`, `graphIndexCreateWith:on:`, `graphIndexDropBy:on:`, `graphIndexDropWith:on:` | `graphQuery:cypher:` CREATE/DROP INDEX | b | none |

## 3. Ambiguous items (c)

| # | Item | Reason | Decision |
|---|---|---|---|
| c1 | `FkGraphDb>>mergeNodeLabeled:`, `mergeNodeLabeled:properties:` | `MERGE (n:L {…}) RETURN n` is get-or-create. GRAPH.RO_QUERY rejects MERGE, and creating the graph is part of the intent. | **Leave as is** (GRAPH.QUERY). |
| c2 | `FkGraphDb>>mergeRelationshipTyped:…`, `mergeInRelationshipTyped:…`, `mergeOutRelationshipTyped:…`; `FkGraphNode>>relateOneTo:typed:`, `relateOneTo:typed:properties:` | MATCH both nodes, then MERGE the relationship. This is a conditional write: if a node is missing, MATCH finds nothing and nothing is merged. It still contains MERGE, which RO_QUERY rejects. | **Leave as is** (GRAPH.QUERY). |
| c3 | `FkGraphObject>>reload` (private) | A pure read (`MATCH … RETURN n` via `runCypher:`), but it is only called right after a GRAPH.QUERY write on the same object (`propertyAt:put:`, `changeProperties:using:`, `FkGraphNode>>changeLabels:using:`). That write has already created the graph, so switching to RO would not change any observable behaviour. Its zero-record handling (`oneValueIfNone:` → `FkGraphDbError noSuchObject`) would stay the same either way. | **Leave as is** (out of scope; no public read reaches it alone). |
| c4 | General-purpose entry points: `FkGraphDb>>runCypher:*`, `callProcedure:*`; `FkGraphEndpoint>>graphQuery:cypher:*`, `graphCallProcedure:procedure:`, `graphCallProcedure:procedure:arguments:` | These are raw APIs: the caller picks the command and their read-only counterparts already exist. `graphCallProcedure:procedure:` loses its last internal callers (`graphIndexes:`/`graphConstraints:`) but stays public and is tested directly (`FkGraphEndpointProcedureCallTest` line 74). | **Leave as is.** |
| c5 | MATCH-based writes in (b) (e.g. `deleteAll`, `deleteNodesLabeled:where:`, `nodeAt:propertyAt:put:`) on a missing graph | They match nothing, but GRAPH.QUERY still creates an empty graph as a side effect. | **Leave as is**: these are writes, and avoiding the side effect would need an `exists` pre-check on every write, which is out of scope. |
| c6 | `FkGraphEndpoint>>refreshCache:graph:procedure:` (private, compact id-cache refresh) | Sends `CALL db.labels()` etc. via `rawGraphQuery:cypher:compact:` (GRAPH.QUERY). It only runs while decoding a reply that has already succeeded, so the graph exists and cannot be created by it. Not one of the audited selectors. | **Leave as is**; noted for a possible future read-replica concern. |
| c7 | `FalkorSt-Udf` (`FkGraphEndpoint.extension.st`: `graphUdfLoad:*`, `graphUdfList*`, `graphUdfDelete:`, `graphUdfFlush`) | Uses server-wide `GRAPH.UDF …` via `unifiedCommand:`, not graph keys. There are no audited call sites; UDF loading does not touch a graph. | **Nothing to change.** |
| c8 | Not audited but adjacent: `FkGraphDb>>createConstraintBy:`/`dropConstraintBy:` (GRAPH.CONSTRAINT), `explain:*` (GRAPH.EXPLAIN), `profile:*` (GRAPH.PROFILE, which executes the query), diagnostics | They use other commands, outside the selector set of this audit. | **Leave as is**; out of scope. |

## 4. Planned new tests

All of these are integration tests against a real FalkorDB. Each test's graph is named
`<TestClass>_<selector>` and does not exist at test start; `FkGraphEndpointTestCase>>tearDown`
deletes it if it was created. Every "missing graph" test asserts `self deny: db exists` (or
`graphList excludes`) **both before and after** the reads, which proves they no longer create the
graph.

| Test class | Selector | Asserts |
|---|---|---|
| FkGraphIndexInfoTest *(new, FalkorSt-Core-Tests, pure unit)* | `testAllFromQueryResultMapsEachRecord` | `allFromQueryResult:` on an FkQueryResult with a header and two records answers two FkGraphIndexInfo whose `label` comes from the mapped record. |
| FkGraphIndexInfoTest | `testAllFromQueryResultOnEmptyResultAnswersEmpty` | `allFromQueryResult: (FkQueryResult new setHeader: #() records: #() statistics: #())` is empty. |
| FkGraphConstraintInfoTest *(new, FalkorSt-Core-Tests, pure unit)* | `testAllFromQueryResultMapsEachRecord` / `testAllFromQueryResultOnEmptyResultAnswersEmpty` | Same as above for FkGraphConstraintInfo. |
| FkGraphEndpointTest | `testGraphIndexesOnAMissingGraphSignalsWithoutCreatingIt` | `self should: [ endpoint graphIndexes: graphName ] raise: RsGenericError`; afterwards `endpoint graphList` does not include graphName. |
| FkGraphEndpointTest | `testGraphConstraintsOnAMissingGraphSignalsWithoutCreatingIt` | Same for `graphConstraints:`. |
| FkGraphDbTest | `testIndexesAndConstraintsOnAGraphThatDoesNotExistYetAnswerEmptyWithoutCreatingIt` | `deny: db exists`; `db indexes isEmpty`; `db constraints isEmpty`; `deny: db exists`. (Existing `testCreateIndexByListsTheIndex` / `testCreateConstraintByListsTheConstraint` still cover the non-empty path.) |
| FkGraphDbTest | `testNodeReadsOnAGraphThatDoesNotExistYetAnswerNilOrEmptyWithoutCreatingIt` | `deny: db exists`; `(db nodeAt: 1) isNil` (id 1, not 0; see section 5); `nodesLabeled: 'Person'`, `nodesLabeled:having:value:`, `nodesLabeled:havingAll:`, `nodesLabeled:where:`, `nodesLabeled:where:skip:limit:`, `nodesLabeled:where:orderBy:skip:limit:` are all empty; `deny: db exists`. |
| FkGraphDbTest | `testRelationshipReadsOnAGraphThatDoesNotExistYetAnswerNilOrEmptyWithoutCreatingIt` | `deny: db exists`; `(db relationshipAt: 1) isNil`; `relationshipsTyped:`, `relationshipsTyped:having:value:`, `relationshipsTyped:havingAll:`, `relationshipsTyped:where:`, `relationshipsTyped:where:orderBy:skip:limit:` are all empty; `deny: db exists`. |
| FkGraphDbTest | `testOneHopPathReadsOnAGraphThatDoesNotExistYetAnswerEmptyOrFalseWithoutCreatingIt` | `deny: db exists`; `oneHopPathsTyped:direction:from: 1 havingAll:endNodeWithLabels:havingAll:whereIn:returning:` is empty (it delegates to the `returnIn:returning:` variant); `existsOneHopPathsTyped:direction:from: 1 whereIn:` answers `false` (it delegates to the full variant); `deny: db exists`. |
| FkGraphNodeTest | `testReadsOnANodeOfADroppedGraphAnswerEmptyWithoutRecreatingIt` | Via the `createAliceOfADroppedGraphIn:` helper: create a node, then `db drop`, and `deny: db exists`. On the stale node: `relationships`, `inRelationships`, `outRelationships`, `relationshipsTyped: 'KNOWS'`, `oneHopPathsTyped:where:`, `inOneHopPathsTyped:where:`, `outOneHopPathsTyped:where:` are empty; `types isEmpty`. Finally `deny: db exists`. |
| FkGraphNodeTest | `testExistsChecksOnANodeOfADroppedGraphAnswerFalseWithoutRecreatingIt` | Same setup. `existsRelationshipTyped:`, `existsInRelationshipTyped:`, `existsOutRelationshipTyped:` are `false`. Finally `deny: db exists`. |
| FkGraphRelationshipTest | `testNodeNavigationOnARelationshipOfADroppedGraphAnswersNilWithoutRecreatingIt` | Create two nodes and an outgoing KNOWS relationship (`createAliceKnowsBobIn:`). Fetch the relationship via `node outRelationships first` so the navigation origin is known. `db drop`; then `startNode`, `endNode`, `otherNode`, `ownNode` are all `nil`; `deny: db exists`. |

Existing regression coverage that must keep passing unchanged:
- `FkGraphDbTest>>testReadsOnAGraphThatDoesNotExistYetAnswerEmptyResults`
- `FkGraphDbTest>>testReadOnlyQueryErrorsOtherThanAMissingGraphStillSignal`
- every FkGraphEndpointTest index and constraint listing test
- `FkGraphEndpointProcedureCallTest`
- the FkGraphNodeTest and FkGraphRelationshipTest navigation tests on existing graphs

## 5. Phase 2 corrections

Found during implementation:

- **Do not use id 0 in missing-graph tests.** On a freshly created empty graph, FalkorDB answers a
  phantom node for `MATCH (n) WHERE id(n) = 0 RETURN n` (`count(n)` is 0; ids 1..100000 answer
  nothing). Before this change, `db nodeAt: 0` on a missing graph therefore created the graph *and*
  answered a non-nil FkGraphNode, so section 2's "Expected result" for the pre-change behaviour was
  not quite right. The same applies to a stale FkGraphRelationship whose start node had id 0:
  `startNode` answered that phantom node. After the change, a missing graph gives no records, so
  the answer is `nil` for any id. The new FkGraphDb tests use id 1 so they test the read-only path
  rather than this server quirk.
- **Long tests split or shortened.** The linter warns when a method is longer than 15 lines. The
  FkGraphNodeTest stale-node test is split into a collection-read test and an exists-check test,
  which share `createAliceOfADroppedGraphIn:`. The FkGraphDbTest node-read test binds its WHERE
  block to a temp.
- **One-hop test trimmed.** The planned four-call test exceeded the linter's method-length limit.
  `oneHopPathsTyped:...returning:` delegates to `...returnIn:returning:`, and
  `existsOneHopPathsTyped:direction:from:whereIn:` delegates to the full variant, so one call per
  family covers all four selectors.
- **RED for FkGraphNode / FkGraphRelationship tests.** These need no code change of their own (the
  FkGraphDb change covers them). They were confirmed red by temporarily restoring `runCypher:` in
  `nodeAt:` and `oneHopPathsQueryResultFor:...`, then confirmed green after restoring
  `runReadOnlyCypher:`.
