# Feature: FkGraphDb facades for explain/profile, slowlog, memory, copy/drop, exists, allPropertyKeys

## Goal

`FkGraphDb` exposes facade methods for the graph-scoped `FkGraphEndpoint` commands that have no
facade yet (continuation of PR #39's index/constraint/procedure facades): `explain:`/`profile:`
(accepting a String or a CyQuery), `slowLog`/`resetSlowLog`, `memoryUsage`/`memoryUsageSamples:`,
`copyTo:` (answering an FkGraphDb for the copy on the same stick), `drop` (deletes the whole graph
key), `exists`, and `allPropertyKeys`. Covered by integration tests against a real FalkorDB.
Server-wide commands (graphList / graphConfig* / graphInfo) and UDFs stay out of scope.

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st (branch `feature/graphdb-diagnostics-copy-delete-facades`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement FkGraphDb diagnostics/copy/drop facades (TDD)'.
            t prompt: 'Add facade methods to FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st) in this Pharo/Tonel project for graph-scoped FkGraphEndpoint commands that have no FkGraphDb facade yet. This continues PR #39 (index/constraint/procedure facades) — look at how #indexes, #constraints and #callProcedure: delegate to the endpoint and follow the same style. Work test-first (TDD): write a failing SUnit test, implement, verify it passes, then move on. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle and consult the smalltalk-developer skill for Tonel editing and its style guide. Import only via st-import — never write your own package-loading eval code. Do NOT create or switch git branches; work on the currently checked-out branch.

Naming policy (decided by the user): separate method categories, no "get" prefix, drop the "graph" prefix, Smalltalk-like names, only these representative methods.

All endpoint methods below already exist in src/FalkorSt-Core/FkGraphEndpoint.class.st (verified) — delegate to them, do not modify FalkorSt-Core:

1. Category ''actions-diagnostics'' (query diagnostics):
   - #explain: cypherQueryOrString -> endpoint graphExplain: self name cypher: ...
   - #explain: cypherQueryOrString arguments: argsDict -> graphExplain:cypher:params:
   - #profile: cypherQueryOrString -> graphProfile:cypher:
   - #profile: cypherQueryOrString arguments: argsDict -> graphProfile:cypher:params:
   Pass the query through the existing private #cypherStringFor: (as #runCypher: does) so both a raw String and a CyQuery are accepted. Answer the raw reply unchanged — do not parse it (its content varies across FalkorDB versions). Keep it DRY: the no-arguments forms should delegate to the arguments: forms only if the endpoint treats an empty params dictionary identically (check #prependParams:to:); otherwise delegate to the endpoint''s plain form.

2. Category ''actions-diagnostics'' (slowlog / memory):
   - #slowLog -> graphSlowLog: self name (collection of FkSlowLogEntry)
   - #resetSlowLog -> graphResetLog: self name
   - #memoryUsage -> graphMemoryUsage: self name (Dictionary)
   - #memoryUsageSamples: sampleCount -> graphMemoryUsage: self name samples: sampleCount (Dictionary)

3. Category ''global operations'' (the graph itself):
   - #copyTo: destGraphName -> graphCopy: self name to: destGraphName, then answer a new FkGraphDb for the destination on the SAME stick (FkGraphDb class >> on:named: with self stick).
   - #drop -> graphDelete: self name. Deletes the whole graph key, unlike the existing #deleteAll which only removes nodes/relationships and leaves indexes/constraints behind. Add no special post-drop state to the instance (the same name can be reused afterwards). Mention this difference from #deleteAll in the method comment.
   - #exists -> answers whether (self endpoint graphList includes: self name). Check with st-eval what graphList actually answers (element class) and adapt if needed.

4. Category ''global operations'' (metadata):
   - #allPropertyKeys -> (self callReadOnlyProcedure: ''db.propertyKeys'') firstColumnValues — the plain collection of property key names, pairing with the existing #allLabels / #allRelationshipTypes.

Out of scope: graphList / graphConfig* / graphInfo (server-wide, stay on the endpoint), UDFs.

Tests: add SUnit integration tests to src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st (real FalkorDB on localhost:6379; follow its existing fixtures, setUp/tearDown and graph cleanup conventions). Cover: explain/profile with a String and with a CyQuery and with arguments (assert a non-empty reply, not its exact text); slowLog answers a collection (of FkSlowLogEntry if non-empty) and resetSlowLog empties it; memoryUsage / memoryUsageSamples: answer a non-empty Dictionary; copyTo: answers an FkGraphDb with the destination name whose data matches the source (e.g. same node count); drop removes the graph so #exists answers false afterwards (and true before); allPropertyKeys includes property keys created in the test. The copyTo: and drop tests must clean up every extra graph they create, even when an assertion fails (use ensure: or the tearDown pattern already in the test case).

Class comment: update FkGraphDb''s class comment only briefly — per the project rule the class comment is a summary, not a reference manual. Add at most a line or two naming the key new APIs (e.g. diagnostics via #explain:/#profile:, #drop vs #deleteAll); do not list every method.'.
            t goal: 'all new FkGraphDbTest tests for the explain/profile, slowLog, memoryUsage, copyTo:, drop, exists and allPropertyKeys facades are passing' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects and FalkorSt-Objects-Tests packages (in that order) from /home/mumez/git/Falkor.st/src into the running Pharo image, then run all tests in the FalkorSt-Core-Tests and FalkorSt-Objects-Tests packages (including the new FkGraphDbTest tests for explain/profile, slowLog, memoryUsage, copyTo:, drop, exists and allPropertyKeys). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until both packages pass, then report the final counts. Also confirm via st-eval that no stray test graphs are left behind (endpoint graphList).' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in /home/mumez/git/Falkor.st for the FkGraphDb diagnostics/copy/drop facade feature (use git diff develop and git status to see the changes; expected: src/FalkorSt-Objects/FkGraphDb.class.st and src/FalkorSt-Objects-Tests/FkGraphDbTest.class.st). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill style guide section for conventions (intention-revealing names, method categorization, short CRC class comment). Also verify: method names follow the policy (no get prefix, no graph prefix), new methods are in the ''actions-diagnostics'' and ''global operations'' categories, explain:/profile: go through #cypherStringFor:, copyTo: answers an FkGraphDb on the same stick, nothing under src/FalkorSt-Core or src/BaselineOfFalkorSt was changed, there is no duplicated delegation logic (DRY), and the class comment addition is a short summary rather than a per-method reference. Fix whatever issues these checks surface, then re-run st-import and st-test on FalkorSt-Core-Tests and FalkorSt-Objects-Tests to confirm everything still imports cleanly and all tests still pass. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
