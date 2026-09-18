"
I am the high-level, CRUD-capable counterpart to FkNode: a decoded node plus the FkGraphDb it came
from. I mirror SgNode (../SCypherGraph, reference-only). Everything about running Cypher against my
FkGraphDb and delegating reads to my wrapped raw value is inherited from FkGraphObject - I only add
what's specific to nodes.

Responsibility:
- Delegate #labels to my wrapped FkNode
- Supply the CyNode pattern element FkGraphObject's #delete / #propertyAt:put: / #reload match
  myself by id through

Collaborators:
- FkNode: the decoded node I wrap, held as my inherited #rawGraphObject
- FkGraphObject: my superclass, running the Cypher (built with SCypher's CyQuery/CyNode) my
  mutating operations need

Public API and Key Messages:
- FkGraphNode class >> on:in: - wraps an FkNode with the FkGraphDb it was fetched through
  (inherited from FkGraphObject)
- #id / #labels / #properties / #propertyAt: - delegate to the wrapped FkNode
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped FkNode
- #delete - DELETEs the node in FalkorDB
- #rawNode - the wrapped FkNode (an alias for the inherited #rawGraphObject)
"
Class {
	#name : 'FkGraphNode',
	#superclass : 'FkGraphObject',
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'accessing' }
FkGraphNode >> labels [
	^ self rawGraphObject labels
]

{ #category : 'private' }
FkGraphNode >> matchElementNamed: anIdentifier [
	^ CyNode name: anIdentifier
]

{ #category : 'accessing' }
FkGraphNode >> rawNode [
	^ self rawGraphObject
]
