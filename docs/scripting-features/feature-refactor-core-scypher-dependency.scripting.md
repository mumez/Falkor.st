# Feature: refactor — FalkorSt-Core depends on SCypher (index Cypher via SCypher, procedure call moved to Core)

## Goal

Kanban issue `1790858915116-refactor-依存関係の整理`, 案1:

- `FalkorSt-Core` declares an explicit dependency on SCypher in `BaselineOfFalkorSt`.
- Index CREATE/DROP Cypher (`FkGraphIndex`) and index listing (`FkGraphEndpoint>>graphIndexes:`) are
  generated with SCypher instead of hand-rolled quoting/escaping.
- The `graphCallProcedure:*` extension currently in `FalkorSt-Objects` moves into `FalkorSt-Core` as
  regular `FkGraphEndpoint` methods, with its tests.
- All `FalkorSt-Core-Tests` and `FalkorSt-Objects-Tests` pass against a real FalkorDB.

The final phase gives an independent verdict on whether the refactor actually made the code
simpler (案2 = keep the current code if it did not). The outer workflow opens a PR only on
`VERDICT: SIMPLER`; otherwise it comments on the kanban issue and opens no PR.

## Orchestration Shape

sequential: refactor A (dependency + move procedure call) → refactor B (index Cypher via SCypher) →
full test run → lint & review → simplicity evaluation (read-only, emits VERDICT), all via claude

## Working Directory

/home/mumez/git/Falkor.st (branch `refactor/core-scypher-dependency`, based on `develop` @ 38c5155)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Refactor A: Core depends on SCypher, move graphCallProcedure into Core'.
            t prompt: 'Refactor this Pharo/Tonel project (Falkor.st, a FalkorDB client) so that FalkorSt-Core explicitly depends on SCypher. Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle and consult the smalltalk-developer skill for Tonel editing and style. Import only via st-import — never write your own package-loading eval code. Do not commit; leave changes in the working tree.

Background (verified against the current code): FalkorSt-Core used to avoid depending on SCypher, so the procedure-call API was added as extension methods in FalkorSt-Objects. But Core already silently relies on SCypher: FkGraphEndpoint>>cypherParamsClauseFor: calls SCypher''s #cypherValueString. The user has decided (kanban issue, plan 1) to make the dependency explicit.

Do exactly this:
1. src/BaselineOfFalkorSt/BaselineOfFalkorSt.class.st: change package FalkorSt-Core to requires: #(''RediStick'' ''SCypher''). FalkorSt-Objects may keep listing SCypher or rely on Core — keep whichever is simpler and consistent. Do not change anything else in the Baseline.
2. Move every method in src/FalkorSt-Objects/FkGraphEndpoint.extension.st (graphCallProcedure:procedure:, graphCallProcedure:procedure:arguments:, graphCallProcedure:procedure:arguments:yield:readOnly:, procedureCallCypherFor:arguments:yield:, procedureCallParamNameAt:, procedureCallParamsFor:) into src/FalkorSt-Core/FkGraphEndpoint.class.st as regular methods (public ones in the existing commands-graph category, helpers in private or a fitting existing category), unchanged in behavior. Delete the extension file.
3. Move src/FalkorSt-Objects-Tests/FkGraphEndpointProcedureCallTest.class.st into src/FalkorSt-Core-Tests/ (update #category/#package to FalkorSt-Core-Tests). Keep the tests unchanged otherwise.
4. Where Core builds CALL strings by hand, use the moved API / CyCall instead when it is a straightforward simplification: e.g. FkGraphEndpoint>>graphIndexes: (''CALL db.indexes()'') can go through graphCallProcedure:procedure:. For the internal compact id-cache refresh (#refreshCache:graph:procedure:, which sends ''CALL '' , procedureName , ''()'' via rawGraphQuery:cypher:compact: and must stay raw/compact), only switch the string building to CyCall if it stays a one-liner; do not change its raw-reply behavior.
5. FkGraphEndpoint class comment: add the graphCallProcedure API as ONE short bullet (the class comment is a summary of key API, not a reference manual) and update the note that says Core avoids SCypher, if any. README.md: the line saying FalkorSt-Objects adds graphCallProcedure must now say it is part of FkGraphEndpoint (Core).

Re-import in dependency order after moving (FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects, FalkorSt-Objects-Tests) and make sure the image does not keep a stale *FalkorSt-Objects extension of the moved methods. Run FalkorSt-Core-Tests and FalkorSt-Objects-Tests and report the counts.'.
            t goal: 'graphCallProcedure lives in FalkorSt-Core, the Baseline declares the SCypher dependency for Core, and FalkorSt-Core-Tests and FalkorSt-Objects-Tests all pass' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Refactor B: generate index Cypher with SCypher'.
            t prompt: 'In this Pharo/Tonel project (/home/mumez/git/Falkor.st), FalkorSt-Core now depends on SCypher (done in the previous step). Rewrite FkGraphIndex (src/FalkorSt-Core/FkGraphIndex.class.st) so its CREATE/DROP INDEX Cypher is generated with SCypher instead of the hand-rolled helpers (#quotedName:, #quotedString:, #entityPattern, #propertyListFor:, #statementForVerb:properties:options:, #statementPrefixFor:). Keep the public API and behavior: #createCypher, #dropCypherForProperty:, the range/fulltext/vector/cch kinds, node:/relationship:, props:, dimension:, similarityFunction:. Use st-import/st-test/st-eval from the smalltalk-dev plugin and the smalltalk-developer style guide. Import only via st-import. Do not commit.

Facts verified in the running image (SCypher local clone: ../SCypher/repository/SCypher-Core, see CyCreateIndex, CyDropIndex, CyIndexCommand, CyIndexSpecifier, CyCommand, CyCommandSpecifier):
- (CyCreateIndex nodeLabeled: ''Person'' prop: ''age'') cypherString -> ''CREATE INDEX FOR (n:Person) ON (n.age) '' (note TRAILING SPACE).
- Identifiers are escaped by SCypher: (CyCreateIndex nodeLabeled: ''Per`son x'' prop: ''a ge'') -> ''CREATE INDEX FOR (n:`Per``son x`) ON (n.`a ge`) ''.
- (CyCreateIndex relationshipTyped: ''KNOWS'' prop: ''since'') -> ''CREATE INDEX FOR ()-[r:KNOWS]-() ON (r.since) '' — UNDIRECTED pattern, while the current code emits ()-[e:KNOWS]->(). Verify against the real FalkorDB that the undirected form is accepted for create AND drop; if not, report it.
- Index type: (cmd spec: [ :s | s fullText ]) -> CREATE FULLTEXT INDEX ...; arbitrary types via (cmd spec: [ :s | s type: ''VECTOR'' ]) -> CREATE VECTOR INDEX ...; same mechanism for CCH. Range = no type keyword.
- (CyDropIndex nodeLabeled: ''Person'' prop: ''age'') cypherString -> ''DROP INDEX FOR (n:Person) ON (n.age) ''.
- There is NO CyCreateIndex class>>nodeLabeled:props:. Multiple properties: CyCommand class>>target:props: with props as a CyObjects of node @ prop expressions (see CyCommand class>>nodeLabeled:prop: for how a single one is built).
- SCypher has no OPTIONS clause for indexes. Dictionary>>cypherValueString renders JSON-style {"dimension":3,"similarityFunction":"it''s"} (quoted keys, double-quoted strings) which is likely NOT valid FalkorDB Cypher. Keep a minimal, correct OPTIONS {dimension: 3, similarityFunction: ''euclidean''} rendering — using SCypher''s String>>cypherValueString for the string value if it yields a valid single-quoted literal — appended after the SCypher-generated statement. Verify the vector index create works against the real FalkorDB.

Rules:
- Do NOT change SCypher itself. If SCypher lacks something, work around it minimally inside FkGraphIndex and note it in your report (that is input for the later simplicity evaluation).
- Update the expected strings in FkGraphIndexTest (src/FalkorSt-Core-Tests) only where the new output legitimately differs (variable names n/r instead of e, trailing-space trimming, relationship pattern); every integration test that creates/drops/lists indexes against FalkorDB must still pass unchanged in intent.
- Keep FkGraphIndex class comment short; update it if it mentions the hand-rolled quoting.
- FkGraphConstraint uses the GRAPH.CONSTRAINT command, not Cypher — leave it alone.

Run FalkorSt-Core-Tests and FalkorSt-Objects-Tests at the end and report counts, plus a short list of any SCypher gaps you had to work around.'.
            t goal: 'FkGraphIndex generates its CREATE/DROP INDEX Cypher via SCypher and all FalkorSt-Core-Tests and FalkorSt-Objects-Tests pass' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import FalkorSt-Core, FalkorSt-Core-Tests, FalkorSt-Objects and FalkorSt-Objects-Tests (in that order) from /home/mumez/git/Falkor.st/src into the running Pharo image, then run all tests in FalkorSt-Core-Tests and FalkorSt-Objects-Tests. Report the exact pass/fail/error counts per package and the names of any failing tests. If any test fails, fix the implementation or test and re-run until both packages pass, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all changes in /home/mumez/git/Falkor.st against develop (git diff develop, git status) for the "FalkorSt-Core depends on SCypher" refactor. Consult the st-lint skill (or the smalltalk-validator MCP tools) on every changed Tonel file, and the smalltalk-developer skill style guide (intention-revealing names, method categories, short CRC class comments). Also verify: BaselineOfFalkorSt declares SCypher for FalkorSt-Core; src/FalkorSt-Objects/FkGraphEndpoint.extension.st is gone and the moved methods live in FkGraphEndpoint.class.st; FkGraphEndpointProcedureCallTest lives in FalkorSt-Core-Tests; no procedure argument value is string-concatenated into Cypher; no leftover dead hand-rolled quoting helpers; class comments stay summaries; README matches the new placement; SCypher itself was not modified. Fix whatever you find, then re-run st-import and st-test on FalkorSt-Core-Tests and FalkorSt-Objects-Tests. Do not commit. Report what was found and fixed, and the final test counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Simplicity evaluation'.
            t prompt: 'You are an independent evaluator. Do NOT modify any file, do NOT commit — read only. In /home/mumez/git/Falkor.st, a refactor on the current branch (compare with: git diff develop, git diff develop --stat, and git status for new/deleted files) made FalkorSt-Core depend on SCypher, generated index CREATE/DROP/listing Cypher with SCypher instead of hand-rolled quoting, and moved the graphCallProcedure API from FalkorSt-Objects into Core. The kanban issue says: plan 1 = do this refactor; plan 2 = if generating Cypher with SCypher does not make the implementation meaningfully simpler, keep the current code.

Judge whether the PRODUCTION code (src/FalkorSt-Core, src/FalkorSt-Objects, src/BaselineOfFalkorSt — tests count only as secondary evidence) became simpler. Consider and report concretely:
1. Production lines added/removed (exclude test packages and docs), and number of methods before/after in FkGraphIndex and FkGraphEndpoint.
2. Hand-written quoting/escaping/Cypher-assembly code removed vs. new workaround code added to bridge SCypher gaps (e.g. trimming SCypher output, custom OPTIONS rendering, string post-processing of generated Cypher).
3. Whether responsibility is clearer: is the dependency structure (Baseline, package placement of graphCallProcedure) more honest/consistent than before?
4. Any new risk (behavior change such as relationship index pattern direction, reliance on SCypher internals or private API).
5. Test status reported by the previous steps.

Then decide. SIMPLER means: the production code is clearly easier to read and maintain overall (less hand-rolled escaping/assembly, workarounds small and local), even if the line count is roughly equal. NOT_SIMPLER means: workarounds and indirection offset the gains, or the result is harder to follow than develop.

End your answer with a short justification (3-6 bullets) followed by exactly one final line, with nothing after it, either:
VERDICT: SIMPLER
or
VERDICT: NOT_SIMPLER' ]
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

The outer kanban-orchestration-dev workflow reads the last line of the final step's result:
`VERDICT: SIMPLER` → commit, push, and open a PR to `develop`; `VERDICT: NOT_SIMPLER` → append the
evaluation to the kanban issue and open no PR.
