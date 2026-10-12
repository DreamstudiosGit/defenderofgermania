class_name JoustTrack
extends RefCounted
## Where the riders are on the lists at any moment of the joust's timeline. Presentation only:
## the simulation fixes when the lances meet, this only moves the horses so they meet then.
## The lists run along x; rider 0 starts at -END on the +z side, rider 1 at +END on the -z
## side, so they pass left to left with the tilt barrier (z = 0) between them.

const END := 26.0
## Distance from the middle at the moment the lance tips meet.
const MEET := 1.6
const LANE := 1.25
## The run-up accelerates: distance grows with time to this power.
const RUN_EXPONENT := 1.6
## Speed left at the end of the clash, as a share of the impact speed.
const CLASH_EXIT_SPEED := 0.2
## The horses turn around this long before the return ends.
const TURN_SECONDS := 1.2
const CHEST_HEIGHT := 1.9
const EYE_HEIGHT := 2.42

## Distance along the own lane from the start end, heading (+1 towards the opponent's end,
## -1 back) and speed in m/s.
var distance: float = 0.0
var heading: float = 1.0
var speed: float = 0.0


## Track of a rider at the current simulation tick plus `alpha` of the next one.
static func at(sim: JoustSim, alpha: float) -> JoustTrack:
	var cfg := sim.cfg
	var track := JoustTrack.new()
	var phase := sim.state.phase
	var dt := sim.tick_seconds()
	var in_phase := (sim.state.phase_tick + alpha) * dt
	var run := cfg.runup_seconds + cfg.aim_seconds
	var impact_speed := (END - MEET) * RUN_EXPONENT / run
	var exit_distance := _clash_distance(cfg.clash_seconds, cfg.clash_seconds, impact_speed)
	match phase:
		JoustState.Phase.RUNUP, JoustState.Phase.AIM:
			var time := (sim.pass_tick() + alpha) * dt
			var share := clampf(time / run, 0.0, 1.0)
			track.distance = (END - MEET) * pow(share, RUN_EXPONENT)
			track.speed = impact_speed * pow(share, RUN_EXPONENT - 1.0)
		JoustState.Phase.CLASH:
			track.distance = _clash_distance(in_phase, cfg.clash_seconds, impact_speed)
			var slowing := impact_speed * (1.0 - CLASH_EXIT_SPEED) / cfg.clash_seconds
			track.speed = impact_speed - slowing * minf(in_phase, cfg.clash_seconds)
		JoustState.Phase.RETURN:
			var share := smoothstep(0.0, 1.0, in_phase / cfg.return_seconds)
			track.distance = lerpf(exit_distance, 0.0, share)
			var turning := in_phase > cfg.return_seconds - TURN_SECONDS
			track.heading = 1.0 if turning else -1.0
			track.speed = 0.0 if turning else exit_distance / cfg.return_seconds * 1.5
		JoustState.Phase.FINALE, JoustState.Phase.OVER:
			track.distance = exit_distance if sim.state.pass_count > 0 else 0.0
	return track


static func _clash_distance(time: float, clash: float, impact_speed: float) -> float:
	var slowing := impact_speed * (1.0 - CLASH_EXIT_SPEED) / clash
	var t := minf(time, clash)
	return END - MEET + impact_speed * t - 0.5 * slowing * t * t


## World position of a rider on his lane.
func position(rider: int) -> Vector3:
	var x := -END + distance if rider == 0 else END - distance
	return Vector3(x, 0.0, LANE if rider == 0 else -LANE)


## Facing as a basis: the models look along +z, rider 0 rides towards +x.
func basis(rider: int) -> Basis:
	var towards := heading if rider == 0 else -heading
	return Basis(Vector3.UP, PI / 2 if towards > 0.0 else -PI / 2)


## Unit vectors of the target plane on `target` as `attacker` sees him: right and up.
static func target_axes(attacker_position: Vector3, target_chest: Vector3) -> Basis:
	var toward := (target_chest - attacker_position)
	toward.y = 0.0
	toward = toward.normalized() if not toward.is_zero_approx() else Vector3.RIGHT
	var right := toward.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, -toward)


## World point of an offset in the target plane on a rider's chest.
static func target_point(chest: Vector3, axes: Basis, offset: Vector2) -> Vector3:
	return chest + axes.x * offset.x + axes.y * offset.y
