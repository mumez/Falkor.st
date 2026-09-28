Extension { #name : 'Point' }

{ #category : '*FalkorSt-Core' }
Point >> asFkPoint [
	"Answer an FkPoint, reading x as longitude and y as latitude (GIS/GeoJSON order)"

	^ FkPoint latitude: self y longitude: self x
]
