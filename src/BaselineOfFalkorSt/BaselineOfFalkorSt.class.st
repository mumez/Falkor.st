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
			package: 'FalkorSt-Core' with: [ spec requires: #('RediStick' 'SCypher') ].
		spec
			package: 'FalkorSt-Core-Tests' with: [ spec requires: #('FalkorSt-Core') ].

		spec
			group: 'default' with: #('Core');
			group: 'Core' with: #('FalkorSt-Core');
			group: 'Tests' with: #('FalkorSt-Core-Tests') ]
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
