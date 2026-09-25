# Feature: FkGraphDb パス存在確認/returnIn拡張 + FkGraphNode リレーションシップナビゲーション

## Goal

Kanban issue 1789908020189（FkGraphDb: パス存在確認・returnIn付き探索バリアント）と
1789908034289（FkGraphNode: リレーションシップナビゲーションAPI）の両方が実装される。
`FkGraphDb` に `existsOneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:` /
`existsOneHopPathsTyped:direction:from:whereIn:` / `oneHopPathsTyped:...whereIn:returnIn:returning:` が
追加され、それらの上に構築された `FkGraphNode` のリレーションシップ取得・存在確認・一ホップパス探索・
relateTo系の便利メソッド一式が追加される。既存の全テストを壊さず、新規テストが追加されて全テストが
パスする。st-lintのスタイルガイドに沿っている。

## Orchestration Shape

sequential: Part1 implement (TDD) → Part2 implement (TDD) → full test-suite verification → lint & review,
all via claude

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Part 1: FkGraphDb path existence checks + returnIn-customizable one-hop queries (TDD)'.
            t prompt: 'Work on branch feature/fkgraph-path-exists-and-node-relationship-navigation (already checked out in this working directory) of the Falkor.st Pharo project.

Use the smalltalk-dev plugin skills (st-init, st-import, st-test, st-lint, st-eval) for the Edit -> Import -> Test cycle, per this project''s CLAUDE.md. Consult the smalltalk-developer skill''s style guide section while editing Tonel files.

Goal: add path-existence-check and returnIn-customizable one-hop path query support to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st), mirroring the existing oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning: method already in that file (see docs/scripting-features/feature-fkgraphdb-path-traversal-query.scripting.md for the established pattern/style this codebase already follows) and Neo4reSt-GraphModel''s N4GraphDb (../Neo4reSt/src/Neo4reSt-GraphModel/N4GraphDb.class.st, category ''actions-paths'') as the reference for behavior.

## 1. New methods on FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st)

a) `FkGraphDb >> existsOneHopPathsTyped: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder`

Answers true/false for whether at least one matching one-hop path exists, WITHOUT building any FkGraphPath wrapper (there is nothing to wrap for an existence check). Build the query via SCypher''s `CyQuery class >> matchPathWithRelationshipsOfTypes:havingAll:fromNodeAt:endNodeIn:pathIn:whereIn:pathProcessIn:returnIn:` (see ../SCypher/repository/SCypher-Core/CyQuery.class.st for its exact signature) using `pathProcessIn: [:path | path count > 0]` and `returnIn: [:r | r]` -- this mirrors N4GraphDb>>existsOneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn: exactly. Use the SAME direction-block selection logic already used by the existing oneHopPathsTyped:... method in this file: `#in` -> `[ :startNode :rel :endNode | startNode <- rel - endNode ]`, `#out` -> `[ :startNode :rel :endNode | startNode - rel -> endNode ]`, anything else (undirected) -> `[ :startNode :rel :endNode | startNode - rel - endNode ]`. Run the built query via `self runCypher:` and answer the first row''s first value as a Boolean.

b) `FkGraphDb >> existsOneHopPathsTyped: typeOrTypes direction: direction from: startNodeId whereIn: whereClauseBuilder`

Convenience overload calling (a) with empty relProps/labels/endNodeProps (`#()` each), mirroring N4GraphDb''s overload of the same name.

c) `FkGraphDb >> oneHopPathsTyped: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder returnIn: returnBlock returning: returner`

Extends the existing oneHopPathsTyped:...returning: method with a returnIn: parameter: like the existing method, but passes `returnIn: returnBlock` through to CyQuery''s matchPathWithRelationshipsOfTypes:...whereIn:returnIn: instead of the default (nil, meaning "return the whole path p"), so callers can narrow which columns the underlying Cypher RETURNs. The `returner` block still receives the already-wrapped per-record result the same way the existing method does -- wrap whatever the record''s first value actually is into the appropriate Fk* type (if returnBlock narrows the return to just the path, wrap it as FkGraphPath as today; if the caller''s returnBlock narrows to something else, the wrapping must match what is actually returned -- keep this simple and correct rather than trying to handle every possible shape generically). Document clearly in the method comment and in the class comment that `returnBlock` controls the underlying Cypher RETURN clause shape, so the caller-supplied `returner` must match what `returnBlock` actually returns.

Keep the EXISTING 6-keyword `oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning:` method as a thin wrapper that delegates to this new one with `returnIn: nil`, so the query-building logic is not duplicated. Do not change its existing behavior or signature.

Update FkGraphDb.class.st''s class comment (the "Public API and Key Messages" and "Implementation Points" sections) to document these three new methods, following the existing bullet style already used there for the path/traversal methods.

## 2. Tests (TDD -- write these first, then make them pass)

Add integration tests to src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st (same style/category as existing tests in that file -- it runs against a real FalkorDB instance, not a mock) covering:
- existsOneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn: returns true when a matching path exists and false when it does not (cover at least the #out direction, and one case using a whereIn: filter that excludes the match).
- existsOneHopPathsTyped:direction:from:whereIn: convenience overload behaves the same as the full version with empty filters.
- oneHopPathsTyped:...whereIn:returnIn:returning: with a returnIn: block that narrows the Cypher RETURN to just the end node (or a specific property), proving the returned records reflect the narrowed shape and that the returner block''s wrapping still works correctly.
- The existing oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning: tests (already in this file) still pass unmodified -- this confirms the thin-wrapper refactor did not change its behavior.

If new fixture nodes/relationships are needed for these tests, follow the existing setUp/tearDown and fixture-creation helper patterns already in this class (e.g. however the earlier path/traversal tests or relationship-CRUD tests set up their fixtures).

Run tests after each change via the st-test skill / MCP tools, importing changed packages first via st-import. Do not stop until FkGraphDbTest passes and the pre-existing tests across FalkorSt-Objects-Tests still pass (i.e. no regressions).' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Part 2: FkGraphNode relationship navigation API (TDD)'.
            t prompt: 'Work on branch feature/fkgraph-path-exists-and-node-relationship-navigation (already checked out in this working directory) of the Falkor.st Pharo project. This step follows the Part 1 topic above, which added existsOneHopPathsTyped:... and oneHopPathsTyped:...returnIn:returning: to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st) -- confirm those methods exist and FkGraphDbTest passes before building on top of them; if Part 1''s work is missing or broken, fix it first.

Use the smalltalk-dev plugin skills (st-init, st-import, st-test, st-lint, st-eval) for the Edit -> Import -> Test cycle, per this project''s CLAUDE.md. Consult the smalltalk-developer skill''s style guide section while editing Tonel files.

Goal: add relationship-navigation API to FkGraphNode (src/FalkorSt-Objects/FkGraphNode.class.st), mirroring Neo4reSt-GraphModel''s N4Node (../Neo4reSt/src/Neo4reSt-GraphModel/N4Node.class.st, categories ''accessing-relationships*'' / ''accessing-paths'' / ''relationships'') for behavior, but built ONLY on top of FkGraphDb''s existing `oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning:` (direction nil/#in/#out) for fetching and the Part-1 `existsOneHopPathsTyped:...` methods for existence checks -- do not re-derive Cypher directly in FkGraphNode. This is the highest-priority gap in Falkor.st''s high-level object API: fetching related nodes/relationships from a node instance currently does not exist at all.

FkGraphNode already has `self id` and `self db` available via its superclass FkGraphObject (src/FalkorSt-Objects/FkGraphObject.class.st) -- use those as the startNodeId/db arguments into FkGraphDb''s methods, the same way N4Node passes `self id` and uses `self db` when calling into N4GraphDb.

## 1. Relationship fetching

- `relationships` -> `self relationshipsTyped: {}`
- `relationshipsTyped: typeOrTypes` -> `self relationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: {}`
- `relationshipsTyped: typeOrTypes having: key value: value` -> `self relationshipsTyped: typeOrTypes havingAll: {key -> value} endNodeWithLabels: {} havingAll: {}`
- `relationshipsTyped: typeOrTypes endNodeHaving: key value: value` -> `self relationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: {key -> value}`
- `relationshipsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps` -> calls `self db oneHopPathsTyped: typeOrTypes direction: nil from: self id havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: [:start :rel :end |] returning: [:path | path relationships]`, then flattens the resulting collection-of-collections into one single OrderedCollection of FkGraphRelationship (each FkGraphPath already wraps its relationships as FkGraphRelationship via FkGraphPath>>#relationships, so no re-wrapping is needed here -- just flatten)
- `relationshipsTyped: typeOrTypes where: whereClauseBuilder` -> same shape but passes `whereClauseBuilder` straight through as the `whereIn:` block instead of an empty one
- Mirror the same 6 methods for direction #in as `inRelationships` / `inRelationshipsTyped:` / `inRelationshipsTyped:having:key:value:` / `inRelationshipsTyped:endNodeHaving:key:value:` / `inRelationshipsTyped:havingAll:endNodeWithLabels:havingAll:` / `inRelationshipsTyped:where:` (passing `direction: #in` instead of `nil`), and direction #out as the same 6 methods prefixed `out` (passing `direction: #out`)
- `types` -> `(self relationships collect: [:each | each type]) asSet`

## 2. Existence checks

- `existsRelationshipTyped: typeOrTypes` -> `self db existsOneHopPathsTyped: typeOrTypes direction: nil from: self id whereIn: [:start :rel :end |]`
- `existsRelationshipTyped: typeOrTypes having: key value: value` -> same but with a whereIn: block that filters on the relationship''s property. Before writing this, check how the existing FkGraphDb where-clause blocks build property-equality filters elsewhere in this codebase (e.g. `nodesLabeled:havingAll:`/`havingAll:` block-building in FkGraphDb, and how CyIdentifier''s `@`/property-access operator is used in FkGraphObject and FkGraphNode/FkGraphRelationship already) and use the exact same SCypher API/operator style here rather than assuming N4Node''s Neo4j-era selector names (like `prop:`) carry over directly -- verify against ../SCypher''s actual CyIdentifier/CyRelationship class API in this repo''s checkout.
- `existsRelationshipTyped: typeOrTypes endNodeHaving: key value: value` -> same idea, but the property-equality filter is built against the end-node identifier instead of the relationship identifier.
- Mirror all three for `existsInRelationshipTyped:...` (passing `direction: #in`) and `existsOutRelationshipTyped:...` (passing `direction: #out`).

## 3. One-hop path fetching (lower-level, for callers who want the full path, not just endpoints/relationships)

- `oneHopPathsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps` -> `self db oneHopPathsTyped: typeOrTypes direction: nil from: self id havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: [:start :rel :end |] returning: [:path | path]`
- `oneHopPathsTyped: typeOrTypes where: whereClauseBuilder` -> same but with `whereIn: whereClauseBuilder` and empty relProps/labels/endNodeProps
- Mirror both for `inOneHopPathsTyped:...` (direction #in) and `outOneHopPathsTyped:...` (direction #out)

## 4. Relationship creation convenience

- `relateTo: otherNode typed: typeName` -> `self relateTo: otherNode typed: typeName properties: #()`
- `relateTo: otherNode typed: type properties: propertiesArray` -> `self db createOutRelationshipTyped: type fromNodeId: self id toNodeId: otherNode id properties: propertiesArray` (CREATE; reuses FkGraphDb''s existing method, answers an FkGraphRelationship)
- `relateOneTo: otherNode typed: typeName` -> `self relateOneTo: otherNode typed: typeName properties: #()`
- `relateOneTo: otherNode typed: type properties: propertiesArray` -> `self db mergeOutRelationshipTyped: type fromNodeId: self id toNodeId: otherNode id properties: propertiesArray` (MERGE; reuses FkGraphDb''s existing method, answers an FkGraphRelationship or nil)

Update FkGraphNode.class.st''s class comment (Responsibility / Public API and Key Messages sections) to document all of the above, following the exact CRC-comment style already used in that file (and in FkGraphObject.class.st / FkGraphRelationship.class.st for reference).

## 5. Tests (TDD -- write these first, then make them pass)

Add integration tests to src/FalkorSt-Objects-Tests/FkGraphNodeTest.class.st (same style as existing tests in that file -- check what fixture pattern that file and FkGraphDbTest already use for creating nodes/relationships, and reuse the same approach) covering:
- relationships / relationshipsTyped: / inRelationshipsTyped: / outRelationshipsTyped: return the expected FkGraphRelationship(s) for a small fixture graph with at least one out-relationship and one in-relationship on the same node, using two distinct relationship types.
- relationshipsTyped:having:key:value: and relationshipsTyped:endNodeHaving:key:value: filter correctly (matching case returns the relationship, non-matching value returns empty).
- existsRelationshipTyped: / existsOutRelationshipTyped: / existsInRelationshipTyped: return true for a type that exists on the fixture node and false for a type that does not.
- oneHopPathsTyped: / outOneHopPathsTyped: / inOneHopPathsTyped: return FkGraphPath(s) with the correct startNode/endNode/relationships.
- relateTo:typed: (CREATE) and relateOneTo:typed: (MERGE) both create a relationship that becomes reachable afterward via relationshipsTyped:; running relateOneTo:typed: a second time with the same arguments does not create a duplicate relationship (MERGE semantics), while relateTo:typed: run twice does create two.
- types answers the correct Set of relationship type strings for a node with multiple distinct outgoing/incoming relationship types.

Run tests after each change via the st-test skill / MCP tools, importing changed packages first via st-import. Do not stop until FkGraphNodeTest passes and the pre-existing tests across FalkorSt-Objects-Tests still pass (i.e. no regressions).' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Verify full test suite'.
            t prompt: 'In this same Falkor.st working directory, on branch feature/fkgraph-path-exists-and-node-relationship-navigation, re-import every locally-managed package (FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests, in dependency order per the BaselineOf) via the st-import skill, then run the full test suite via the st-test skill for FalkorSt-Core-Tests and FalkorSt-Objects-Tests. Report the exact pass/fail counts for each package. If anything fails, fix it (referring back to the previous two topics'' implementations, i.e. the FkGraphDb existsOneHopPathsTyped:.../returnIn: additions and the FkGraphNode relationship-navigation additions) and re-run until everything passes. Do not consider this step done until both test packages report zero failures and zero errors.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and style review'.
            t prompt: 'In this same Falkor.st working directory, on branch feature/fkgraph-path-exists-and-node-relationship-navigation, run the st-lint skill (or the smalltalk-validator MCP tools directly) against every Tonel file changed or added for this feature: src/FalkorSt-Objects/FkGraphDb.class.st, src/FalkorSt-Objects/FkGraphNode.class.st, src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st, src/FalkorSt-Objects-Tests/FkGraphNodeTest.class.st.

Also consult the smalltalk-developer skill''s style guide section and review the new/changed code against it directly (naming, method categorization, class comment format, Tonel structure).

Fix every finding you make (do not just report them), then re-import the affected packages via st-import and re-run the full test suite via st-test to confirm nothing regressed after your fixes. Report a final summary: what was fixed, and confirmation that all tests still pass.' ]
    } agentBy: [ :a | a claude ] ].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result ]
    onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval. `forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately — watch for the completion block's own report (e.g. via Transcript), the `onTimeout:` block's report if a step stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration script id>`.
