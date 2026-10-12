class_name MapGeometry
extends RefCounted
## Plane geometry of the map table in kilometres (x east, y south): Voronoi cells of the
## province centres clipped to the realm, a hand-drawn wobble for their borders, point lookup.
## The drawing only approximates the realm; the adjacency list in data/map.json is the rule.


static func centres_km(map: MapData) -> Dictionary[String, Vector2]:
	var centres: Dictionary[String, Vector2] = {}
	for id: String in map.provinces:
		centres[id] = map.geography.to_km(map.provinces[id].at)
	return centres


static func province_cells(map: MapData) -> Dictionary[String, PackedVector2Array]:
	return voronoi_cells(centres_km(map), map.geography.outline_km())


## The part of the outline closer to each site than to any other; when the outline cuts a
## cell apart, the piece holding the site.
static func voronoi_cells(
	sites: Dictionary[String, Vector2], outline: PackedVector2Array
) -> Dictionary[String, PackedVector2Array]:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		bounds = bounds.expand(point)
	for site: Vector2 in sites.values():
		bounds = bounds.expand(site)
	bounds = bounds.grow(1.0)
	var box := PackedVector2Array([
		bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	])
	var cells: Dictionary[String, PackedVector2Array] = {}
	for id: String in sites:
		var cell := box
		for other: String in sites:
			if other != id and not cell.is_empty():
				cell = _closer_half(cell, sites[id], sites[other])
		cells[id] = _piece_with(Geometry2D.intersect_polygons(cell, outline), sites[id])
	return cells


## Subdivides the polygon into steps of at most `step` and moves every point along a smooth
## field, so shared borders bend the same way in both cells. The field moves no point by more
## than `amplitude` and stays one-to-one while amplitude / wavelength is below about 0.09.
static func wobble(
	polygon: PackedVector2Array, amplitude: float, wavelength: float, step: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var count := maxi(1, ceili(a.distance_to(b) / step))
		for k: int in count:
			var point := a.lerp(b, float(k) / count)
			result.append(point + displacement(point, amplitude, wavelength))
	return result


static func displacement(point: Vector2, amplitude: float, wavelength: float) -> Vector2:
	var q := point * TAU / wavelength
	var coarse := Vector2(sin(q.y + 0.7), sin(q.x * 1.13 + 1.3))
	var fine := Vector2(sin(q.x * 2.3 + q.y * 1.7 + 2.1), sin(q.y * 2.6 - q.x * 1.4 + 0.4))
	return (coarse * 0.7 + fine * 0.3) * amplitude


static func wobbled_cells(
	cells: Dictionary[String, PackedVector2Array], amplitude: float, wavelength: float,
	step: float
) -> Dictionary[String, PackedVector2Array]:
	var result: Dictionary[String, PackedVector2Array] = {}
	for id: String in cells:
		result[id] = wobble(cells[id], amplitude, wavelength, step)
	return result


## The cell holding the point, or "" outside every cell.
static func cell_at(cells: Dictionary[String, PackedVector2Array], point: Vector2) -> String:
	for id: String in cells:
		if Geometry2D.is_point_in_polygon(point, cells[id]):
			return id
	return ""


static func area(polygon: PackedVector2Array) -> float:
	return absf(signed_area(polygon))


## Positive when the polygon turns counter-clockwise in x-right, y-up terms.
static func signed_area(polygon: PackedVector2Array) -> float:
	var twice := 0.0
	for i: int in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		twice += a.x * b.y - b.x * a.y
	return twice * 0.5


## Pairs "A-B" (A < B) of cells sharing a border longer than `min_km`.
static func touching_pairs(
	cells: Dictionary[String, PackedVector2Array], min_km: float = 5.0
) -> Array[String]:
	var pairs: Array[String] = []
	var ids: Array[String] = []
	ids.assign(cells.keys())
	ids.sort()
	for i: int in ids.size():
		var grown := Geometry2D.offset_polygon(cells[ids[i]], 1.0)
		if grown.is_empty():
			continue
		for j: int in range(i + 1, ids.size()):
			var shared := 0.0
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(grown[0], cells[ids[j]]):
				shared += area(piece)
			if shared > min_km:
				pairs.append("%s-%s" % [ids[i], ids[j]])
	return pairs


## Clips a convex polygon to the half plane closer to `site` than to `other`.
static func _closer_half(
	polygon: PackedVector2Array, site: Vector2, other: Vector2
) -> PackedVector2Array:
	var middle := (site + other) * 0.5
	var away := other - site
	var result := PackedVector2Array()
	for i: int in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var side_a := (a - middle).dot(away)
		var side_b := (b - middle).dot(away)
		if side_a <= 0.0:
			result.append(a)
		if (side_a < 0.0 and side_b > 0.0) or (side_a > 0.0 and side_b < 0.0):
			result.append(a.lerp(b, side_a / (side_a - side_b)))
	return result


static func _piece_with(pieces: Array[PackedVector2Array], site: Vector2) -> PackedVector2Array:
	var largest := PackedVector2Array()
	for piece: PackedVector2Array in pieces:
		if Geometry2D.is_point_in_polygon(site, piece):
			return piece
		if area(piece) > area(largest):
			largest = piece
	return largest
