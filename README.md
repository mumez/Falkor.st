# falkor.st

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

## Status

Early development. Only `GRAPH.QUERY` execution and result decoding (verbose and compact formats) are implemented so far.
