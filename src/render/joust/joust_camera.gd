class_name JoustCamera
extends Camera3D
## Two views of the joust. Through the helmet slit of rider 0 from the ready call until just
## after the impact: down the lists during the run-up, then locked on the opponent's chest with
## a zoom that keeps him the same size while he closes in. From the stand otherwise: the herald's
## sweep, following the riders and closing on the winner.

const RUN_FOV := 62.0
const MIN_FOV := 14.0
## Height of the world the aim zoom keeps on screen at the opponent's distance.
const AIM_VIEW_HEIGHT := 3.6
const AIM_BLEND_SECONDS := 0.35
## The view stays in the helmet this long after the impact, then cuts to the stand.
const AFTER_IMPACT_SECONDS := 0.8
const BOB := 0.05
const BOB_RATE := 9.0
const STAND_FOV := 44.0
const FOLLOW := 4.0

var first_person: bool = false

var _look := Vector3.ZERO
var _impact_look := Vector3.ZERO


func _ready() -> void:
	fov = STAND_FOV
	near = 0.05
	far = 400.0


func frame(sim: JoustSim, riders: JoustRiders, alpha: float, delta: float) -> void:
	var state := sim.state
	var in_phase := (state.phase_tick + alpha) * sim.tick_seconds()
	var was_first_person := first_person
	first_person = (
		state.phase in [JoustState.Phase.READY, JoustState.Phase.RUNUP, JoustState.Phase.AIM]
		or (state.phase == JoustState.Phase.CLASH and in_phase < AFTER_IMPACT_SECONDS)
	)
	if first_person:
		_helmet(sim, riders, alpha, in_phase)
	else:
		_stand(sim, riders, alpha, 1.0 if was_first_person else 1.0 - exp(-FOLLOW * delta))


## Visible height of the world at a distance for the current field of view.
func view_height(distance: float) -> float:
	return 2.0 * distance * tan(deg_to_rad(fov) * 0.5)


func _helmet(sim: JoustSim, riders: JoustRiders, alpha: float, in_phase: float) -> void:
	var state := sim.state
	var track := JoustTrack.at(sim, alpha)
	var seat := Transform3D(track.basis(0), track.position(0))
	var time := (state.tick + alpha) * sim.tick_seconds()
	var gallop := clampf(track.speed / 8.0, 0.0, 1.0)
	var eye := seat * Vector3(0.0, JoustTrack.EYE_HEIGHT, 0.12)
	eye.y += sin(time * BOB_RATE) * BOB * gallop
	var opponent := riders.chest(1)
	var ahead := eye + seat.basis.z * 30.0 + Vector3.DOWN * 0.8
	var run_look := ahead.lerp(opponent, 0.35)
	var look := run_look
	var wanted_fov := RUN_FOV
	match state.phase:
		JoustState.Phase.AIM:
			var blend := smoothstep(0.0, 1.0, in_phase / AIM_BLEND_SECONDS)
			look = run_look.lerp(opponent, blend)
			var zoom := rad_to_deg(2.0 * atan(AIM_VIEW_HEIGHT * 0.5 / eye.distance_to(opponent)))
			wanted_fov = lerpf(RUN_FOV, clampf(zoom, MIN_FOV, RUN_FOV), blend)
			_impact_look = look
		JoustState.Phase.CLASH:
			look = _impact_look
			wanted_fov = lerpf(fov, RUN_FOV, 0.08)
	fov = wanted_fov
	_look = look
	global_position = eye
	if not eye.is_equal_approx(look):
		look_at(look, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, sin(time * BOB_RATE * 0.5) * 0.01 * gallop)


func _stand(sim: JoustSim, riders: JoustRiders, alpha: float, follow: float) -> void:
	var state := sim.state
	var a := riders.chest(0)
	var b := riders.chest(1)
	var target := (a + b) * 0.5
	var spread := absf(a.x - b.x)
	var eye := Vector3(clampf(target.x, -18.0, 18.0), 5.5 + spread * 0.12, 13.0 + spread * 0.42)
	var wanted_fov := STAND_FOV
	match state.phase:
		JoustState.Phase.INTRO:
			var elapsed := (state.phase_tick + alpha) * sim.tick_seconds()
			var share := smoothstep(0.35, 0.65, elapsed / sim.cfg.intro_seconds)
			target = a.lerp(b, share) + Vector3.DOWN * 0.4
			eye = target + Vector3(-5.0 + 10.0 * share, 3.6, 11.0)
			wanted_fov = 46.0
		JoustState.Phase.CLASH when state.unseated >= 0:
			target = riders.body_position(state.unseated)
			eye = target + Vector3(-2.5, 3.0, 9.0)
			wanted_fov = 42.0
		JoustState.Phase.FINALE, JoustState.Phase.OVER:
			var focus := riders.chest(state.winner if state.winner >= 0 else 0)
			if state.unseated >= 0:
				focus = focus.lerp(riders.body_position(state.unseated), 0.5)
			target = focus + Vector3.DOWN * 0.6
			eye = focus + Vector3(-4.0, 4.8, 12.5)
			wanted_fov = 40.0
	target.z = minf(target.z, 0.5)
	global_position = global_position.lerp(eye, follow) if follow < 1.0 else eye
	_look = _look.lerp(target, follow) if follow < 1.0 else target
	fov = lerpf(fov, wanted_fov, follow)
	if not global_position.is_equal_approx(_look):
		look_at(_look, Vector3.UP)
