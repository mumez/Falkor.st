"
I am the high-level, CRUD-capable counterpart to FkNode: a decoded node plus the FkGraphDb it came
from. I mirror SgGraphObject/SgNode (../SCypherGraph, reference-only): read accessors delegate to
my wrapped FkNode, while mutating operations ask my FkGraphDb to run Cypher (built with SCypher)
against FalkorDB and then replace my wrapped FkNode with a freshly reloaded one - I never mutate a
wrapped FkNode's properties in place.

Responsibility:
- Delegate #id, #labels, #properties, #propertyAt: to my wrapped FkNode
- Run a Cypher SET/DELETE against my FkGraphDb for #propertyAt:put: / #delete, then reload my
  wrapped FkNode from FalkorDB so local state never diverges from what was actually committed

Collaborators:
- FkNode: the decoded node I wrap and delegate reads to
- FkGraphDb: runs the Cypher (built with SCypher's CyQuery/CyNode) my mutating operations need

Public API and Key Messages:
- FkGraphNode class >> on:in: - wraps an FkNode with the FkGraphDb it was fetched through
- #id / #labels / #properties / #propertyAt: - delegate to the wrapped FkNode
- #propertyAt:put: - SETs the property in FalkorDB, then reloads the wrapped FkNode
- #delete - DELETEs the node in FalkorDB
"
Class {
	#name : 'FkGraphNode',
	#superclass : 'Object',
	#instVars : [
		'rawNode',
		'db'
	],
	#category : 'FalkorSt-Objects',
	#package : 'FalkorSt-Objects'
}

{ #category : 'instance creation' }
FkGraphNode class >> on: aFkNode in: aFkGraphDb [
	^ self new
		rawNode: aFkNode;
		db: aFkGraphDb;
		yourself
]

{ #category : 'accessing' }
FkGraphNode >> db [
	^ db
]

{ #category : 'private' }
FkGraphNode >> db: anObject [
	db := anObject
]

{ #category : 'private' }
FkGraphNode >> cypherStringFor: aCyQuery [
	"CyQuery's default delimiter is a bare carriage return, which FalkorDB's Cypher parser
	rejects between clauses - use a space instead."

	aCyQuery delimiter: ' '.
	^ aCyQuery cypherString
]

{ #category : 'actions' }
FkGraphNode >> delete [
	| n node query |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: self id) delete: node.
	self db runCypher: (self cypherStringFor: query)
]

{ #category : 'accessing' }
FkGraphNode >> id [
	^ self rawNode id
]

{ #category : 'accessing' }
FkGraphNode >> labels [
	^ self rawNode labels
]

{ #category : 'accessing' }
FkGraphNode >> properties [
	^ self rawNode properties
]

{ #category : 'accessing' }
FkGraphNode >> propertyAt: key [
	^ self rawNode properties at: key ifAbsent: [ nil ]
]

{ #category : 'actions' }
FkGraphNode >> propertyAt: key put: value [
	| n node query |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery
		match: node
		where: (n getId equals: self id)
		set: { (n @ key) to: value }.
	self db runCypher: (self cypherStringFor: query).
	self reload
]

{ #category : 'accessing' }
FkGraphNode >> rawNode [
	^ rawNode
]

{ #category : 'private' }
FkGraphNode >> rawNode: anObject [
	rawNode := anObject
]

{ #category : 'private' }
FkGraphNode >> reload [
	| n node query result |
	n := 'n' asCypherIdentifier.
	node := CyNode name: n.
	query := CyQuery match: node where: (n getId equals: self id) return: n.
	result := self db runCypher: (self cypherStringFor: query).
	rawNode := result records first first
]
