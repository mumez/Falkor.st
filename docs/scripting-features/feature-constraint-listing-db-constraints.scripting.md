# Feature: constraint-listing — list constraints via db.constraints()

## Goal

`FkGraphEndpoint>>graphConstraints: graphName` lists a graph's schema constraints via
`CALL db.constraints()` (equivalent to falkordb-py's `list_constraints()`), answering an
`OrderedCollection` of a new read-only value class `FkGraphConstraintInfo` that follows the same
pattern as `FkGraphEndpoint>>graphIndexes:` / `FkGraphIndexInfo`. Integration tests against a real
FalkorDB show UNIQUE + MANDATORY constraints on a node label and a relationship type are listed with
the correct constraintType / entityType / entityName / properties / status, and that a graph without
constraints answers an empty collection. `FkGraphConstraint` (the builder) is not changed.

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st (branch `feature/constraint-listing`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement graphConstraints: listing (TDD)'.
            t prompt: 'Add constraint listing to FkGraphEndpoint in this Pharo/Tonel project (/home/mumez/git/Falkor.st, branch feature/constraint-listing), equivalent to falkordb-py''s list_constraints(), which runs CALL db.constraints(). Work test-first (TDD): write a failing SUnit test, implement, verify it passes. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle and consult the smalltalk-developer skill for Tonel editing and its style guide. Import only via st-import — never write your own package-loading eval code.

API (decided — follow exactly):
- FkGraphEndpoint>>graphConstraints: graphName (category ''commands-graph'', in src/FalkorSt-Core/FkGraphEndpoint.class.st) answering an OrderedCollection of FkGraphConstraintInfo. Mirror the existing #graphIndexes: exactly:
    graphIndexes: graphName
        ^ (self graphCallProcedure: graphName procedure: ''db.indexes'') mappedRecords collect: [ :record | FkGraphIndexInfo fromRecord: record ]
- New class FkGraphConstraintInfo (src/FalkorSt-Core/FkGraphConstraintInfo.class.st, superclass Object, package FalkorSt-Core), modelled on src/FalkorSt-Core/FkGraphIndexInfo.class.st (read it first): an immutable wrapper over the raw mapped record — one instVar rawConstraintInfo, class-side #fromRecord:, private-accessing #rawConstraintInfo / #rawConstraintInfo:, and read-only accessors using `self rawConstraintInfo at: key ifAbsent: []`.
- Accessors, named to align with the existing FkGraphConstraint builder so users can compare a listed constraint with one they built: #constraintType (key ''type''), #entityType (key ''entitytype''), #entityName (key ''label''), #properties (key ''properties''), #status (key ''status'').
- Do NOT add status (or anything else) to FkGraphConstraint — it is a builder and a status there would be confusing. Do not change FkGraphConstraint at all.

Already verified by the orchestrator against the test FalkorDB (sync://localhost:6379, FalkorDB 6.0.1, same major version as CI): (endpoint graphCallProcedure: g procedure: ''db.constraints'') mappedRecords answers Dictionaries like (''entitytype''->''NODE'' ''label''->''Person'' ''properties''->an OrderedCollection(''email'') ''status''->''OPERATIONAL'' ''type''->''UNIQUE''), so the keys above are correct. Still re-check the relationship-type case with st-eval yourself.

Known FalkorDB gotchas to check yourself (do not assume — verify with st-eval):
1. A UNIQUE constraint requires a pre-existing exact-match (range) index on the same label/type and properties; create it first via the existing #graphIndexCreateBy:on: (e.g. [ :i | i range; node: ''Person''; props: #(''email'') ]). Constraint creation uses the existing #graphConstraintCreateBy:on: (e.g. [ :c | c unique; node: ''Person''; props: #(''email'') ]).
2. Constraint creation is asynchronous: status may be ''UNDER CONSTRUCTION'' before becoming ''OPERATIONAL''. Make the test robust — poll #graphConstraints: briefly (bounded loop with a short Delay, e.g. up to a few seconds) until the expected constraint is OPERATIONAL, then assert. Check how a failed constraint (''FAILED'') looks too and do not hide it.
3. Both the local test server and CI run FalkorDB 6; avoid relying on version-specific output where a robust assertion is possible (e.g. compare properties as a collection of names regardless of Array/OrderedCollection).

Tests: add to src/FalkorSt-Core-Tests/FkGraphEndpointTest.class.st next to the existing index listing tests (#testGraphIndexesEmptyWhenGraphHasNoIndexes, #indexInfoLabeled:entityType:, #assertListedProperty:type:label:entityType: — follow their style and helper pattern and the existing cleanup so no graph is left behind):
- Create UNIQUE and MANDATORY constraints on a node label (e.g. Person) and on a relationship type (e.g. KNOWS), then #graphConstraints: lists each one as an FkGraphConstraintInfo with the correct constraintType (''UNIQUE''/''MANDATORY''), entityType (''NODE''/''RELATIONSHIP''), entityName, properties and status ''OPERATIONAL''.
- A graph with no constraints (e.g. after CREATE (:Person)) answers an empty collection.

Docs: keep class comments short (key API only — they are summaries, not reference manuals). Give FkGraphConstraintInfo a short CRC class comment in the same style as FkGraphIndexInfo. In FkGraphEndpoint''s class comment add only: one collaborator line for FkGraphConstraintInfo (next to the FkGraphIndexInfo line) and one short public-API line for #graphConstraints: (next to #graphIndexes:). Do not rewrite other parts of the comment.

Boundaries: Fk prefix, intention-revealing names, no new package, no Baseline change, no changes to RediStick or SCypher, no format-specific value objects. Do NOT git commit — leave the changes uncommitted.'.
            t goal: 'the new graphConstraints: tests in FkGraphEndpointTest are passing against the real FalkorDB' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages (in that order) from /home/mumez/git/Falkor.st/src into the running Pharo image, then also import FalkorSt-Objects and FalkorSt-Objects-Tests if those directories exist under src (they depend on Core). Run all tests in FalkorSt-Core-Tests and, if present, FalkorSt-Objects-Tests (including the new graphConstraints: tests in FkGraphEndpointTest). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until all pass, then report the final counts. Do not git commit.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in /home/mumez/git/Falkor.st for the constraint-listing feature (use git diff develop and git status: expected src/FalkorSt-Core/FkGraphConstraintInfo.class.st, src/FalkorSt-Core/FkGraphEndpoint.class.st, src/FalkorSt-Core-Tests/FkGraphEndpointTest.class.st). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill style guide section (intention-revealing names, method categorization, short CRC class comment). Also verify: #graphConstraints: mirrors #graphIndexes: (no duplicated decoding logic), FkGraphConstraintInfo mirrors FkGraphIndexInfo''s immutable raw-record wrapper shape, FkGraphConstraint was not changed, nothing under src/BaselineOfFalkorSt changed, and the class comment additions are one short line each (no per-method reference). Fix whatever these checks surface, then re-run st-import and st-test on FalkorSt-Core-Tests to confirm everything still imports cleanly and all tests pass. Report a summary of what was found and fixed, or confirm there was nothing to fix. Do not git commit.' ]
    } agentBy: [ :a | a claude ]
].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result ]
    onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval.
`forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately — watch for
the completion block's own report (e.g. via Transcript), the `onTimeout:` block's report if a step
stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration script id>`.
