# Feature: procedure-call — graphCallProcedure API for FkGraphEndpoint

## Goal

`FkGraphEndpoint` can call a FalkorDB procedure (`CALL proc(args) YIELD cols`) through a dedicated
API equivalent to falkordb-py's `call_procedure(procedure, read_only, args, emit)`, with arguments
bound as query parameters (never string-concatenated) and the CALL string built with SCypher's
`CyCall`, routed to `GRAPH.RO_QUERY` when read-only and
`GRAPH.QUERY` otherwise, answering an `FkQueryResult`. Covered by unit tests of the generated Cypher
and integration tests against a real FalkorDB. Because `FalkorSt-Core` does not depend on SCypher,
the API is added as extension methods on `FkGraphEndpoint` packaged in `FalkorSt-Objects` (no
Baseline change). This is the common base for the later
index-management / constraint-listing work.

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st (branch `feature/procedure-call-graph-call-procedure`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement graphCallProcedure API (TDD)'.
            t prompt: 'Add a procedure-call API for FkGraphEndpoint in this Pharo/Tonel project, equivalent to falkordb-py''s call_procedure(procedure, read_only, args, emit). Work test-first (TDD): write a failing SUnit test, implement, verify it passes, then move on. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and its style guide. Import only via st-import — never write your own package-loading eval code.

PLACEMENT (decided by the user — follow exactly): the CALL string is built with SCypher''s CyCall, but FalkorSt-Core does NOT depend on SCypher (BaselineOfFalkorSt: FalkorSt-Core requires only RediStick; FalkorSt-Objects requires FalkorSt-Core and SCypher). Do NOT change the Baseline. Instead implement the API as EXTENSION METHODS on FkGraphEndpoint packaged in FalkorSt-Objects: create src/FalkorSt-Objects/FkGraphEndpoint.extension.st (Tonel extension file: Extension { #name : ''FkGraphEndpoint'' } with methods in category ''*FalkorSt-Objects''). Do not modify src/FalkorSt-Core at all.

Public API (extension methods on FkGraphEndpoint):
- #graphCallProcedure: graphName procedure: procedureName arguments: argumentsCollection yield: yieldNamesOrNil readOnly: aBoolean — the full form. Answers an FkQueryResult.
- #graphCallProcedure:procedure: — no arguments, no YIELD, readOnly false.
- #graphCallProcedure:procedure:arguments: — given arguments, no YIELD, readOnly false.
Document these defaults in the method comments.

Behavior (verified against the current code — trust these facts):
1. Arguments are bound as query parameters, NEVER string-concatenated into the query. Build a params dictionary param0 -> first arg, param1 -> second arg, ... and a CALL that references them as $param0, $param1, ...
2. Delegate execution to the existing public FkGraphEndpoint methods #graphQuery:cypher:params: (readOnly false -> GRAPH.QUERY) and #graphRoQuery:cypher:params: (readOnly true -> GRAPH.RO_QUERY). They already prepend CYPHER key=value ... via the private #prependParams:to: (unchanged cypher when the dictionary is empty), use default compact decoding and the endpoint queryTimeoutMsecs. Do not duplicate that logic.
3. Build the CALL string with SCypher''s CyCall (local clone ../SCypher, repository/SCypher-Core/CyCall.class.st), not by hand. Verified in the running image:
   - (CyCall of: ''db.labels'') cypherString -> CALL db.labels()  (note: a TRAILING SPACE is emitted when there is no YIELD — trim it or write tests accordingly)
   - (CyCall of: procName arguments: { ''param0'' asCypherParameter. ''param1'' asCypherParameter }) cypherString -> CALL procName($param0, $param1)
   - YIELD with a single name: (aCall yield: ''label''; yourself) -> ... YIELD label
   - PITFALL: passing an Array of Strings to #yield: renders a list literal (YIELD [...]) — WRONG. For multiple names wrap them in a CyYield: (aCall yield: (CyYield withAll: yieldNames); yourself) with yieldNames = #(''label'' ''properties'') -> ... YIELD label, properties (Strings are fine here; the equivalent identifier form is CyYield of: (''a'' asCypherIdentifier) , (''b'' asCypherIdentifier))
4. Factor the CyCall building (and the params dictionary building) into separately unit-testable extension method(s) with intention-revealing names, so tests can assert the generated Cypher without a server.
5. Do NOT touch the internal CALL db.labels()/db.relationshipTypes()/db.propertyKeys() path in FalkorSt-Core used for compact id-cache refresh.
6. No new value objects, no format-specific result types, no new package, no Baseline change, no changes to RediStick or SCypher (use CyCall/CyYield as they are).

Tests: create a new test class FkGraphEndpointProcedureCallTest in FalkorSt-Objects-Tests (src/FalkorSt-Objects-Tests/), subclass of FkGraphEndpointTestCase (the same shared setup FkGraphDbTest uses — real FalkorDB via self endpoint / stick, self graphName). Give it a short class comment. Cover:
- Unit tests of the generated Cypher / params: 0 arguments, N arguments, with and without YIELD (single and multiple names).
- Integration: in the test graph, create nodes with a couple of distinct labels, then graphCallProcedure:procedure: with db.labels answers those labels.
- Integration: a YIELD subset (a procedure with multiple output columns such as db.indexes or dbms.procedures, whichever exists on current FalkorDB — check first with st-eval) answers only the yielded columns in the result header.
- Integration: a string argument containing single and double quotes is passed safely through param binding (e.g. via a procedure that takes a string argument; if none is convenient, assert on the generated params and that the call executes without a syntax error).
- Integration: readOnly true goes through GRAPH.RO_QUERY (e.g. db.labels works read-only).
Follow the existing cleanup pattern of FkGraphEndpointTestCase/FkGraphDbTest so no graph is left behind even if an assertion fails.

Docs: do NOT edit FkGraphEndpoint''s class comment in FalkorSt-Core (Core must not advertise an Objects-package extension). If FkGraphDb''s class comment or README.md has a natural place listing FkGraphEndpoint capabilities or supported commands, add at most one short line for procedure calls — class comments are summaries of key API, not reference manuals. Keep the change minimal; do not refactor unrelated methods.'.
            t goal: 'all tests in the new FkGraphEndpointProcedureCallTest are passing' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects and FalkorSt-Objects-Tests packages (in that order) from /home/mumez/git/Falkor.st/src into the running Pharo image, then run all tests in the FalkorSt-Core-Tests and FalkorSt-Objects-Tests packages (including the new FkGraphEndpointProcedureCallTest). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in /home/mumez/git/Falkor.st for the graphCallProcedure feature (src/FalkorSt-Objects/FkGraphEndpoint.extension.st, the new FkGraphEndpointProcedureCallTest, and README.md / FkGraphDb class comment if touched; use git diff develop and git status to see the changes). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill style guide section for conventions (intention-revealing names, method categorization, short CRC class comment). Also verify: argument values are never string-concatenated into the Cypher (only $paramN references), CyCall is used to build the CALL string, nothing under src/FalkorSt-Core or src/BaselineOfFalkorSt was changed, any doc addition is a single short line (not a per-method reference), and the internal db.labels id-cache refresh path is unchanged. Fix whatever issues these checks surface, then re-run st-import and st-test on FalkorSt-Core-Tests and FalkorSt-Objects-Tests to confirm everything still imports cleanly and all tests still pass. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
