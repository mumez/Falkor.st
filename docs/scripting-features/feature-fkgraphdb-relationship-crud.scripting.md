# Feature: FkGraphDb リレーションシップCRUD操作の追加

## Goal

`FkGraphDb` (src/FalkorSt-Objects/FkGraphDb.class.st) に、SCypherGraph の `SgGraphDb`
(../SCypherGraph/src/SCypherGraph-Core/SgGraphDb.class.st、actions-relationships カテゴリ) を参考にした
リレーションシップCRUD操作一式を追加する。新設する `FkGraphRelationship`（`FkGraphObject` サブクラス、
`FkGraphNode` の姉妹クラス）でラップして返し、既存の `FkGraphObject`(`#delete`/`#propertyAt:put:`/
`#reload`) と重複しない形で実装する。各メソッドは実FalkorDBインスタンスに対する統合テストで検証済み
であること。

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
            t title: 'Implement FkGraphDb relationship CRUD operations (TDD)'.
            t prompt: 'This is a Pharo/Tonel project (FalkorDB client, class prefix Fk). You are on git branch feature/fkgraphdb-relationship-crud in this working directory. Add a set of relationship-CRUD convenience methods to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st), plus a new FkGraphRelationship class, following the TDD cycle (write a failing SUnit test first, then implement, then verify green, for each method or small group of closely related methods before moving to the next). Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill (in particular its style guide section) for Tonel editing conventions (method categories, CRC-style class comments, naming).

Read these existing files first to understand the conventions and collaborators you must build on:
- src/FalkorSt-Objects/FkGraphDb.class.st (the class you are extending: holds #stick/#settings/#name, has #runCypher:/#runCypher:arguments: and #runReadOnlyCypher:/#runReadOnlyCypher:arguments: wrappers, owns the private #cypherStringFor: helper, and already implements node-CRUD methods such as #nodeAt:, #nodeAt:propertyAt:put:, #nodeAt:properties:, #nodeAt:mergeProperties:, #deleteNodeAt: — the new relationship methods should follow exactly the same conventions for parameter binding via #valuesArgumentsFor: and for answering `result statistics`)
- src/FalkorSt-Objects/FkGraphObject.class.st (superclass of FkGraphNode and the new FkGraphRelationship; already implements #delete, #propertyAt:put:, #reload generically via #matchElementNamed: — a CyNode/CyRelationship pattern element supplied by the subclass. Do not modify this file; the new FkGraphRelationship only needs to supply #matchElementNamed:.)
- src/FalkorSt-Objects/FkGraphNode.class.st (the sibling class to model FkGraphRelationship on: wraps a raw FkNode plus the FkGraphDb it came from, delegates #labels, supplies #matchElementNamed: as `CyNode name: anIdentifier`)
- src/FalkorSt-Core/FkRelationship.class.st (the raw decoded relationship value to wrap: has #id/#type/#startNodeId/#endNodeId/#properties)
- src/FalkorSt-Core/FkPath.class.st (has #nodes/#relationships — needed because the create/merge relationship queries below return a path, not the relationship directly; see point 12)
- ../SCypherGraph/src/SCypherGraph-Core/SgGraphDb.class.st, actions-relationships category (createRelationshipTyped:fromNodeId:toNodeId:properties:, createInRelationshipTyped:.../createOutRelationshipTyped:..., mergeRelationshipTyped:.../mergeInRelationshipTyped:.../mergeOutRelationshipTyped:..., relationshipAt:, relationshipAt:propertyAt:put:, relationshipAt:properties:, relationshipAt:mergeProperties:, deleteRelationshipAt:) — this is the reference implementation for the Cypher-building patterns. Follow its query-building approach faithfully, but adapt the *result handling* to this project''s FkGraphRelationship wrapping instead of SgGraphDb''s #objectFromCypherResult:.
- ../SCypher/repository/SCypher-Core/CyQuery.class.st, in particular class-side `matchPathWithNodeAt:nodeAt:createIn:` and `matchPathWithNodeAt:nodeAt:mergeIn:` (each MATCHes two nodes by id, builds a path via the given block, and returns `p`, the whole path — not the relationship alone).

First, create the new class FkGraphRelationship (src/FalkorSt-Objects/FkGraphRelationship.class.st, superclass FkGraphObject), mirroring FkGraphNode''s shape:
1. #type — delegates to `self rawGraphObject type`.
2. #startNodeId — delegates to `self rawGraphObject startNodeId`.
3. #endNodeId — delegates to `self rawGraphObject endNodeId`.
4. #matchElementNamed: anIdentifier — builds and answers `CyRelationship start: s end: e name: anIdentifier`, where `s`/`e` are fresh anonymous node identifiers created inside the method (e.g. `s := ''s'' asCypherIdentifier. e := ''e'' asCypherIdentifier.`), the relationship-shaped counterpart to FkGraphNode''s `CyNode name: anIdentifier`. This is what the inherited #delete/#propertyAt:put:/#reload match themselves by id through — no changes to FkGraphObject are needed.
5. #rawRelationship — an alias for the inherited #rawGraphObject (mirrors FkGraphNode''s #rawNode).
Give FkGraphRelationship a CRC-style class comment mirroring FkGraphNode''s comment shape (Responsibility/Collaborators/Public API and Key Messages).

Then implement exactly these methods on FkGraphDb (method category ''actions-relationships''), each delegating Cypher construction to SCypher''s CyRelationship/CyQuery builders (mirroring SgGraphDb''s corresponding method):
6. #createRelationshipTyped:fromNodeId:toNodeId:properties: typeOrTypes startNodeId endNodeId propertiesArray — undirected CREATE via `CyQuery matchPathWithNodeAt:startNodeId nodeAt:endNodeId createIn: [ :startNode :endNode :relIdentifier | | rel | rel := relIdentifier rel: typeOrTypes props: propertiesArray. startNode - rel - endNode ]` (mirror SgGraphDb''s createRelationshipTyped:fromNodeId:toNodeId:properties:).
7. #createInRelationshipTyped:fromNodeId:toNodeId:properties: / #createOutRelationshipTyped:fromNodeId:toNodeId:properties: — same shape but using `startNode <- rel - endNode` / `startNode - rel -> endNode` respectively in the createIn: block (mirror SgGraphDb''s createInRelationshipTyped:.../createOutRelationshipTyped:...).
8. #mergeRelationshipTyped:fromNodeId:toNodeId:properties: and #mergeInRelationshipTyped:.../#mergeOutRelationshipTyped:... — the same three directional variants but via `CyQuery matchPathWithNodeAt:nodeAt:mergeIn:` instead of createIn: (mirror SgGraphDb''s merge*RelationshipTyped:... methods).
9. #relationshipAt: systemId — MATCH a relationship by internal id, mirroring SgGraphDb''s relationshipAt: (`s := ''s'' asCypherIdentifier. e := ''e'' asCypherIdentifier. r := ''r'' asCypherIdentifier. rel := CyRelationship start: s end: e name: r. query := CyQuery match: rel where: (r getId equals: systemId) return: r.`), answering it wrapped as FkGraphRelationship, or nil when the result has no records (mirror SgGraphDb''s #firstOrNilOf: pattern — do NOT signal FkGraphDbError here, that is #reload''s job, not a plain lookup''s).
10. #relationshipAt:propertyAt:put: systemId key value — SET a single property by id (mirror SgGraphDb''s relationshipAt:propertyAt:put:, using the same MATCH...WHERE id(r)=...SET pattern as #relationshipAt:, plus `set: { (r @ key) to: value }`). Implement as its own MATCH/SET query directly on FkGraphDb (do not fetch the relationship first and delegate to FkGraphObject''s instance-level #propertyAt:put: — that would cost an extra round trip and isn''t what the reference method does). Answer `result statistics`, matching FkGraphDb''s existing #nodeAt:propertyAt:put:.
11. #relationshipAt:properties: systemId argsDict — SET (replace) the relationship''s full property map by id using `set: (r to: ''values'' asCypherParameter)` bound via `self valuesArgumentsFor: argsDict` (mirror FkGraphDb''s existing #nodeAt:properties: for the parameter-binding convention, and SgGraphDb''s relationshipAt:properties: for the Cypher shape). Answer `result statistics`.
12. #relationshipAt:mergeProperties: systemId argsDict — SET the relationship''s properties by id using Cypher''s `+=` merge-assign form via `set: (r addAll: ''values'' asCypherParameter)` bound the same way (mirror FkGraphDb''s existing #nodeAt:mergeProperties: and SgGraphDb''s relationshipAt:mergeProperties:). Answer `result statistics`.
13. #deleteRelationshipAt: systemId — MATCH a relationship by id and DELETE it (mirror SgGraphDb''s deleteRelationshipAt: and FkGraphDb''s existing #deleteNodeAt: for the `result statistics`-answering convention).

Important result-unwrapping detail specific to relationships: the create/merge queries built with `matchPathWithNodeAt:nodeAt:createIn:`/`mergeIn:` RETURN a path (`p`), not the relationship directly. Where FkGraphDb''s node methods do `aFkQueryResult records first first` to get a raw FkNode straight off a query result (see #firstNodeOrNilFrom:), the six create/merge relationship methods (points 6-8) must instead pull the raw FkRelationship out of the returned FkPath''s #relationships collection: `aFkQueryResult records first first` gives an FkPath; that FkPath''s `relationships first` is the raw FkRelationship to wrap as `FkGraphRelationship on: ... in: self`. Consider adding a small private helper (e.g. #firstRelationshipOrNilFrom:) analogous to FkGraphDb''s existing #firstNodeOrNilFrom:, to avoid repeating this unwrapping across the six methods. #relationshipAt: and #deleteRelationshipAt: don''t have this wrinkle since their queries return/match the relationship identifier directly, the same way the node methods do.

Do not otherwise modify FkGraphNode, FkGraphEndpoint, or any GRAPH.QUERY decoding logic — scope is strictly the new FkGraphRelationship class, the new methods listed above on FkGraphDb, plus their tests. Update FkGraphDb''s class comment (Public API and Key Messages section) to list the new relationship methods — extend the existing comment rather than rewriting it wholesale.

Testing: add tests to FkGraphDbTest (src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st, superclass FkGraphEndpointTestCase, which runs against a real FalkorDB instance and provides `self graphName` / `stick`), following its existing pattern (`FkGraphDb on: stick named: self graphName`) for constructing the FkGraphDb under test. Cover at least: createRelationshipTyped:.../createInRelationshipTyped:.../createOutRelationshipTyped:... (assert type/startNodeId/endNodeId/properties on the returned FkGraphRelationship, and assert direction is respected for the directed variants by checking which end is the start/end node id), mergeRelationshipTyped:... idempotency (merging twice does not create a duplicate relationship — e.g. verify via a count query or by checking ids match), relationshipAt: found and not-found (nil) cases, relationshipAt:propertyAt:put: / relationshipAt:properties: / relationshipAt:mergeProperties: each correctly mutating a relationship''s properties as read back via a fresh relationshipAt:, and deleteRelationshipAt: removing the relationship (verify via a subsequent relationshipAt: returning nil). Each test must create its own nodes to connect and clean up everything it creates (nodes, relationships, labels) at the end so tests do not interfere with each other or leave state behind, following whatever cleanup convention FkGraphEndpointTestCase / FkGraphDbTest already establishes.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, and FalkorSt-Objects-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in FalkorSt-Objects-Tests (including the new FkGraphDb relationship-CRUD tests added in the previous step) as well as FalkorSt-Core-Tests, to confirm no regressions. Report the exact pass/fail/error counts per package and the names of any failing tests. If any test fails, fix the implementation or test and re-run until both packages fully pass, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the FkGraphDb relationship-CRUD feature (the new FkGraphRelationship.class.st, the modified FkGraphDb.class.st, and the modified/added test file(s)). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format, CRC-style comments). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
