# Feature: FkGraphConstraint value class for GRAPH.CONSTRAINT CREATE/DROP

## Goal

`FkGraphEndpoint` gains a friendlier, object-based way to build and issue GRAPH.CONSTRAINT
CREATE/DROP commands via a new `FkGraphConstraint` value class, on top of the existing
`#graphConstraintCreate:type:entityType:entityName:properties:` /
`#graphConstraintDrop:type:entityType:entityName:properties:` methods (kept unchanged as the
delegation target), each covered by unit tests against a real FalkorDB instance.

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude

## Working Directory

/home/mumez/git/Falkor.st

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
    builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Implement FkGraphConstraint value class (TDD)'.
            t prompt: 'This Pharo/Tonel project (FalkorDB client, class prefix Fk) currently has two positional-argument methods on FkGraphEndpoint (src/FalkorSt-Core/FkGraphEndpoint.class.st): #graphConstraintCreate:type:entityType:entityName:properties: and #graphConstraintDrop:type:entityType:entityName:properties: (both already implemented and tested — do not remove or change their signatures or behavior, they stay as the delegation target). Add a friendlier object-based API on top of them, following this repo''s existing conventions (Fk class prefix, method categories, CRC-style class comments — see FkGraphEndpoint and FkGraphInfoOptions for the house style) and TDD (write a failing SUnit test first, then implement, then verify green, for each piece below before moving on). Use the smalltalk-dev plugin skills (st-import, st-test, st-eval) for the edit/import/test cycle, and consult the smalltalk-developer skill for Tonel editing and style.

A source note on the originating ticket: it sketched the desired call shape as `constraint := FkGraphConstraint unique node props: #(...). endpoint graphConstraintCreateWith: constraint.` and a block form `endpoint graphConstraintCreateBy: [:const | const unique node props: #(...)]`. That sketch is illustrative only and is incomplete as written — it omits the entity name (NODE label / RELATIONSHIP type) and the graph name, both of which GRAPH.CONSTRAINT CREATE/DROP require (see the existing #graphConstraintCreate:type:entityType:entityName:properties: signature). Implement the complete, concrete design below instead, which preserves the spirit of the sketch (fluent builder + block/options-pattern variant, delegating to the existing methods) while being fully specified:

1. New class FkGraphConstraint (superclass Object, package/category FalkorSt-Core) with instance variables constraintType, entityType, entityName, properties. Give it a CRC-style class comment (Responsibility/Collaborators/Public API and Key Messages) matching the style of FkGraphInfoOptions''s comment.

2. Instance-side fluent mutators, each setting the relevant field and answering self so sends chain (e.g. `FkGraphConstraint new unique node: ''Person'' props: #(''first_name'' ''last_name'')`):
   - #unique - sets constraintType to ''UNIQUE''
   - #mandatory - sets constraintType to ''MANDATORY''
   - #node: aLabel - sets entityType to ''NODE'' and entityName to aLabel
   - #relationship: aRelType - sets entityType to ''RELATIONSHIP'' and entityName to aRelType
   - #props: aCollection - sets properties to aCollection
   Also add plain accessors (constraintType, entityType, entityName, properties) since FkGraphEndpoint will read these to build the delegated call.

3. On FkGraphEndpoint, add four new commands-graph-category methods, each validating nothing extra and simply reading the FkGraphConstraint''s fields to delegate to the existing positional methods:
   - #graphConstraintCreateWith:on: (aFkGraphConstraint, aGraphName) -> delegates to graphConstraintCreate:type:entityType:entityName:properties:
   - #graphConstraintCreateBy:on: (aBlock, aGraphName) -> creates `FkGraphConstraint new`, evaluates aBlock with it (block mutates and returns the constraint, mirroring how #graphInfo: evaluates its optionsBlock against a fresh FkGraphInfoOptions), then delegates the same way
   - #graphConstraintDropWith:on: (aFkGraphConstraint, aGraphName) -> delegates to graphConstraintDrop:type:entityType:entityName:properties:
   - #graphConstraintDropBy:on: (aBlock, aGraphName) -> same block-based pattern as the create variant, delegating to graphConstraintDrop:type:entityType:entityName:properties:
   Choose exact argument order/keyword wording only if you find a clearly better idiomatic alternative that still reads naturally as "with this constraint, on this graph" / "by building via this block, on this graph" — but keep the four methods symmetric in shape (2 create + 2 drop, each with a with:on: and a by:on: variant) and keep the delegation to the existing positional methods (do not duplicate the GRAPH.CONSTRAINT argument-building logic).

4. Update FkGraphEndpoint''s class comment (Public API and Key Messages, and Collaborators sections) to mention the four new methods and FkGraphConstraint, following the existing bullet style — extend it, do not rewrite it. If the project README documents supported GRAPH.CONSTRAINT usage, update it too, mirroring how the existing constraint methods were documented.

Do NOT change the two existing positional-argument methods'' signatures, remove them, or change GRAPH.QUERY decoding or any other command family. Keep scope to exactly: the new FkGraphConstraint class and the four new FkGraphEndpoint delegation methods described above.

Testing: add tests to FkGraphEndpointTest (FalkorSt-Core-Tests) exercising the real FalkorDB instance via `self endpoint` and a dedicated test graph name (not shared with other tests, to avoid collisions). Cover at least: (a) FkGraphConstraint''s fluent builder produces the expected constraintType/entityType/entityName/properties for both unique+node and mandatory+relationship combinations, (b) #graphConstraintCreateWith:on: successfully creates a constraint end-to-end against FalkorDB, (c) #graphConstraintCreateBy:on: does the same via the block form, (d) #graphConstraintDropWith:on: and #graphConstraintDropBy:on: each successfully drop a previously created constraint. Each test that creates a constraint or a graph must clean up after itself (drop the constraint and/or the test graph) using an ensure: block, following the restore-safe pattern already used elsewhere in FkGraphEndpointTest (e.g. testGraphConfigSetUpdatesParamValue), so tests do not leave state behind even if an assertion fails.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Run full test suite'.
            t prompt: 'Using the smalltalk-dev plugin st-import and st-test skills (or the equivalent smalltalk-interop MCP tools), import the FalkorSt-Core and FalkorSt-Core-Tests packages from this repo''s src/ directory into the running Pharo image, then run all tests in the FalkorSt-Core-Tests package (including the new FkGraphConstraint / GRAPH.CONSTRAINT tests added in the previous step). Report the exact pass/fail/error counts and the names of any failing tests. If any test fails, fix the implementation or test and re-run until the full package passes, then report the final counts.' ]
    } agentBy: [ :a | a claude ].
    builder seq: {
        builder topicBy: [ :t |
            t title: 'Lint and review'.
            t prompt: 'Review all Tonel files changed in this working directory for the FkGraphConstraint feature (the new FkGraphConstraint.class.st, the modified FkGraphEndpoint.class.st, and the modified test file). Consult the st-lint skill (or the smalltalk-validator MCP tools) to lint the changed Tonel files, and consult the smalltalk-developer skill''s style guide section for Smalltalk conventions (naming, method categorization, class comment format). Fix whatever issues either check surfaces, then re-run st-import and st-test to confirm everything still imports cleanly and all tests still pass after the fixes. Report a summary of what was found and fixed, or confirm there was nothing to fix.' ]
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
