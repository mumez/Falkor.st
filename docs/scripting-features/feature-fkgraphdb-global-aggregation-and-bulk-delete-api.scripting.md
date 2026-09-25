# Feature: FkGraphDb: グローバル集計・一括削除系APIの追加 (Neo4reSt整合)

## Goal

`FkGraphDb` (src/FalkorSt-Objects/FkGraphDb.class.st) gains graph-wide aggregation and bulk-delete
methods that close the gap with Neo4reSt's `N4GraphDb` 'global operations' category: `allLabels`,
`allRelationshipTypes`, `countNodes`, `countNodesLabeled:`, `countRelationships`,
`countRelationshipsTyped:`, `deleteAll`, `deleteAllNodes`, `deleteAllRelationships`,
`deleteRelationshipsTyped:`, `deleteRelationshipsTyped:havingAll:`, and `orphanedNodes`. All new
methods are covered by integration tests against a real FalkorDB instance and the class comment's
"Public API and Key Messages" section is updated to mention them (summary only, not exhaustive).

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude, each phase its own `seq:` block

## Working Directory

/home/mumez/git/Falkor.st (already on branch `feature/fkgraphdb-global-aggregation-and-bulk-delete-api`, branched from `develop`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
	builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Implement FkGraphDb global aggregation and bulk-delete API'.
			t prompt: 'Add graph-wide aggregation and bulk-delete methods to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st) in this Pharo/Tonel repository (falkor.st, a FalkorDB client built on RediStick + SCypher). Use the smalltalk-dev plugin skills (st-init, st-import, st-eval, st-test) for the Edit -> Import -> Test cycle, and follow the smalltalk-developer skill''s style guide. Work test-first: write a failing SUnit test for each method, then implement it, then confirm it passes.

Read src/FalkorSt-Objects/FkGraphDb.class.st in full before starting - it already has runCypher:/runReadOnlyCypher:, a labelsFor: helper that normalizes a single label or an Array of labels, and nodesFrom:/relationshipsFrom: helpers that wrap raw query records into FkGraphNode/FkGraphRelationship. Reuse these helpers; do not duplicate Cypher-building logic that already exists (e.g. the existing deleteNodesLabeled:where:, relationshipsTyped:where:, deleteRelationshipAt: methods show the established patterns for MATCH/WHERE/DELETE and for building relationship patterns with CyRelationship / r rel:props:).

Add these methods to FkGraphDb, in a new class-extension category named ''global operations'' (matching the reference library''s naming) except where noted otherwise:

- allLabels: distinct list of every label used anywhere in the graph. Equivalent to `MATCH (n) WITH DISTINCT labels(n) AS labels UNWIND labels AS label RETURN DISTINCT label`. Build it with SCypher: `n := ''n'' asCypherIdentifier. query := CyQuery match: (n asNode). labels := ''labels'' asCypherIdentifier. (query addWith: (n labels as: labels)) beDistinct. label := ''label'' asCypherIdentifier. query addUnwind: (labels deepCopy as: label). (query addReturn: label) beDistinct.` Run it with runReadOnlyCypher: and answer the raw scalar values as an Array/OrderedCollection of strings (result records collect: [:r | r first]).
- allRelationshipTypes: distinct list of every relationship type used anywhere in the graph. Equivalent to `MATCH ()-[r]->() RETURN DISTINCT type(r)`. Build it with: `r := ''r'' asCypherIdentifier. query := CyQuery match: ('''' asCypherIdentifier asNode - r asRelationship - '''' asCypherIdentifier asNode). (query addReturn: r type) beDistinct.` Run read-only, answer the raw scalar values the same way as allLabels.
- countNodes: total node count. Implement as `^ self countNodesLabeled: #()`.
- countNodesLabeled: labelOrLabels (category ''actions-nodes'', not ''global operations'' - it takes a label filter like the other actions-nodes methods): node count for the given label(s), using self labelsFor: to normalize the argument. Build `n := ''n'' asCypherIdentifier. node := CyNode name: n labels: (self labelsFor: labelOrLabels). query := CyQuery match: node. query addReturn: n count.` Run read-only. The result is a single scalar row - answer it the same way the existing code extracts a single value from a FkQueryResult (check how other single-scalar-returning methods in this class, or FkQueryResult itself, expose the first row/first value - do not guess, read FkQueryResult''s actual API first).
- countRelationships: total relationship count. Implement as `^ self countRelationshipsTyped: #()`.
- countRelationshipsTyped: typeOrTypes (category ''actions-relationships''): relationship count for the given type(s). Normalize typeOrTypes into an Array the same way relationshipsTyped:havingAll: does today. Build an anonymous directed pattern with the type filter (`rel := r rel: typeOrTypes props: #()` then `query := CyQuery match: ('''' asCypherIdentifier asNode - rel -> '''' asCypherIdentifier asNode)`), then `(query addReturn: (r id count) beDistinct)`. Run read-only, extract the single scalar the same way as countNodesLabeled:.
- deleteAll: delete every node and relationship in the graph. Equivalent to `MATCH (n) DETACH DELETE n`. Build `n := ''n'' asCypherIdentifier. query := CyQuery match: n asNode. (query addDelete: n) withRelations: true.` Run as a write query (runCypher:) and answer the query''s statistics (follow the same statistics-returning convention as deleteNodeAt:/deleteNodesLabeled:where:).
- deleteAllNodes: delete every node (and its relationships, since FalkorDB requires DETACH-style deletion for connected nodes). Implement as `^ self deleteNodesLabeled: #() havingAll: #()`, reusing the existing method.
- deleteAllRelationships: delete every relationship without touching nodes. Implement as `^ self deleteRelationshipsTyped: #() havingAll: #()` (see the two new methods below).
- deleteRelationshipsTyped: typeOrTypes (category ''actions-relationships''): bulk-delete relationships of the given type(s) anywhere in the graph. Implement as `^ self deleteRelationshipsTyped: typeOrTypes havingAll: #()`.
- deleteRelationshipsTyped: typeOrTypes havingAll: propertiesArray (category ''actions-relationships''): bulk-delete relationships of the given type(s) filtered by property equality, mirroring how relationshipsTyped:havingAll: builds its pattern but performing DELETE instead of RETURN. Build `r := ''r'' asCypherIdentifier. rel := r rel: typeOrTypes props: propertiesArray. query := CyQuery match: ('''' asCypherIdentifier asNode - rel - '''' asCypherIdentifier asNode). query addDelete: r.` Run as a write query and answer the query''s statistics.
- orphanedNodes: nodes with no relationships at all. Equivalent to `MATCH (n) WHERE NOT (n)--() RETURN n`. Build `n := ''n'' asCypherIdentifier. query := CyQuery match: n asNode where: (n asNode -- '''' asCypherIdentifier asNode) exists not return: n.` Run read-only and wrap the results into FkGraphNode using the existing nodesFrom: helper.

After implementing, update the class comment''s "Public API and Key Messages" section to mention the new methods (one or two lines each, consistent with the existing entries'' level of detail) - do not turn the class comment into an exhaustive method reference; keep it a summary per this project''s CLAUDE.local.md guidance.

Do not modify any other existing FkGraphDb method''s behavior, and do not add any new value-object classes - reuse FkGraphNode/FkGraphRelationship as-is.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Run the FalkorSt test suite for the new API'.
			t prompt: 'Run the full FalkorSt-Core-Tests / FalkorSt-Objects test suite in this repository (falkor.st) using the st-test skill (or the run_package_test / run_class_test MCP tools), after re-importing any changed packages with st-import if needed. Report the full pass/fail counts, and specifically confirm that the new tests for FkGraphDb''s allLabels, allRelationshipTypes, countNodes, countNodesLabeled:, countRelationships, countRelationshipsTyped:, deleteAll, deleteAllNodes, deleteAllRelationships, deleteRelationshipsTyped:, deleteRelationshipsTyped:havingAll:, and orphanedNodes methods (added in the previous step) all pass against the real FalkorDB test instance. If anything fails, investigate and fix it (following the smalltalk-debugger skill if needed) until the whole suite is green, then re-run to confirm.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Lint and review the FkGraphDb changes'.
			t prompt: 'Lint and review the changes made to src/FalkorSt-Objects/FkGraphDb.class.st (and any related test files) in this repository (falkor.st) for the new global-aggregation and bulk-delete API (allLabels, allRelationshipTypes, countNodes, countNodesLabeled:, countRelationships, countRelationshipsTyped:, deleteAll, deleteAllNodes, deleteAllRelationships, deleteRelationshipsTyped:, deleteRelationshipsTyped:havingAll:, orphanedNodes). Use the st-lint skill (or the smalltalk-validator MCP tools lint_tonel_smalltalk_from_file / validate_tonel_smalltalk_from_file) against the changed Tonel files, and check the changes against the smalltalk-developer skill''s style guide section (naming, method categorization, Tonel syntax, class comment conventions). Fix anything the lint or style review turns up, re-import and re-run the affected tests to confirm everything still passes after any fixes, and report a summary of what was checked and fixed.' ]
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
