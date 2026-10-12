class_name RaidLayout
extends RefCounted
## The raid's one corridor in metres from the entrance: guard posts, sneak paths around some
## posts, the door of the target room, the deed spot and the far door reinforcements come
## through. Which posts have a sneak path follows the seed.

const START_X := 0.5
## How close the leader must stand to a sneak entrance to take it.
const ENTRANCE_REACH := 1.2


class SneakPath:
	var post: int
	var from_x: float
	var to_x: float
	## Presentation only: through the cellar (true) or over a gallery (false).
	var below: bool


var posts := PackedFloat64Array()
var sneak_paths: Array[SneakPath] = []
var door_x: float = 0.0
var deed_x: float = 0.0
var end_x: float = 0.0
var reinforcements: int = 0


static func build(cfg: RaidConfig, setup: RaidSetup, rng: RandomNumberGenerator) -> RaidLayout:
	var layout := RaidLayout.new()
	var castle := cfg.castle(setup.home_castle, setup.castle_level)
	var rules := cfg.layout
	for i: int in castle.guards:
		layout.posts.append(rules.entry_length + i * rules.post_spacing)
	layout.door_x = layout.posts[layout.posts.size() - 1] + rules.door_gap
	layout.deed_x = layout.door_x + rules.room_length * rules.deed_at
	layout.end_x = layout.door_x + rules.room_length
	layout.reinforcements = castle.reinforcements
	# The guard at the target door never has a way around.
	var candidates: Array[int] = []
	for i: int in castle.guards - 1:
		candidates.append(i)
	for i: int in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var chosen := candidates.slice(0, castle.sneak_paths)
	chosen.sort()
	for post: int in chosen:
		var path := SneakPath.new()
		path.post = post
		path.from_x = layout.posts[post] - rules.sneak_before
		path.to_x = layout.posts[post] + rules.sneak_after
		path.below = rng.randf() < 0.5
		layout.sneak_paths.append(path)
	return layout


## The sneak path whose entrance lies within reach of x, or -1.
func entrance_at(x: float) -> int:
	for i: int in sneak_paths.size():
		if absf(sneak_paths[i].from_x - x) <= ENTRANCE_REACH:
			return i
	return -1


func is_in_target_room(x: float) -> bool:
	return x >= door_x
