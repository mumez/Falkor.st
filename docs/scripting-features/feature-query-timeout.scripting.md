# Feature: query-timeout — TIMEOUT support for GRAPH.QUERY / GRAPH.RO_QUERY

## Goal

`FkGraphEndpoint` and `FkGraphDb` can send FalkorDB's `TIMEOUT <ms>` argument with `GRAPH.QUERY` and
`GRAPH.RO_QUERY` (matching falkordb-py's `query(q, params, timeout)`). The timeout can be passed
explicitly or taken implicitly from a default in `FkSettings`, which moves to `FalkorSt-Core`.
`TIMEOUT n` is sent only when a timeout is given and greater than 0, and existing selectors behave
as before. Unit and integration tests cover this, and all four packages pass.

## Orchestration Shape

sequential: implement (TDD) → full test suite (all 4 packages) → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st (branch `feature/query-timeout`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement TIMEOUT support for GRAPH.QUERY / GRAPH.RO_QUERY (TDD)'.
            t prompt: 'In this Pharo/Tonel project (FalkorDB client, see CLAUDE.md), add support for FalkorDB''s TIMEOUT <milliseconds> argument on GRAPH.QUERY and GRAPH.RO_QUERY, for parity with falkordb-py query(q, params, timeout). Work test-first (TDD): write a failing SUnit test, implement, and confirm it passes before moving on. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle. Import Tonel packages only through st-import, with no eval-hack package loading. Consult the smalltalk-developer skill for Tonel editing and style. Tests run against a real FalkorDB on localhost:6379. Do not use mocks. Do NOT git commit.

Specs (checked against the codebase; implement this and nothing more):

1. Move FkSettings to FalkorSt-Core. The user decided this because FalkorSt-Core cannot depend on FalkorSt-Objects, and FkGraphEndpoint needs the default. The superclass SkSettings lives in Stick-Core, which RediStick Core already loads, so NO Baseline change is needed. Move src/FalkorSt-Objects/FkSettings.class.st to src/FalkorSt-Core/FkSettings.class.st and set #category/#package to FalkorSt-Core. Move src/FalkorSt-Objects-Tests/FkSettingsTest.class.st to src/FalkorSt-Core-Tests/ in the same way. Use git mv so the history follows the files. Add FkSettings>>queryTimeoutMsecs, which defaults to 0 (meaning no TIMEOUT argument is sent), and FkSettings>>queryTimeoutMsecs:. Follow the existing targetUrl accessor pattern (at:ifAbsentPut: / at:put:). Import order is always FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests. Afterwards, check in the image that FkSettings package name is FalkorSt-Core.

2. FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st):
   - Add an instance variable queryTimeoutMsecs. Its accessor #queryTimeoutMsecs lazily defaults to FkSettings default queryTimeoutMsecs. Add a setter #queryTimeoutMsecs:, so a user can set a per-connection default that every query uses implicitly.
   - Add the public selectors #graphQuery:cypher:compact:timeout: and #graphRoQuery:cypher:compact:timeout:, which are the base methods. Add #graphQuery:cypher:params:compact:timeout: and #graphRoQuery:cypher:params:compact:timeout:, which prepend params through the existing #prependParams:to: and delegate to the base methods, mirroring how the existing params variants work today. Put them in the commands-graph category.
   - Existing selectors keep their signatures. #graphQuery:cypher:compact: and #graphRoQuery:cypher:compact: delegate to the new timeout: base methods, passing self queryTimeoutMsecs. The other existing variants already funnel into those, so they keep working unchanged.
   - Build the TIMEOUT argument in ONE private place. Extend the existing private #executeGraphCommand:graph:cypher:compact: / #rawGraphCommand:graph:cypher:compact: path with a timeout: keyword, for example #executeGraphCommand:graph:cypher:compact:timeout: and #rawGraphCommand:graph:cypher:compact:timeout:. Append the string TIMEOUT and the millisecond value as a string only when the timeout is non-nil and > 0. Do not duplicate this logic per command. Keep the existing non-timeout private selectors, delegating with timeout nil, only if they still have callers. Otherwise replace them.
   - The existing #rawGraphQuery:cypher:compact: and #rawGraphRoQuery:cypher:compact: must behave exactly as before and send no TIMEOUT. The internal id-cache refresh (#refreshCache:graph:procedure:) uses them. Do not touch GRAPH.EXPLAIN / GRAPH.PROFILE.

3. FkGraphDb (src/FalkorSt-Objects/FkGraphDb.class.st): add #runCypher:arguments:timeout: and #runReadOnlyCypher:arguments:timeout: in the querying category. They call the new endpoint params/compact/timeout selectors with compact true, which is the current default. The existing #runCypher:, #runCypher:arguments:, #runReadOnlyCypher:, and #runReadOnlyCypher:arguments: must pass self settings queryTimeoutMsecs. FkGraphDb has its own settings instance variable that defaults to FkSettings default, so honor that instance and not the global. Route these through the timeout: variants instead of duplicating code. Before you route #runCypher: through the arguments: path, check in the image how #prependParams:to: behaves with an empty Dictionary. If it would change the cypher string sent (for example by adding a bare CYPHER prefix), choose a clean delegation that keeps the no-arguments query string unchanged.

4. Tests:
   - Unit (FalkorSt-Core-Tests): command arguments contain TIMEOUT followed by n only when the timeout is given and > 0, and do not contain them when it is nil or 0. Test through the private argument-building seam you create. If needed, split argument building into its own private method, for example #graphCommandArgs:graph:cypher:compact:timeout:, so it can be asserted without the server.
   - FkSettingsTest: default queryTimeoutMsecs = 0, and an override works.
   - An endpoint queryTimeoutMsecs defaults to the FkSettings value and can be overridden per endpoint. Restore any global FkSettings state you change in tearDown.
   - Integration: a long-running READ query, for example UNWIND range(1, 100000000) AS x RETURN count(x), with a timeout of 1 ms signals an error. Use GRAPH.RO_QUERY for this, because FalkorDB may ignore TIMEOUT for write queries. Check empirically in the image what GRAPH.QUERY does with the same query and timeout, and which exception class RediStick signals. Assert on that exact class with should:raise: instead of guessing, and add a GRAPH.QUERY timeout-error test only if the server actually enforces it. A normal query with a generous timeout (for example 10000) succeeds through both the endpoint timeout: selectors and the FkGraphDb timeout: selectors. Put the FkGraphDb tests in FalkorSt-Objects-Tests, following the existing FkGraphDbTest setup.

5. Class comments must stay SHORT. They are a summary of the key API, not a reference manual. Add only the new timeout selectors and settings to the FkGraphEndpoint, FkGraphDb, and FkSettings class comments, as one or two short lines each. Update the FkSettings comment to reflect its new package and its queryTimeoutMsecs responsibility. Use the Fk prefix, intention-revealing names, and the existing method categories.

Forbidden in this run: a new package, Baseline changes, changes to ../RediStick or ../SCypher, format-specific value objects, and refactoring unrelated methods.

Finally, report the files changed, the selectors added, the exception class observed for the timeout, and what GRAPH.QUERY did with TIMEOUT.'.
            t goal: 'all new timeout-related SUnit tests pass and all existing tests in FalkorSt-Core-Tests and FalkorSt-Objects-Tests still pass' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite (all 4 packages)'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import these packages from /home/mumez/git/Falkor.st/src into the running Pharo image, in this order: FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests. Import only through st-import, with no eval-hack loading. Then run all tests in FalkorSt-Core-Tests and FalkorSt-Objects-Tests, which includes the new query TIMEOUT tests and the relocated FkSettingsTest. Verify in the image that FkSettings belongs to package FalkorSt-Core and that no stale copy remains in FalkorSt-Objects. Report the exact pass/fail/error counts for each package and the names of any failing tests. If a test fails, fix the implementation or the test (do not weaken assertions to make them pass), re-import, and re-run until both packages pass fully. Then report the final counts. Do NOT git commit.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in /home/mumez/git/Falkor.st for the query TIMEOUT feature. Use git status and git diff against develop to find them: they include FkGraphEndpoint.class.st, FkGraphDb.class.st, the relocated FkSettings.class.st and FkSettingsTest.class.st, and the changed or added test classes. Run the st-lint skill (or the smalltalk-validator MCP tools) on the changed Tonel files. Consult the smalltalk-developer skill style guide section for naming, method categorization, and class comment format. Also check these points:
(a) The TIMEOUT argument is built in exactly one private place.
(b) Class comments stay short and list only the key API, not every method.
(c) The existing selectors and rawGraphQuery:/rawGraphRoQuery:cypher:compact: behave as before.
(d) No Baseline, RediStick, or SCypher changes were made.
(e) FkSettings has no leftover references to its old package.
Fix whatever issues these checks surface. Then re-import all four packages via st-import (order: FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests) and re-run the FalkorSt-Core-Tests and FalkorSt-Objects-Tests suites to confirm everything still passes. Report what was found and fixed, or confirm there was nothing to fix, with the final test counts. Do NOT git commit.' ]
    } agentBy: [ :a | a claude ]
].
script forkRunThen: [ :orc | Transcript crShow: 'Done: ' , orc result printString ]
    onTimeout: [ :timeoutStep :ex | Transcript crShow: 'Timed out: ' , timeoutStep printString ].
script register
```

## How to run

Paste the script above into a Pharo Playground, or ask the assistant to run it via st-eval.
`forkRunThen:onTimeout:` runs the orchestration in the background and returns immediately. Watch
for the completion block's report (e.g. in the Transcript), or for the `onTimeout:` block's report
if a step stalls. You can also check progress with
`AbOrchestrationManager default orchestrationAt: <orchestration script id>`.
