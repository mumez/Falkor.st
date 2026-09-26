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
- FkQueryResult class >> fromCompactReply:resolvedBy:graph: - decode a compact-format GRAPH.QUERY
  raw reply, resolving label/relationship-type/property-key ids through the given FkGraphEndpoint
- #header - OrderedCollection of column name Strings (empty when the query had no RETURN clause)
- #records - OrderedCollection of decoded rows, each row an OrderedCollection of decoded values
- #statistics - OrderedCollection of statistic line Strings
- #recordsDo:, #firstRecordDo:ifNone:, #oneValueDo:ifNone:, #oneValue - safe record accessors
  that don't fail on an empty result (#oneValue answers nil both when there are no records and
  when the first cell is a Cypher null)

Implementation Points:
- In the verbose (non---compact) reply format, only null, integer, and string Cypher values are
  distinguishable on the wire; FalkorDB serializes boolean, double, list, map, and path values as
  plain strings containing their printed form (see FalkorDB's result-structure docs). Decoding
  those into typed Smalltalk values or an FkPath therefore isn't reliable from a verbose reply
  alone; such cells are exposed as their raw String there.
- Node/relationship cells are unambiguous in verbose mode (tagged nested arrays keyed by
  'id'/'labels'/'properties' or 'id'/'type'/'src_node'/'dest_node'/'properties') and are decoded
  in full, including recursively decoding their property values.
- The compact format tags every value as a [ValueType, value] pair (see design.md Decision 7 for
  the full code table), which removes the verbose format's ambiguity: boolean, double, array, map,
  and path values all decode to their proper Smalltalk/FkPath representation. Compact node/
  relationship label, type, and property-key ids are resolved to names via the FkGraphEndpoint
  passed to #fromCompactReply:resolvedBy:graph:.
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

{ #category : 'private-verbose' }
FkQueryResult class >> decodePropertiesFrom: rawPropertyPairs [
	| dict |
	dict := Dictionary new.
	rawPropertyPairs do: [ :pair | dict at: pair first put: (self decodeVerboseValue: pair second) ].
	^ dict
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactCell: rawCell resolvedBy: anEndpoint graph: graphName [
	^ self
		decodeCompactValueType: rawCell first
		raw: rawCell second
		resolvedBy: anEndpoint
		graph: graphName
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactMap: rawMapValue resolvedBy: anEndpoint graph: graphName [
	| dict |
	dict := Dictionary new.
	1 to: rawMapValue size by: 2 do: [ :i |
		dict
			at: (rawMapValue at: i)
			put: (self decodeCompactCell: (rawMapValue at: i + 1) resolvedBy: anEndpoint graph: graphName) ].
	^ dict
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactNode: rawNode resolvedBy: anEndpoint graph: graphName [
	| labels properties |
	labels := rawNode second collect: [ :labelId | anEndpoint labelNameAt: labelId inGraph: graphName ].
	properties := self decodeCompactProperties: rawNode third resolvedBy: anEndpoint graph: graphName.
	^ FkNode id: rawNode first labels: labels properties: properties
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactPath: rawPathValue resolvedBy: anEndpoint graph: graphName [
	^ FkPath
		nodes: (self decodeCompactCell: rawPathValue first resolvedBy: anEndpoint graph: graphName)
		relationships: (self decodeCompactCell: rawPathValue second resolvedBy: anEndpoint graph: graphName)
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactProperties: rawPropertyTriples resolvedBy: anEndpoint graph: graphName [
	| dict |
	dict := Dictionary new.
	rawPropertyTriples do: [ :triple |
		dict
			at: (anEndpoint propertyKeyNameAt: triple first inGraph: graphName)
			put: (self
				decodeCompactValueType: triple second
				raw: triple third
				resolvedBy: anEndpoint
				graph: graphName) ].
	^ dict
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactRecord: rawRecord resolvedBy: anEndpoint graph: graphName [
	^ rawRecord collect: [ :rawCell | self decodeCompactCell: rawCell resolvedBy: anEndpoint graph: graphName ]
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactRelationship: rawRelationship resolvedBy: anEndpoint graph: graphName [
	| properties |
	properties := self decodeCompactProperties: rawRelationship fifth resolvedBy: anEndpoint graph: graphName.
	^ FkRelationship
		id: rawRelationship first
		type: (anEndpoint relationshipTypeNameAt: rawRelationship second inGraph: graphName)
		startNodeId: rawRelationship third
		endNodeId: rawRelationship fourth
		properties: properties
]

{ #category : 'private-compact' }
FkQueryResult class >> decodeCompactValueType: typeCode raw: rawValue resolvedBy: anEndpoint graph: graphName [
	"See falkordb-go's `ResultSetScalarTypes` enum for the full ValueType code table."
	typeCode = 1 ifTrue: [ ^ nil ]. "VALUE_NULL"
	typeCode = 2 ifTrue: [ ^ rawValue ]. "VALUE_STRING"
	typeCode = 3 ifTrue: [ ^ rawValue ]. "VALUE_INTEGER"
	typeCode = 4 ifTrue: [ ^ rawValue = 'true' ]. "VALUE_BOOLEAN"
	typeCode = 5 ifTrue: [ ^ (rawValue copyReplaceAll: 'e+' with: 'e') asNumber ]. "VALUE_DOUBLE"
	typeCode = 6 ifTrue: [ ^ rawValue collect: [ :cell | self decodeCompactCell: cell resolvedBy: anEndpoint graph: graphName ] ]. "VALUE_ARRAY"
	typeCode = 7 ifTrue: [ ^ self decodeCompactRelationship: rawValue resolvedBy: anEndpoint graph: graphName ]. "VALUE_EDGE"
	typeCode = 8 ifTrue: [ ^ self decodeCompactNode: rawValue resolvedBy: anEndpoint graph: graphName ]. "VALUE_NODE"
	typeCode = 9 ifTrue: [ ^ self decodeCompactPath: rawValue resolvedBy: anEndpoint graph: graphName ]. "VALUE_PATH"
	typeCode = 10 ifTrue: [ ^ self decodeCompactMap: rawValue resolvedBy: anEndpoint graph: graphName ]. "VALUE_MAP"
	^ rawValue "VALUE_UNKNOWN/VALUE_POINT/VALUE_VECTORF32: not needed by this change, left undecoded"
]

{ #category : 'private-verbose' }
FkQueryResult class >> decodeVerboseGraphEntity: rawEntity [
	| secondFieldName |
	secondFieldName := rawEntity second first.
	secondFieldName = 'labels' ifTrue: [ ^ self decodeVerboseNode: rawEntity ].
	secondFieldName = 'type' ifTrue: [ ^ self decodeVerboseRelationship: rawEntity ].
	^ rawEntity
]

{ #category : 'private-verbose' }
FkQueryResult class >> decodeVerboseNode: rawNode [
	^ FkNode
		id: rawNode first second
		labels: rawNode second second
		properties: (self decodePropertiesFrom: rawNode third second)
]

{ #category : 'private-verbose' }
FkQueryResult class >> decodeVerboseRecord: rawRecord [
	^ rawRecord collect: [ :rawValue | self decodeVerboseValue: rawValue ]
]

{ #category : 'private-verbose' }
FkQueryResult class >> decodeVerboseRelationship: rawRelationship [
	^ FkRelationship
		id: rawRelationship first second
		type: rawRelationship second second
		startNodeId: rawRelationship third second
		endNodeId: rawRelationship fourth second
		properties: (self decodePropertiesFrom: rawRelationship fifth second)
]

{ #category : 'private-verbose' }
FkQueryResult class >> decodeVerboseValue: rawValue [
	"OrderedCollection is RediStick's generic nested-RESP-array shape; a node/relationship value
	arrives as one, while every other verbose scalar (string, integer, nil) does not, so this check
	- rather than a polymorphic dispatch - is what actually distinguishes them here."
	(rawValue isKindOf: OrderedCollection) ifTrue: [ ^ self decodeVerboseGraphEntity: rawValue ].
	^ rawValue
]

{ #category : 'instance creation' }
FkQueryResult class >> fromCompactReply: rawReply resolvedBy: anEndpoint graph: graphName [
	rawReply size = 1
		ifTrue: [ ^ self new setHeader: #() records: #() statistics: rawReply first ].
	^ self new
		setHeader: (rawReply first collect: [ :headerCell | headerCell second ])
		records: (rawReply second collect: [ :rawRecord |
			self decodeCompactRecord: rawRecord resolvedBy: anEndpoint graph: graphName ])
		statistics: rawReply third
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
FkQueryResult >> firstRecordDo: aBlock [
	^ self firstRecordDo: aBlock ifNone: [ nil ]
]

{ #category : 'accessing' }
FkQueryResult >> firstRecordDo: aBlock ifNone: noneBlock [
	^ self records
		ifEmpty: noneBlock
		ifNotEmpty: [ :nonEmptyRecords | aBlock value: nonEmptyRecords first ]
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
FkQueryResult >> oneValue [
	^ self oneValueDo: [ :value | value ]
]

{ #category : 'accessing' }
FkQueryResult >> oneValueDo: aBlock [
	^ self oneValueDo: aBlock ifNone: [ nil ]
]

{ #category : 'accessing' }
FkQueryResult >> oneValueDo: aBlock ifNone: noneBlock [
	^ self firstRecordDo: [ :record | aBlock value: record first ] ifNone: noneBlock
]

{ #category : 'accessing' }
FkQueryResult >> records [
	^ records
]

{ #category : 'private' }
FkQueryResult >> records: anObject [
	records := anObject
]

{ #category : 'enumerating' }
FkQueryResult >> recordsDo: aBlock [
	self records do: aBlock
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
