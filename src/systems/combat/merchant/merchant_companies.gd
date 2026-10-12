class_name MerchantCompanies
extends RefCounted
## The leader's companies lie in ambush along the road and break out when the train's head
## passes. Then they go for the nearest free escort within engage range — holding him until
## the fight is decided (longer for weak units and tough escorts, never by chance) — or else
## for the nearest rolling wagon to pull its driver off the box, which takes longer than for
## the leader.

## The ambush breaks when the leading rolling wagon is this close.
const AMBUSH_TRIGGER := 2.0


static func update(sim: MerchantSim, dt: float) -> void:
	var s := sim.state
	for c: int in s.company_count():
		s.company_timer[c] = maxf(0.0, s.company_timer[c] - dt)
		match s.company_state[c]:
			MerchantState.Company.HIDDEN:
				if _train_head(s) >= s.company_ambush_x[c] - AMBUSH_TRIGGER:
					s.company_state[c] = MerchantState.Company.RUNNING
					s.events.append(MerchantEvent.new(MerchantEvent.Kind.AMBUSH, -1, -1, c))
			MerchantState.Company.RUNNING:
				_hunt(sim, c, dt)
			MerchantState.Company.FIGHTING:
				_fight(sim, c)
			MerchantState.Company.PULLING:
				_pull(sim, c)


## The company c holds escort e: both stand until the fight is decided.
static func bind(sim: MerchantSim, c: int, e: int) -> void:
	var s := sim.state
	s.company_state[c] = MerchantState.Company.FIGHTING
	s.company_target[c] = e
	s.company_timer[c] = s.company_fight[c] * sim.escort.guard / sim.cfg.reference_guard
	s.escort_state[e] = MerchantState.Escort.BOUND
	s.escort_target[e] = c


static func _hunt(sim: MerchantSim, c: int, dt: float) -> void:
	var s := sim.state
	var e := _free_escort(sim, c)
	if e >= 0:
		_run(sim, c, s.escort_x[e], dt)
		if absf(s.escort_x[e] - s.company_x[c]) <= sim.cfg.company_reach:
			bind(sim, c, e)
		return
	var w := _nearest_rolling(sim, c)
	if w < 0:
		s.company_state[c] = MerchantState.Company.IDLE
		return
	_run(sim, c, sim.box_x(w), dt)
	if absf(sim.box_x(w) - s.company_x[c]) <= sim.cfg.company_reach:
		s.company_state[c] = MerchantState.Company.PULLING
		s.company_target[c] = w
		s.company_timer[c] = sim.cfg.company_pull_seconds


static func _fight(sim: MerchantSim, c: int) -> void:
	var s := sim.state
	var e := s.company_target[c]
	if s.escort_state[e] != MerchantState.Escort.BOUND or s.escort_target[e] != c:
		s.company_state[c] = MerchantState.Company.RUNNING
		return
	if s.company_timer[c] <= 0.0:
		MerchantEscorts.knock_down(sim, e, c)
		s.company_state[c] = MerchantState.Company.RUNNING


static func _pull(sim: MerchantSim, c: int) -> void:
	var s := sim.state
	var w := s.company_target[c]
	if not s.is_rolling(w):
		s.company_state[c] = MerchantState.Company.RUNNING
		return
	s.company_x[c] = sim.box_x(w)
	if s.company_timer[c] <= 0.0:
		sim.stop_wagon(w, MerchantState.Stop.DRIVER, c)
		s.company_state[c] = MerchantState.Company.RUNNING


static func _free_escort(sim: MerchantSim, c: int) -> int:
	var s := sim.state
	var best := -1
	var nearest := sim.cfg.engage_range
	for e: int in s.escort_count():
		var distance := absf(s.escort_x[e] - s.company_x[c])
		if s.escort_free(e) and distance <= nearest:
			best = e
			nearest = distance
	return best


static func _nearest_rolling(sim: MerchantSim, c: int) -> int:
	var s := sim.state
	var best := -1
	var nearest := INF
	for w: int in s.wagon_count():
		var distance := absf(sim.box_x(w) - s.company_x[c])
		if s.is_rolling(w) and distance < nearest:
			best = w
			nearest = distance
	return best


static func _train_head(s: MerchantState) -> float:
	var head := -INF
	for w: int in s.wagon_count():
		if s.is_rolling(w):
			head = maxf(head, s.wagon_x[w])
	return head


static func _run(sim: MerchantSim, c: int, goal: float, dt: float) -> void:
	var s := sim.state
	var limit := s.gate_x - 1.0
	s.company_x[c] = minf(move_toward(s.company_x[c], goal, s.company_speed[c] * dt), limit)
