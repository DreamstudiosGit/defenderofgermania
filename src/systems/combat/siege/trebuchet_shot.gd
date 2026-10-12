class_name TrebuchetShot
extends RefCounted
## One throw as the player (or the computer aimer) set it up. Whole numbers keep replays exact.

enum Projectile { STONE, FIRE_POT }

const PROJECTILE_IDS: Array[String] = ["stone", "fire_pot"]

## Counterweight in percent of the trebuchet's range of loads.
var counterweight: int = 50
## Release angle above the horizon in degrees.
var angle: int = 45
var projectile: Projectile = Projectile.STONE
## How long the shot was aimed; only counts towards the playing time, never the outcome.
var aim_seconds: float = -1.0


static func make(
	weight: int, release_angle: int, kind: Projectile = Projectile.STONE, seconds: float = -1.0
) -> TrebuchetShot:
	var shot := TrebuchetShot.new()
	shot.counterweight = weight
	shot.angle = release_angle
	shot.projectile = kind
	shot.aim_seconds = seconds
	return shot


func projectile_id() -> String:
	return PROJECTILE_IDS[projectile]
