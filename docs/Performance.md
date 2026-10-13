# Performance: Falkor.st (FalkorDB) vs Neo4reSt (Neo4j)

This page compares the high-level object APIs of two Pharo graph clients:

- **Falkor.st** `FkGraphDb` → FalkorDB, RESP over a Redis socket
- **Neo4reSt** `N4GraphDb` → Neo4j, HTTP transactional API + JSON

It measures load and CRUD latency/throughput plus container memory. Both clients build their
Cypher with [SCypher](https://github.com/mumez/SCypher), and the workload sends the same
selectors to either object. The numbers therefore show what a Pharo user of each high-level API
actually gets: Cypher building, transport, server execution, and decoding into node objects. They
are not a server-only benchmark.

The benchmark code is the opt-in `Benchmarks` baseline group (`FalkorSt-Benchmarks`). It is not
part of the default load or CI.

## Summary

Results are from one run on one machine (see [Environment](#environment)). Use them for the
order of magnitude, not as exact figures.

- **Load**: FalkorDB inserted the scale-M dataset (30,000 nodes + 120,000 relationships, one call
  each) in **175 s**, at 859 ops/sec. Neo4j took **1,285 s**, at 117 ops/sec. That makes FalkorDB
  about 7.4× faster. At scale S, the ratio was about 9.6×.
- **Writes** (C-node, C-rel, U-prop, U-merge, D-node): FalkorDB took about 0.9–2.1 ms per call.
  Neo4j took about 4.6–12.9 ms per call. This is the largest gap.
- **Point reads** (R-id, R-prop, R-count): FalkorDB took about 0.8–1.1 ms. Neo4j took about
  1.2–3.9 ms.
- **1-hop traversal** (R-hop): FalkorDB took about 3.2 ms. Neo4j took 4.4 ms (S) and 6.7 ms (M; median
  4.6 ms).
- **Unindexed filter with `LIMIT 20`** (R-where): **Neo4j was faster** (mean about 2.2–2.3 ms vs
  4.0–4.8 ms). This was the only operation where Neo4j won.
- Going from S to M, FalkorDB's per-call latency barely changed, except for R-where and D-node.
- **Memory**: the FalkorDB container used about 75 MiB when empty and grew by 11 MiB for scale M.
  The Neo4j container used about 1.47 GiB when empty, because the JVM heap is pinned at 1 GiB and
  the page cache is set to 512 MiB. It grew by 43 MiB for scale M.

## Methodology

### Model and dataset

A synthetic social network, inspired by FalkorDB's `demo/social`:

```
(:Person {id, name, age, city})
(:Post   {id, text, createdAt})          createdAt: epoch seconds (no temporal types)
(:Person)-[:FRIEND {since}]->(:Person)
(:Person)-[:POSTED]->(:Post)
(:Person)-[:LIKES {at}]->(:Post)
```

| Scale | Person | Post | FRIEND | POSTED | LIKES | Nodes | Relationships |
|---|---:|---:|---:|---:|---:|---:|---:|
| S | 1,000 | 2,000 | 5,000 | 2,000 | 5,000 | 3,000 | 12,000 |
| M | 10,000 | 20,000 | 50,000 | 20,000 | 50,000 | 30,000 | 120,000 |
| L (not run) | 100,000 | 200,000 | 500,000 | 200,000 | 500,000 | 300,000 | 1,200,000 |

`FkBenchDatasetGenerator` derives every value from a single `Random seed: 42`, so the same seed
always produces the same dataset. FRIEND and LIKES have no self-loops and no duplicate pairs.
Every Post has exactly one POSTED author. `age` is uniform in 18–80.

### Operations

| Id | Phase | High-level call |
|---|---|---|
| C-node | load | `createNodeLabeled:properties:` |
| C-rel | load | `createOutRelationshipTyped:fromNodeId:toNodeId:properties:` |
| R-id | query | `nodeAt:` (random Person) |
| R-prop | query | `nodesLabeled: 'Person' havingAll: {'id' -> x}` (indexed) |
| R-where | query | `nodesLabeled: 'Person' where: [:n \| (n @ 'age') >= x] skip: 0 limit: 20` (no index on `age`) |
| R-hop | query | `oneHopPathsTyped: 'FRIEND' direction: #out from: id ...` |
| R-count | query | `countNodesLabeled: 'Person'` |
| U-prop | query | `nodeAt:propertyAt:put:` (`age`) |
| U-merge | query | `nodeAt:mergeProperties:` (two properties) |
| D-node | query | `deleteNodeAt:withRelations: true` (distinct Persons) |

Each call runs one statement in its own (auto-commit) transaction.

- **Server warm-up** (`#serverWarmupPhase`, unmeasured): the whole workload is run on a separate
  300-person dataset (seed + 1), and then the graph is emptied. Without it, a freshly started
  Neo4j is still JIT-compiling. Its median `RETURN 1` fell from 6.6 ms to 2.3 ms over about 2,500
  calls.
- **Load phase** (`#loadPhase`): the graph is reset, and range indexes on `Person(id)` and
  `Post(id)` are created (unmeasured). Then every node and every relationship is inserted one call
  at a time. Each call is one latency sample. The total elapsed time is reported as well.
- **Query phase** (`#queryPhase`): each operation runs 100 warm-up calls (discarded) and then 1,000
  measured calls. Arguments come from a `Random seed: 42`. D-node runs last and deletes distinct
  Persons, so its count is capped at the Person count (900 measured at scale S).

Latency is the wall-clock time per call, measured in Pharo (`Time microsecondClockValue` delta).
The client is single-threaded, uses one connection, and runs operations sequentially. ops/sec is
count ÷ sum of latencies.

### Memory

`scripts/benchmark/memory-snapshot.sh` records `docker stats` memory usage for the whole container
at three checkpoints per (target, scale):

- `empty`: fresh container, after the server warm-up
- `loaded`: after the load phase
- `after-query`: after the query phase

## Environment

| | |
|---|---|
| Date | 2026-10-13 |
| Hardware | AMD Ryzen 5 5600X; WSL2 VM with 4 vCPU and 15 GiB RAM |
| OS | Windows 11 (10.0.26200) + WSL2 Ubuntu 24.04.1 (kernel 6.6.87.2-microsoft-standard-WSL2) |
| Docker | Docker Engine 29.7.2 (inside WSL2) |
| Pharo | Pharo 14.0.0 build 782 (64-bit), clean image: Falkor.st + Neo4reSt + PharoSmalltalkInteropServer |
| FalkorDB | `falkordb/falkordb:latest` (`sha256:e2765e20…`), FalkorDB 6.0.1 |
| Neo4j | `neo4j:community` (`sha256:6f3f17e7…`), Neo4j Kernel 2026.09.0 community |
| Docker limits | both containers: `cpus: 2`, `mem_limit: 4g`, run one at a time, fresh container per (target, scale) |
| Neo4j memory | heap initial = max = 1G, page cache 512m |
| Falkor.st | `74fae78` (develop) |
| SCypher | v1.4.0 (`090c7ac`) |
| Neo4reSt | `8c46283` (includes PR #18, HTTP connection reuse) |
| RediStick | `93147be` |

## Reproduction

```bash
# one database at a time; a fresh container per target and scale
docker compose -f scripts/benchmark/docker-compose.yml --profile falkordb up -d
# ... run the target (below), then:
docker compose -f scripts/benchmark/docker-compose.yml --profile falkordb down -v
docker compose -f scripts/benchmark/docker-compose.yml --profile neo4j up -d
```

The containers listen on 16379 (FalkorDB) and 17474 (Neo4j), so a development server on the default
port can keep running. The FalkorDB/Neo4j images can be pinned with `FALKORDB_IMAGE` /
`NEO4J_IMAGE`.

```smalltalk
Metacello new
  baseline: 'FalkorSt';
  repository: 'github://mumez/falkor.st/src';
  load: #('Benchmarks').

runner := FkBenchRunner new
  scale: FkBenchScale small;          "or FkBenchScale medium"
  seed: 42; warmup: 100; iterations: 1000;
  target: FkBenchFalkorTarget new;    "or FkBenchNeo4jTarget new"
  yourself.
runner serverWarmupPhase.   "then: scripts/benchmark/memory-snapshot.sh falkordb-S-empty"
runner loadPhase.           "then: scripts/benchmark/memory-snapshot.sh falkordb-S-loaded"
runner queryPhase.          "then: scripts/benchmark/memory-snapshot.sh falkordb-S-after-query"

(FkBenchReport fromRunners: { falkorRunner. neo4jRunner }) asMarkdown.
```

Snapshots are appended to `scripts/benchmark/memory.csv` (git-ignored). Each phase is a separate
message so that the snapshot script can run in between. Pharo does not shell out by itself.

## Results

### Scale S (1000 persons), seed 42, warmup 100, iterations 1000

Targets: FalkorDB (FalkorDB 6.0.1), Neo4j (Neo4j Kernel 2026.09.0 community)

#### Load phase

| Target | Operations | Total (s) | ops/sec |
|---|---:|---:|---:|
| FalkorDB | 15000 | 17.330 | 865.533 |
| Neo4j | 15000 | 166.503 | 90.088 |

#### Latency (ms)

| Operation | Target | Count | Mean | Median | p95 | p99 | ops/sec |
|---|---|---:|---:|---:|---:|---:|---:|
| C-node | FalkorDB | 3000 | 1.108 | 1.053 | 1.384 | 2.515 | 902.132 |
| C-node | Neo4j | 3000 | 9.986 | 9.078 | 13.452 | 16.851 | 100.138 |
| C-rel | FalkorDB | 12000 | 1.167 | 1.053 | 1.348 | 2.495 | 857.244 |
| C-rel | Neo4j | 12000 | 11.377 | 10.159 | 15.874 | 22.404 | 87.896 |
| R-id | FalkorDB | 1000 | 1.051 | 1.004 | 1.296 | 2.327 | 951.798 |
| R-id | Neo4j | 1000 | 2.814 | 2.970 | 3.870 | 4.501 | 355.326 |
| R-prop | FalkorDB | 1000 | 1.057 | 1.002 | 1.358 | 2.258 | 946.471 |
| R-prop | Neo4j | 1000 | 3.850 | 3.166 | 4.247 | 5.118 | 259.713 |
| R-where | FalkorDB | 1000 | 4.017 | 3.870 | 5.232 | 5.688 | 248.963 |
| R-where | Neo4j | 1000 | 2.226 | 2.131 | 2.893 | 3.575 | 449.150 |
| R-hop | FalkorDB | 1000 | 3.249 | 3.134 | 5.300 | 6.351 | 307.758 |
| R-hop | Neo4j | 1000 | 4.378 | 4.491 | 6.242 | 8.002 | 228.403 |
| R-count | FalkorDB | 1000 | 0.818 | 0.787 | 0.965 | 1.873 | 1223.165 |
| R-count | Neo4j | 1000 | 1.270 | 1.229 | 1.583 | 2.192 | 787.323 |
| U-prop | FalkorDB | 1000 | 0.863 | 0.829 | 1.077 | 1.846 | 1159.100 |
| U-prop | Neo4j | 1000 | 8.022 | 7.679 | 11.584 | 14.268 | 124.661 |
| U-merge | FalkorDB | 1000 | 0.874 | 0.844 | 1.042 | 1.694 | 1144.264 |
| U-merge | Neo4j | 1000 | 8.178 | 7.268 | 10.100 | 13.253 | 122.273 |
| D-node | FalkorDB | 900 | 1.460 | 1.403 | 2.015 | 2.502 | 685.137 |
| D-node | Neo4j | 900 | 12.470 | 12.578 | 15.822 | 18.541 | 80.193 |

### Scale M (10000 persons), seed 42, warmup 100, iterations 1000

Targets: FalkorDB (FalkorDB 6.0.1), Neo4j (Neo4j Kernel 2026.09.0 community)

#### Load phase

| Target | Operations | Total (s) | ops/sec |
|---|---:|---:|---:|
| FalkorDB | 150000 | 174.547 | 859.369 |
| Neo4j | 150000 | 1285.489 | 116.687 |

#### Latency (ms)

| Operation | Target | Count | Mean | Median | p95 | p99 | ops/sec |
|---|---|---:|---:|---:|---:|---:|---:|
| C-node | FalkorDB | 30000 | 1.141 | 1.046 | 1.341 | 3.547 | 876.614 |
| C-node | Neo4j | 30000 | 4.574 | 4.113 | 6.363 | 8.023 | 218.635 |
| C-rel | FalkorDB | 120000 | 1.169 | 1.074 | 1.376 | 3.313 | 855.703 |
| C-rel | Neo4j | 120000 | 9.568 | 8.544 | 13.382 | 16.657 | 104.519 |
| R-id | FalkorDB | 1000 | 1.054 | 0.996 | 1.276 | 3.160 | 948.957 |
| R-id | Neo4j | 1000 | 3.078 | 2.946 | 3.644 | 4.844 | 324.919 |
| R-prop | FalkorDB | 1000 | 1.072 | 1.006 | 1.307 | 3.147 | 933.023 |
| R-prop | Neo4j | 1000 | 3.221 | 3.101 | 3.877 | 5.343 | 310.448 |
| R-where | FalkorDB | 1000 | 4.793 | 3.693 | 6.053 | 6.632 | 208.621 |
| R-where | Neo4j | 1000 | 2.287 | 2.088 | 4.199 | 4.878 | 437.255 |
| R-hop | FalkorDB | 1000 | 3.231 | 3.034 | 5.654 | 6.877 | 309.522 |
| R-hop | Neo4j | 1000 | 6.669 | 4.644 | 6.811 | 8.340 | 149.957 |
| R-count | FalkorDB | 1000 | 0.822 | 0.772 | 0.989 | 2.520 | 1217.022 |
| R-count | Neo4j | 1000 | 1.230 | 1.193 | 1.413 | 2.299 | 812.935 |
| U-prop | FalkorDB | 1000 | 0.872 | 0.834 | 1.013 | 1.892 | 1146.466 |
| U-prop | Neo4j | 1000 | 7.575 | 7.107 | 10.737 | 13.843 | 132.015 |
| U-merge | FalkorDB | 1000 | 0.894 | 0.841 | 1.101 | 2.422 | 1118.037 |
| U-merge | Neo4j | 1000 | 7.173 | 6.771 | 10.490 | 12.012 | 139.420 |
| D-node | FalkorDB | 1000 | 2.121 | 2.007 | 3.044 | 4.172 | 471.490 |
| D-node | Neo4j | 1000 | 12.918 | 11.875 | 14.317 | 18.307 | 77.409 |

### Container memory

`docker stats` memory usage for the whole container. Δ load = `loaded − empty`.

| Target | Scale | empty | loaded | after-query | Δ load |
|---|---|---:|---:|---:|---:|
| FalkorDB | S | 75.1 MiB | 76.8 MiB | 77.1 MiB | +1.7 MiB |
| Neo4j | S | 1.472 GiB | 1.499 GiB | 1.502 GiB | +28 MiB |
| FalkorDB | M | 74.2 MiB | 85.5 MiB | 89.4 MiB | +11.3 MiB |
| Neo4j | M | 1.476 GiB | 1.518 GiB | 1.519 GiB | +43 MiB |

`docker stats` prints GiB values to three decimals, so Neo4j deltas are accurate to about ±1 MiB.

### Supplemental: per-call floor

These numbers were measured after the runs, with a fresh container, 100 warm-up calls, and 1,000
measured calls. They show how much of each latency is fixed per-call cost rather than graph work.

| Call | Target | Mean (ms) | Median (ms) | p95 (ms) |
|---|---|---:|---:|---:|
| `PING` (RESP, no graph) | FalkorDB | 0.514 | 0.495 | 0.644 |
| `runCypher: 'RETURN 1'` | FalkorDB | 0.808 | 0.759 | 1.003 |
| `queryByCypher: 'RETURN 1'` | Neo4j | 1.262 | 1.202 | 1.489 |


## Caveats

- **Client-side, high-level API numbers.** Each latency includes building the Cypher with SCypher in
  Pharo, the transport, server execution, and decoding into `FkGraphNode` / `N4Node`. The results
  compare the two clients as they are used, not the two servers in isolation.
- **Transport differs**: RESP over a persistent Redis socket vs HTTP + JSON. The per-call floor
  measured on this machine was about 0.5 ms for `PING` and 0.8 ms for `RETURN 1` on FalkorDB, and
  about 1.2 ms for `RETURN 1` on Neo4j (see the supplemental table). Both containers are reached
  through Docker's port forwarding inside WSL2, which adds a constant cost to every call on both
  sides.
- **Write durability is not equalised.** Each call is its own auto-commit transaction. Neo4j makes
  each committed write transaction durable in its transaction log. FalkorDB ran with the image's
  default Redis persistence, and no per-write `fsync` was configured. This is probably a large part
  of the gap between Neo4j's write latency (about 5–13 ms) and its read latency (about 1–3 ms). It
  was not tuned on either side.
- **Neo4j warm-up is not fully over after `#serverWarmupPhase`.** Neo4j's C-node mean was 10.0 ms at
  scale S but 4.6 ms at scale M, where C-node runs for 30,000 calls. Part of the S load figure for
  Neo4j is probably residual JIT warm-up. FalkorDB's numbers were stable across scales.
- **Memory is container memory**, measured with `docker stats`. Neo4j's absolute numbers are
  dominated by the pinned 1 GiB JVM heap and the 512 MiB page cache. They do not reflect graph size.
  FalkorDB's numbers include the Redis allocator. Compare the deltas (`loaded − empty`), not the
  absolute values. Neo4j Community has no usable JMX, so container memory is the only common
  measure.
- **API adaptations.** The workload sends identical selectors to both `FkGraphDb` and `N4GraphDb`,
  but a few behaviours differ:
  - `oneHopPathsTyped:...returnIn:returning:`: `FkGraphDb` calls the returner once per path,
    wrapping each in `FkGraphPath`. `N4GraphDb` calls it once with the decoded result. The runner
    uses an identity returner, so each library does its default decoding work.
  - `whereIn:` must be a block on both (`[ :start :rel :end | ]` for no filter).
  - D-node deletes distinct Persons, so its warm-up and measured counts are capped at the Person
    count (900 measured at scale S).
  - Index creation is target-specific: `createIndexBy:` on FalkorDB and raw
    `CREATE INDEX ... IF NOT EXISTS` + `db.awaitIndexes()` on Neo4j. It is not measured.
- The `falkordb/falkordb:latest` image ships with `TIMEOUT 1000` and `RESULTSET_SIZE 10000`. All
  benchmark queries return small results, so these limits did not affect them.
- **Fixed issues found while building this benchmark** (not present in the numbers above):
  - FalkorDB C-rel took about 580 ms per call with SCypher < v1.4.0. SCypher rendered
    `MATCH (a), (b) WHERE ((id(a) = x) AND (id(b) = y))`, and FalkorDB 6.0.1 planned it as a
    Cartesian product of two full node scans (O(N²)). SCypher v1.4.0 and falkor.st PR #45 fixed it.
    See [Performance-workaround.md](Performance-workaround.md).
  - Neo4j calls had a floor of about 10 ms with Neo4reSt before PR #18, because it opened a new HTTP
    connection for every request. Reusing the connection brought this down to about 1.5 ms.
- Scale L (1.5M entities) was not run.
