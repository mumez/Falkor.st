"
I test FkSettings' targetUrl default and override behavior.

Coverage:
- graph-object-api spec: ""Default target URL"" / ""Explicit target URL""
"
Class {
	#name : 'FkSettingsTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Objects-Tests',
	#package : 'FalkorSt-Objects-Tests'
}

{ #category : 'tests' }
FkSettingsTest >> testDefaultTargetUrl [
	self assert: FkSettings new targetUrl equals: 'sync://localhost:6379'
]

{ #category : 'tests' }
FkSettingsTest >> testExplicitTargetUrl [
	| settings |
	settings := FkSettings new.
	settings targetUrl: 'sync://example.com:1234'.
	self assert: settings targetUrl equals: 'sync://example.com:1234'
]
