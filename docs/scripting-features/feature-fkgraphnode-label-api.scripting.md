# Feature: FkGraphNode: ラベル操作APIの追加 (Neo4reSt整合)

## Goal

`FkGraphNode` (src/FalkorSt-Objects/FkGraphNode.class.st) gains the label-manipulation API that is
entirely missing compared to Neo4reSt's `N4Node`: `addLabel:`/`addLabels:`, `removeLabel:`/
`removeLabels:`, `allLabels` (re-queries FalkorDB for the node's current labels, distinct from the
existing local-cache-only `#labels`), and `label` (first-label shortcut, `nil` when empty). All new
methods are covered by integration tests against a real FalkorDB instance, and the class comment's
"Public API and Key Messages" section is updated to mention them (summary only, not exhaustive).

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude, each phase its own `seq:` block

## Working Directory

/home/mumez/git/Falkor.st (already on branch `feature/fkgraphnode-label-api`, branched from `develop`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
	builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Implement FkGraphNode label-manipulation API'.
			t prompt: 'Add label-manipulation methods to FkGraphNode (src/FalkorSt-Objects/FkGraphNode.class.st) in this Pharo/Tonel repository (falkor.st, a FalkorDB client built on RediStick + SCypher). Use the smalltalk-dev plugin skills (st-init, st-import, st-eval, st-test) for the Edit -> Import -> Test cycle, and follow the smalltalk-developer skill''s style guide. Work test-first: write a failing SUnit test for each method in src/FalkorSt-Objects-Tests/FkGraphNodeTest.class.st (this test class already exists - add methods to it), then implement it, then confirm it passes.

Read src/FalkorSt-Objects/FkGraphNode.class.st and its superclass src/FalkorSt-Objects/FkGraphObject.class.st in full before starting. Key facts already confirmed by reading the code:
- FkGraphNode already has an instance method `#labels` implemented as `^ self rawGraphObject labels` - this reads only the locally-cached decoded node, NOT the database''s current state. The new `allLabels` method must be a *different* method that re-queries FalkorDB, so it does not collide with or change the meaning of the existing `#labels`.
- FkGraphObject (the superclass) establishes this project''s pattern for mutating an existing node/relationship by id: build a CyQuery with `self matchElementNamed: n` (FkGraphNode''s implementation of this returns `CyNode name: anIdentifier`) matched by `(n getId equals: self id)`, run it via `self db runCypher:`, then call `self reload` (also inherited from FkGraphObject) to re-fetch the raw node from FalkorDB and replace `rawGraphObject` with the fresh copy. See `FkGraphObject >> propertyAt:put:` for the exact shape to mirror:
  ```
  FkGraphObject >> propertyAt: key put: value [
      | n element query |
      n := ''n'' asCypherIdentifier.
      element := self matchElementNamed: n.
      query := CyQuery match: element where: (n getId equals: self id) set: { (n @ key) to: value }.
      self db runCypher: query.
      self reload
  ]
  ```
- The reference implementation for this feature is N4Node (../Neo4reSt/src/Neo4reSt-GraphModel/N4Node.class.st, category ''actions-labels''/''accessing'', reference-only, not a dependency) but its addLabels:/removeLabels: are Neo4j-REST-specific: they bind query params, use `cypherStatusOfContainUpdates:`, return a Boolean, and manually patch the locally-cached raw object on success (`self rawGraphObject addLabels: labels`). Do NOT port that shape. Instead follow this project''s own established run-then-reload pattern shown above - do not return a Boolean, do not manually patch rawGraphObject, just run the Cypher and call self reload (matching propertyAt:put:''s convention exactly).

Add these methods to FkGraphNode:

- `addLabel: label` - wraps a single label into an Array and delegates to `addLabels:`, i.e. `^ self addLabels: { label }`.
- `addLabels: labels` - builds `n := ''n'' asCypherIdentifier. element := self matchElementNamed: n. query := CyQuery match: element where: (n getId equals: self id) set: (n labels: labels).` (SCypher''s `CyIdentifier >> labels: aCollection` answers a `CySetItemExpression` that can be passed directly to `set:` without wrapping it in an Array - do not write `set: { ... }` for this one, just `set: (n labels: labels)`), then `self db runCypher: query. self reload` per the established pattern - no boolean return value.
- `removeLabel: label` - wraps a single label into an Array and delegates to `removeLabels:`, i.e. `^ self removeLabels: { label }`.
- `removeLabels: labels` - same shape as addLabels: but with `remove: (n labels: labels)` instead of `set: (n labels: labels)` in the CyQuery (SCypher''s `CyQuery class >> match:where:remove:` exists and takes a single removal expression the same way `match:where:set:` takes a single set expression).
- `allLabels` - re-queries FalkorDB for the node''s current labels rather than reading the local cache. Build `n := ''n'' asCypherIdentifier. node := self matchElementNamed: n. query := CyQuery match: node where: (n getId equals: self id) return: n labels.` (SCypher''s `CyObject >> labels` - inherited by `CyIdentifier` - answers `CyFuncInvocation labels: self`, i.e. passing the bare identifier `n` as the return expression renders `labels(n)` in the generated Cypher; this is the same idiom FkGraphDb''s own `allLabels` method already uses (`n labels`), so match that existing convention rather than writing out `CyFuncInvocation labels: n` explicitly). Run this with `self db runReadOnlyCypher: query` (read-only, no mutation) and answer the first record''s first value directly: `^ result records first first`.
- `label` - first-label shortcut. `| labels | labels := self labels. labels isEmpty ifTrue: [ ^ nil ]. ^ labels first`. This reads the local `#labels` cache (matching N4Node''s convention), not `allLabels`.

After implementing, update the class comment''s "Public API and Key Messages" section (and "Responsibility" section if appropriate) to mention the new methods in one or two lines each, at the same level of detail as the existing entries - do not turn the class comment into an exhaustive method reference; keep it a summary per this project''s conventions.

Tests to add to FkGraphNodeTest (create a node with an initial label, then exercise each new method against a real FalkorDB instance):
- addLabel:/addLabels: actually add the label(s), visible via both the existing `#labels` (after reload) and the new `#allLabels`.
- removeLabel:/removeLabels: actually remove the label(s), visible via both `#labels` and `#allLabels`.
- `#label` returns the first label when one or more labels exist, and `nil` when the node has no labels at all (create a labelless node for this case if FkGraphNode/FkGraphDb''s existing node-creation API supports it, e.g. via an empty labels array).

Do not modify any other existing FkGraphNode method''s behavior, do not touch FkGraphDb''s own (already-implemented, out of scope) global `allLabels`/`allRelationshipTypes` methods, and do not add any new value-object classes.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Run the FalkorSt test suite for the new label API'.
			t prompt: 'Run the full FalkorSt-Core-Tests / FalkorSt-Objects-Tests test suite in this repository (falkor.st) using the st-test skill (or the run_package_test / run_class_test MCP tools), after re-importing any changed packages with st-import if needed. Report the full pass/fail counts, and specifically confirm that the new tests for FkGraphNode''s addLabel:, addLabels:, removeLabel:, removeLabels:, allLabels, and label methods (added in the previous step) all pass against the real FalkorDB test instance. If anything fails, investigate and fix it (following the smalltalk-debugger skill if needed) until the whole suite is green, then re-run to confirm.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Lint and review the FkGraphNode changes'.
			t prompt: 'Lint and review the changes made to src/FalkorSt-Objects/FkGraphNode.class.st (and its test file src/FalkorSt-Objects-Tests/FkGraphNodeTest.class.st) in this repository (falkor.st) for the new label-manipulation API (addLabel:, addLabels:, removeLabel:, removeLabels:, allLabels, label). Use the st-lint skill (or the smalltalk-validator MCP tools lint_tonel_smalltalk_from_file / validate_tonel_smalltalk_from_file) against the changed Tonel files, and check the changes against the smalltalk-developer skill''s style guide section (naming, method categorization, Tonel syntax, class comment conventions). Fix anything the lint or style review turns up, re-import and re-run the affected tests to confirm everything still passes after any fixes, and report a summary of what was checked and fixed.' ]
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
