# Feature: RO_QUERY, DELETE, INFO support for FkGraphEndpoint

## Goal

`FkGraphEndpoint` supports FalkorDB's `GRAPH.RO_QUERY`, `GRAPH.DELETE`, and `GRAPH.INFO` commands,
each covered by unit tests, following this repo's existing conventions (class prefix `Fk`, method
categories, RediStick's Options-object pattern for `GRAPH.INFO`'s optional sections).

## Orchestration Shape

sequential: implement (TDD, all three commands) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement GRAPH.RO_QUERY, GRAPH.DELETE, GRAPH.INFO (TDD)'.
            t prompt: 'Add support for three FalkorDB commands to FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st), in this Pharo/Tonel project. Work test-first (TDD): for each command, write a failing SUnit test in FalkorSt-Core-Tests (following the existing FkGraphEndpointTestCase shared setup pattern already used for GRAPH.QUERY tests), then implement the method(s), then verify the test passes, before moving to the next command. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and style.

Concrete specs (already verified against docs.falkordb.com and the existing codebase — implement exactly this, do not add anything beyond it):

1. GRAPH.RO_QUERY <graph_name> <query> [--compact] — read-only Cypher query, same result-set shape as GRAPH.QUERY (verbose or compact), decoding into the same FkQueryResult value objects that GRAPH.QUERY already uses. Mirror the existing method family on FkGraphEndpoint exactly, one-for-one, just renamed and targeting GRAPH.RO_QUERY instead of GRAPH.QUERY:
   - #graphQuery:cypher: -> #graphRoQuery:cypher:
   - #graphQuery:cypher:compact: -> #graphRoQuery:cypher:compact:
   - #graphQuery:cypher:params: -> #graphRoQuery:cypher:params:
   - #graphQuery:cypher:params:compact: -> #graphRoQuery:cypher:params:compact:
   - #rawGraphQuery:cypher:compact: -> #rawGraphRoQuery:cypher:compact:
   Reuse the existing #cypherLiteralFor:/#cypherParamsClauseFor:/#cypherStringLiteralFor:/#prependParams:to: private helpers rather than duplicating them. Do NOT add timeout or version arguments — those are explicitly out of scope, matching how GRAPH.QUERY itself does not support them in this codebase.

2. GRAPH.DELETE <graph_name> — deletes an entire graph, returns a plain status string reply (no FkQueryResult decoding, unlike GRAPH.QUERY/GRAPH.RO_QUERY). Add one method: #graphDelete: graphName, sending the command GRAPH.DELETE plus graphName as an array via #unifiedCommand: and answering the raw reply directly.

3. GRAPH.INFO [Section [Section ...]] — sections are the literal strings RunningQueries, WaitingQueries, ObjectPool; omitting all sections returns all three (server-side default), so this is the one command with genuinely optional parameters and needs RediStick''s Options-object pattern (see src/RediStick-Json/RsJsonGetOptions.class.st and its jsonGet:paths:using: wiring in RsRedisEndpoint.extension.st in the local ../RediStick clone, both readable from this repo''s sibling directory, for the pattern to follow):
   - New class FkGraphInfoOptions (superclass Object, package FalkorSt-Core) with three nilable instance variables: runningQueries, waitingQueries, objectPool (each a Boolean or nil), each with a getter and setter in an accessing method category.
   - #asArray on FkGraphInfoOptions answers an OrderedCollection (or Array) containing the string RunningQueries if runningQueries = true, WaitingQueries if waitingQueries = true, ObjectPool if objectPool = true, in that order — answering an empty collection if none are set to true (matching the server''s "omit all = return all" semantics; do NOT special-case "all nil/false" to mean something else).
   - On FkGraphEndpoint: #graphInfo (no args) sends GRAPH.INFO with no extra args via #unifiedCommand: and answers the raw reply. #graphInfo: optionsBlock creates an FkGraphInfoOptions new, evaluates optionsBlock with it (same shape as RsRedisEndpoint>>jsonGet:paths:using:), appends its #asArray to the GRAPH.INFO command args, sends it via #unifiedCommand:, and answers the raw reply. Neither method decodes the reply into a value object — GRAPH.INFO''s section arrays are heterogeneous ad-hoc data, not FkQueryResult-shaped output, so a future change can add structured decoding if ever needed. Do not build that decoding now.

For all three: put the new command methods in the existing commands-graph method category (matching #graphQuery:cypher: etc.), and any new private helpers in private/accessing as appropriate, matching FkGraphEndpoint''s existing category conventions. Update FkGraphEndpoint''s class comment (Responsibility and Public API and Key Messages sections) to mention the three new commands. Keep the change minimal and scoped exactly to what is specified above — do not refactor unrelated existing methods, do not add timeout/version support to RO_QUERY, do not add result decoding for DELETE or INFO.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in the FalkorSt-Core-Tests package (including the new GRAPH.RO_QUERY, GRAPH.DELETE, and GRAPH.INFO tests added in the previous step). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the GRAPH.RO_QUERY / GRAPH.DELETE / GRAPH.INFO feature (FkGraphEndpoint.class.st, the new FkGraphInfoOptions class, and their test files). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
