# Performance Notes

Known FalkorDB query-planner issues that affect how falkor.st builds Cypher, and how each is
worked around.

## FalkorDB 6.0.1 (module ver 60001): id-based lookups falling back to full/label scans

Verified against a real FalkorDB 6.0.1 instance (`redis-cli`, `EXPLAIN`) on a graph of
`(:N)-[:R]->(:N)` x1000:

- A parenthesized id comparison in `WHERE` (`WHERE ((id(n) = x))`) does not use `NodeByIdSeek`.
  Fixed on the query-generation side: SCypher >= v1.4.0 no longer wraps the top-level `WHERE`
  expression in redundant parentheses, so a plain `WHERE id(n) = x` becomes `NodeByIdSeek` again
  without any falkor.st change. This covers `FkGraphDb>>nodeAt:`,
  `nodeAt:properties:`/`mergeProperties:`/`propertyAt:put:`/`removePropertyAt:`,
  `deleteNodeAt:withRelations:`, `FkGraphNode`/`FkGraphObject`'s `reload`, `delete`,
  `propertyAt:put:`, `changeProperties:using:`, `labelsFromDb`, `changeLabels:using:`, and the
  `create*RelationshipTyped:...`/`merge*RelationshipTyped:...` family (via SCypher's
  `matchPathWithNodeAt:...`, which already matches each node in its own `MATCH`).
- Combining an id comparison with other conditions via `AND` in a single `WHERE` still does not
  seek, even once the outer parentheses are gone.
- A pattern where the far node carries a label makes the planner prefer a label scan over seeking
  the known id.
- **Planner bug**: when a later `MATCH` traverses from a node bound by an earlier `MATCH`'s
  `WHERE id(...) = x`, that earlier `WHERE` is silently dropped unless a `WITH` separates the two
  `MATCH` clauses - without the `WITH`, the query matches from every node in the graph, not just
  the one seeked by id.

### Workaround: `FkGraphDb>>oneHopPathsQueryFor:...` (used by `oneHopPathsTyped:...` /
`existsOneHopPathsTyped:...` / `FkGraphNode>>existsInRelationshipTyped:` and friends)

Builds two statements instead of SCypher's single-`MATCH` `matchPathWithRelationshipsOfTypes:...`
shortcut:

```
MATCH (s) WHERE id(s) = x
WITH s
MATCH p = (s)-[r:TYPE {...}]->(e:Label {...}) WHERE <whereIn>
RETURN p
```

- The `WITH s` is required to avoid the planner bug above.
- The second `WHERE` is omitted entirely when `whereIn` is `nil`.
- The `s`/`r`/`e`/`p` Cypher variable-naming convention is unchanged.

Verified (`redis-cli`, `EXPLAIN`, same 1000-edge graph) for `#out`/`#in`/undirected, with an
end-node label and properties, with a `whereIn` filter on `e`/`s`/`r`, and for
`count(p) > 0` (`existsOneHopPathsTyped:...`): all use `NodeByIdSeek` for the start node, and
result counts/existence are correct, including when the start node id doesn't exist.

Fixed in: SCypher v1.4.0 (removes the redundant outer `WHERE` parentheses) + this falkor.st change
(splits `oneHopPathsQueryFor:...` into its own `MATCH`/`WITH`/`MATCH` form).

### Workaround: `FkGraphRelationship>>baseQueryMatching:withId:` (used by `reload`, `delete`,
`propertyAt:put:`, `changeProperties:using:`/`properties:`/`mergeProperties:`/`removePropertyAt:`,
all inherited from `FkGraphObject`)

`FkGraphObject`'s default `#baseQueryMatching:withId:` (`MATCH element WHERE id(n) = x`) is fine for
`FkGraphNode` - a plain node-by-id seek - but FalkorDB has no relationship-by-id seek, so the same
form on a relationship pattern (`MATCH (s)-[n]-(e) WHERE id(n) = x`) always scans every
relationship matching the pattern. `FkGraphRelationship` overrides the hook to seek its own start
node by id first instead:

```
MATCH (s) WHERE id(s) = startNodeId
WITH s
MATCH (s)-[n]-(e) WHERE id(n) = x
```

- Same `WITH` requirement as above, for the same planner bug.
- Only the start node is seeked (not both endpoints) - seeking both would turn the traversal into
  an Expand Into instead of a Conditional Traverse (also verified against a real instance), but
  the single-endpoint form already removes the full scan with no extra query-building complexity.

Verified (`redis-cli`, `EXPLAIN`) for `reload`/`delete`/`propertyAt:put:`/`SET`: `NodeByIdSeek` on
`s` followed by a `Conditional Traverse` to `n`, with correct results.

### Out of scope: relationship-by-id lookups through `FkGraphDb`

`FkGraphDb>>relationshipAt:` and its siblings (`relationshipAt:properties:`,
`mergeProperties:`, `propertyAt:put:`, `removePropertyAt:`, `deleteRelationshipAt:`) only know the
relationship's id, not either endpoint's - unlike `FkGraphRelationship`'s instance operations above,
they have no start node id available to seek through, so they always scan all relationships of the
matched pattern. Nothing to work around on the falkor.st side today.
