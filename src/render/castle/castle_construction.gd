class_name CastleConstruction
extends RefCounted
## A piece under construction: how deep it still sits in the ground, the scaffold bays around it
## and the site props beside it ("construction" and "pieces" in data/castle_art.json). Scaffold
## spots are [x, y, z, yaw_deg, bays] and site props [piece, x, y, z, yaw_deg] in the piece's
## own coordinates; without spots the bays line the piece's bounding box.

const MAX_STOREYS := 8


## Where a piece at `progress` stands, given its finished place `base`: sunk into the ground so
## that it rises out of it as it grows, or for pieces marked "rise": "grow" (roofs on top of
## others) scaled up from its foot. Its first course always shows.
static func posed(piece: String, base: Transform3D, progress: float) -> Transform3D:
	if progress >= 1.0:
		return base
	var shown := _shown(progress)
	if _grows(piece):
		return base * Transform3D(Basis.from_scale(Vector3.ONE * shown), Vector3.ZERO)
	var mesh := CastleArt.mesh(piece)
	if mesh == null:
		return base
	var depth := (1.0 - shown) * mesh.get_aabb().size.y * base.basis.get_scale().y
	return base.translated(Vector3.DOWN * depth)


## Height of the piece's highest built point in its own coordinates at `progress`.
static func built_top(piece: String, progress: float) -> float:
	var mesh := CastleArt.mesh(piece)
	if mesh == null:
		return 0.0
	var box := mesh.get_aabb()
	var shown := _shown(minf(progress, 1.0))
	if _grows(piece):
		return box.end.y * shown
	return box.end.y - (1.0 - shown) * box.size.y


static func _shown(progress: float) -> float:
	if progress >= 1.0:
		return 1.0
	return lerpf(CastleArt.number("construction", "min_shown", 0.08), 1.0, progress)


static func _grows(piece: String) -> bool:
	var settings: Dictionary = CastleArt.section("pieces").get(piece, {})
	return settings.get("rise", "sink") == "grow"


static func add_props(layout: CastleLayout, target: CastleLayout.Placement) -> void:
	var mesh := CastleArt.mesh(target.piece)
	if mesh == null:
		return
	var box := mesh.get_aabb()
	var settings: Dictionary = CastleArt.section("pieces").get(target.piece, {})
	var spots: Variant = settings.get("scaffold", _perimeter(box))
	var top := built_top(target.piece, target.progress)
	if spots is Array:
		for spot: Variant in spots:
			if spot is Array and (spot as Array).size() == 5:
				_add_bays(layout, target, spot, top)
	var gap := CastleArt.number("construction", "site_gap", 3.0)
	var default_site := str(CastleArt.section("construction").get("default_site", ""))
	var sites: Variant = settings.get("site", [[default_site, 0.0, 0.0, box.end.z + gap, 0.0]])
	if sites is Array:
		for site: Variant in sites:
			if site is Array and (site as Array).size() == 5:
				var item: Array = site
				var local := Vector3(float(item[1]), float(item[2]), float(item[3]))
				_append(layout, target, CastleLayout.Kind.SITE, str(item[0]), local, float(item[4]))


static func _add_bays(
	layout: CastleLayout, target: CastleLayout.Placement, spot: Array, top: float
) -> void:
	var settings := CastleArt.section("construction")
	var piece := str(settings.get("scaffold_piece", ""))
	var width := float(settings.get("bay_width", 3.0))
	var height := float(settings.get("bay_height", 3.0))
	var base := Vector3(float(spot[0]), float(spot[1]), float(spot[2]))
	var yaw := float(spot[3])
	var bays := maxi(1, int(spot[4]))
	var storeys := clampi(ceili((top - base.y) / height), 1, MAX_STOREYS)
	var along := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.RIGHT
	for bay: int in bays:
		var offset := along * width * (bay - (bays - 1) * 0.5)
		for storey: int in storeys:
			var at := base + offset + Vector3.UP * height * storey
			_append(layout, target, CastleLayout.Kind.SCAFFOLD, piece, at, yaw)


static func _append(
	layout: CastleLayout, target: CastleLayout.Placement, kind: CastleLayout.Kind, piece: String,
	local: Vector3, yaw_deg: float
) -> void:
	var placement := CastleLayout.Placement.new()
	placement.piece = piece
	placement.kind = kind
	placement.source = target.source
	placement.transform = (
		target.transform * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), local)
	)
	layout.placements.append(placement)


## Bays along the four sides of the piece's footprint, facing outwards.
static func _perimeter(box: AABB) -> Array:
	var depth := CastleArt.number("construction", "bay_depth", 1.4) * 0.5
	var width := CastleArt.number("construction", "bay_width", 3.0)
	var low := box.position
	var high := box.end
	var center := box.get_center()
	var sides := [
		[center.x, low.y, high.z + depth, 0.0, box.size.x],
		[center.x, low.y, low.z - depth, 180.0, box.size.x],
		[high.x + depth, low.y, center.z, 90.0, box.size.z],
		[low.x - depth, low.y, center.z, -90.0, box.size.z],
	]
	var spots: Array = []
	for side: Array in sides:
		spots.append([side[0], side[1], side[2], side[3], maxi(1, floori(float(side[4]) / width))])
	return spots
