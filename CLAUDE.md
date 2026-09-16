# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

falkor.st is a Pharo client for [FalkorDB](https://github.com/FalkorDB/falkordb), built on top of
[RediStick](https://github.com/mumez/RediStick) (Redis client, local clone `../RediStick`) and
[SCypher](https://github.com/mumez/SCypher) (Cypher query builder, local clone `../SCypher`). FalkorDB is a
Redis module that interprets Cypher, so falkor.st talks to it as a Redis extension rather than a separate
protocol — RediStick handles the RESP wire protocol, falkor.st only interprets already-parsed nested
Smalltalk collections.

Status: early development. Only `GRAPH.QUERY` execution and result decoding (verbose and compact) are
in scope right now (see `openspec/changes/add-graph-query-support/`). `GRAPH.RO_QUERY`, `GRAPH.DELETE`,
`GRAPH.EXPLAIN`, `GRAPH.PROFILE`, `GRAPH.LIST`, `GRAPH.CONFIG`, `GRAPH.SLOWLOG`, a high-level object-graph
API, and SCypher integration are explicitly out of scope for now.

Reference-only sibling repo `../SCypherGraph` (`SgNode`/`SgRelationship`/`SgGraphObject`) is the model for
this project's node/relationship value objects, adapted for FalkorDB — it is not a dependency.

## Commands

This is a Tonel/Pharo project loaded via Metacello; there is no local build step outside the Pharo image.
Use the `smalltalk-dev` plugin skills (`st-init`, `st-import`, `st-test`, `st-export`, `st-lint`,
`st-validate`, `st-eval`) rather than shell commands for the Edit → Import → Test cycle.

- Load into a Pharo image: `Metacello new baseline: 'FalkorSt'; repository: 'github://mumez/falkor.st/src'; load.`
- Run tests: `st-test` (SUnit, package `FalkorSt-Core-Tests`), after importing via `st-import`.
- CI runs `smalltalkci` against Pharo64-12/13/14 with a `falkordb/falkordb:latest` service container on port
  6379 (`.github/workflows/main.yml`) — integration tests need a real FalkorDB instance, not a mock.

## Architecture

- `src/BaselineOfFalkorSt` — Metacello baseline. Declares dependencies: RediStick (`Core` group,
  `github://mumez/RediStick/src`) and SCypher (`github://mumez/SCypher/repository`).
- `src/FalkorSt-Core` — main library code (class prefix `Fk`, following RediStick → `Rs`, SCypher → `Cy`).
- `src/FalkorSt-Core-Tests` — SUnit tests, depends on `FalkorSt-Core`.

### Extension pattern: subclass, don't extend

RediStick's own JSON/Stream/Search packages add stateless commands via `.extension.st` methods directly on
`RsRedisEndpoint`. falkor.st needs per-connection state (id caches for compact-format decoding), which
Smalltalk extension methods can't add, so it subclasses instead:

- `FkGraphEndpoint` (subclass of `RsRedisEndpoint`) — adds `GRAPH.*` command methods and owns the
  label/relationship-type/property-key id-cache instance variables.
- `FkFalkorStick` (subclass of `RsRediStick`) — overrides `#endpointClassForScheme:` to answer
  `FkGraphEndpoint`. This is an existing RediStick extension point; no changes to RediStick are needed.

### Result decoding

Both verbose and compact `GRAPH.QUERY` replies arrive as ordinary RESP multi-bulk arrays — RediStick's
`#unifiedCommand:`/`#parseReply` already turns these into nested `OrderedCollection`s generically.
`FkGraphEndpoint` walks that nested collection itself to build `FkQueryResult` (header/records/statistics)
and per-value objects (`FkNode`, `FkRelationship`, `FkPath`, plus native scalars). Verbose and compact
decoding are designed to converge on the *same* value objects: only the raw-value-to-object step differs
(compact resolves label/type/property-key ids through per-graph caches on `FkGraphEndpoint`, populated via
`db.labels()` / `db.relationshipTypes()` / `db.propertyKeys()` and refreshed on cache miss; verbose reads
names directly off the wire). Downstream code should never need to know which format was used to decode a
result — don't build format-specific value objects.

Full design rationale and rejected alternatives are in
`openspec/changes/add-graph-query-support/design.md`; task-by-task implementation status is in
`openspec/changes/add-graph-query-support/tasks.md`.

## Implementation Rules

- When editing `.st` files, actively consult the `smalltalk-developer` skill — in particular its style
  guide section.
- When debugging Smalltalk code, consult the `smalltalk-debugger` skill — in particular its
  troubleshooting and UI debugging sections.
- Names matter: check that class/method/variable names are intentionally revealing (long names are fine).
- Keep the DRY principle to make code simple and clean.
- New features must be covered by unit tests.
- Act on facts; if unsure, state your assumptions. Write the minimum code that solves the problem.

## Key Gotchas

- Timeout on import — check your dependency order. Try `read_screen` for details (a Pharo debugger window
  has likely opened).
- **No `eval` hack for resolving imports**: Tonel files must be imported via the `st-import` skill.
  Preparing package-loading code yourself could be dangerous.
