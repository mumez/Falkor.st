# Feature: GRAPH.CONFIG GET/SET support for FkGraphEndpoint

## Goal

`FkGraphEndpoint` supports FalkorDB's `GRAPH.CONFIG GET` and `GRAPH.CONFIG SET` commands, each
covered by unit tests against a real FalkorDB instance, following this repo's existing conventions
(class prefix `Fk`, method categories, undecoded-raw-reply convention already used for
`GRAPH.DELETE`/`GRAPH.INFO`).

## Orchestration Shape

sequential: implement (TDD, both commands) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement GRAPH.CONFIG GET/SET (TDD)'.
            t prompt: 'Add support for two FalkorDB commands to FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st), in this Pharo/Tonel project. Work test-first (TDD): write a failing SUnit test in FalkorSt-Core-Tests (FkGraphEndpointTest, using the existing FkGraphEndpointTestCase shared setup — a real FalkorDB at sync://localhost:6379 via `self endpoint`), then implement the method(s), then verify the test passes, before moving to the next command. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and style.

Concrete specs (already verified against docs.falkordb.com and the existing codebase — implement exactly this, do not add anything beyond it):

1. GRAPH.CONFIG GET <param|*> — retrieves the value of one config parameter, or all of them when the parameter is the literal string ''*''. Add #graphConfigGet: paramName on FkGraphEndpoint, sending the command as an array {''GRAPH.CONFIG''. ''GET''. paramName} via #unifiedCommand:, answering the raw reply directly (same undecoded-raw-reply convention as #graphDelete:/#graphInfo — no FkQueryResult involved).

2. GRAPH.CONFIG SET key1 val1 [key2 val2 ...] — sets one or more config parameters at runtime (not persisted across a server restart); the wire command is a flat arg list of alternating keys and values. Add #graphConfigSet: paramsDictionary on FkGraphEndpoint: build an OrderedCollection starting with ''GRAPH.CONFIG'' and ''SET'', then append each key and value from paramsDictionary (keysAndValuesDo:) as separate elements (do NOT reuse #cypherParamsClauseFor: — that helper builds a single Cypher-literal string for CYPHER-prefix params, a different shape from this flat raw-argument-array wire format), send via #unifiedCommand:, and answer the raw reply directly.

Do NOT implement GRAPH.CONFIG REWRITE, config value type coercion/parsing, or a convenience "get all" wrapper method — not requested, keep scope to exactly the two methods above.

For both: put the new command methods in the existing commands-graph method category (matching #graphDelete:/#graphInfo). Update FkGraphEndpoint''s class comment (Responsibility, Public API and Key Messages, and Collaborators sections as relevant) to mention the two new commands, following the existing bullet style — extend it, do not rewrite it.

Testing: add tests to FkGraphEndpointTest that exercise the real FalkorDB instance via self endpoint (no self graphName needed — GRAPH.CONFIG is not graph-scoped, unlike GRAPH.QUERY). Cover: (a) GRAPH.CONFIG GET with a known parameter name answers a non-nil value, (b) GRAPH.CONFIG GET with ''*'' answers a non-empty reply, (c) GRAPH.CONFIG SET on a safe, runtime-settable parameter (inspect the actual GET ''*'' reply to find one — e.g. a numeric timeout/limit setting is typically safe to toggle and restore) followed by GET on that same parameter reflects the new value. Keep the change minimal and scoped exactly to what is specified above — do not refactor unrelated existing methods.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in the FalkorSt-Core-Tests package (including the new GRAPH.CONFIG GET/SET tests added in the previous step). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the GRAPH.CONFIG GET/SET feature (FkGraphEndpoint.class.st and its test file). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
