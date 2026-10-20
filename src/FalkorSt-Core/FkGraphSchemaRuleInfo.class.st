"
I am the abstract superclass of one schema rule (an index or a constraint) as listed by
CALL db.indexes() or CALL db.constraints(). I wrap the raw mapped record and expose the columns
both listings share; subclasses add their rule-specific accessors. I never talk to FalkorDB myself.

Responsibility:
- Build instances from a db.indexes() / db.constraints() FkQueryResult, one per record
- Retain the raw mapped record so a missing or renamed key is still inspectable rather than
  silently lost behind a nil accessor
- Expose the shared #label / #entityType / #properties / #status columns

Collaborators:
- FkQueryResult: the procedure result whose mapped records I am built from

Public API and Key Messages:
- class >> collectFromQueryResult: - build one instance per record of a procedure result
- #label / #entityType / #properties / #status
"
Class {
	#name : 'FkGraphSchemaRuleInfo',
	#superclass : 'Object',
	#instVars : [
		'rawRecord'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkGraphSchemaRuleInfo class >> collectFromQueryResult: aFkQueryResult [
	^ (aFkQueryResult mappedRecords collect: [ :record | self fromRecord: record ]) asArray
]

{ #category : 'instance creation' }
FkGraphSchemaRuleInfo class >> fromRecord: aDictionary [
	^ self new
		rawRecord: aDictionary;
		yourself
]

{ #category : 'accessing' }
FkGraphSchemaRuleInfo >> entityType [
	^ self valueAt: 'entitytype'
]

{ #category : 'accessing' }
FkGraphSchemaRuleInfo >> label [
	^ self valueAt: 'label'
]

{ #category : 'printing' }
FkGraphSchemaRuleInfo >> printOn: aStream [
	super printOn: aStream.
	aStream
		nextPut: $(;
		nextPutAll: (STON toString: self rawRecord);
		nextPut: $)
]

{ #category : 'accessing' }
FkGraphSchemaRuleInfo >> properties [
	^ self valueAt: 'properties'
]

{ #category : 'accessing' }
FkGraphSchemaRuleInfo >> status [
	^ self valueAt: 'status'
]

{ #category : 'private-accessing' }
FkGraphSchemaRuleInfo >> rawRecord [
	^ rawRecord
]

{ #category : 'private-accessing' }
FkGraphSchemaRuleInfo >> rawRecord: aDictionary [
	rawRecord := aDictionary
]

{ #category : 'private-accessing' }
FkGraphSchemaRuleInfo >> valueAt: columnName [
	^ self rawRecord at: columnName ifAbsent: [ nil ]
]
