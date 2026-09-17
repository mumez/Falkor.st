# Falkor.st

[![smalltalkCI](https://github.com/mumez/falkor.st/actions/workflows/main.yml/badge.svg)](https://github.com/mumez/falkor.st/actions/workflows/main.yml)

A [FalkorDB](https://github.com/FalkorDB/falkordb) client for Pharo, built on top of [RediStick](https://github.com/mumez/RediStick) (Redis client) and [SCypher](https://github.com/mumez/SCypher) (Cypher query builder).

FalkorDB is a Redis module that lets Redis interpret Cypher queries over a property graph, so falkor.st talks to it as a Redis extension rather than a separate protocol.

## Installation

```smalltalk
Metacello new
  baseline: 'FalkorSt';
  repository: 'github://mumez/falkor.st/src';
  load.
```

## Basic Usage

```smalltalk
stick := FkFalkorStick targetUrl: 'sync://localhost:6379'.
stick connect.

result := stick endpoint graphQuery: 'social' cypher: 'CREATE (p:Person {name: ''Alice''}) RETURN p'.
node := result records first first.
node properties at: #name. "'Alice'"

stick close.
```

`graphQuery:cypher:` runs `GRAPH.QUERY` and decodes the reply (compact format by default) into an
`FkQueryResult`, whose `records` are rows of decoded values (`FkNode`, `FkRelationship`, `FkPath`, or
native scalars). See `FkGraphEndpoint` for the full command set (`GRAPH.RO_QUERY`, `GRAPH.DELETE`,
`GRAPH.INFO`, `GRAPH.CONFIG`, `GRAPH.CONSTRAINT CREATE`/`DROP`, `GRAPH.EXPLAIN`, `GRAPH.PROFILE`,
`GRAPH.LIST`, `GRAPH.COPY`, `GRAPH.MEMORY`, `GRAPH.SLOWLOG`, and more).

## Status

Commands are implemented, except for administrative ACL commands.

## Roadmap

A high-level object-graph API, modeled on [SCypherGraph's `SgGraphDb`](https://github.com/mumez/SCypherGraph#examples), is planned on top of the current command layer.
