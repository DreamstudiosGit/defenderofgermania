class_name CoronationPlate
extends MarginContainer
## The coronation as an illuminated page (GDD "Krönungsszene als Buchmalerei-Tafel"):
## parchment, a border band in the house's colours between gold rules with a vine and corner
## bosses, the house's shield, the heading as a rubric and one dry chronicle line opened by a
## gilded initial. Everything is drawn here; there is no painted art.

const PARCHMENT := Color(0.94, 0.88, 0.74)
const PARCHMENT_EDGE := Color(0.60, 0.45, 0.27)
const INK := Color(0.22, 0.14, 0.08)
const GILT := Color(0.86, 0.67, 0.25)
const WIDTH := 640.0
const RIM := 12.0
const BAND := 18.0
const VINE_STEP := 22.0
const INITIAL_SIZE := 78.0
const LETTER_SIZE := 58
## Fixed seed: the parchment's specks look the same on every coronation.
const GRAIN_SEED := 1198
const GRAIN_SPECKS := 320

var _colors := PackedColorArray([CampaignStyle.MUTED, CampaignStyle.TEXT])
var _badge := HouseBadge.new(Vector2(62, 74))
var _heading := Label.new()
var _date := Label.new()
var _rule := Control.new()
var _initial := Control.new()
var _text := Label.new()
var _letter := ""


func _init() -> void:
	name = "coronation_plate"
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := int(RIM + BAND + 24.0)
	for side: String in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, inner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_badge)
	_heading.name = "heading"
	_date.name = "date"
	for label: Label in [_heading, _date]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	_heading.add_theme_font_size_override("font_size", 34)
	_date.add_theme_font_size_override("font_size", CampaignStyle.SMALL_SIZE + 1)
	_date.add_theme_color_override("font_color", INK.lightened(0.25))
	_rule.custom_minimum_size.y = 16.0
	_rule.draw.connect(_draw_rule)
	column.add_child(_rule)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	column.add_child(body)
	_initial.custom_minimum_size = Vector2(INITIAL_SIZE, INITIAL_SIZE)
	_initial.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_initial.draw.connect(_draw_initial)
	body.add_child(_initial)
	_text.name = "chronicle"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size.x = 240.0
	_text.add_theme_font_size_override("font_size", 19)
	_text.add_theme_color_override("font_color", INK)
	body.add_child(_text)


## Shows the winner's coronation at the site in state.crown.crowned_at.
func show_coronation(state: GameState, rules: GameRules) -> void:
	var house := state.winner
	var site := state.crown.crowned_at
	_colors = rules.map.house_colors[house]
	_badge.colors = _colors
	_heading.text = tr("CAMPAIGN_CROWN_PLATE_" + site.to_upper()) % CrownFormat.site_name(
		rules.map, site
	)
	_heading.add_theme_color_override("font_color", _rubric(_colors[0]))
	_date.text = "%s · %s %d" % [
		CampaignFormat.house_name(house),
		CampaignFormat.season_name(state.season()),
		CampaignFormat.year(state),
	]
	var line := tr("CAMPAIGN_CROWN_PLATE_%s_%s" % [house.to_upper(), site.to_upper()])
	_letter = line.left(1)
	_text.text = line.substr(1)
	queue_redraw()
	_rule.queue_redraw()
	_initial.queue_redraw()


func _draw() -> void:
	var page := Rect2(Vector2.ZERO, size)
	draw_rect(page, PARCHMENT)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAIN_SEED
	for i: int in GRAIN_SPECKS:
		var spot := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var speck := Color(PARCHMENT_EDGE, rng.randf_range(0.04, 0.13))
		draw_circle(spot, rng.randf_range(0.6, 1.9), speck)
	for i: int in 7:
		draw_rect(page.grow(-1.5 - i * 3.0), Color(PARCHMENT_EDGE, 0.07), false, 3.0)
	_draw_border(page.grow(-RIM))


## The band in the house's field colour between two gold rules, a vine of leaves and berries
## along it and a boss on every corner.
func _draw_border(frame: Rect2) -> void:
	var band := frame.grow(-BAND * 0.5)
	draw_rect(band, _colors[0], false, BAND)
	draw_rect(frame, GILT, false, 2.0)
	draw_rect(frame.grow(-BAND), GILT, false, 2.0)
	draw_rect(frame.grow(1.5), INK, false, 1.0)
	var corners := PackedVector2Array([
		band.position,
		Vector2(band.end.x, band.position.y),
		band.end,
		Vector2(band.position.x, band.end.y),
	])
	for i: int in corners.size():
		var from := corners[i]
		var to := corners[(i + 1) % corners.size()]
		var along := (to - from).normalized()
		var steps := int(from.distance_to(to) / VINE_STEP)
		for step: int in range(1, steps):
			var spot := from.lerp(to, float(step) / steps)
			if step % 2 == 0:
				draw_circle(spot, 2.6, _charge())
			else:
				draw_colored_polygon(_diamond(spot, along * 5.5, along.orthogonal() * 2.6), GILT)
	for corner: Vector2 in corners:
		_draw_boss(corner)


## A gilt boss with a four-leaf rosette in the house's colours.
func _draw_boss(center: Vector2) -> void:
	draw_circle(center, 14.0, GILT)
	draw_arc(center, 14.0, 0.0, TAU, 32, INK, 1.0, true)
	draw_circle(center, 10.5, _colors[0])
	for k: int in 4:
		var petal := center + Vector2.from_angle(PI * 0.5 * k) * 5.0
		draw_circle(petal, 3.4, _charge())
	draw_circle(center, 2.6, GILT)


## A gold rule under the heading with a diamond in the house's colour and berries at its ends.
func _draw_rule() -> void:
	var mid := _rule.size * 0.5
	var half := minf(_rule.size.x * 0.32, 190.0)
	_rule.draw_line(Vector2(mid.x - half, mid.y), Vector2(mid.x + half, mid.y), GILT, 2.0)
	for end: float in [mid.x - half, mid.x + half]:
		_rule.draw_circle(Vector2(end, mid.y), 3.2, GILT)
	_rule.draw_colored_polygon(_diamond(mid, Vector2(11.0, 0.0), Vector2(0.0, 6.5)), GILT)
	_rule.draw_colored_polygon(_diamond(mid, Vector2(7.5, 0.0), Vector2(0.0, 4.0)), _colors[0])


## The gilded initial: a gold square around the house's field with gilt dots in its corners
## and the first letter of the chronicle line in the charge colour.
func _draw_initial() -> void:
	var box := Rect2(Vector2.ZERO, _initial.size)
	_initial.draw_rect(box, GILT)
	var field := box.grow(-5.0)
	_initial.draw_rect(field, _colors[0])
	_initial.draw_rect(field.grow(-3.0), Color(GILT, 0.8), false, 1.0)
	var inward := PackedVector2Array([Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)])
	var corners := PackedVector2Array([
		field.position,
		Vector2(field.end.x, field.position.y),
		field.end,
		Vector2(field.position.x, field.end.y),
	])
	for i: int in corners.size():
		_initial.draw_circle(corners[i] + inward[i] * 7.0, 2.2, GILT)
	_initial.draw_rect(box, INK, false, 1.5)
	if _letter.is_empty():
		return
	var font := get_theme_default_font()
	var extent := font.get_string_size(_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE)
	var ascent := font.get_ascent(LETTER_SIZE)
	var baseline := Vector2(
		(box.size.x - extent.x) * 0.5,
		(box.size.y + ascent - font.get_descent(LETTER_SIZE)) * 0.5
	)
	_initial.draw_string_outline(
		font, baseline, _letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, 6, INK
	)
	_initial.draw_string(
		font, baseline, _letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE, _charge()
	)


func _charge() -> Color:
	return _colors[1] if _colors.size() > 1 else GILT


## The heading in the house's field colour, darkened where it would be too pale on parchment.
func _rubric(field: Color) -> Color:
	return field.darkened(0.35) if field.get_luminance() > 0.45 else field


static func _diamond(center: Vector2, along: Vector2, across: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + along, center + across, center - along, center - across
	])
