class_name GeoReference
extends RefCounted

const ORIGIN_LAT := 40.15112
const ORIGIN_LON := 26.40200

# Town / landmark reference points.
const CANAKKALE := Vector2(40.15112, 26.40200)
const ECEABAT := Vector2(40.18446, 26.36000)
const KILITBAHIR := Vector2(40.14778, 26.37944)
const DUR_YOLCU := Vector2(40.15647, 26.37316)

# v11 uses the published ferry-terminal coordinates for the actual docking targets.
# Çanakkale: 40°09'02" N, 26°24'07" E
# Eceabat:    40°11'03" N, 26°21'37" E
const CANAKKALE_DOCK := Vector2(40.1505556, 26.4019444)
const ECEABAT_DOCK := Vector2(40.1841667, 26.3602778)

static func to_local(lat_lon: Vector2) -> Vector3:
	var lat0 := deg_to_rad(ORIGIN_LAT)
	var x := (lat_lon.y - ORIGIN_LON) * 111320.0 * cos(lat0)
	var z := -(lat_lon.x - ORIGIN_LAT) * 110540.0
	return Vector3(x, 0.0, z)
