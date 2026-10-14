"
I am one row of CALL db.constraints(): the constraints FalkorDB reports for a single label or
relationship type.

Responsibility:
- Add the constraint type and an FkGraphConstraint-style #entityName to the columns my
  superclass exposes

Collaborators:
- FkGraphProcedureRowInfo: my superclass, which builds me from a db.constraints() result

Public API and Key Messages:
- #constraintType / #entityType / #entityName / #properties / #status
"
Class {
	#name : 'FkGraphConstraintInfo',
	#superclass : 'FkGraphProcedureRowInfo',
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'accessing' }
FkGraphConstraintInfo >> constraintType [
	^ self valueAt: 'type'
]

{ #category : 'accessing' }
FkGraphConstraintInfo >> entityName [
	"The db.constraints() 'label' column, named after FkGraphConstraint>>entityName (not
	FkGraphIndexInfo>>label) so a listed constraint reads like the one that was built."

	^ self label
]
