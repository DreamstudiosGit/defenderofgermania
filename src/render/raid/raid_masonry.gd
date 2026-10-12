class_name RaidMasonry
extends RefCounted
## Lays the raid's walls in staggered stone blocks with a little jitter in depth and shade, drawn
## as one MultiMesh in front of a dark mortar backing, so the ink pass picks out every block.

const DEPTH := 0.3
const GAP := 0.035

## Walls as (x0, y0, x1, y1) with their plane in _planes.
var _walls: Array[Vector4] = []
var _planes := PackedFloat64Array()


func wall(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	if x1 - x0 > 0.01 and y1 - y0 > 0.01:
		_walls.append(Vector4(x0, y0, x1, y1))
		_planes.append(z)


func build(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var block_size: Array = RaidArt.list("rooms", "block_size")
	var width := float(block_size[0]) if block_size.size() == 2 else 0.62
	var height := float(block_size[1]) if block_size.size() == 2 else 0.34
	var transforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	var stone := RaidArt.color("stone")
	var dark := RaidArt.color("stone_dark")
	for i: int in _walls.size():
		var rect := _walls[i]
		var z := _planes[i]
		root.add_child(RaidArt.box(
			Vector3(rect.z - rect.x, rect.w - rect.y, 0.1),
			Vector3((rect.x + rect.z) * 0.5, (rect.y + rect.w) * 0.5, z - DEPTH - 0.05), "stone_cut"
		))
		var y := floorf(rect.y / height) * height
		while y < rect.w:
			var row_height := height * rng.randf_range(0.8, 1.2)
			var x := floorf(rect.x / width) * width - width * rng.randf_range(0.0, 0.9)
			while x < rect.z:
				var block_width := width * rng.randf_range(0.6, 1.5)
				var left := maxf(x, rect.x)
				var right := minf(x + block_width, rect.z)
				var bottom := maxf(y, rect.y)
				var top := minf(y + row_height, rect.w)
				if right - left > 0.05 and top - bottom > 0.05:
					var size := Vector3(right - left - GAP, top - bottom - GAP, DEPTH)
					var center := Vector3(
						(left + right) * 0.5, (bottom + top) * 0.5,
						z - DEPTH * 0.5 + rng.randf_range(-0.03, 0.04)
					)
					transforms.append(Transform3D(Basis.from_scale(size), center))
					var shade := stone.lerp(dark, rng.randf() * 0.7) * rng.randf_range(0.9, 1.08)
					colors.append(Color(shade, 1.0))
				x += block_width
			y += row_height
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	var blocks := MultiMeshInstance3D.new()
	blocks.multimesh = multimesh
	blocks.material_override = RaidArt.instance_material()
	root.add_child(blocks)
	return root
