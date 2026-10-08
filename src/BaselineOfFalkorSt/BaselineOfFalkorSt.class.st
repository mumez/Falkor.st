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
		self neo4reSt: spec.
		spec
			package: 'FalkorSt-Core' with: [ spec requires: #('RediStick' 'SCypher') ].
		spec
			package: 'FalkorSt-Core-Tests' with: [ spec requires: #('FalkorSt-Core') ].
		spec
			package: 'FalkorSt-Objects' with: [ spec requires: #('FalkorSt-Core' 'SCypher') ].
		spec
			package: 'FalkorSt-Objects-Tests' with: [ spec requires: #('FalkorSt-Core-Tests' 'FalkorSt-Objects') ].
		spec
			package: 'FalkorSt-Udf' with: [ spec requires: #('FalkorSt-Core') ].
		spec
			package: 'FalkorSt-Udf-Tests' with: [ spec requires: #('FalkorSt-Core-Tests' 'FalkorSt-Udf') ].
		spec
			package: 'FalkorSt-Benchmarks' with: [ spec requires: #('FalkorSt-Objects' 'Neo4reSt') ].
		spec
			package: 'FalkorSt-Benchmarks-Tests' with: [ spec requires: #('FalkorSt-Benchmarks') ].

		spec
			group: 'default' with: #('Core' 'Objects' 'Udf' 'Tests');
			group: 'Core' with: #('FalkorSt-Core');
			group: 'Tests' with: #('FalkorSt-Core-Tests' 'FalkorSt-Objects' 'FalkorSt-Objects-Tests' 'FalkorSt-Udf' 'FalkorSt-Udf-Tests');
			group: 'Objects' with: #('FalkorSt-Objects');
			group: 'ObjectsTests' with: #('FalkorSt-Objects-Tests');
			group: 'Udf' with: #('FalkorSt-Udf');
			group: 'UdfTests' with: #('FalkorSt-Udf-Tests');
			group: 'Benchmarks' with: #('FalkorSt-Benchmarks');
			group: 'BenchmarksTests' with: #('FalkorSt-Benchmarks-Tests') ]
]

{ #category : 'external projects' }
BaselineOfFalkorSt >> neo4reSt: spec [
	spec
		baseline: 'Neo4reSt'
		with: [ spec
				repository: 'github://mumez/Neo4reSt/src';
				loads: 'Core' ]
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
