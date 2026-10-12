class_name RaidAnimator
extends RefCounted
## Poses a skinned fighter straight from its glTF clips at a time the caller picks, so a blow's
## contact frame lands on the simulation tick of the hit. Clip changes cross-fade briefly.

const FADE_SECONDS := 0.1

var _skeleton: Skeleton3D
var _clips: Dictionary[StringName, Animation] = {}
## Per clip: bone index of every track (-1 for tracks on other nodes).
var _track_bones: Dictionary[StringName, PackedInt32Array] = {}
var _clip: StringName = &""
var _time: float = 0.0
var _fade: float = 0.0
var _from_rotations: Array[Quaternion] = []
var _from_positions: Array[Vector3] = []


func _init(skeleton: Skeleton3D, player: AnimationPlayer) -> void:
	_skeleton = skeleton
	for clip_name: StringName in player.get_animation_list():
		var animation := player.get_animation(clip_name)
		_clips[clip_name] = animation
		var bones := PackedInt32Array()
		for track: int in animation.get_track_count():
			var path := animation.track_get_path(track)
			bones.append(skeleton.find_bone(path.get_concatenated_subnames()))
		_track_bones[clip_name] = bones


func has_clip(clip_name: StringName) -> bool:
	return _clips.has(clip_name)


func clip_length(clip_name: StringName) -> float:
	return _clips[clip_name].length if _clips.has(clip_name) else 0.0


func current_clip() -> StringName:
	return _clip


## Shows `clip_name` at `time` seconds; a new clip fades in from the pose shown so far.
func show_pose(clip_name: StringName, time: float, loop: bool = false) -> void:
	if not _clips.has(clip_name):
		return
	if clip_name != _clip:
		_snapshot()
		_clip = clip_name
		_fade = 1.0 if _from_rotations.size() == _skeleton.get_bone_count() else 0.0
	var length := _clips[clip_name].length
	_time = fposmod(time, length) if loop and length > 0.0 else clampf(time, 0.0, length)


func update(delta: float) -> void:
	if _clip.is_empty():
		return
	_fade = maxf(0.0, _fade - delta / FADE_SECONDS)
	var animation := _clips[_clip]
	var bones := _track_bones[_clip]
	var count := _skeleton.get_bone_count()
	var rotations: Array[Quaternion] = []
	var positions: Array[Vector3] = []
	for bone: int in count:
		var rest := _skeleton.get_bone_rest(bone)
		rotations.append(rest.basis.get_rotation_quaternion())
		positions.append(rest.origin)
	for track: int in bones.size():
		var bone := bones[track]
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				rotations[bone] = animation.rotation_track_interpolate(track, _time)
			Animation.TYPE_POSITION_3D:
				positions[bone] = animation.position_track_interpolate(track, _time)
	var weight := 1.0 - _fade
	for bone: int in count:
		var rotation := rotations[bone]
		var position := positions[bone]
		if _fade > 0.0:
			rotation = _from_rotations[bone].slerp(rotation, weight)
			position = _from_positions[bone].lerp(position, weight)
		_skeleton.set_bone_pose_rotation(bone, rotation)
		_skeleton.set_bone_pose_position(bone, position)


func _snapshot() -> void:
	_from_rotations.clear()
	_from_positions.clear()
	for bone: int in _skeleton.get_bone_count():
		_from_rotations.append(_skeleton.get_bone_pose_rotation(bone))
		_from_positions.append(_skeleton.get_bone_pose_position(bone))
