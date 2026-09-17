# Feature: GRAPH.LIST/GRAPH.COPY support for FkGraphEndpoint

## Goal

`FkGraphEndpoint` supports FalkorDB's `GRAPH.LIST` and `GRAPH.COPY` commands, each covered by unit
tests against a real FalkorDB instance, following this repo's existing conventions (class prefix
`Fk`, method categories, undecoded-raw-reply convention already used for
`GRAPH.DELETE`/`GRAPH.CONFIG`).

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
            t title: 'Implement GRAPH.LIST/GRAPH.COPY (TDD)'.
            t prompt: 'Add support for two FalkorDB "graph-lifecycle" commands to FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st), in this Pharo/Tonel project. Work test-first (TDD): write a failing SUnit test in FalkorSt-Core-Tests (FkGraphEndpointTest, using the existing FkGraphEndpointTestCase shared setup — a real FalkorDB at sync://localhost:6379 via `self endpoint`), then implement the method(s), then verify the test passes, before moving to the next command. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and style.

Concrete specs (already verified against docs.falkordb.com and the existing codebase — implement exactly this, do not add anything beyond it):

1. GRAPH.LIST — no arguments beyond the command name itself; lists all graph names currently present in the keyspace. Answers a raw, undecoded reply (an array of graph-name strings) — do not decode it into any value object.

2. GRAPH.COPY src dest — duplicates the graph named src into a new graph named dest (the source graph remains accessible while the copy is in progress). Answers a raw, undecoded status reply.

Neither command takes any optional flags. Implement exactly these two public methods in the existing `commands-graph` method category, mirroring the simplest existing example, `#graphDelete:` (`^ self unifiedCommand: { ''GRAPH.DELETE''. graphName }`):
- `#graphList` — sends `{ ''GRAPH.LIST'' }` via #unifiedCommand:, answers the raw reply.
- `#graphCopy:to:` — sends `{ ''GRAPH.COPY''. srcGraphName. destGraphName }` via #unifiedCommand:, answers the raw reply.

Do NOT implement any result decoding, value object, or additional variant for either command — not requested, keep scope to exactly the two methods described above. Do not touch GRAPH.QUERY decoding, compact-id-resolution, or any other command family in this file.

Update FkGraphEndpoint''s class comment (Responsibility, and Public API and Key Messages sections) to mention the two new methods, following the existing bullet style — extend it, do not rewrite it. If the project README documents supported GRAPH.* commands (check for a commands/features list), add GRAPH.LIST/GRAPH.COPY there too, mirroring how GRAPH.CONFIG/GRAPH.CONSTRAINT were documented previously.

Testing: add tests to FkGraphEndpointTest that exercise the real FalkorDB instance via self endpoint and dedicated test graph names (do not reuse a shared graph other tests depend on, to avoid collisions). Cover: (a) after creating a graph via a simple query (e.g. a CREATE), GRAPH.LIST''s reply contains that graph''s name, (b) GRAPH.COPY successfully copies a graph such that the destination graph name appears in a subsequent GRAPH.LIST reply, and querying the destination graph returns the copied data. Each test that creates a graph must clean up after itself (drop every test graph it created, source and destination alike, via #graphDelete:) using an ensure: block, following the restore-safe pattern used elsewhere in FkGraphEndpointTest, so tests do not leave state behind even if an assertion fails. Keep the change minimal and scoped exactly to what is specified above — do not refactor unrelated existing methods.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in the FalkorSt-Core-Tests package (including the new GRAPH.LIST/GRAPH.COPY tests added in the previous step). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the GRAPH.LIST/GRAPH.COPY feature (FkGraphEndpoint.class.st and its test file). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
