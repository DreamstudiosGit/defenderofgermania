extends GutTest
## Joust input: presses are stamped to the frame and handed to the tick containing them; the
## shield follows WASD with y up; every zone, skill and hint has its texts.

const DT := 1.0 / 30.0
const EPSILON := 1e-6


func before_all() -> void:
	JoustInputMap.register()


func after_each() -> void:
	for action: String in ["joust_kb_strike", "joust_kb_spur", "joust_kb_shield_up"]:
		Input.action_release(action)


func test_a_press_lands_in_the_tick_that_contains_it() -> void:
	var reader := JoustInputReader.new(BattleInputMap.Device.KEYBOARD)
	Input.action_press("joust_kb_strike")
	reader.poll(4.512)
	var early := reader.take(4.5 - DT, DT, 0.8)
	assert_eq(early.strike, JoustInput.NO_PRESS, "an earlier tick does not take it")
	var due := reader.take(4.5, DT, 0.8)
	assert_almost_eq(due.strike, 0.012 / DT, EPSILON)
	var later := reader.take(4.5 + DT, DT, 0.8)
	assert_eq(later.strike, JoustInput.NO_PRESS, "a press is used once")


func test_holding_the_button_does_not_press_again() -> void:
	var reader := JoustInputReader.new(BattleInputMap.Device.KEYBOARD)
	Input.action_press("joust_kb_spur")
	reader.poll(1.0)
	assert_gte(reader.take(1.0, DT, 0.8).spur, 0.0)
	await wait_physics_frames(2)
	reader.poll(1.2)
	assert_eq(reader.take(1.2, DT, 0.8).spur, JoustInput.NO_PRESS)


func test_shield_up_points_up() -> void:
	var reader := JoustInputReader.new(BattleInputMap.Device.KEYBOARD)
	Input.action_press("joust_kb_shield_up")
	assert_gt(reader.take(0.0, DT, 0.8).shield.y, 0.5)


func test_mouse_points_where_the_hand_should_go() -> void:
	var reader := JoustInputReader.new(BattleInputMap.Device.KEYBOARD)
	reader.set_screen_frame(Vector2(640, 400), 200.0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640, 300)
	reader.handle_event(motion)
	var input := reader.take(0.0, DT, 0.8)
	assert_almost_eq(input.aim.y, 0.5 / 0.8, EPSILON, "100 px up is half a metre up")
	assert_almost_eq(input.aim.x, 0.0, EPSILON)


func test_zones_skills_and_hints_have_texts_in_both_languages() -> void:
	var cfg := JoustConfig.load_file()
	var keys: Array[String] = ["JOUST_HINT_KEYBOARD", "JOUST_HINT_PAD", "JOUST_HIT_MISS"]
	for zone: JoustConfig.Zone in cfg.zones:
		keys.append(JoustHud.hit_key(zone.id))
	for skill: int in JoustConfig.SKILLS:
		keys.append("JOUST_SKILL_%d" % skill)
	var rows := {}
	var file := FileAccess.open("res://data/i18n/texts.csv", FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		rows[row[0]] = row
	for key: String in keys:
		var row: PackedStringArray = rows.get(key, PackedStringArray())
		assert_true(row.size() >= 3 and not row[1].is_empty() and not row[2].is_empty(), key)
