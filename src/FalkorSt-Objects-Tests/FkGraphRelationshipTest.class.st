"
I test FkGraphRelationship's endpoint accessors (#startNode/#endNode/#headNode/#tailNode) against a
real FalkorDB instance, including the anchor-relative direction convention #headNodeId/#tailNodeId
depend on.

Coverage:
- graph-object-api spec: ""Fetching a relationship's start/end node""
- graph-object-api spec: ""Resolving head/tail node relative to the traversal anchor""
- graph-object-api spec: ""A relationship with no known direction signals an error on head/tail""
"
Class {
	#name : 'FkGraphRelationshipTest',
	#superclass : 'FkGraphEndpointTestCase',
	#category : 'FalkorSt-Objects-Tests',
	#package : 'FalkorSt-Objects-Tests'
}

{ #category : 'accessing' }
FkGraphRelationshipTest >> db [
	^ FkGraphDb on: stick named: self graphName
]

{ #category : 'creating' }
FkGraphRelationshipTest >> createAliceKnowsBobIn: db [
	| alice bob |
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	db createOutRelationshipTyped: 'KNOWS' fromNodeId: alice id toNodeId: bob id properties: #().
	^ { alice. bob }
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testStartNodeAndEndNodeAnswerTheRelationshipsEndpoints [
	| db people alice bob rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	bob := people second.
	rel := (db relationshipsTyped: 'KNOWS') first.
	self assert: rel startNode id equals: alice id.
	self assert: rel endNode id equals: bob id
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testHeadAndTailResolveCorrectlyForOutRelationship [
	| db people alice bob rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	bob := people second.
	rel := (alice outRelationshipsTyped: 'KNOWS') first.
	self assert: rel tailNode id equals: alice id.
	self assert: rel headNode id equals: bob id
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testHeadAndTailResolveCorrectlyForInRelationship [
	| db people alice bob rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	bob := people second.
	rel := (bob inRelationshipsTyped: 'KNOWS') first.
	self assert: rel tailNode id equals: bob id.
	self assert: rel headNode id equals: alice id
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testHeadNodeIdSignalsUnknownDirectionWhenDirectionIsNotSet [
	| db people alice rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	rel := db relationshipAt: (db relationshipsTyped: 'KNOWS') first id.
	self
		should: [ rel headNodeId ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #UnknownDirection ]
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testTailNodeIdSignalsUnknownDirectionWhenDirectionIsNotSet [
	| db people rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	rel := db relationshipAt: (db relationshipsTyped: 'KNOWS') first id.
	self
		should: [ rel tailNodeId ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #UnknownDirection ]
]
