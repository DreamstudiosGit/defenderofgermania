class_name MerchantBatch
extends MultiMeshInstance3D
## One Blender model drawn many times in the raid. Custom data drives the figures' limb motion
## (unit_motion: phase, movement, contact, time); house colours tint the mask surfaces.

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)


func _init(model: Mesh, count: int, colors: PackedColorArray = PackedColorArray()) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = model
	multimesh.instance_count = count
	if colors.size() >= 2:
		set_instance_shader_parameter("house_primary", colors[0])
		set_instance_shader_parameter("house_secondary", colors[1])
	for i: int in count:
		multimesh.set_instance_transform(i, HIDDEN)


## Places instance i; movement 0..1 sets the stride, time is the motion clock in seconds.
func place(i: int, where: Transform3D, movement: float = 0.0, time: float = 0.0) -> void:
	multimesh.set_instance_transform(i, where)
	multimesh.set_instance_custom_data(i, Color(i * 1.73, movement, 0.0, time))


func hide_instance(i: int) -> void:
	multimesh.set_instance_transform(i, HIDDEN)


## A figure standing at a road point, facing along the road (+1 towards the gate).
static func upright(at: Vector3, facing: float, scale_factor: float = 1.0) -> Transform3D:
	var yaw := PI / 2 if facing >= 0.0 else -PI / 2
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), at)
