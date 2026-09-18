Class {
	#name : 'BaselineOfFalkorSt',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfFalkorSt',
	#package : 'BaselineOfFalkorSt'
}

{ #category : 'baseline' }
BaselineOfFalkorSt >> baseline: spec [
	<baseline>

	spec for: #'common' do: [
		self rediStick: spec.
		self sCypher: spec.
		spec
			package: 'FalkorSt-Core' with: [ spec requires: #('RediStick') ].
		spec
			package: 'FalkorSt-Core-Tests' with: [ spec requires: #('FalkorSt-Core') ].
		spec
			package: 'FalkorSt-Objects' with: [ spec requires: #('FalkorSt-Core' 'SCypher') ].
		spec
			package: 'FalkorSt-Objects-Tests' with: [ spec requires: #('FalkorSt-Core-Tests' 'FalkorSt-Objects') ].

		spec
			group: 'default' with: #('Core');
			group: 'Core' with: #('FalkorSt-Core');
			group: 'Tests' with: #('FalkorSt-Core-Tests' 'FalkorSt-Objects' 'FalkorSt-Objects-Tests');
			group: 'Objects' with: #('FalkorSt-Objects');
			group: 'ObjectsTests' with: #('FalkorSt-Objects-Tests') ]
]

{ #category : 'external projects' }
BaselineOfFalkorSt >> rediStick: spec [
	spec
		baseline: 'RediStick'
		with: [ spec
				repository: 'github://mumez/RediStick/src';
				loads: 'Core' ]
]

{ #category : 'external projects' }
BaselineOfFalkorSt >> sCypher: spec [
	spec
		baseline: 'SCypher'
		with: [ spec
				repository: 'github://mumez/SCypher/repository';
				loads: 'Core' ]
]
