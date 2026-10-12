class_name SiegeBallistics
extends RefCounted
## Flight of a stone or fire pot in the side view: x is the distance from the trebuchet, y the
## height. Constant gravity and a constant wind push; the first part or the ground the path
## enters is the impact. Only + − × ÷ and sqrt are used (IEEE-exact on every platform), so a
## replay gives the same hits everywhere; sine and cosine come from a fixed polynomial.

enum Face { NONE, FRONT, TOP, BACK, BOTTOM, GROUND }

const PREVIEW_POINTS := 24


class Launch:
	var x0: float
	var y0: float
	var vx: float
	var vy: float
	## Wind push along x (m/s²).
	var ax: float
	var gravity: float

	func x_at(t: float) -> float:
		return x0 + vx * t + 0.5 * ax * t * t

	func y_at(t: float) -> float:
		return y0 + vy * t - 0.5 * gravity * t * t

	## Single-precision point for the presentation.
	func point(t: float) -> Vector2:
		return Vector2(x_at(t), y_at(t))


class Impact:
	var time: float = 0.0
	var x: float = 0.0
	var y: float = 0.0
	## Castle part index, or -1 for the ground (or nothing within the flight limit).
	var part: int = -1
	var face: Face = Face.NONE


static func speed(config: SiegeConfig, shot: TrebuchetShot) -> float:
	var span := float(config.counterweight_max - config.counterweight_min)
	var share := float(shot.counterweight - config.counterweight_min) / span
	var projectile := config.projectiles[shot.projectile_id()]
	return (config.speed_min + (config.speed_max - config.speed_min) * share) * (
		projectile.speed_factor
	)


## The shot must already lie within the trebuchet's ranges (TrebuchetSim clamps it).
static func launch(config: SiegeConfig, shot: TrebuchetShot, wind: float) -> Launch:
	var result := Launch.new()
	var v := speed(config, shot)
	result.x0 = config.release.x
	result.y0 = config.release.y
	result.vx = v * cos_deg(shot.angle)
	result.vy = v * sin_deg(shot.angle)
	result.ax = wind * config.wind_acceleration
	result.gravity = config.gravity
	return result


## Seconds until the path comes down to the ground, ignoring the castle.
static func ground_time(path: Launch) -> float:
	return (path.vy + sqrt(path.vy * path.vy + 2.0 * path.gravity * path.y0)) / path.gravity


## Height of the path where it passes x; -INF if the wind turns it back before x.
static func height_at(path: Launch, x: float) -> float:
	var distance := x - path.x0
	var discriminant := path.vx * path.vx + 2.0 * path.ax * distance
	if discriminant < 0.0:
		return -INF
	var denominator := path.vx + sqrt(discriminant)
	if denominator <= 0.0:
		return -INF
	return path.y_at(2.0 * distance / denominator)


## The first share of the unobstructed flight (the part the player may see before throwing).
static func preview(path: Launch, share: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var end := ground_time(path) * share
	for i: int in PREVIEW_POINTS + 1:
		points.append(path.point(end * i / PREVIEW_POINTS))
	return points


## Steps the path at the configured rate and returns where it first enters a standing part
## of the castle or the ground.
static func trace(config: SiegeConfig, path: Launch, castle: SiegeCastle) -> Impact:
	var impact := Impact.new()
	var steps := ceili(config.max_flight_seconds * config.step_rate)
	var x := path.x0
	var y := path.y0
	for i: int in steps:
		var t1 := float(i + 1) / config.step_rate
		var x1 := path.x_at(t1)
		var y1 := path.y_at(t1)
		var best := INF
		if y1 <= 0.0:
			best = y / (y - y1)
			impact.part = -1
			impact.face = Face.GROUND
		for p: int in castle.part_count():
			if not castle.blocks(p):
				continue
			var entry := _entry(x, y, x1, y1, castle.world_rect(p))
			if entry[0] <= best:
				best = entry[0]
				impact.part = p
				impact.face = int(entry[1]) as Face
		if best <= 1.0:
			impact.time = (i + best) / config.step_rate
			impact.x = x + (x1 - x) * best
			impact.y = y + (y1 - y) * best
			return impact
		x = x1
		y = y1
	impact.part = -1
	impact.face = Face.NONE
	impact.time = config.max_flight_seconds
	impact.x = x
	impact.y = y
	return impact


## Liang–Barsky: [u, face] where the segment from (x0, y0) to (x1, y1) enters the rectangle
## [left, bottom, right, top]; u = INF when it misses.
static func _entry(
	x0: float, y0: float, x1: float, y1: float, rect: PackedFloat64Array
) -> PackedFloat64Array:
	var dx := x1 - x0
	var dy := y1 - y0
	var p := PackedFloat64Array([-dx, dx, -dy, dy])
	var q := PackedFloat64Array([x0 - rect[0], rect[2] - x0, y0 - rect[1], rect[3] - y0])
	var faces: Array[Face] = [Face.FRONT, Face.BACK, Face.BOTTOM, Face.TOP]
	var enter := 0.0
	var leave := 1.0
	var face := Face.NONE
	for k: int in 4:
		if p[k] == 0.0:
			if q[k] < 0.0:
				return PackedFloat64Array([INF, Face.NONE])
			continue
		var r := q[k] / p[k]
		if p[k] < 0.0:
			if r > leave:
				return PackedFloat64Array([INF, Face.NONE])
			if r > enter:
				enter = r
				face = faces[k]
		else:
			if r < enter:
				return PackedFloat64Array([INF, Face.NONE])
			leave = minf(leave, r)
	if face == Face.NONE:
		return PackedFloat64Array([INF, Face.NONE])
	return PackedFloat64Array([enter, face])


static func sin_deg(degrees: float) -> float:
	var x := degrees * PI / 180.0
	var x2 := x * x
	# Horner form of the Taylor series up to x^15 (error below 1e-9 for 0..90°).
	return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0 * (1.0 - x2 / 72.0 * (
		1.0 - x2 / 110.0 * (1.0 - x2 / 156.0 * (1.0 - x2 / 210.0)))))))


static func cos_deg(degrees: float) -> float:
	var x := degrees * PI / 180.0
	var x2 := x * x
	return 1.0 - x2 / 2.0 * (1.0 - x2 / 12.0 * (1.0 - x2 / 30.0 * (1.0 - x2 / 56.0 * (
		1.0 - x2 / 90.0 * (1.0 - x2 / 132.0 * (1.0 - x2 / 182.0 * (1.0 - x2 / 240.0)))))))
