# Feature: FkGraphDb relationship-search and property-removal API (Neo4reSt parity)

## Goal

`FkGraphDb` gains graph-wide typed relationship search (`relationshipsTyped:` and its
`having:value:`/`havingAll:`/`where:`/`where:orderBy:skip:limit:` variants), single-property
removal for both nodes and relationships (`nodeAt:removePropertyAt:` /
`relationshipAt:removePropertyAt:`), and a single-property-equality shortcut for node search
(`nodesLabeled:having:key:value:`) — closing the gap against Neo4reSt's `N4GraphDb` reference API.
All new methods are covered by SUnit tests against a real FalkorDB instance, the class comment is
updated, and `st-lint` passes clean on the touched files.

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, three separate `seq:` blocks (one topic
each), all via claude.

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
	builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Implement FkGraphDb relationship-search and property-removal API'.
			t prompt: 'Add relationship-search and property-removal API methods to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st), targeting parity with Neo4reSt''s N4GraphDb (../Neo4reSt/src/Neo4reSt-GraphModel/N4GraphDb.class.st, categories ''actions-relationships'' and ''actions-nodes'' - reference-only, not a dependency). Work via the Edit -> Import -> Test cycle using the st-import and st-eval skills.

Add these methods to FkGraphDb, mirroring N4GraphDb''s same-named methods but adapted to the FalkorDB/FkGraphDb conventions already used elsewhere in the class (CyQuery-based building via ''n''/''s''/''e''/''r'' asCypherIdentifier, self runCypher:, wrapping results into FkGraphRelationship/FkGraphNode via #on:in:, answering query statistics for mutations, collection-returning methods reusing the existing collect-pattern like #nodesFrom:):

1. relationshipsTyped: typeOrTypes (category ''actions-relationships'') - all relationships of the given type(s) anywhere in the graph, no property filter. Delegates to relationshipsTyped:havingAll: with #().
2. relationshipsTyped: typeOrTypes having: key value: value - shortcut for a single property-equality filter. Delegate to relationshipsTyped:where: with a one-key/value where-block built the same way as point 7 below, NOT N4GraphDb''s HTTP-param style (FkGraphDb has no direct param-binding equivalent for this call shape).
3. relationshipsTyped: typeOrTypes havingAll: assocArray - delegates to relationshipsTyped:where: with [:r | r havingAll: assocArray].
4. relationshipsTyped: typeOrTypes where: whereClauseBuilder - delegates to the orderBy:skip:limit: variant with nil/nil/nil.
5. relationshipsTyped: typeOrTypes where: whereClauseBuilder orderBy: orderByClauseBuilder skip: skip limit: limit - MATCH an anonymous directed path ('''' asCypherIdentifier asNode) - rel -> ('''' asCypherIdentifier asNode) where rel := r rel: typeOrTypes props: #() and r := ''r'' asCypherIdentifier, apply whereClauseBuilder value: r, return: r, and orderBy/skip/limit. Reuse CyQuery class >> match:where:return:orderBy:skip:limit: - the same builder FkGraphDb already uses in nodesLabeled:where:orderBy:skip:limit: (src/FalkorSt-Objects/FkGraphDb.class.st). Before wiring this, read that existing method AND CyQuery.class.st in ../SCypher/repository/SCypher-Core/CyQuery.class.st (method match:where:return:orderBy:skip:limit:, around line 76) to see exactly how the orderBy parameter is passed there (raw clause vs. block) - match FkGraphDb''s own established calling convention exactly rather than guessing; do not invoke orderByClauseBuilder as a block unless nodesLabeled:where:orderBy:skip:limit: already does so for its own orderByClause parameter. Wrap each result relationship via FkGraphRelationship on: record first in: self, following the existing per-record wrapping idioms in #firstRelationshipOrNilFrom: and #nodesFrom: - write an analogous private #relationshipsFrom: helper for this.
6. relationshipAt: systemId removePropertyAt: key (category ''actions-relationships'') - MATCH relationship by id, remove: (r @ key) via CyQuery class >> match:where:remove:, answer result statistics. Mirror the existing relationshipAt:propertyAt:put: method''s structure exactly, swapping set: for remove:.
7. nodesLabeled: labelOrLabels having: key value: value (category ''actions-nodes'') - shortcut for a single property-equality filter, delegating to nodesLabeled:where: with a one-key/value where-block (e.g. [:node | (node @ key) equals: value] - check the exact comparison message CyNode/where-clause blocks already use elsewhere in this class, such as in nodesLabeled:havingAll:, and match it).
8. nodeAt: systemId removePropertyAt: key (category ''actions-nodes'') - mirror nodeAt:propertyAt:put:, swapping set: for remove:. MATCH node by id, remove: (n @ key), answer result statistics.

Update the class comment''s "Public API and Key Messages" and "Implementation Points" sections in FkGraphDb.class.st to document the new methods, following the existing terse style already used for sibling methods in that same class comment.

Follow TDD: for each method, write a failing SUnit test first in src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st (package FalkorSt-Objects-Tests), then implement, then confirm it passes. Read FkGraphDbTest.class.st first to match its existing setup/teardown and assertion conventions for integration tests against a real FalkorDB instance (fixture creation helpers, cleanup, assertion patterns) before writing new tests - don''t invent a different test style.'.
			t goal: 'all 8 new FkGraphDb methods are implemented, documented in the class comment, and covered by passing SUnit tests in FkGraphDbTest' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Run the FalkorSt-Objects-Tests suite'.
			t prompt: 'Using the st-test skill (or the smalltalk-interop MCP run_package_test / run_class_test tools), run the full FalkorSt-Objects-Tests package test suite (and specifically FkGraphDbTest) against the current image state in /home/mumez/git/Falkor.st. Report the exact pass/fail counts and the full names of any failing or erroring tests. If any test related to the new relationship-search or property-removal methods added in the previous step fails, fix the implementation or the test (whichever is wrong) and re-run until the whole suite is green. Do not modify unrelated passing tests.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Lint and review the changes'.
			t prompt: 'Consult the st-lint skill (or the smalltalk-validator MCP lint_tonel_smalltalk_from_file tool) against every Tonel file touched in this feature: src/FalkorSt-Objects/FkGraphDb.class.st and src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st in /home/mumez/git/Falkor.st. Also consult the smalltalk-developer skill''s style guide section and review the touched methods against it (naming, method categorization, CRC-style class comment conventions). Fix any findings from either the linter or the style guide review, keeping changes scoped to only the methods added/touched by this feature - do not refactor unrelated code. Report a final summary of what was fixed, if anything.' ]
	} agentBy: [ :a | a claude ] ].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result ]
	onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval.
`forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately — watch
for the completion block's own report (e.g. via Transcript), the `onTimeout:` block's report if a
step stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration
script id>`.
