class_name RaidFeedback
extends RefCounted
## Turns the raid's events into feedback: sparks and pop-up words where a blow lands, dust for a
## felled guard, the alarm shout, the far door opening and the target room changing at the deed.

const TIRED_POP_GAP := 1.0
const POP_HIT := Color(1.0, 0.85, 0.6)
const POP_BLOCKED := Color(0.85, 0.85, 0.9)
const POP_PARRIED := Color(0.7, 0.9, 1.0)
const ALARM := Color(1.0, 0.4, 0.3)

var _tired_cooldown: float = 0.0


func update(delta: float) -> void:
	_tired_cooldown -= delta


func show(
	state: RaidState, world: RaidWorld, effects: RaidEffects, hud: RaidHud, camera: Camera3D
) -> void:
	for event: RaidEvent in state.events:
		var at := _blow_point(event, state, world)
		var screen := camera.unproject_position(at)
		match event.kind:
			RaidEvent.Kind.HIT:
				var on_leader := event.fighter == RaidEvent.LEADER
				effects.sparks(at, 26, Color(1.0, 0.75, 0.35), 3.2)
				hud.pop(tr("RAID_POP_HURT" if on_leader else "RAID_POP_HIT"), screen, POP_HIT)
			RaidEvent.Kind.BLOCKED:
				effects.sparks(at, 12, Color(0.95, 0.95, 1.0), 2.0)
				hud.pop(tr("RAID_POP_BLOCKED"), screen, POP_BLOCKED)
			RaidEvent.Kind.PARRIED:
				effects.sparks(at, 18, Color(0.7, 0.85, 1.0), 2.6)
				hud.pop(tr("RAID_POP_PARRIED"), screen, POP_PARRIED)
			RaidEvent.Kind.DOWN:
				effects.dust(Vector3(at.x, world.floor_y(at.x), at.z))
				if event.fighter != RaidEvent.LEADER:
					hud.pop(tr("RAID_POP_DOWN"), screen + Vector2(0, -40), GroupShield.GOLD)
			RaidEvent.Kind.TIRED:
				if _tired_cooldown <= 0.0:
					_tired_cooldown = TIRED_POP_GAP
					hud.pop(tr("RAID_POP_TIRED"), screen, Color(0.8, 0.8, 0.8))
			RaidEvent.Kind.ALARM:
				hud.shout(tr("RAID_SHOUT_ALARM"), tr("RAID_HUD_ALARM"), ALARM)
			RaidEvent.Kind.SNEAK_IN:
				hud.pop(tr("RAID_POP_SNEAK"), screen, Color(0.8, 0.85, 1.0))


## Where an event shows: at the height of the blow on the fighter it concerns, in front of him.
static func _blow_point(event: RaidEvent, state: RaidState, world: RaidWorld) -> Vector3:
	var x := state.leader.x + 0.4
	if event.fighter >= 0 and event.fighter < state.guards.size():
		x = state.guards[event.fighter].x - 0.4
	var height := RaidEffects.BLOW_HEIGHTS[clampi(event.height, 0, 2)] if event.height >= 0 else 1.2
	return Vector3(x, world.floor_y(x) + height, RaidWorld.LANE_Z + 0.5)
