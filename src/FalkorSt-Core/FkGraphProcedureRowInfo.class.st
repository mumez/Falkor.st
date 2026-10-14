"
I am the abstract superclass of one row of a FalkorDB listing procedure such as CALL db.indexes()
or CALL db.constraints(). I wrap the raw mapped record and expose the columns every such listing
shares; subclasses add their procedure-specific accessors. I never talk to FalkorDB myself.

Responsibility:
- Build instances from a procedure's FkQueryResult, one per record
- Retain the raw mapped record so a missing or renamed key is still inspectable rather than
  silently lost behind a nil accessor
- Expose the shared #label / #entityType / #properties / #status columns

Collaborators:
- FkQueryResult: the procedure result whose mapped records I am built from

Public API and Key Messages:
- class >> allFromQueryResult: - build one instance per record of a procedure result
- #label / #entityType / #properties / #status
"
Class {
	#name : 'FkGraphProcedureRowInfo',
	#superclass : 'Object',
	#instVars : [
		'rawRecord'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkGraphProcedureRowInfo class >> allFromQueryResult: aFkQueryResult [
	^ (aFkQueryResult mappedRecords collect: [ :record | self fromRecord: record ]) asArray
]

{ #category : 'instance creation' }
FkGraphProcedureRowInfo class >> fromRecord: aDictionary [
	^ self new
		rawRecord: aDictionary;
		yourself
]

{ #category : 'accessing' }
FkGraphProcedureRowInfo >> entityType [
	^ self valueAt: 'entitytype'
]

{ #category : 'accessing' }
FkGraphProcedureRowInfo >> label [
	^ self valueAt: 'label'
]

{ #category : 'accessing' }
FkGraphProcedureRowInfo >> properties [
	^ self valueAt: 'properties'
]

{ #category : 'accessing' }
FkGraphProcedureRowInfo >> status [
	^ self valueAt: 'status'
]

{ #category : 'private-accessing' }
FkGraphProcedureRowInfo >> rawRecord [
	^ rawRecord
]

{ #category : 'private-accessing' }
FkGraphProcedureRowInfo >> rawRecord: aDictionary [
	rawRecord := aDictionary
]

{ #category : 'private-accessing' }
FkGraphProcedureRowInfo >> valueAt: columnName [
	^ self rawRecord at: columnName ifAbsent: [ nil ]
]
