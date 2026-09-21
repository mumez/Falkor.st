"
I am the high-level, CRUD-capable counterpart to FkNode: a decoded node plus the FkGraphDb it came
from. I mirror SgNode (../SCypherGraph, reference-only). Everything about running Cypher against my
FkGraphDb and delegating reads to my wrapped raw value is inherited from FkGraphObject - I only add
what's specific to nodes.

Responsibility:
- Delegate #labels to my wrapped FkNode
- Supply the CyNode pattern element FkGraphObject's #delete / #propertyAt:put: / #reload match
  myself by id through
- SET/REMOVE my labels in FalkorDB, then reload the wrapped FkNode, mirroring #propertyAt:put:
- Re-query FalkorDB for my current labels (#labelsFromDb), independent of the locally-cached #labels
- Fetch my one-hop relationships/end nodes/paths (in any direction, filtered by type/property/
  end-node label, or by an arbitrary where-clause block) by delegating to my FkGraphDb's
  #oneHopPathsTyped:direction:from:... family
- Answer whether a matching one-hop relationship exists without fetching it, by delegating to my
  FkGraphDb's #existsOneHopPathsTyped:direction:from:... family
- Create/merge an outgoing relationship to another FkGraphNode as a convenience over my FkGraphDb's
  #createOutRelationshipTyped:.../#mergeOutRelationshipTyped:...

Collaborators:
- FkNode: the decoded node I wrap, held as my inherited #rawGraphObject
- FkGraphObject: my superclass, running the Cypher (built with SCypher's CyQuery/CyNode) my
  mutating operations need
- FkGraphDb: my #db, run the one-hop path/existence queries and relationship-creation commands my
  relationship-navigation API is built on
- FkGraphPath / FkGraphRelationship: what my one-hop path/relationship accessors answer

Public API and Key Messages:
- FkGraphNode class >> on:in: - wraps an FkNode with the FkGraphDb it was fetched through
  (inherited from FkGraphObject)
- #id / #labels / #properties / #propertyAt: - delegate to the wrapped FkNode
- #label - the first of my locally-cached #labels, or nil if I have none
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped FkNode
- #addLabel: / #addLabels: - SET one or more labels in FalkorDB, then reload the wrapped FkNode
- #removeLabel: / #removeLabels: - REMOVE one or more labels in FalkorDB, then reload the wrapped FkNode
- #labelsFromDb - re-query FalkorDB for my current labels rather than reading the local #labels
  cache; named distinctly from FkGraphDb's own #allLabels (which means every distinct label across
  the whole graph, an unrelated concept) and from #labels (unrelated to caching) so the name itself
  signals the DB-vs-cache distinction; answers an empty collection (not nil) for a labelless node
- #delete - DELETEs the node in FalkorDB
- #rawNode - the wrapped FkNode (an alias for the inherited #rawGraphObject)
- #relationships / #relationshipsTyped: / #relationshipsTyped:having:value: /
  #relationshipsTyped:endNodeHaving:value: / #relationshipsTyped:havingAll:endNodeWithLabels:havingAll: /
  #relationshipsTyped:where: - answer a flat OrderedCollection of FkGraphRelationship for one-hop
  relationships in either direction, optionally filtered by type/relationship-property/end-node-label/
  end-node-property or an arbitrary where-clause block
- #inRelationships / #inRelationshipsTyped:... / #outRelationships / #outRelationshipsTyped:... -
  the same six-method family restricted to incoming/outgoing relationships only
- #types - the Set of distinct relationship-type strings across all of my relationships
- #existsRelationshipTyped: / #existsRelationshipTyped:having:value: /
  #existsRelationshipTyped:endNodeHaving:value: - answer a Boolean for whether a matching one-hop
  relationship exists in either direction, without fetching it
- #existsInRelationshipTyped:... / #existsOutRelationshipTyped:... - the same three-method family
  restricted to incoming/outgoing relationships only
- #oneHopPathsTyped:havingAll:endNodeWithLabels:havingAll: / #oneHopPathsTyped:where: - answer a
  collection of FkGraphPath for one-hop paths in either direction, for callers who need the whole
  path rather than just the relationship or the end node
- #inOneHopPathsTyped:... / #outOneHopPathsTyped:... - the same two-method family restricted to
  incoming/outgoing paths only
- #relateTo:typed: / #relateTo:typed:properties: - CREATE a new outgoing relationship to another
  FkGraphNode, answering it wrapped as an FkGraphRelationship
- #relateOneTo:typed: / #relateOneTo:typed:properties: - MERGE (create-if-absent) an outgoing
  relationship to another FkGraphNode, answering it wrapped as an FkGraphRelationship or nil

Implementation Points:
- #addLabels: and #removeLabels: share their match/where/run/reload skeleton through the private
  #changeLabels:using: helper - the block passed in only picks whether the label change is
  appended to the query via CyQuery's #addSet: or #addRemove:, since #labels: (SCypher's
  CyIdentifier >> labels:) answers the same CySetItemExpression either way.
- #labelsFromDb (empty collection for a labelless node) and #label (nil for a labelless node) have
  deliberately different empty-case shapes: #label mirrors N4Node's single-value convention, while
  #labelsFromDb mirrors #labels'/#allLabels'-style collection accessors elsewhere in this project,
  none of which answer nil for ""no results"" - see the covering tests for both cases.
- Every relationship/path/existence accessor is built only on top of FkGraphDb's existing
  #oneHopPathsTyped:direction:from:havingAll:endNodeWithLabels:havingAll:whereIn:returning: and
  #existsOneHopPathsTyped:direction:from:whereIn: - I never build Cypher directly myself, mirroring
  N4Node (../Neo4reSt, reference-only) but delegating to FkGraphDb rather than re-deriving queries.
- direction: nil/#in/#out is FkGraphDb's own convention (see its class comment); #relationshipsTyped:.../
  #oneHopPathsTyped:... use nil (either direction), the #in.../#out... families pass #in/#out through.
- The relationshipsTyped:... family fetches one-hop paths with a returner block of
  [:path | path relationships], which yields a collection of relationship-collections (one per
  matching path) since FkGraphPath already wraps its relationships as FkGraphRelationship - these are
  flattened into a single OrderedCollection rather than re-wrapped.
- #existsRelationshipTyped:having:value:/#existsRelationshipTyped:endNodeHaving:value: build their
  where-clause with SCypher's CyIdentifier '@'/#equals: operators (matching FkGraphDb's own
  #havingAll:-based where-clause building), not N4Node's Neo4j-era #prop: selector.
"
Class {
	#name : 'FkGraphNode',
	#superclass : 'FkGraphObject',
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'actions-labels' }
FkGraphNode >> addLabel: label [
	^ self addLabels: { label }
]

{ #category : 'actions-labels' }
FkGraphNode >> addLabels: labels [
	^ self changeLabels: labels using: [ :query :setItem | query addSet: setItem ]
]

{ #category : 'private' }
FkGraphNode >> changeLabels: labels using: addStatementBlock [
	| n element query |
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery match: element where: (n getId equals: self id).
	addStatementBlock value: query value: (n labels: labels).
	self db runCypher: query.
	self reload
]

{ #category : 'accessing' }
FkGraphNode >> labelsFromDb [
	| n element query result |
	n := 'n' asCypherIdentifier.
	element := self matchElementNamed: n.
	query := CyQuery match: element where: (n getId equals: self id) return: n labels.
	result := self db runReadOnlyCypher: query.
	^ result records first first
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsInRelationshipTyped: typeOrTypes [
	^ self db existsOneHopPathsTyped: typeOrTypes direction: #in from: self id whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsInRelationshipTyped: typeOrTypes endNodeHaving: key value: value [
	^ self db
		existsOneHopPathsTyped: typeOrTypes
		direction: #in
		from: self id
		whereIn: [ :start :rel :end | (end @ key) equals: value ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsInRelationshipTyped: typeOrTypes having: key value: value [
	^ self db
		existsOneHopPathsTyped: typeOrTypes
		direction: #in
		from: self id
		whereIn: [ :start :rel :end | (rel @ key) equals: value ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsOutRelationshipTyped: typeOrTypes [
	^ self db existsOneHopPathsTyped: typeOrTypes direction: #out from: self id whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsOutRelationshipTyped: typeOrTypes endNodeHaving: key value: value [
	^ self db
		existsOneHopPathsTyped: typeOrTypes
		direction: #out
		from: self id
		whereIn: [ :start :rel :end | (end @ key) equals: value ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsOutRelationshipTyped: typeOrTypes having: key value: value [
	^ self db
		existsOneHopPathsTyped: typeOrTypes
		direction: #out
		from: self id
		whereIn: [ :start :rel :end | (rel @ key) equals: value ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsRelationshipTyped: typeOrTypes [
	^ self db existsOneHopPathsTyped: typeOrTypes direction: nil from: self id whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsRelationshipTyped: typeOrTypes endNodeHaving: key value: value [
	^ self db
		existsOneHopPathsTyped: typeOrTypes
		direction: nil
		from: self id
		whereIn: [ :start :rel :end | (end @ key) equals: value ]
]

{ #category : 'accessing-relationships-existence' }
FkGraphNode >> existsRelationshipTyped: typeOrTypes having: key value: value [
	^ self db
		existsOneHopPathsTyped: typeOrTypes
		direction: nil
		from: self id
		whereIn: [ :start :rel :end | (rel @ key) equals: value ]
]

{ #category : 'accessing-paths' }
FkGraphNode >> inOneHopPathsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps [
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: #in
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-paths' }
FkGraphNode >> inOneHopPathsTyped: typeOrTypes where: whereClauseBuilder [
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: #in
		havingAll: {}
		endNodeWithLabels: {}
		havingAll: {}
		whereIn: whereClauseBuilder
]

{ #category : 'accessing-relationships' }
FkGraphNode >> inRelationships [
	^ self inRelationshipsTyped: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> inRelationshipsTyped: typeOrTypes [
	^ self inRelationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> inRelationshipsTyped: typeOrTypes endNodeHaving: key value: value [
	^ self inRelationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: { key -> value }
]

{ #category : 'accessing-relationships' }
FkGraphNode >> inRelationshipsTyped: typeOrTypes having: key value: value [
	^ self inRelationshipsTyped: typeOrTypes havingAll: { key -> value } endNodeWithLabels: {} havingAll: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> inRelationshipsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps [
	^ self
		relationshipsTyped: typeOrTypes
		direction: #in
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-relationships' }
FkGraphNode >> inRelationshipsTyped: typeOrTypes where: whereClauseBuilder [
	^ self
		relationshipsTyped: typeOrTypes
		direction: #in
		havingAll: {}
		endNodeWithLabels: {}
		havingAll: {}
		whereIn: whereClauseBuilder
]

{ #category : 'accessing' }
FkGraphNode >> label [
	^ self labels ifEmpty: [ nil ] ifNotEmpty: [ :labels | labels first ]
]

{ #category : 'accessing' }
FkGraphNode >> labels [
	^ self rawGraphObject labels
]

{ #category : 'private' }
FkGraphNode >> matchElementNamed: anIdentifier [
	^ CyNode name: anIdentifier
]

{ #category : 'accessing-paths' }
FkGraphNode >> oneHopPathsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps [
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: nil
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: [ :start :rel :end | ]
]

{ #category : 'private' }
FkGraphNode >> oneHopPathsTyped: typeOrTypes direction: direction havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder [
	^ self db
		oneHopPathsTyped: typeOrTypes
		direction: direction
		from: self id
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: whereClauseBuilder
		returning: [ :path | path ]
]

{ #category : 'accessing-paths' }
FkGraphNode >> oneHopPathsTyped: typeOrTypes where: whereClauseBuilder [
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: nil
		havingAll: {}
		endNodeWithLabels: {}
		havingAll: {}
		whereIn: whereClauseBuilder
]

{ #category : 'accessing-paths' }
FkGraphNode >> outOneHopPathsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps [
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: #out
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-paths' }
FkGraphNode >> outOneHopPathsTyped: typeOrTypes where: whereClauseBuilder [
	^ self
		oneHopPathsTyped: typeOrTypes
		direction: #out
		havingAll: {}
		endNodeWithLabels: {}
		havingAll: {}
		whereIn: whereClauseBuilder
]

{ #category : 'accessing-relationships' }
FkGraphNode >> outRelationships [
	^ self outRelationshipsTyped: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> outRelationshipsTyped: typeOrTypes [
	^ self outRelationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> outRelationshipsTyped: typeOrTypes endNodeHaving: key value: value [
	^ self outRelationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: { key -> value }
]

{ #category : 'accessing-relationships' }
FkGraphNode >> outRelationshipsTyped: typeOrTypes having: key value: value [
	^ self outRelationshipsTyped: typeOrTypes havingAll: { key -> value } endNodeWithLabels: {} havingAll: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> outRelationshipsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps [
	^ self
		relationshipsTyped: typeOrTypes
		direction: #out
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: [ :start :rel :end | ]
]

{ #category : 'accessing-relationships' }
FkGraphNode >> outRelationshipsTyped: typeOrTypes where: whereClauseBuilder [
	^ self
		relationshipsTyped: typeOrTypes
		direction: #out
		havingAll: {}
		endNodeWithLabels: {}
		havingAll: {}
		whereIn: whereClauseBuilder
]

{ #category : 'accessing' }
FkGraphNode >> rawNode [
	^ self rawGraphObject
]

{ #category : 'actions-labels' }
FkGraphNode >> removeLabel: label [
	^ self removeLabels: { label }
]

{ #category : 'actions-labels' }
FkGraphNode >> removeLabels: labels [
	^ self changeLabels: labels using: [ :query :setItem | query addRemove: setItem ]
]

{ #category : 'relationships' }
FkGraphNode >> relateOneTo: otherNode typed: type properties: propertiesArray [
	^ self db
		mergeOutRelationshipTyped: type
		fromNodeId: self id
		toNodeId: otherNode id
		properties: propertiesArray
]

{ #category : 'relationships' }
FkGraphNode >> relateOneTo: otherNode typed: typeName [
	^ self relateOneTo: otherNode typed: typeName properties: #()
]

{ #category : 'relationships' }
FkGraphNode >> relateTo: otherNode typed: type properties: propertiesArray [
	^ self db
		createOutRelationshipTyped: type
		fromNodeId: self id
		toNodeId: otherNode id
		properties: propertiesArray
]

{ #category : 'relationships' }
FkGraphNode >> relateTo: otherNode typed: typeName [
	^ self relateTo: otherNode typed: typeName properties: #()
]

{ #category : 'accessing-relationships' }
FkGraphNode >> relationships [
	^ self relationshipsTyped: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> relationshipsTyped: typeOrTypes [
	^ self relationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> relationshipsTyped: typeOrTypes endNodeHaving: key value: value [
	^ self relationshipsTyped: typeOrTypes havingAll: {} endNodeWithLabels: {} havingAll: { key -> value }
]

{ #category : 'accessing-relationships' }
FkGraphNode >> relationshipsTyped: typeOrTypes having: key value: value [
	^ self relationshipsTyped: typeOrTypes havingAll: { key -> value } endNodeWithLabels: {} havingAll: {}
]

{ #category : 'accessing-relationships' }
FkGraphNode >> relationshipsTyped: typeOrTypes havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps [
	^ self
		relationshipsTyped: typeOrTypes
		direction: nil
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: [ :start :rel :end | ]
]

{ #category : 'private' }
FkGraphNode >> relationshipsTyped: typeOrTypes direction: direction havingAll: relProps endNodeWithLabels: labels havingAll: endNodeProps whereIn: whereClauseBuilder [
	| pathRelationships |
	pathRelationships := self db
		oneHopPathsTyped: typeOrTypes
		direction: direction
		from: self id
		havingAll: relProps
		endNodeWithLabels: labels
		havingAll: endNodeProps
		whereIn: whereClauseBuilder
		returning: [ :path | path relationships ].
	^ pathRelationships inject: OrderedCollection new into: [ :all :each | all addAll: each; yourself ]
]

{ #category : 'accessing-relationships' }
FkGraphNode >> relationshipsTyped: typeOrTypes where: whereClauseBuilder [
	^ self
		relationshipsTyped: typeOrTypes
		direction: nil
		havingAll: {}
		endNodeWithLabels: {}
		havingAll: {}
		whereIn: whereClauseBuilder
]

{ #category : 'accessing-relationships' }
FkGraphNode >> types [
	^ (self relationships collect: [ :each | each type ]) asSet
]
