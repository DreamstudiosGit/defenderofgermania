class_name CastleSettlement
extends RefCounted
## The village around a castle: how many houses a population shows and where they stand
## ("settlement" in data/castle_art.json). Lots come from one fixed shuffle and are taken
## nearest-first (houses along the road count as nearer), so a growing village keeps its houses
## and adds new ones at its edge.


class Lot:
	var piece: String
	var transform: Transform3D


static func house_count(population: float) -> int:
	var settings := CastleArt.section("settlement")
	var count := roundi(population * float(settings.get("houses_per_population", 0.5)))
	return clampi(count, int(settings.get("min_houses", 0)), int(settings.get("max_houses", 40)))


## Up to `count` lots outside `inner_radius`; keep_outs are circles (x, z, radius) to avoid.
static func lots(count: int, inner_radius: float, keep_outs: Array[Vector3]) -> Array[Lot]:
	var settings := CastleArt.section("settlement")
	var spacing := float(settings.get("spacing", 8.0))
	var road := float(settings.get("road_half_width", 5.0))
	var result: Array[Lot] = []
	var taken: Array[Vector2] = []
	for candidate: Dictionary in _candidates(inner_radius, settings):
		if result.size() >= count:
			break
		var at: Vector2 = candidate["at"]
		if at.y > 0.0 and absf(at.x) < road + spacing * 0.4:
			continue
		if _blocked(at, keep_outs) or _crowded(at, taken, spacing):
			continue
		taken.append(at)
		var lot := Lot.new()
		lot.piece = str(candidate["piece"])
		var basis := Basis(Vector3.UP, float(candidate["yaw"])).scaled(
			Vector3.ONE * float(candidate["scale"])
		)
		lot.transform = Transform3D(basis, Vector3(at.x, 0.0, at.y))
		result.append(lot)
	return result


static func _candidates(inner_radius: float, settings: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.get("seed", 1198))
	var outer := float(settings.get("outer_radius", 60.0))
	var pull := float(settings.get("road_pull", 12.0))
	var road := float(settings.get("road_half_width", 5.0))
	var jitter := deg_to_rad(float(settings.get("yaw_jitter_deg", 10.0)))
	var variants: Array = settings.get("variants", [])
	var weights: Array = settings.get("variant_weights", [])
	var result: Array[Dictionary] = []
	for i: int in int(settings.get("candidates", 1000)):
		var angle := rng.randf() * TAU
		var radius := sqrt(lerpf(inner_radius * inner_radius, outer * outer, rng.randf()))
		var at := Vector2(cos(angle), sin(angle)) * radius
		var road_distance := absf(at.x) - road if at.y > 0.0 else INF
		var by_road := road_distance < 9.0
		# Houses by the road face it; the others face the castle.
		var facing := Vector2(-signf(at.x), 0.0) if by_road else -at.normalized()
		var candidate := {
			"at": at,
			"yaw": atan2(facing.x, facing.y) + rng.randf_range(-jitter, jitter),
			"scale": rng.randf_range(
				float(settings.get("scale_min", 1.0)), float(settings.get("scale_max", 1.0))
			),
			"piece": _variant(variants, weights, rng.randf()),
			"score": radius - (pull if by_road else 0.0),
		}
		result.append(candidate)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"])
	)
	return result


static func _variant(variants: Array, weights: Array, roll: float) -> String:
	if variants.is_empty():
		return ""
	var total := 0.0
	for i: int in variants.size():
		total += float(weights[i]) if i < weights.size() else 1.0
	var pick := roll * total
	for i: int in variants.size():
		pick -= float(weights[i]) if i < weights.size() else 1.0
		if pick <= 0.0:
			return str(variants[i])
	return str(variants[-1])


static func _blocked(at: Vector2, keep_outs: Array[Vector3]) -> bool:
	for circle: Vector3 in keep_outs:
		if at.distance_to(Vector2(circle.x, circle.y)) < circle.z:
			return true
	return false


static func _crowded(at: Vector2, taken: Array[Vector2], spacing: float) -> bool:
	for other: Vector2 in taken:
		if at.distance_squared_to(other) < spacing * spacing:
			return true
	return false
