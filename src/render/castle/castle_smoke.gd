class_name CastleSmoke
extends RefCounted
## Chimney smoke over every n-th finished house or hall that has a chimney ("smoke" in
## data/castle_art.json, chimney tops in the piece's own coordinates): the village is lived in.


## Adds smoke to `node`, the `index`-th placed piece, when its piece has a chimney and its turn
## comes up.
static func add(node: MeshInstance3D, piece: String, index: int) -> void:
	var settings := CastleArt.section("smoke")
	var chimneys: Dictionary = settings.get("chimneys", {})
	var every := maxi(int(settings.get("every", 1)), 1)
	if not chimneys.has(piece) or index % every != 0:
		return
	var tops: Variant = chimneys[piece]
	if not tops is Array:
		return
	for top: Variant in tops:
		node.add_child(_emitter(CastleArt.vector(top), settings))


static func _emitter(at: Vector3, settings: Dictionary) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = at
	smoke.amount = int(settings.get("amount", 6))
	smoke.lifetime = float(settings.get("lifetime", 4.0))
	smoke.preprocess = smoke.lifetime
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	var speed := float(settings.get("speed", 1.0))
	smoke.initial_velocity_min = speed * 0.7
	smoke.initial_velocity_max = speed * 1.2
	smoke.gravity = CastleArt.vector(settings.get("drift"), Vector3(0.4, 0.2, 0.1))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	var color := CastleArt.color("smoke", "color", Color(0.92, 0.9, 0.86, 0.7))
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	smoke.color_ramp = fade
	var quad := QuadMesh.new()
	var size := float(settings.get("size", 1.5))
	quad.size = Vector2(size, size)
	quad.material = CastleArt.puff()
	smoke.mesh = quad
	return smoke
