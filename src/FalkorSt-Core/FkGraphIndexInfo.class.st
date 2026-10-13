"
I am one row of CALL db.indexes(): the indexes FalkorDB reports for a single label or
relationship type. Properties on that entity can have different kinds, so #types and #options are
dictionaries keyed by property name. I am built from a db.indexes() result; I never talk to
FalkorDB myself.

Responsibility:
- Expose the label, properties, per-property kinds and options, language, stopwords, entity type,
  and status from one db.indexes() record as read-only accessors over the raw mapped record
- Retain that raw mapped record so a missing or renamed key is still inspectable rather than
  silently lost behind a nil accessor

Collaborators:
- FkQueryResult: the CALL db.indexes() result whose mapped records I am built from

Public API and Key Messages:
- #label / #properties / #types / #options / #language / #stopwords / #entityType / #status
- FkGraphIndexInfo class >> allFromQueryResult: - build one instance per record of a db.indexes()
  result
"
Class {
	#name : 'FkGraphIndexInfo',
	#superclass : 'Object',
	#instVars : [
		'rawIndexInfo'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkGraphIndexInfo class >> allFromQueryResult: aFkQueryResult [
	^ aFkQueryResult mappedRecords collect: [ :record | self fromRecord: record ]
]

{ #category : 'instance creation' }
FkGraphIndexInfo class >> fromRecord: aDictionary [
	^ self new
		rawIndexInfo: aDictionary;
		yourself
]

{ #category : 'accessing' }
FkGraphIndexInfo >> entityType [
	^ self rawIndexInfo at: 'entitytype' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> label [
	^ self rawIndexInfo at: 'label' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> language [
	^ self rawIndexInfo at: 'language' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> options [
	^ self rawIndexInfo at: 'options' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> properties [
	^ self rawIndexInfo at: 'properties' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> status [
	^ self rawIndexInfo at: 'status' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> stopwords [
	^ self rawIndexInfo at: 'stopwords' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphIndexInfo >> types [
	^ self rawIndexInfo at: 'types' ifAbsent: []
]

{ #category : 'private-accessing' }
FkGraphIndexInfo >> rawIndexInfo [
	^ rawIndexInfo
]

{ #category : 'private-accessing' }
FkGraphIndexInfo >> rawIndexInfo: aDictionary [
	rawIndexInfo := aDictionary
]
