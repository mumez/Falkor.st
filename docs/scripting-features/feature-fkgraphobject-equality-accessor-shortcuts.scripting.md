# Feature: FkGraphObject: 等価性・アクセサショートカットの追加 (Neo4reSt整合、低優先度)

## Goal

`FkGraphObject` (src/FalkorSt-Objects/FkGraphObject.class.st) gains the small set of comparison and
accessor-shortcut methods that Neo4reSt's `N4GraphObject` has and falkor.st is missing: `=`/`hash`
(id+class equality instead of identity), `@`/`at:`/`at:put:` (shortcuts for `propertyAt:`/
`propertyAt:put:`), and `name`/`name:` (shortcuts for the `'name'` property). All new methods
delegate to `FkGraphObject`'s existing members only (`id`, `propertyAt:`, `propertyAt:put:`) - no
new instance variables, no new Cypher queries. Covered by unit tests added to `FkGraphNodeTest`
(the only concrete `FkGraphObject` subclass on this branch), and the class comment's "Public API
and Key Messages" section is updated to mention them (summary only, not exhaustive).

## Orchestration Shape

sequential: implement (TDD) → test → lint & review, all via claude, each phase its own `seq:` block

## Working Directory

/home/mumez/git/Falkor.st (already on branch `feature/fkgraphobject-equality-accessor-shortcuts`,
branched from `develop`)

## Script

```Smalltalk
| script |
script := AgenticBrowser scriptBy: [ :builder |
	builder sharedDirectoryPath: '/home/mumez/git/Falkor.st'.
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Implement FkGraphObject equality and accessor-shortcut methods'.
			t prompt: 'Add equality and accessor-shortcut methods to FkGraphObject (src/FalkorSt-Objects/FkGraphObject.class.st) in this Pharo/Tonel repository (falkor.st, a FalkorDB client built on RediStick + SCypher). Use the smalltalk-dev plugin skills (st-init, st-import, st-eval, st-test) for the Edit -> Import -> Test cycle, and follow the smalltalk-developer skill''s style guide. Work test-first: write a failing SUnit test for each method in src/FalkorSt-Objects-Tests/FkGraphNodeTest.class.st (this test class already exists - add methods to it), then implement it, then confirm it passes.

Read src/FalkorSt-Objects/FkGraphObject.class.st in full before starting. Key facts already confirmed by reading the code:
- FkGraphObject has instance variables `rawGraphObject` and `db`, and existing methods `id` (delegates to `self rawGraphObject id`), `propertyAt: key` (delegates to `self rawGraphObject properties at: key ifAbsent: [ nil ]`), and `propertyAt: key put: value` (runs a Cypher SET then reloads). All new methods in this task must be written purely in terms of these three existing methods - do not touch rawGraphObject or db directly, do not add instance variables, do not run any new Cypher.
- FkGraphObject has no concrete instances of its own (`matchElementNamed:` is subclassResponsibility) - the only concrete subclass on this branch is FkGraphNode (src/FalkorSt-Objects/FkGraphNode.class.st). FkGraphRelationship does not exist yet on this branch (it is still in flight on a separate, unmerged branch) - do not reference it or assume it exists.
- The reference implementation is N4GraphObject (../Neo4reSt/src/Neo4reSt-GraphModel/N4GraphObject.class.st, reference-only sibling project, never a dependency) - already read and confirmed to map cleanly onto FkGraphObject''s existing members with no adaptation needed. Port these exact bodies (adjusting only receiver/message names to match this project''s existing methods):

Add these instance methods to FkGraphObject:
- `= other` -> `^ self class = other class and: [ self id = other id ]` (category: comparing)
- `hash` -> `^ self id hash` (category: comparing)
- `@ propName` -> `^ self propertyAt: propName` (category: accessing) - shortcut for propertyAt:
- `at: propName` -> `^ self propertyAt: propName` (category: accessing) - shortcut alias
- `at: propName put: value` -> `^ self propertyAt: propName put: value` (category: accessing) - shortcut alias
- `name` -> `^ self propertyAt: ''name''` (category: accessing) - shortcut for the ''name'' property
- `name: aString` -> `^ self propertyAt: ''name'' put: aString` (category: accessing) - shortcut for the ''name'' property

After implementing, update FkGraphObject''s class comment "Public API and Key Messages" section (and "Responsibility" section if appropriate) to mention the new methods in one or two lines each, at the same level of detail as the existing entries - do not turn the class comment into an exhaustive method reference; keep it a summary per this project''s conventions.

Tests to add to FkGraphNodeTest (use the existing `createGraphNode` helper, or `self db createNodeLabeled:properties:`, to build FkGraphNode instances against a real FalkorDB instance):
- `=`/`hash`: two separately-fetched FkGraphNode wrappers around the same underlying node id are `=` and have equal `hash`; two FkGraphNode wrappers around different node ids are not `=`.
- `@`/`at:`/`at:put:` behave identically to `propertyAt:`/`propertyAt:put:` - e.g. `(node @ ''name'')` equals `(node propertyAt: ''name'')`, `(node at: ''name'')` equals `(node propertyAt: ''name'')`, and `node at: ''age'' put: 31` has the same effect (both on the local wrapper and in FalkorDB) as `node propertyAt: ''age'' put: 31`.
- `name`/`name:` round-trip through the ''name'' property: creating a node with a ''name'' property and reading `node name` answers it; `node name: ''NewName''` updates it, visible via both `node name` and `node propertyAt: ''name''`.

Do not modify any other existing FkGraphObject or FkGraphNode method''s behavior, do not add any new value-object classes, and do not attempt to create or reference FkGraphRelationship.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Run the FalkorSt test suite for the new FkGraphObject API'.
			t prompt: 'Run the full FalkorSt-Core-Tests / FalkorSt-Objects-Tests test suite in this repository (falkor.st) using the st-test skill (or the run_package_test / run_class_test MCP tools), after re-importing any changed packages with st-import if needed. Report the full pass/fail counts, and specifically confirm that the new tests for FkGraphObject''s =, hash, @, at:, at:put:, name, and name: methods (added in the previous step, in FkGraphNodeTest) all pass against the real FalkorDB test instance. If anything fails, investigate and fix it (following the smalltalk-debugger skill if needed) until the whole suite is green, then re-run to confirm.' ]
	} agentBy: [ :a | a claude ].
	builder seq: {
		builder topicBy: [ :t |
			t title: 'Lint and review the FkGraphObject changes'.
			t prompt: 'Lint and review the changes made to src/FalkorSt-Objects/FkGraphObject.class.st (and its test file src/FalkorSt-Objects-Tests/FkGraphNodeTest.class.st) in this repository (falkor.st) for the new equality/accessor-shortcut API (=, hash, @, at:, at:put:, name, name:). Use the st-lint skill (or the smalltalk-validator MCP tools lint_tonel_smalltalk_from_file / validate_tonel_smalltalk_from_file) against the changed Tonel files, and check the changes against the smalltalk-developer skill''s style guide section (naming, method categorization, Tonel syntax, class comment conventions). Fix anything the lint or style review turns up, re-import and re-run the affected tests to confirm everything still passes after any fixes, and report a summary of what was checked and fixed.' ]
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
