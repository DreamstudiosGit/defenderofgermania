class_name MapGeography
extends RefCounted
## Real-world placement of the map from the "geography" section of data/map.json: the realm's
## outline and the projection of longitude/latitude to kilometres on the map table.

const KM_PER_DEGREE_LAT := 110.57
const KM_PER_DEGREE_LON_EQUATOR := 111.32

## Longitude and latitude (degrees) at the map's (0, 0).
var origin := Vector2.ZERO
## Border of the realm as longitude/latitude points, in order.
var outline := PackedVector2Array()


static func read(r: DataReader, data: Dictionary) -> MapGeography:
	var geography := MapGeography.new()
	r.context = "geography"
	geography.origin = lon_lat(r, data, "origin")
	for item: Variant in r.list(data, "outline"):
		var point: Array = item if item is Array else []
		if point.size() == 2 and (point[0] is float or point[0] is int):
			geography.outline.append(Vector2(float(point[0]), float(point[1])))
		else:
			r.errors.append("geography.outline: expected [longitude, latitude] pairs")
	if geography.outline.size() < 3:
		r.errors.append("geography.outline: needs at least three points")
	r.context = ""
	return geography


## Reads a [longitude, latitude] pair.
static func lon_lat(r: DataReader, data: Dictionary, key: String) -> Vector2:
	var values := r.numbers(data, key)
	if values.size() != 2:
		r.errors.append("%s.%s: expected [longitude, latitude]" % [r.context, key])
		return Vector2.ZERO
	return Vector2(values[0], values[1])


## Kilometres east (x) and south (y) of the origin, equirectangular at the origin's latitude.
func to_km(point: Vector2) -> Vector2:
	var east := (point.x - origin.x) * KM_PER_DEGREE_LON_EQUATOR * cos(deg_to_rad(origin.y))
	var south := (origin.y - point.y) * KM_PER_DEGREE_LAT
	return Vector2(east, south)


func outline_km() -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in outline:
		points.append(to_km(point))
	return points


func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_km(point), outline_km())
