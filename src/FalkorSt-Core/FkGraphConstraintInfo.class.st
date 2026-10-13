"
I am one row of CALL db.constraints(): the constraints FalkorDB reports for a single label or
relationship type. I am built from a db.constraints() result; I never talk to FalkorDB myself.

Responsibility:
- Expose the constraint type, entity type/name, properties, and status from one db.constraints()
  record as read-only accessors over the raw mapped record
- Retain that raw mapped record so a missing or renamed key is still inspectable rather than
  silently lost behind a nil accessor

Collaborators:
- FkQueryResult: the CALL db.constraints() result whose mapped records I am built from

Public API and Key Messages:
- #constraintType / #entityType / #entityName / #properties / #status
- FkGraphConstraintInfo class >> allFromQueryResult: - build one instance per record of a
  db.constraints() result
"
Class {
	#name : 'FkGraphConstraintInfo',
	#superclass : 'Object',
	#instVars : [
		'rawConstraintInfo'
	],
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'instance creation' }
FkGraphConstraintInfo class >> allFromQueryResult: aFkQueryResult [
	^ aFkQueryResult mappedRecords collect: [ :record | self fromRecord: record ]
]

{ #category : 'instance creation' }
FkGraphConstraintInfo class >> fromRecord: aDictionary [
	^ self new
		rawConstraintInfo: aDictionary;
		yourself
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> constraintType [
	^ self rawConstraintInfo at: 'type' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> entityName [
	"The db.constraints() 'label' column, named after FkGraphConstraint>>entityName (not
	FkGraphIndexInfo>>label) so a listed constraint reads like the one that was built."

	^ self label
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> label [
	^ self rawConstraintInfo at: 'label' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> entityType [
	^ self rawConstraintInfo at: 'entitytype' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> properties [
	^ self rawConstraintInfo at: 'properties' ifAbsent: []
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> status [
	^ self rawConstraintInfo at: 'status' ifAbsent: []
]

{ #category : 'private-accessing' }
FkGraphConstraintInfo >> rawConstraintInfo [
	^ rawConstraintInfo
]

{ #category : 'private-accessing' }
FkGraphConstraintInfo >> rawConstraintInfo: aDictionary [
	rawConstraintInfo := aDictionary
]
