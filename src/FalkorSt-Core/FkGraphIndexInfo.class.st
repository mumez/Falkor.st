"
I am one row of CALL db.indexes(): the indexes FalkorDB reports for a single label or
relationship type. Properties on that entity can have different kinds, so #types and #options are
dictionaries keyed by property name. I am produced by FkGraphEndpoint>>graphIndexes:; I never talk
to FalkorDB myself.

Responsibility:
- Hold the label, properties, per-property kinds and options, language, stopwords, entity type,
  and status from one db.indexes() record
- Keep the raw mapped record I was built from, so a missing or renamed key is still inspectable
  rather than silently lost behind a nil accessor

Collaborators:
- FkGraphEndpoint: builds instances of me from mapped db.indexes() records

Public API and Key Messages:
- #label / #properties / #types / #options / #language / #stopwords / #entityType / #status
- #rawIndexInfo - the raw mapped db.indexes() record I was built from
- FkGraphIndexInfo class >> fromRecord: - build one instance from a mapped record
"
Class {
	#name : 'FkGraphIndexInfo',
	#superclass : 'Object',
	#instVars : [
		'label',
		'properties',
		'types',
		'options',
		'language',
		'stopwords',
		'entityType',
		'status',
		'rawIndexInfo'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkGraphIndexInfo class >> fromRecord: aDictionary [
	^ self new
		rawIndexInfo: aDictionary;
		label: (aDictionary at: 'label' ifAbsent: []);
		properties: (aDictionary at: 'properties' ifAbsent: []);
		types: (aDictionary at: 'types' ifAbsent: []);
		options: (aDictionary at: 'options' ifAbsent: []);
		language: (aDictionary at: 'language' ifAbsent: []);
		stopwords: (aDictionary at: 'stopwords' ifAbsent: []);
		entityType: (aDictionary at: 'entitytype' ifAbsent: []);
		status: (aDictionary at: 'status' ifAbsent: []);
		yourself
]

{ #category : 'accessing' }
FkGraphIndexInfo >> entityType [
	^ entityType
]

{ #category : 'accessing' }
FkGraphIndexInfo >> label [
	^ label
]

{ #category : 'accessing' }
FkGraphIndexInfo >> language [
	^ language
]

{ #category : 'accessing' }
FkGraphIndexInfo >> options [
	^ options
]

{ #category : 'accessing' }
FkGraphIndexInfo >> properties [
	^ properties
]

{ #category : 'accessing' }
FkGraphIndexInfo >> rawIndexInfo [
	^ rawIndexInfo
]

{ #category : 'accessing' }
FkGraphIndexInfo >> status [
	^ status
]

{ #category : 'accessing' }
FkGraphIndexInfo >> stopwords [
	^ stopwords
]

{ #category : 'accessing' }
FkGraphIndexInfo >> types [
	^ types
]

{ #category : 'private' }
FkGraphIndexInfo >> entityType: anObject [
	entityType := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> label: anObject [
	label := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> language: anObject [
	language := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> options: anObject [
	options := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> properties: anObject [
	properties := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> rawIndexInfo: anObject [
	rawIndexInfo := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> status: anObject [
	status := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> stopwords: anObject [
	stopwords := anObject
]

{ #category : 'private' }
FkGraphIndexInfo >> types: anObject [
	types := anObject
]
