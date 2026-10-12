class_name GroupShield
extends Control

const SHIELD_SIZE := Vector2(144, 162)
const GOLD := Color(1.0, 0.82, 0.30)
const RIM := Color(0.18, 0.11, 0.06)
const BLUE_SHIELDS: Array[Texture2D] = [
	preload("res://assets/ui/combat/combat_group_infantry_blue.svg"),
	preload("res://assets/ui/combat/combat_group_crossbow_blue.svg"),
	preload("res://assets/ui/combat/combat_group_cavalry_blue.svg"),
	preload("res://assets/ui/combat/combat_group_siege_blue.svg")
]
const RED_SHIELDS: Array[Texture2D] = [
	preload("res://assets/ui/combat/combat_group_infantry_red.svg"),
	preload("res://assets/ui/combat/combat_group_crossbow_red.svg"),
	preload("res://assets/ui/combat/combat_group_cavalry_red.svg"),
	preload("res://assets/ui/combat/combat_group_siege_red.svg")
]
const SELECTED_GLOW: Texture2D = preload("res://assets/ui/combat/combat_group_selected_glow.svg")
const LEADER_CROWN: Texture2D = preload("res://assets/ui/combat/combat_status_leader.svg")
const BOLT: Texture2D = preload("res://assets/ui/combat/combat_status_bolt.svg")

var group: int = 0
var active: bool = false
var companies: int = 0
var bolts: int = -1
var max_bolts: int = 3
var has_leader: bool = false
var house_color := Color.WHITE
var accent := Color.WHITE


func _init() -> void:
	custom_minimum_size = SHIELD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var textures := BLUE_SHIELDS if house_color.b >= house_color.r else RED_SHIELDS
	var icon: Texture2D = textures[clampi(group, 0, textures.size() - 1)]
	var tint := Color.WHITE if companies > 0 else Color(0.52, 0.49, 0.45, 0.65)
	draw_texture_rect(icon, rect, false, tint)
	if active:
		draw_texture_rect(SELECTED_GLOW, rect, false)
	var status_scale := size.x / SHIELD_SIZE.x
	if bolts >= 0:
		var total_width := max_bolts * 11.0 * status_scale
		for i: int in max_bolts:
			var at := Vector2((size.x - total_width) * 0.5 + i * 11.0 * status_scale, size.y * 0.11)
			var bolt_tint := Color.WHITE if i < bolts else Color(0.15, 0.17, 0.19, 0.8)
			draw_texture_rect(BOLT, Rect2(at, Vector2(11, 21) * status_scale), false, bolt_tint)
	var font := ThemeDB.fallback_font
	var label := "×%d" % companies
	var font_size := maxi(12, roundi(18.0 * status_scale))
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var label_at := Vector2(size.x * 0.79 - label_width * 0.5, size.y * 0.92)
	draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, RIM)
	draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.94, 0.78))
	if has_leader:
		draw_texture_rect(
			LEADER_CROWN,
			Rect2(Vector2(size.x * 0.09, size.y * 0.77), Vector2(27, 30) * status_scale), false
		)
