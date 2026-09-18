# Feature: FkGraphDb にパス／トラバーサルクエリを追加

## Goal

`FkGraphDb` に `matchPathWithRelationshipsOfTypes:havingAll:fromNodeAt:endNodeIn:pathIn:whereIn:` と
`oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning:` が追加され、
新設の `FkGraphPath`（nodes/relationships/startNode/endNode/rawPath を提供する、FkGraphObjectを継承しない
薄いラッパー）に結果がマッピングされる。既存の44テストを壊さず、新規テストが追加されて全テストがパスする。
st-lintのスタイルガイドに沿っている。

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
            t title: 'Implement FkGraphDb path/traversal queries (TDD)'.
            t prompt: 'Work on branch feature/fkgraphdb-path-traversal-query (already checked out in this working directory) of the Falkor.st Pharo project.

Use the smalltalk-dev plugin skills (st-init, st-import, st-test, st-lint, st-eval) for the Edit -> Import -> Test cycle, per this project''s CLAUDE.md. Consult the smalltalk-developer skill''s style guide section while editing Tonel files.

Goal: add path/traversal query support to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st), mirroring the existing node/relationship CRUD methods already in that file (e.g. createOutRelationshipTyped:fromNodeId:toNodeId:properties:) in style and naming.

## 1. New class FkGraphPath (src/FalkorSt-Objects/FkGraphPath.class.st)

A thin wrapper holding a raw FkPath (src/FalkorSt-Core/FkPath.class.st) plus the FkGraphDb it was fetched through.

IMPORTANT: unlike FkGraphNode/FkGraphRelationship, do NOT make this a subclass of FkGraphObject (src/FalkorSt-Objects/FkGraphObject.class.st). A path has no id/delete/propertyAt:put: concept, so FkGraphObject''s CRUD API (and its subclassResponsibility #matchElementNamed:) does not apply. Implement FkGraphPath as an independent class, structured similarly (on:in: factory, holding the raw value + db) but without inheriting FkGraphObject.

Reference (read-only, do not depend on it): ../SCypherGraph/src/SCypherGraph-Core/SgPath.class.st -- it subclasses SgGraphObject, but do not follow that part of the design for the reason above.

Public API:
- `FkGraphPath class >> on: aFkPath in: aFkGraphDb`
- `#nodes` - collect each element of the raw FkPath''s #nodes, wrapped via `FkGraphNode on: each in: self db`, into an OrderedCollection
- `#relationships` - collect each element of the raw FkPath''s #relationships, wrapped via `FkGraphRelationship on: each in: self db`, into an OrderedCollection
- `#startNode` - `self nodes first`
- `#endNode` - `self nodes last`
- `#rawPath` - the held raw FkPath (name it like the existing #rawNode / #rawRelationship accessors on FkGraphNode/FkGraphRelationship)
- `#db` - the FkGraphDb, private/accessing category as appropriate

Write a CRC-style class comment (Responsibility / Collaborators / Public API and Key Messages) following the exact style of FkGraphNode.class.st, FkGraphRelationship.class.st and FkGraphObject.class.st''s class comments already in the repo.

## 2. New methods on FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st)

a) `FkGraphDb >> matchPathWithRelationshipsOfTypes: typeOrTypes havingAll: relPropsArray fromNodeAt: startNodeId endNodeIn: endNodeBlock pathIn: pathCreationBlock whereIn: whereClauseBuilder`

A thin wrapper that just calls SCypher''s `CyQuery class >> matchPathWithRelationshipsOfTypes:havingAll:fromNodeAt:endNodeIn:pathIn:whereIn:` (see ../SCypher/repository/SCypher-Core/CyQuery.class.st for its exact signature and behavior) and answers the built CyQuery -- it does not run the query. This mirrors SgGraphDb''s method of the same name (../SCypherGraph/src/SCypherGraph-Core/SgGraphDb.class.st, actions-paths category) which is a similarly thin wrapper.

b) `FkGraphDb >> oneHopPathsTyped: typeOrTypes direction: direction from: startNodeId havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder returning: returner`

Reference SgGraphDb''s `oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning:` (same file, actions-paths category) for the overall shape:
- Build a path pattern block from `direction` (a Symbol): `#in` -> `[ :startNode :rel :endNode | startNode <- rel - endNode ]`, `#out` -> `[ :startNode :rel :endNode | startNode - rel -> endNode ]`, anything else (undirected) -> `[ :startNode :rel :endNode | startNode - rel - endNode ]`.
- Build the end-node block as `[ :e | e node: labels props: endNodeProps ]` (CyIdentifier>>#node:props: from SCypher).
- Build the query via the method from (a) above.
- Run it with `self runCypher:` (like every other query-running method in this file).
- For each record in the result, wrap the raw FkPath (the record''s first value) as `FkGraphPath on: ... in: self`, then apply `returner value:` to that *wrapped* FkGraphPath (NOT to the raw FkPath) so the caller''s block can pull out whatever it needs -- the path itself, `startNode`, `endNode`, `relationships`, etc. -- already as properly-wrapped FkGraphNode/FkGraphRelationship/FkGraphPath objects. This differs deliberately from SgGraphDb, which applies its `returner` to the raw path before a generic dispatch-based wrap; falkor.st always wraps explicitly by class first (see FkGraphDb''s existing createRelationshipTyped:/mergeRelationshipTyped: methods for the established pattern), so apply `returner` after wrapping instead.
- Answer the collection of `returner value: ...` results.

Update FkGraphDb.class.st''s class comment (the "Public API and Key Messages" and "Implementation Points" sections) to document these two new methods, following the existing bullet style used there for the relationship-CRUD methods.

## 3. Tests (TDD -- write these first, then make them pass)

Add integration tests to src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st (same style/category as existing tests in that file -- it runs against a real FalkorDB instance, not a mock) covering:
- `oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning:` for at least the `#out` direction, verifying the returned FkGraphPath(s) have the expected start/end node ids and relationship type, using a `returner` block that answers the path itself.
- A variant using the `returner` block to answer just `endNode` (or `relationships`), proving the wrapped-object access works after the path is built.
- `matchPathWithRelationshipsOfTypes:havingAll:fromNodeAt:endNodeIn:pathIn:whereIn:` building a CyQuery directly (can be a simpler unit-style test verifying it delegates to CyQuery correctly, or an integration test running the built query via `runCypher:` -- pick whichever fits the existing test style best).

If the setUp/tearDown fixtures in FkGraphDbTest need new nodes/relationships created for these tests, follow the existing helper patterns already in that class (e.g. however earlier relationship-CRUD tests set up their fixtures).

Also add a new src/FalkorSt-Objects-Tests/FkGraphPathTest.class.st with focused unit tests for FkGraphPath''s #nodes/#relationships/#startNode/#endNode/#rawPath, using simple stub/hand-built FkPath and FkGraphDb instances where an integration test would be overkill (check how FkGraphNodeTest.class.st is structured for the equivalent pattern on FkGraphNode, since FkGraphPath needs no live FalkorDB connection to test its own wrapping logic).

Run tests after each change via the st-test skill / MCP tools, importing changed packages first via st-import. Do not stop until FkGraphDbTest and the new FkGraphPathTest both pass, and the pre-existing 44 tests across FalkorSt-Objects-Tests still pass (i.e. no regressions).' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Verify full test suite'.
            t prompt: 'In this same Falkor.st working directory, on branch feature/fkgraphdb-path-traversal-query, re-import every locally-managed package (FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests, in dependency order per the BaselineOf) via the st-import skill, then run the full test suite via the st-test skill for FalkorSt-Core-Tests and FalkorSt-Objects-Tests. Report the exact pass/fail counts for each package. If anything fails, fix it (referring back to the previous topic''s implementation) and re-run until everything passes. Do not consider this step done until both test packages report zero failures and zero errors.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and style review'.
            t prompt: 'In this same Falkor.st working directory, on branch feature/fkgraphdb-path-traversal-query, run the st-lint skill (or the smalltalk-validator MCP tools directly) against every Tonel file changed or added for the path/traversal-query feature: src/FalkorSt-Objects/FkGraphDb.class.st, src/FalkorSt-Objects/FkGraphPath.class.st, src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st, src/FalkorSt-Objects-Tests/FkGraphPathTest.class.st.

Also consult the smalltalk-developer skill''s style guide section and review the new/changed code against it directly (naming, method categorization, class comment format, Tonel structure).

Fix every finding you make (do not just report them), then re-import the affected packages via st-import and re-run the full test suite via st-test to confirm nothing regressed after your fixes. Report a final summary: what was fixed, and confirmation that all tests still pass.' ]
    } agentBy: [ :a | a claude ] ].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result ]
    onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval. `forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately — watch for the completion block's own report (e.g. via Transcript), the `onTimeout:` block's report if a step stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration script id>`.
