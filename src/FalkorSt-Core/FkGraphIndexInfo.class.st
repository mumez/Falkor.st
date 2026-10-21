"
I am one row of CALL db.indexes(): the indexes FalkorDB reports for a single label or
relationship type. Properties on that entity can have different kinds, so #types and #options are
dictionaries keyed by property name.

Responsibility:
- Add the index-specific per-property kinds and options, language, and stopwords to the columns
  my superclass exposes

Collaborators:
- FkGraphSchemaRuleInfo: my superclass, which builds me from a db.indexes() result

Public API and Key Messages:
- #label / #properties / #types / #options / #language / #stopwords / #entityType / #status
"
Class {
	#name : 'FkGraphIndexInfo',
	#superclass : 'FkGraphSchemaRuleInfo',
	#category : 'FalkorSt-Core',
	#package : 'FalkorSt-Core'
}

{ #category : 'accessing' }
FkGraphIndexInfo >> language [
	^ self valueAt: 'language'
]

{ #category : 'accessing' }
FkGraphIndexInfo >> options [
	^ self valueAt: 'options'
]

{ #category : 'accessing' }
FkGraphIndexInfo >> stopwords [
	^ self valueAt: 'stopwords'
]

{ #category : 'accessing' }
FkGraphIndexInfo >> types [
	^ self valueAt: 'types'
]
