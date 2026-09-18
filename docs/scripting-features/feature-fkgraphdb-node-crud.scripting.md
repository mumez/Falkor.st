# Feature: FkGraphDb ノードCRUD操作の追加

## Goal

`FkGraphDb` (src/FalkorSt-Objects/FkGraphDb.class.st) に、SCypherGraph の `SgGraphDb`
(../SCypherGraph/src/SCypherGraph-Core/SgGraphDb.class.st、actions-nodes カテゴリ) を参考にした
ノードCRUD操作一式を追加する。結果はすべて既存の `FkGraphNode` (`FkGraphObject` サブクラス) で
ラップして返し、既存の `FkGraphObject`(`#delete`/`#propertyAt:put:`/`#reload`) と重複しない形で
実装する。各メソッドは実FalkorDBインスタンスに対する統合テストで検証済みであること。

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement FkGraphDb node CRUD operations (TDD)'.
            t prompt: 'This is a Pharo/Tonel project (FalkorDB client, class prefix Fk). You are on git branch feature/fkgraphdb-node-crud in this working directory. Add a set of node-CRUD convenience methods to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st), following the TDD cycle (write a failing SUnit test first, then implement, then verify green, for each method or small group of closely related methods before moving to the next). Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill (in particular its style guide section) for Tonel editing conventions (method categories, CRC-style class comments, naming).

Read these existing files first to understand the conventions and collaborators you must build on:
- src/FalkorSt-Objects/FkGraphDb.class.st (the class you are extending: holds #stick/#settings/#name, has #runCypher: and #runReadOnlyCypher: wrappers around #endpoint graphQuery:cypher:/graphRoQuery:cypher:)
- src/FalkorSt-Objects/FkGraphObject.class.st (superclass of FkGraphNode; already implements #delete, #propertyAt:put:, #reload generically via #matchElementNamed: — a CyNode/CyRelationship pattern element supplied by the subclass; also has a private #cypherStringFor: that sets `aCyQuery delimiter: '' ''` before calling #cypherString, because FalkorDB''s Cypher parser rejects CyQuery''s default bare-CR delimiter between clauses)
- src/FalkorSt-Objects/FkGraphNode.class.st (wraps a raw FkNode plus the FkGraphDb it came from; `FkGraphNode on: rawNode in: aFkGraphDb` is how you construct one)
- ../SCypherGraph/src/SCypherGraph-Core/SgGraphDb.class.st, actions-nodes category (createNodeLabeled:/createNodeLabeled:properties:, mergeNodeLabeled:/mergeNodeLabeled:properties:, nodeAt:, nodeAt:mergeProperties:, nodeAt:properties:, nodeAt:propertyAt:put:, nodesLabeled:/nodesLabeled:havingAll:/nodesLabeled:where: with orderBy/skip/limit variants, deleteNode:, deleteNodeAt:, deleteNodesLabeled:havingAll:/where:) — this is the reference implementation for the Cypher-building patterns (CyNode/CyQuery/CyCreate/CyMerge/CyReturn) and argument shapes. Follow its query-building approach faithfully, but adapt the *result handling*: SgGraphDb wraps raw records via #objectFromCypherResult:, whereas in this project you must wrap each raw decoded node (an FkNode, found via `result records first first` or similar, matching how FkGraphObject>>reload already extracts a raw node from a query result) into an FkGraphNode via `FkGraphNode on: rawNode in: self`.

Implement exactly these methods on FkGraphDb (method category e.g. ''actions-nodes''), each delegating Cypher construction to SCypher''s CyNode/CyQuery builders (mirroring SgGraphDb''s corresponding method) and each returning FkGraphNode instances (not raw FkNode / not raw query results) for the ones that answer nodes:
1. #createNodeLabeled: labelOrLabels — CREATE a node with the given label(s) and no properties, return it wrapped as FkGraphNode.
2. #createNodeLabeled:properties: labelOrLabels props — same but with properties (props is an Array of key/value pairs the way SgGraphDb''s createNodeLabeled:properties: expects — check CyNode''s expected props argument shape by reading SCypher''s CyNode class if unclear).
3. #mergeNodeLabeled: labelOrLabels — MERGE (create-if-absent) a node with the given label(s), return it wrapped as FkGraphNode.
4. #mergeNodeLabeled:properties: labelOrLabels props — same but with properties.
5. #nodeAt: systemId — MATCH a node by its internal FalkorDB id, return it wrapped as FkGraphNode, or nil if not found (mirror SgGraphDb''s nodeAt:, which returns nil via #firstOrNilOf: when the result is empty — do NOT signal FkGraphDbError here, that is reload''s job, not a plain lookup''s).
6. #nodesLabeled: labelOrLabels — MATCH all nodes with the given label(s), return an OrderedCollection (or similar) of FkGraphNode.
7. #nodesLabeled:havingAll: labelOrLabels assocArray — same but filtered to nodes having all the given property key/value pairs (mirror SgGraphDb''s havingAll: helper, which builds a where-block from the association array).
8. #nodesLabeled:where: labelOrLabels whereClauseBuilder — same but filtered via an arbitrary one-argument where-clause block (block receives the CyNode/identifier the way SgGraphDb''s does), returning matching nodes as FkGraphNode.
9. #nodesLabeled:where:orderBy:skip:limit: and #nodesLabeled:where:skip:limit: — orderBy/skip/limit variants mirroring SgGraphDb''s corresponding methods (same signatures, same semantics: orderBy is optional in the "no orderBy" variant).
10. #nodeAt:propertyAt:put: systemId key value — SET a single property by id (mirror SgGraphDb''s nodeAt:propertyAt:put:, using a MATCH...WHERE id(...)=... SET pattern); this is a plain "find by id, set one property" operation distinct from a wrapped FkGraphNode''s own #propertyAt:put: (which operates on an object you already hold) — implement it as its own MATCH/SET query on FkGraphDb, do not just look up the node and delegate to FkGraphObject>>propertyAt:put: (that would cost an extra round trip and isn''t what SgGraphDb''s reference method does). Answer whatever SgGraphDb''s equivalent answers (the query''s status/result) — look at #statusOfTransactCypher: in SgGraphDb for the reference return shape, but express it using this project''s #runCypher: (there is no separate transact/run split here — GRAPH.QUERY covers both reads and writes in FkGraphDb).
11. #nodeAt:properties: systemId argsDict — SET (replace) the node''s full property map by id, same MATCH/SET pattern as above but replacing all properties rather than merging.
12. #nodeAt:mergeProperties: systemId argsDict — SET the node''s properties by id using Cypher''s `+=` merge-assign form (mirror SgGraphDb''s nodeAt:mergeProperties:, which uses `n.addAll:` — find CyNode''s equivalent merge-assign builder method).
13. #deleteNodeAt: systemId — MATCH a node by id and DELETE it (mirror SgGraphDb''s deleteNodeAt:).
14. #deleteNode: aFkGraphNode — convenience that deletes by the given FkGraphNode''s id (delegates to #deleteNodeAt: with the node''s #id — do not duplicate the MATCH/DELETE Cypher).
15. #deleteNodesLabeled:havingAll: labelOrLabels assocArray and #deleteNodesLabeled:where: labelOrLabels whereClauseBuilder — bulk delete matching nodes by label plus a property-equality filter or an arbitrary where-clause block (mirror SgGraphDb''s deleteNodesLabeled:havingAll:/where:).

Every CyQuery you build in these methods must have its delimiter set to '' '' before calling #cypherString, exactly like FkGraphObject>>cypherStringFor: already does (this exists because FalkorDB''s Cypher parser rejects CyQuery''s default bare-CR delimiter between clauses). Rather than adding a second copy of this helper on FkGraphDb, MOVE #cypherStringFor: from FkGraphObject to FkGraphDb (it belongs on the class that owns #runCypher:/#runReadOnlyCypher: and is a more natural place for every caller — including FkGraphObject itself — to reach it from): delete the private method from FkGraphObject.class.st and add the same method (same body) to FkGraphDb.class.st in an appropriate category (e.g. private). Then update every existing call site in FkGraphObject (#delete, #propertyAt:put:, #reload) from `self cypherStringFor: query` to `self db cypherStringFor: query`, and use `self cypherStringFor: query` (now a local private method) from the new FkGraphDb node-CRUD methods you are adding. Re-run the existing FkGraphObject/FkGraphNode tests after this move to confirm nothing regressed.

Do not otherwise modify FkGraphObject, FkGraphNode''s existing methods, FkGraphEndpoint, or any GRAPH.QUERY decoding logic — scope is strictly the new methods listed above on FkGraphDb, the cypherStringFor: move described above, plus their tests. Update FkGraphDb''s class comment (Public API and Key Messages section) to list the new methods and the newly-owned #cypherStringFor: helper, and update FkGraphObject''s class comment to drop the now-removed helper from its own description — extend/adjust the existing comments rather than rewriting them wholesale.

Testing: add tests to a test class for these methods — check whether FkGraphDbTest (src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st, superclass FkGraphEndpointTestCase, which runs against a real FalkorDB instance and provides `self graphName` / `stick`) is the right home, and follow its existing pattern (`FkGraphDb on: stick named: self graphName`) for constructing the FkGraphDb under test. Cover at least: createNodeLabeled: and createNodeLabeled:properties: (assert the returned FkGraphNode has the right labels/properties), mergeNodeLabeled: idempotency (merging twice does not create a duplicate node), nodeAt: found and not-found (nil) cases, nodesLabeled: / nodesLabeled:havingAll: / nodesLabeled:where: returning the expected matching nodes, at least one orderBy/skip/limit variant behaving correctly with several nodes, nodeAt:propertyAt:put: / nodeAt:properties: / nodeAt:mergeProperties: each correctly mutating a node''s properties as read back via a fresh nodeAt:, deleteNodeAt: and deleteNode: removing the node (verify via a subsequent nodeAt: returning nil), and deleteNodesLabeled:havingAll:/where: removing exactly the matching nodes and leaving others. Each test must clean up any nodes/labels it creates (e.g. delete them at the end, or use a per-test unique label) so tests do not interfere with each other or leave state behind, following whatever cleanup convention FkGraphEndpointTestCase / FkGraphDbTest already establishes.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, and FalkorSt-Objects-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in FalkorSt-Objects-Tests (including the new FkGraphDb node-CRUD tests added in the previous step) as well as FalkorSt-Core-Tests, to confirm no regressions. Report the exact pass/fail/error counts per package and the names of any failing tests. If any test fails, fix the implementation or test and re-run until both packages fully pass, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the FkGraphDb node-CRUD feature (the modified FkGraphDb.class.st and the modified/added test file(s)). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format, CRC-style comments). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
    } agentBy: [ :a | a claude ]
].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result ]
    onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval.
`forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately — watch
for the completion block's own report (e.g. via Transcript), the `onTimeout:` block's report if a
step stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration script id>`.
