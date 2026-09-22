# Feature: Add bulk property operations and directional endpoint accessors to FkGraphNode/FkGraphRelationship (Neo4reSt-GraphModel alignment)

## Goal

FkGraphNode gains `properties:` / `mergeProperties:` / `removePropertyAt:` / `deleteWithRelations`.
FkGraphRelationship gains `startNode` / `endNode` / `direction` / `headNode` / `headNodeId` /
`tailNode` / `tailNodeId` / `properties:` / `mergeProperties:` / `removePropertyAt:`. All new API is
covered by passing SUnit tests against a real FalkorDB instance, and the change is lint-clean per
this project's style guide.

## Orchestration Shape

sequential: plan → implement (TDD) → test → lint & review, four separate `seq:` blocks, all via
claude

## Working Directory

/home/mumez/git/Falkor.st (already checked out on branch
`feature/fkgraphnode-fkgraphrelationship-bulk-properties-and-endpoint-accessors`, based on
`develop`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
	builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Plan bulk properties and direction API'.
			t prompt: 'Falkor.st is a Pharo client for FalkorDB. Read CLAUDE.md at the repo root first for project context and workflow (use the smalltalk-dev skills - st-import/st-test/st-lint/st-validate/st-eval - not shell commands, for every Edit -> Import -> Test step in every phase of this orchestration).

Task: FalkorSt-Objects has FkGraphObject (shared superclass, src/FalkorSt-Objects/FkGraphObject.class.st) with subclasses FkGraphNode (src/FalkorSt-Objects/FkGraphNode.class.st) and FkGraphRelationship (src/FalkorSt-Objects/FkGraphRelationship.class.st). Compared with Neo4reSt''s N4Node/N4Relationship (../Neo4reSt/src/Neo4reSt-GraphModel/, reference-only, NOT a dependency - never add it to any Baseline), these are missing:

FkGraphNode:
- properties: (bulk SET of the whole property map)
- mergeProperties: (bulk MERGE of the whole property map)
- removePropertyAt:
- deleteWithRelations (delete the node together with its relationships)

FkGraphRelationship:
- startNode / endNode (fetch the actual FkGraphNode for the id - today only startNodeId/endNodeId exist)
- direction / headNode / headNodeId / tailNode / tailNodeId (direction-aware endpoint accessors)
- properties: / mergeProperties: / removePropertyAt: (same three bulk operations as above)

Read the actual current source before designing anything - do not assume this description is exhaustive:
- src/FalkorSt-Objects/FkGraphObject.class.st - already has propertyAt:put: (SETs one property via a CyQuery built through matchElementNamed:, then #reload''s from FalkorDB) and delete. This is the established pattern for object-level mutations: build Cypher generically here via matchElementNamed: (subclassResponsibility on FkGraphNode/FkGraphRelationship), run it, then self reload. Put properties:/mergeProperties:/removePropertyAt: generically on FkGraphObject (NOT duplicated per subclass) so both FkGraphNode and FkGraphRelationship get them for free - mirror propertyAt:put: exactly, do not delegate to FkGraphDb''s per-type node/relationship methods for this.
- src/FalkorSt-Objects/FkGraphDb.class.st - already has nodeAt:properties: / nodeAt:mergeProperties: / nodeAt:removePropertyAt: / relationshipAt:properties: / relationshipAt:mergeProperties: / relationshipAt:removePropertyAt: / deleteNodeAt:withRelations:. Use these ONLY as a reference for the right SCypher builder calls: `n to: ''values'' asCypherParameter` for whole-map SET, `n addAll: ''values'' asCypherParameter` for whole-map MERGE (+=), `n @ key` passed to `remove:` for REMOVE, and the `valuesArgumentsFor:` helper (`{ ''values'' -> argsDict asDictionary } asDictionary`, accessing-category so callable as `self db valuesArgumentsFor:` from FkGraphObject) for binding the whole-map parameter.
- src/FalkorSt-Objects/FkGraphNode.class.st - deleteWithRelations should just delegate to `self db deleteNodeAt: self id withRelations: true` (FkGraphDb already implements the withRelations: boolean).
- src/FalkorSt-Core/FkRelationship.class.st - the raw decoded relationship value: currently only id/type/startNodeId/endNodeId/properties. No direction concept exists anywhere yet.
- src/FalkorSt-Objects/FkGraphPath.class.st - wraps raw path relationships as `FkGraphRelationship on: each in: self db`, with no direction info passed in today.
- FkGraphNode''s private relationshipsTyped:direction:.../oneHopPathsTyped:direction:... family already knows which direction (#in/#out/nil for either) it queried FkGraphDb with - this is the only place in the codebase that currently knows a relationship''s direction relative to an anchor node.

Open design point to resolve in this plan (do not guess blindly, work it out from the above and from Neo4reSt''s N4Relationship.class.st for inspiration only, not literal copying):
1. N4Relationship''s headNodeId/tailNodeId have an actual BUG in the reference code - the ifTrue: branch is missing its ^ return, so both methods currently always answer the ifFalse case regardless of direction. Do NOT reproduce this bug - headNodeId/tailNodeId must actually branch correctly on direction.
2. N4Relationship''s direction is set by its class>>json:for: constructor, which compares startNodeId against a given anchor node''s id to decide #in/#out - direction is relative to whichever node you fetched the relationship "from", not an intrinsic property. A relationship fetched directly by id (FkGraphDb>>relationshipAt:) has no natural anchor. Design how FkGraphRelationship acquires a direction here: thread the #in/#out/nil direction that FkGraphNode''s relationship-fetching family already tracks through into FkGraphRelationship construction (e.g. extend `on:in:` with a direction-carrying variant), leaving direction nil when genuinely unknown (bare relationshipAt:, or a direction-agnostic path). Decide what headNode/headNodeId/tailNode/tailNodeId do when direction is nil (signal vs. sensible fallback) and write that decision down explicitly.

Produce a short written plan (as your reply, no need to write a file) covering: the exact method signatures to add on FkGraphObject/FkGraphNode/FkGraphRelationship/FkRelationship/FkGraphPath, the direction-acquisition design from point 2 above, and which existing call sites (FkGraphPath, FkGraphNode''s relationship/path families, FkGraphDb''s relationshipAt:/createRelationshipTyped:.../mergeRelationshipTyped:... family) need to change to thread direction through. Class prefix is Fk. Keep it concrete enough that the next phase can implement directly from it - no further research needed.'
		]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Implement bulk properties and direction API (TDD)'.
			t prompt: 'Implement the plan from the previous step using TDD: for each new method, write a failing SUnit test first (in FalkorSt-Core-Tests or FalkorSt-Objects-Tests as appropriate, matching existing test file conventions in src/FalkorSt-Objects-Tests/), then implement the minimum code to make it pass, then confirm green via the st-test skill, before moving to the next method. Use st-import after every edit and st-validate/st-lint incrementally if unsure about Tonel syntax - see CLAUDE.md for the required workflow.

Constraints:
- Minimum code that solves the problem - do not add speculative API beyond what the plan calls for.
- Keep class comments (CRC-style) to a summary of the important API, not an exhaustive method list - only touch the class comments of classes you actually changed (FkGraphObject, FkGraphNode, FkGraphRelationship, FkRelationship, FkGraphPath, and FkGraphDb only if you had to change a call site there), adding just enough to reflect the new public API.
- Integration-style tests that call FalkorDB (GRAPH.QUERY etc.) need the real FalkorDB instance already configured for this project (see CLAUDE.md CI section) - do not mock FalkorDB.
- Follow this project''s existing method-categorization and naming conventions (e.g. "properties", "actions", "actions-labels", "accessing" categories already used in FkGraphNode/FkGraphObject).'.
			t goal: 'all new unit tests for the bulk property operations and directional endpoint accessors on FkGraphNode/FkGraphRelationship are implemented and passing, verified via st-test'
		]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Run full test suite'.
			t prompt: 'Using the st-test skill, import the current state of all locally-managed packages (st-import) and run the FULL test suite for FalkorSt-Core-Tests and FalkorSt-Objects-Tests (not just the tests added in the previous step). Report the full pass/fail counts and, if anything besides the newly-added tests fails, treat it as a regression introduced by this change and fix it (re-running st-test to confirm green afterward) rather than leaving it. Reply with the final test counts and a short note on what, if anything, needed fixing.'
		]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Lint and style review'.
			t prompt: 'Consult the st-lint skill (or the smalltalk-validator MCP tools) against every Tonel .st file changed in this orchestration, and consult the smalltalk-developer skill''s style guide section. Fix whatever issues either surfaces (re-running st-lint/st-validate to confirm clean afterward), then re-import (st-import) and re-run the full test suite (st-test) once more to confirm nothing broke from the cleanup. Reply with a short summary of what was found and fixed, or confirm there was nothing to fix.'
		]
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
step stalls, or check progress with `AbOrchestrationManager default orchestrationAt: <orchestration
script id>`.
