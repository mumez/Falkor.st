# Feature: GRAPH.MEMORY/GRAPH.SLOWLOG support for FkGraphEndpoint

## Goal

`FkGraphEndpoint` supports FalkorDB's `GRAPH.MEMORY USAGE` and `GRAPH.SLOWLOG` diagnostic
commands, each covered by unit tests against a real FalkorDB instance, following this repo's
existing conventions (class prefix `Fk`, method categories). Unlike the raw-reply commands added
so far (`GRAPH.LIST`, `GRAPH.CONFIG`, etc.), both of these decode their reply into a usable
structure instead of answering the raw array, since that is the whole point of the feature (a
shared "decode stats reply" pattern).

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
            t title: 'Implement GRAPH.MEMORY/GRAPH.SLOWLOG (TDD)'.
            t prompt: 'Add support for two FalkorDB read-only diagnostic commands to FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st), in this Pharo/Tonel project. Work test-first (TDD): write a failing SUnit test in FalkorSt-Core-Tests (FkGraphEndpointTest, using the existing FkGraphEndpointTestCase shared setup — a real FalkorDB at sync://localhost:6379 via `self endpoint`), then implement the method(s), then verify the test passes, before moving to the next command. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and style.

IMPORTANT context before you start: every admin/diagnostic command added to this file so far (GRAPH.INFO, GRAPH.CONFIG, GRAPH.CONSTRAINT, GRAPH.EXPLAIN, GRAPH.PROFILE, GRAPH.LIST, GRAPH.COPY) just calls `self unifiedCommand: {...}` and answers the raw undecoded reply. Do NOT copy that pattern here by reflex. This feature is deliberately different: both GRAPH.MEMORY and GRAPH.SLOWLOG must decode their reply into a usable structure before answering it, because that decoding is the actual point of the feature (see specs below).

Concrete specs (verified against docs.falkordb.com and the existing codebase — implement exactly this, do not add anything beyond it):

1. GRAPH.MEMORY USAGE <graph-name> [SAMPLES <count>] — reports memory usage statistics for a graph. The raw reply is a flat RESP array alternating key and value (e.g. key1, value1, key2, value2, ...). Add:
   - `#graphMemoryUsage:` — sends `{ ''GRAPH.MEMORY''. ''USAGE''. graphName }` via #unifiedCommand:, decodes the flat reply into a Dictionary (key -> value) and answers that Dictionary instead of the raw array.
   - `#graphMemoryUsage:samples:` — like the above but appends `''SAMPLES''` and the sample count to the command args before sending, e.g. `{ ''GRAPH.MEMORY''. ''USAGE''. graphName. ''SAMPLES''. sampleCount }`.
   - Factor the flat-array-to-Dictionary decoding into one shared private helper method so both entry points use it (do not duplicate the pairing loop).

2. GRAPH.SLOWLOG <graph-name> — reports the graph''s slowest queries (up to 10 entries). The raw reply is an array of entries, each entry itself an array of exactly 4 elements in this order: timestamp, command name, query text, execution time in ms. (There is no separate "query parameters" element in the actual FalkorDB reply shape — verify this yourself against the live server''s actual reply during TDD, by running a quick query and inspecting the raw GRAPH.SLOWLOG reply via #unifiedCommand: before deciding the final field list, rather than assuming.) Add:
   - `#graphSlowLog:` — sends `{ ''GRAPH.SLOWLOG''. graphName }` via #unifiedCommand:, decodes each raw entry into a small dedicated value object (new class, e.g. `FkSlowLogEntry`, with accessors matching the actual fields you confirm from the live reply — keep it minimal, no speculative fields) and answers an OrderedCollection of the decoded entries (empty OrderedCollection if the raw reply is empty).

Both methods are read-only (no graph mutation, no query execution side effects). Implement them in the existing `commands-graph` method category (put any new private decoding helper(s) in the `private` category, matching how the rest of the file is organized). Do not touch GRAPH.QUERY decoding, compact-id-resolution, or any other command family in this file.

Update FkGraphEndpoint''s class comment (Responsibility, and Public API and Key Messages sections) to mention the new methods and the new `FkSlowLogEntry` collaborator (if you introduce one), following the existing bullet style — extend it, do not rewrite it.

Testing: add tests to FkGraphEndpointTest that exercise the real FalkorDB instance via self endpoint and a dedicated test graph name (do not reuse a shared graph other tests depend on, to avoid collisions). Cover: (a) `#graphMemoryUsage:` on a graph with some data returns a Dictionary with at least one key, (b) `#graphMemoryUsage:samples:` behaves the same with an explicit sample count, (c) `#graphSlowLog:` on a graph that has had at least one query run against it returns a non-empty OrderedCollection of decoded entries with sensible field values, (d) `#graphSlowLog:` on a freshly created graph with no completed queries returns an empty OrderedCollection (skip this case only if the live server does not actually behave this way — verify first rather than assuming). Each test that creates a graph must clean up after itself (drop every test graph it created via #graphDelete:) using an ensure: block, following the restore-safe pattern used elsewhere in FkGraphEndpointTest, so tests do not leave state behind even if an assertion fails. Keep the change minimal and scoped exactly to what is specified above — do not refactor unrelated existing methods.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in the FalkorSt-Core-Tests package (including the new GRAPH.MEMORY/GRAPH.SLOWLOG tests added in the previous step). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the GRAPH.MEMORY/GRAPH.SLOWLOG feature (FkGraphEndpoint.class.st, any new FkSlowLogEntry class file, and the test file). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
