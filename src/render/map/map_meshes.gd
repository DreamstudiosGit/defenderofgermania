class_name MapMeshes
extends RefCounted
## Mesh builders for the map table: raised fields, flat ink ribbons and pieces assembled from
## primitive shapes. Plane points are table units (x east, y = world z south).


## Collects primitive shapes into one mesh with one surface per slot (one paint per slot).
class Assembly:
	var _tools: Array[SurfaceTool] = []

	func _init(slots: int) -> void:
		for slot: int in slots:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools.append(tool)

	func add(slot: int, shape: PrimitiveMesh, at: Transform3D) -> void:
		_tools[slot].append_from(shape, 0, at)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for tool: SurfaceTool in _tools:
			tool.commit(mesh)
		return mesh


## A flat-topped block over the polygon from `bottom` to `top`.
static func prism(polygon: PackedVector2Array, bottom: float, top: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_cap(tool, polygon, top)
	var turn := signf(MapGeometry.signed_area(polygon))
	for i: int in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var along := (b - a).normalized()
		var outward := Vector3(along.y, 0.0, -along.x) * turn
		var corners: Array[Vector3] = [
			Vector3(a.x, top, a.y), Vector3(b.x, top, b.y),
			Vector3(b.x, bottom, b.y), Vector3(a.x, bottom, a.y),
		]
		triangle(tool, corners[0], corners[1], corners[2], outward)
		triangle(tool, corners[0], corners[2], corners[3], outward)
	return tool.commit()


## The polygon as an upward face at height y.
static func add_cap(tool: SurfaceTool, polygon: PackedVector2Array, y: float) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i: int in range(0, indices.size(), 3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i + 1]]
		var c := polygon[indices[i + 2]]
		triangle(tool, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP)


## A flat strip at height y along the points, `width` wide; its middle runs `offset` to the
## left of the walking direction (left as in a counter-clockwise polygon's inside).
static func add_ribbon(
	tool: SurfaceTool, points: PackedVector2Array, closed: bool, width: float, y: float,
	offset: float = 0.0
) -> void:
	var count := points.size()
	if count < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i: int in count:
		var normal := _miter(points, i, closed)
		left.append(points[i] + normal * (offset + width * 0.5))
		right.append(points[i] + normal * (offset - width * 0.5))
	var segments := count if closed else count - 1
	for i: int in segments:
		var j := (i + 1) % count
		var quad: Array[Vector3] = [
			Vector3(left[i].x, y, left[i].y), Vector3(left[j].x, y, left[j].y),
			Vector3(right[j].x, y, right[j].y), Vector3(right[i].x, y, right[i].y),
		]
		triangle(tool, quad[0], quad[1], quad[2], Vector3.UP)
		triangle(tool, quad[0], quad[2], quad[3], Vector3.UP)


## A ribbon running just inside the polygon's edge.
static func add_inner_ribbon(
	tool: SurfaceTool, polygon: PackedVector2Array, width: float, y: float
) -> void:
	var inward := signf(MapGeometry.signed_area(polygon))
	add_ribbon(tool, polygon, true, width, y, width * 0.5 * inward)


## Adds the triangle so that it faces `normal` (Godot draws clockwise faces as front).
static func triangle(
	tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3
) -> void:
	var corners: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		corners = [a, c, b]
	for corner: Vector3 in corners:
		tool.set_normal(normal)
		tool.add_vertex(corner)


static func cylinder(top: float, bottom: float, height: float, sides: int = 12) -> CylinderMesh:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return shape


static func sphere(radius: float, height: float, hemisphere: bool = false) -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 12
	shape.rings = 6
	shape.is_hemisphere = hemisphere
	return shape


static func box(size: Vector3) -> BoxMesh:
	var shape := BoxMesh.new()
	shape.size = size
	return shape


static func wedge(size: Vector3) -> PrismMesh:
	var shape := PrismMesh.new()
	shape.size = size
	return shape


static func at(position: Vector3, yaw_deg: float = 0.0, roll_deg: float = 0.0) -> Transform3D:
	var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(yaw_deg), deg_to_rad(roll_deg)))
	return Transform3D(basis, position)


## Unit normal at point i, lengthened at corners so both edges keep the strip's width.
static func _miter(points: PackedVector2Array, i: int, closed: bool) -> Vector2:
	var count := points.size()
	var previous := i - 1 if i > 0 else (count - 1 if closed else -1)
	var next := i + 1 if i < count - 1 else (0 if closed else -1)
	var normal := Vector2.ZERO
	var first := Vector2.ZERO
	if previous >= 0:
		first = _left(points[i] - points[previous])
		normal += first
	if next >= 0:
		var second := _left(points[next] - points[i])
		normal += second
		if first == Vector2.ZERO:
			first = second
	if normal.length_squared() < 1e-12:
		return first
	normal = normal.normalized()
	return normal / maxf(normal.dot(first), 0.35)


static func _left(direction: Vector2) -> Vector2:
	var unit := direction.normalized()
	return Vector2(-unit.y, unit.x)
