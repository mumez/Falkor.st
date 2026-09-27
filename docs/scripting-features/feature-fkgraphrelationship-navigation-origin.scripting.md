# Feature: FkGraphRelationship / FkGraphPath navigation origin (replace #direction)

## Goal

Kanban issue 1790323135062（GraphRelationship>>directionのリファクタリング）が実装される。
`FkGraphRelationship` / `FkGraphPath` の `#direction` が廃止され、起点ノードを明示する
`on:in:navigatedFrom:` と `navigationOriginNodeId` / `navigationDirectionFrom:` に置き換わる。
`ownNode` / `otherNode` は起点ノードから解決され、`ownNodeId` / `otherNodeId` は削除される。
既存の全テストを壊さず（旧APIを使うテストは新APIに書き換え）、新規テストが追加されて全テストが
パスする。st-lintのスタイルガイドに沿っている。

## Orchestration Shape

sequential: implement (TDD) → full test-suite verification → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement: replace FkGraphRelationship/FkGraphPath #direction with navigation origin (TDD)'.
            t prompt: 'Work on branch feature/graph-relationship-navigation-origin (already checked out in this working directory) of the Falkor.st Pharo project.

Use the smalltalk-dev plugin skills (st-init, st-import, st-test, st-lint, st-eval) for the Edit -> Import -> Test cycle, per this project''s CLAUDE.md. Consult the smalltalk-developer skill''s style guide section while editing Tonel files.

Background: FkGraphRelationship (src/FalkorSt-Objects/FkGraphRelationship.class.st) currently carries a traversal #direction (#in / #out / nil) and resolves #ownNodeId/#otherNodeId from it. But that direction is only meaningful relative to the node the relationship was navigated FROM, so the API should name that origin node explicitly instead.

## 1. FkGraphRelationship (src/FalkorSt-Objects/FkGraphRelationship.class.st)

- REMOVE: the ''direction'' instVar, #direction, #direction:, `FkGraphRelationship class >> on:in:direction:`, #ownNodeId, #otherNodeId.
- ADD: instVar ''navigationOriginNodeId'' with accessor #navigationOriginNodeId (setter in the private category).
- ADD: `FkGraphRelationship class >> on: aFkRelationship in: aFkGraphDb navigatedFrom: navigationOriginNodeId` (built on the inherited on:in:, same style as the current on:in:direction:).
- ADD: `#navigationDirectionFrom: aNodeId` (public) - answers #out when aNodeId = self startNodeId, #in when aNodeId = self endNodeId, #unknown otherwise (including nil). Check startNodeId first, so a self-loop answers #out.
- ADD: `#navigationDirection` (private category) - `^ self navigationDirectionFrom: self navigationOriginNodeId`.
- KEEP #ownNode / #otherNode, reimplemented on top of navigationDirection: #ownNode is the node at navigationOriginNodeId; #otherNode is the endpoint on the other side (#out -> endNode id, #in -> startNode id). When navigationDirection is #unknown (no origin, e.g. relationships answered by FkGraphDb>>relationshipAt: or the create*/merge*RelationshipTyped: factories), both keep signaling `FkGraphDbError unknownDirection` (kind #UnknownDirection), as #ownNodeId/#otherNodeId do today. Keep FkGraphDbError class >> unknownDirection and update its class-comment mention (src/FalkorSt-Objects/FkGraphDbError.class.st) to refer to #ownNode/#otherNode and the missing navigation origin.
- Avoid duplicating the unknown-direction signal between #ownNode and #otherNode (DRY) - e.g. a small private helper - but keep it minimal.

## 2. FkGraphPath (src/FalkorSt-Objects/FkGraphPath.class.st)

- REMOVE: the ''direction'' instVar, #direction, #direction:, `FkGraphPath class >> on:in:direction:`. A direction is only meaningful for a one-hop path.
- ADD: `FkGraphPath class >> on: aFkPath in: aFkGraphDb navigatedFrom: navigationOriginNodeId` - for one-hop paths: at construction time, create exactly ONE FkGraphRelationship from the raw path''s single relationship via `FkGraphRelationship on:in:navigatedFrom:` and store it (e.g. in a ''relationships'' instVar holding a one-element collection). #relationships then answers that stored collection instead of collecting new wrappers afterwards.
- Plain `FkGraphPath class >> on:in:` keeps its current behavior: #relationships wraps the raw relationships with plain `FkGraphRelationship on:in:` (no origin).

## 3. Caller (src/FalkorSt-Objects/FkGraphDb.class.st)

The only production caller is FkGraphDb>>oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returnIn:returning: (around line 497): `FkGraphPath on: rawPath in: self direction: direction` -> change to `FkGraphPath on: rawPath in: self navigatedFrom: startNodeId`. Consequence (intended): relationships from undirected queries (direction: nil, e.g. FkGraphNode>>relationships / relationshipsTyped:) now also resolve #ownNode/#otherNode.

Do NOT change the query-side `direction:` keyword of FkGraphDb / FkGraphNode one-hop methods (#in / #out / nil selects the Cypher pattern) - it is out of scope. grep src/ for any remaining use of FkGraphRelationship/FkGraphPath #direction, on:in:direction:, #ownNodeId, #otherNodeId and fix them.

## 4. Class comments

Update the class comments of FkGraphRelationship, FkGraphPath and FkGraphDbError (and FkGraphDb / FkGraphNode only if they mention the path/relationship direction) to describe the navigation origin instead of direction. Per this project''s rules, class comments are summaries of the important API only, not a reference manual listing every method - trim rather than grow them.

## 5. Tests (TDD - write/adjust these first, then make them pass)

Integration tests run against a real FalkorDB (see existing fixtures in each test class):
- src/FalkorSt-Objects-Tests/FkGraphRelationshipTest.class.st: keep the own/other tests for out- and in-relationships; rewrite the two unknown-direction tests (currently on #ownNodeId/#otherNodeId) against #ownNode/#otherNode; add #navigationDirectionFrom: tests for #out, #in and #unknown (an unrelated node id and nil); add a test that a relationship from an undirected query (e.g. `alice relationshipsTyped: ''KNOWS''` and `bob relationshipsTyped: ''KNOWS''`) resolves ownNode/otherNode relative to the queried node.
- src/FalkorSt-Objects-Tests/FkGraphPathTest.class.st: on:in:navigatedFrom: builds exactly one FkGraphRelationship whose navigationOriginNodeId is the given id, and repeated #relationships answers the same instance; plain on:in: behaves as before.
- Check FkGraphDbTest / FkGraphNodeTest for anything relying on the removed API and update it.

Run tests after each change via the st-test skill / MCP tools, importing changed packages first via st-import. Do not stop until FkGraphRelationshipTest and FkGraphPathTest pass and the pre-existing tests across FalkorSt-Objects-Tests still pass (no regressions).' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Verify full test suite'.
            t prompt: 'In this same Falkor.st working directory, on branch feature/graph-relationship-navigation-origin, re-import every locally-managed package (FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests, in dependency order per the BaselineOf) via the st-import skill, then run the full test suite via the st-test skill for FalkorSt-Core-Tests and FalkorSt-Objects-Tests. Report the exact pass/fail counts for each package. Also grep src/ to confirm no remaining references to FkGraphRelationship/FkGraphPath #direction, on:in:direction:, #ownNodeId or #otherNodeId. If anything fails, fix it (referring back to the previous topic''s refactor: FkGraphRelationship on:in:navigatedFrom: / navigationOriginNodeId / navigationDirectionFrom:, FkGraphPath on:in:navigatedFrom:) and re-run until everything passes. Do not consider this step done until both test packages report zero failures and zero errors.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and style review'.
            t prompt: 'In this same Falkor.st working directory, on branch feature/graph-relationship-navigation-origin, run the st-lint skill (or the smalltalk-validator MCP tools directly) against every Tonel file changed for this feature (check `git diff --name-only develop` - expected: src/FalkorSt-Objects/FkGraphRelationship.class.st, FkGraphPath.class.st, FkGraphDb.class.st, FkGraphDbError.class.st and the related tests in src/FalkorSt-Objects-Tests/).

Also consult the smalltalk-developer skill''s style guide section and review the new/changed code against it directly (naming, method categorization, class comment format, Tonel structure). Class comments must stay concise summaries of the important API, not a full method reference.

Fix every finding you make (do not just report them), then re-import the affected packages via st-import and re-run the full test suite via st-test to confirm nothing regressed after your fixes. Report a final summary: what was fixed, and confirmation that all tests still pass.' ]
    } agentBy: [ :a | a claude ] ].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result ]
    onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval. `forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately — watch for the completion block's own report (e.g. via Transcript), the `onTimeout:` block's report if a step stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration script id>`.
