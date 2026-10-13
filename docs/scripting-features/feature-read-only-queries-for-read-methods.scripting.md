# Feature: Read-only queries for read methods

## Goal

Read-only methods (`FkGraphDb>>indexes`, `>>constraints`, `>>nodeAt:`, `>>nodesLabeled:...`, and
every other pure read found by the audit) no longer create a graph that does not exist yet. They go
through `GRAPH.RO_QUERY` and answer an empty/nil/false value for a missing graph, and `db exists`
stays `false` afterwards. Every changed method is covered by a test that failed before the change.

Repro (Kanban-lo issue `1791880664645`):

```smalltalk
db := FkGraphDb named: 'aaa'.
db exists.   "false"
db indexes.  "empty collection"
db exists.   "true - the read created the graph"
```

## Orchestration Shape

sequential, 4 separate `seq:` blocks: (1) inventory audit → docs/read-only-query-audit.md (no src/
changes) → (2) TDD implementation driven by the audit → (3) full test run → (4) lint & review, all
via claude

## Working Directory

/home/mumez/git/Falkor.st (branch `feature/read-only-queries-for-read-methods`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Phase 1: audit read methods that use GRAPH.QUERY'.
            t prompt: 'PHASE 1 - INVENTORY ONLY. Do NOT modify anything under src/ in this step; the only file you may create is docs/read-only-query-audit.md.

Context (Pharo/Tonel project Falkor.st, a FalkorDB client): GRAPH.QUERY creates a graph that does not exist yet, GRAPH.RO_QUERY does not. Several read-only methods use GRAPH.QUERY and therefore silently create missing graphs. Repro:
  db := FkGraphDb named: ''aaa''. db exists "false". db indexes "empty collection". db exists "true!"
Already verified causes:
- FkGraphEndpoint>>graphIndexes: and >>graphConstraints: (src/FalkorSt-Core/FkGraphEndpoint.class.st) call #graphCallProcedure:procedure:, which is read-write (GRAPH.QUERY). The readOnly: variant #graphCallProcedure:procedure:arguments:yield:readOnly: already exists.
- FkGraphDb>>nodeAt: (src/FalkorSt-Objects/FkGraphDb.class.st) and other read methods call #runCypher: / #runCypher:arguments:.
- The read-only path already exists on FkGraphDb: #runReadOnlyCypher:* and #callReadOnlyProcedure:* both wrap GRAPH.RO_QUERY in #answerEmptyResultIfGraphIsMissingDuring:, which answers an empty FkQueryResult when the graph does not exist (and passes the error on otherwise).

Task: audit EVERY call site of #runCypher:, #runCypher:arguments:, #runCypher:arguments:timeout:, non-readOnly #graphCallProcedure:*, and #graphQuery:* in src/FalkorSt-Core, src/FalkorSt-Objects and src/FalkorSt-Udf (skip FalkorSt-Benchmarks). Trace each one back to the public method(s) that reach it (including FkGraphObject / FkGraphNode / FkGraphRelationship methods that go through their db). Classify each public method as:
  (a) pure read - must move to GRAPH.RO_QUERY,
  (b) write - must stay GRAPH.QUERY (CREATE / SET / DELETE / REMOVE / index or constraint creation etc.),
  (c) ambiguous - with a concrete reason (e.g. MERGE / get-or-create, conditional writes, procedures that may write, UDF loading).
Read the actual Cypher each method builds, do not guess from the selector name.

Decide the layering for the endpoint-level methods graphIndexes: / graphConstraints:. The recommended approach is: make them use readOnly: true (GRAPH.RO_QUERY), and have FkGraphDb>>indexes / >>constraints answer an empty collection for a missing graph via #answerEmptyResultIfGraphIsMissingDuring: (or via #callReadOnlyProcedure:). Verify this against the code and state explicitly what a direct FkGraphEndpoint caller would observe on a missing graph after the change (RO_QUERY on a missing graph raises RsGenericError at endpoint level) and whether any existing test or caller depends on the old behaviour. Avoid duplicating the procedure-to-value-object mapping (FkGraphIndexInfo / FkGraphConstraintInfo fromRecord:) between the two layers.

For every (a) item, also determine the return value on a missing graph once it gets an empty FkQueryResult (no records): nil for single-object lookups, empty collection for listings, 0 for counts, false for existence checks, etc. Check each method''s existing result handling (e.g. #firstNodeOrNilFrom:, #oneValueIfNone:, direct #first / #records first calls) and flag any that would raise on zero records and need a change.

Write docs/read-only-query-audit.md containing:
1. A short summary of the problem and the chosen layering decision with its rationale.
2. A table with columns: Class | Selector | Current call | Classification (a/b/c) | Planned change | Expected result on missing graph. Every public read method reached by the audited call sites must appear; (b) items may be listed compactly.
3. A section listing (c) items with the reason and the decision (change or leave as is).
4. A section listing the planned new tests (test class, test selector, what it asserts).
This document is the contract for phase 2; be complete and precise. Finish by replying with a concise summary of the table (counts per classification and the list of (a) selectors).' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Phase 2: TDD implementation from the audit'.
            t prompt: 'PHASE 2 - TDD IMPLEMENTATION. Implement exactly the changes planned in docs/read-only-query-audit.md (written in the previous phase) in this Pharo/Tonel project. Read that document first; it is the contract. Do not change (b) items. Leave (c) items untouched unless the document explicitly decided to change them. If, while working, you find the document wrong about something, fix the document as well and note the correction in your final reply.

Work strictly test-first, one (a) item (or one tightly related group, e.g. indexes + graphIndexes:) at a time:
1. RED: write an SUnit integration test (real FalkorDB, same style and helpers as the existing tests in src/FalkorSt-Core-Tests and src/FalkorSt-Objects-Tests - check how they name and clean up test graphs) that calls the method on a graph that does not exist and asserts (i) the documented empty/nil/false/0 result and (ii) that the graph still does not exist afterwards (db exists is false, or graphList does not include the name for endpoint-level methods). For endpoint methods that will now raise on a missing graph, assert the documented behaviour instead. Import with st-import and run with st-test, and confirm the new test FAILS for the expected reason (the graph got created) before touching the implementation.
2. GREEN: switch the implementation to #runReadOnlyCypher:* / #callReadOnlyProcedure:* / readOnly: true as planned, adjust result handling for zero records if the document says so, re-import, and confirm the test passes.
3. Make sure existing tests that exercise the same method on an existing graph still pass.

Rules: use the smalltalk-dev skills st-import / st-test (never load packages with ad-hoc eval code); consult the smalltalk-developer skill style guide when editing .st files; keep names intention-revealing and DRY; write the minimum code. Update a class comment only where the documented behaviour of an important public API changes, and keep class comments a concise summary rather than a method reference. Do not commit; leave changes uncommitted. Reply with the list of changed methods and new tests.'.
            t goal: 'every (a) item in docs/read-only-query-audit.md is implemented, each has a new test that was confirmed red before the change, and all new tests pass' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suites'.
            t prompt: 'Using the smalltalk-dev st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import all changed packages from this repo''s src/ directory (FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests, and FalkorSt-Udf / FalkorSt-Udf-Tests if they were touched) into the running Pharo image, in dependency order. Then run ALL tests in FalkorSt-Core-Tests and FalkorSt-Objects-Tests (and FalkorSt-Udf-Tests if touched). Report the exact pass/fail/error counts per package and the names of any failing tests. If anything fails, determine whether it is caused by this change (read-only query switch); fix the implementation or the test and re-run until all pass, then report the final counts. Do not commit.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all changes in this working directory (git diff against develop) for the read-only query fix: the changed .st files under src/ and docs/read-only-query-audit.md. Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint every changed Tonel file, and consult the smalltalk-developer skill style guide section (naming, method categories, class comment format). Also check: no (b) write method was switched to read-only; the audit document matches the final code; class comments stay concise summaries of important APIs, not method references; no duplicated logic was introduced between FkGraphEndpoint and FkGraphDb. Fix what you find, then re-run st-import and st-test for the affected packages to confirm everything still passes. Do not commit. Reply with a summary of findings and fixes, plus the final test counts.' ]
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
