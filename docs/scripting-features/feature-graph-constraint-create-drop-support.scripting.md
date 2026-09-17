# Feature: GRAPH.CONSTRAINT CREATE/DROP support for FkGraphEndpoint

## Goal

`FkGraphEndpoint` supports FalkorDB's `GRAPH.CONSTRAINT CREATE` and `GRAPH.CONSTRAINT DROP`
commands for managing MANDATORY/UNIQUE schema constraints, each covered by unit tests against a
real FalkorDB instance, following this repo's existing conventions (class prefix `Fk`, method
categories, undecoded-raw-reply convention already used for `GRAPH.DELETE`/`GRAPH.CONFIG`), with
the CREATE/DROP argument-building logic shared rather than duplicated.

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
            t title: 'Implement GRAPH.CONSTRAINT CREATE/DROP (TDD)'.
            t prompt: 'Add support for two FalkorDB commands to FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st), in this Pharo/Tonel project. Work test-first (TDD): write a failing SUnit test in FalkorSt-Core-Tests (FkGraphEndpointTest, using the existing FkGraphEndpointTestCase shared setup — a real FalkorDB at sync://localhost:6379 via `self endpoint`), then implement the method(s), then verify the test passes, before moving to the next command. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and style.

Concrete specs (already verified against docs.falkordb.com and the existing codebase — implement exactly this, do not add anything beyond it):

1. GRAPH.CONSTRAINT CREATE key MANDATORY|UNIQUE NODE label|RELATIONSHIP reltype PROPERTIES propCount prop [prop...] — creates a schema constraint on graph `key`. `MANDATORY`/`UNIQUE` selects the constraint type; the entity clause is either `NODE label` or `RELATIONSHIP reltype`; `PROPERTIES` is followed by the property count and then that many property names.

2. GRAPH.CONSTRAINT DROP key MANDATORY|UNIQUE NODE label|RELATIONSHIP reltype PROPERTIES propCount prop [prop...] — removes a previously created constraint, using the identical argument shape as CREATE (only the verb differs).

These two commands are argument-symmetric — implement a single private helper method that builds the shared arg tail (constraint type keyword, NODE/RELATIONSHIP entity clause, and PROPERTIES propCount + prop list) from parameters, and have two thin public methods (one for CREATE, one for DROP) that each prepend `''GRAPH.CONSTRAINT''` and their own verb (`''CREATE''`/`''DROP''`) to that shared tail and send the combined OrderedCollection via #unifiedCommand:, answering the raw reply directly (same undecoded-raw-reply convention as #graphDelete:/#graphConfigGet:/#graphConfigSet: — no FkQueryResult involved). Choose idiomatic Smalltalk keyword-message method names/signatures that express: graph key, constraint type (MANDATORY/UNIQUE), entity type + name (NODE label or RELATIONSHIP reltype), and the list of properties — adjust the exact selector names as you find clearest, but keep CREATE and DROP symmetric in shape and sharing the same private arg-building helper (do not duplicate the arg-building logic between them).

Do NOT implement any other GRAPH.CONSTRAINT subcommand, constraint listing/introspection, or response decoding beyond answering the raw reply — not requested, keep scope to exactly the CREATE/DROP pair described above. Do not touch GRAPH.QUERY decoding, compact-id-resolution, or any other command family in this file.

For both: put the new command methods (and the shared private helper) in the existing commands-graph method category (matching #graphDelete:/#graphConfigGet:/#graphConfigSet:; the private helper may go in a `private` or `private-commands-graph` category per existing convention in this file). Update FkGraphEndpoint''s class comment (Responsibility, Public API and Key Messages, and Collaborators sections as relevant) to mention the two new commands, following the existing bullet style — extend it, do not rewrite it. If the project README documents supported GRAPH.* commands (check for a commands/features list), add the two new ones there too, mirroring how GRAPH.CONFIG/GRAPH.INFO were documented previously.

Testing: add tests to FkGraphEndpointTest that exercise the real FalkorDB instance via self endpoint and a dedicated test graph name (do not reuse a shared graph other tests depend on, to avoid collisions). Cover: (a) creating a MANDATORY constraint on a NODE label with one or more properties succeeds, (b) creating a UNIQUE constraint on a NODE label succeeds, (c) dropping a previously created constraint succeeds, (d) a RELATIONSHIP-type constraint (MANDATORY or UNIQUE) can be created and dropped. Each test that creates a constraint or a graph must clean up after itself (drop the constraint and/or the test graph) using an ensure: block, following the restore-safe pattern used by testGraphConfigSetUpdatesParamValue, so tests do not leave state behind even if an assertion fails. Keep the change minimal and scoped exactly to what is specified above — do not refactor unrelated existing methods.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in the FalkorSt-Core-Tests package (including the new GRAPH.CONSTRAINT CREATE/DROP tests added in the previous step). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the GRAPH.CONSTRAINT CREATE/DROP feature (FkGraphEndpoint.class.st and its test file). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
