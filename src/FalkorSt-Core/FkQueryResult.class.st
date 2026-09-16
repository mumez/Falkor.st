"
I am the decoded result of a GRAPH.QUERY execution: the column header (when the query had a
RETURN clause), the decoded records, and the query statistics. I build myself from the raw nested
collection RediStick parses a GRAPH.QUERY RESP reply into.

Responsibility:
- Distinguish a 3-element reply (header + records + statistics) from a 1-element reply
  (statistics only, no RETURN clause)
- Decode each record's raw cell values into native Smalltalk scalars or FkNode/FkRelationship
  value objects

Collaborators:
- FkGraphEndpoint: obtains the raw reply and asks me to decode it
- FkNode / FkRelationship: value objects I build while decoding node/relationship cells

Public API and Key Messages:
- FkQueryResult class >> fromVerboseReply: - decode a verbose-format GRAPH.QUERY raw reply
- #header - OrderedCollection of column name Strings (empty when the query had no RETURN clause)
- #records - OrderedCollection of decoded rows, each row an OrderedCollection of decoded values
- #statistics - OrderedCollection of statistic line Strings

Implementation Points:
- In the verbose (non---compact) reply format, only null, integer, and string Cypher values are
  distinguishable on the wire; FalkorDB serializes boolean, double, list, map, and path values as
  plain strings containing their printed form (see FalkorDB's result-structure docs). Decoding
  those into typed Smalltalk values or an FkPath therefore isn't reliable from a verbose reply
  alone and is deferred to compact-format decoding (--compact carries explicit value-type tags);
  such cells are currently exposed as their raw String here.
- Node/relationship cells are unambiguous in verbose mode (tagged nested arrays keyed by
  'id'/'labels'/'properties' or 'id'/'type'/'src_node'/'dest_node'/'properties') and are decoded
  in full, including recursively decoding their property values.
"
Class {
	#name : 'FkQueryResult',
	#superclass : 'Object',
	#instVars : [
		'header',
		'records',
		'statistics'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'private' }
FkQueryResult class >> decodePropertiesFrom: rawPropertyPairs [
	| dict |
	dict := Dictionary new.
	rawPropertyPairs do: [ :pair | dict at: pair first put: (self decodeVerboseValue: pair second) ].
	^ dict
]

{ #category : 'private' }
FkQueryResult class >> decodeVerboseGraphEntity: rawEntity [
	| secondFieldName |
	secondFieldName := rawEntity second first.
	secondFieldName = 'labels' ifTrue: [ ^ self decodeVerboseNode: rawEntity ].
	secondFieldName = 'type' ifTrue: [ ^ self decodeVerboseRelationship: rawEntity ].
	^ rawEntity
]

{ #category : 'private' }
FkQueryResult class >> decodeVerboseNode: rawNode [
	^ FkNode
		id: rawNode first second
		labels: rawNode second second
		properties: (self decodePropertiesFrom: rawNode third second)
]

{ #category : 'private' }
FkQueryResult class >> decodeVerboseRecord: rawRecord [
	^ rawRecord collect: [ :rawValue | self decodeVerboseValue: rawValue ]
]

{ #category : 'private' }
FkQueryResult class >> decodeVerboseRelationship: rawRelationship [
	^ FkRelationship
		id: rawRelationship first second
		type: rawRelationship second second
		startNodeId: rawRelationship third second
		endNodeId: rawRelationship fourth second
		properties: (self decodePropertiesFrom: rawRelationship fifth second)
]

{ #category : 'private' }
FkQueryResult class >> decodeVerboseValue: rawValue [
	"OrderedCollection is RediStick's generic nested-RESP-array shape; a node/relationship value
	arrives as one, while every other verbose scalar (string, integer, nil) does not, so this check
	- rather than a polymorphic dispatch - is what actually distinguishes them here."
	(rawValue isKindOf: OrderedCollection) ifTrue: [ ^ self decodeVerboseGraphEntity: rawValue ].
	^ rawValue
]

{ #category : 'instance creation' }
FkQueryResult class >> fromVerboseReply: rawReply [
	rawReply size = 1
		ifTrue: [ ^ self new setHeader: #() records: #() statistics: rawReply first ].
	^ self new
		setHeader: rawReply first
		records: (rawReply second collect: [ :rawRecord | self decodeVerboseRecord: rawRecord ])
		statistics: rawReply third
]

{ #category : 'accessing' }
FkQueryResult >> header [
	^ header
]

{ #category : 'private' }
FkQueryResult >> header: anObject [
	header := anObject
]

{ #category : 'accessing' }
FkQueryResult >> records [
	^ records
]

{ #category : 'private' }
FkQueryResult >> records: anObject [
	records := anObject
]

{ #category : 'private' }
FkQueryResult >> setHeader: aHeaderCollection records: aRecordsCollection statistics: aStatisticsCollection [
	self header: aHeaderCollection.
	self records: aRecordsCollection.
	self statistics: aStatisticsCollection
]

{ #category : 'accessing' }
FkQueryResult >> statistics [
	^ statistics
]

{ #category : 'private' }
FkQueryResult >> statistics: anObject [
	statistics := anObject
]
