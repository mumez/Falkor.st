"
I test FkGraphRelationship's endpoint accessors (#startNode/#endNode/#ownNode/#otherNode) and
inherited bulk property mutators against a real FalkorDB instance, including the anchor-relative
direction convention #ownNodeId/#otherNodeId depend on.

Coverage:
- graph-object-api spec: ""Fetching a relationship's start/end node""
- graph-object-api spec: ""Resolving own/other node relative to the traversal anchor""
- graph-object-api spec: ""A relationship with no known direction signals an error on own/other""
- graph-object-api spec: ""Bulk property SET/MERGE/REMOVE on a relationship, inherited from
  FkGraphObject""
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

{ #category : 'creating' }
FkGraphRelationshipTest >> createAliceKnowsBobWithSincePropertyIn: db [
	| alice bob |
	alice := db createNodeLabeled: 'Person' properties: { 'name' -> 'Alice' }.
	bob := db createNodeLabeled: 'Person' properties: { 'name' -> 'Bob' }.
	db
		createOutRelationshipTyped: 'KNOWS'
		fromNodeId: alice id
		toNodeId: bob id
		properties: { 'since' -> 2020 }.
	^ (db relationshipsTyped: 'KNOWS') first
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
FkGraphRelationshipTest >> testOwnAndOtherResolveCorrectlyForOutRelationship [
	| db people alice bob rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	bob := people second.
	rel := (alice outRelationshipsTyped: 'KNOWS') first.
	self assert: rel ownNode id equals: alice id.
	self assert: rel otherNode id equals: bob id
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testOwnAndOtherResolveCorrectlyForInRelationship [
	| db people alice bob rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	bob := people second.
	rel := (bob inRelationshipsTyped: 'KNOWS') first.
	self assert: rel ownNode id equals: bob id.
	self assert: rel otherNode id equals: alice id
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testOtherNodeIdSignalsUnknownDirectionWhenDirectionIsNotSet [
	| db people alice rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	alice := people first.
	rel := db relationshipAt: (db relationshipsTyped: 'KNOWS') first id.
	self
		should: [ rel otherNodeId ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #UnknownDirection ]
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testOwnNodeIdSignalsUnknownDirectionWhenDirectionIsNotSet [
	| db people rel |
	db := self db.
	people := self createAliceKnowsBobIn: db.
	rel := db relationshipAt: (db relationshipsTyped: 'KNOWS') first id.
	self
		should: [ rel ownNodeId ]
		raise: FkGraphDbError
		withExceptionDo: [ :ex | self assert: ex kind equals: #UnknownDirection ]
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testPropertiesReplacesTheWholePropertyMap [
	| rel |
	rel := self createAliceKnowsBobWithSincePropertyIn: self db.
	rel properties: { 'weight' -> 5 }.
	self assert: rel properties equals: { 'weight' -> 5 } asDictionary
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testMergePropertiesAddsWithoutDroppingExistingKeys [
	| rel |
	rel := self createAliceKnowsBobWithSincePropertyIn: self db.
	rel mergeProperties: { 'weight' -> 5 }.
	self assert: (rel propertyAt: 'since') equals: 2020.
	self assert: (rel propertyAt: 'weight') equals: 5
]

{ #category : 'tests' }
FkGraphRelationshipTest >> testRemovePropertyAtRemovesOneKey [
	| rel |
	rel := self createAliceKnowsBobWithSincePropertyIn: self db.
	rel removePropertyAt: 'since'.
	self assert: (rel propertyAt: 'since') isNil
]
