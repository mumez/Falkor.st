"
I test FkSettings' targetUrl and queryTimeoutMsecs default and override behavior.

Coverage:
- graph-object-api spec: ""Default target URL"" / ""Explicit target URL""
- query-timeout spec: ""Default query timeout"" / ""Explicit query timeout""
"
Class {
	#name : 'FkSettingsTest',
	#superclass : 'TestCase',
	#category : 'FalkorSt-Core-Tests',
	#package : 'FalkorSt-Core-Tests'
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

{ #category : 'tests' }
FkSettingsTest >> testDefaultQueryTimeoutMsecs [
	self assert: FkSettings new queryTimeoutMsecs equals: 0
]

{ #category : 'tests' }
FkSettingsTest >> testExplicitQueryTimeoutMsecs [
	| settings |
	settings := FkSettings new.
	settings queryTimeoutMsecs: 5000.
	self assert: settings queryTimeoutMsecs equals: 5000
]

{ #category : 'tests' }
FkSettingsTest >> testDefaultCopiedCopiesDefaultValues [
	| originalTargetUrl |
	originalTargetUrl := FkSettings default targetUrl.
	[
		FkSettings default targetUrl: 'sync://example.com:1234'.
		self assert: FkSettings defaultCopied targetUrl equals: 'sync://example.com:1234' ]
		ensure: [ FkSettings default targetUrl: originalTargetUrl ]
]

{ #category : 'tests' }
FkSettingsTest >> testDefaultCopiedDoesNotAffectDefault [
	| originalTimeout copied |
	originalTimeout := FkSettings default queryTimeoutMsecs.
	copied := FkSettings defaultCopied.
	copied queryTimeoutMsecs: originalTimeout + 1234.
	self assert: FkSettings default queryTimeoutMsecs equals: originalTimeout
]
