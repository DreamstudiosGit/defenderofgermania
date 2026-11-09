class_name UiFonts
extends RefCounted
## The game's two typefaces (GDD "Lesbarkeit"): Texturina, a Textura display face, for headings
## and Vollkorn, a sturdy antiqua, for everything else. Both are variable fonts; the variations
## are cached per weight.

const DISPLAY: FontFile = preload("res://assets/ui/font_texturina.ttf")
const BODY: FontFile = preload("res://assets/ui/font_vollkorn.ttf")
const BODY_ITALIC: FontFile = preload("res://assets/ui/font_vollkorn_italic.ttf")

const REGULAR := 500
const BOLD := 700
## Optical size of the display face: its heading cut, with finer joints than the text cut.
const DISPLAY_OPTICAL_SIZE := 48

static var _cache: Dictionary[String, FontVariation] = {}


## Textura for headings and titles.
static func display(weight: int = BOLD) -> FontVariation:
	return _variation("display", DISPLAY, weight, {"opsz": DISPLAY_OPTICAL_SIZE}, {})


## Antiqua for text, with lining tabular figures so columns of numbers line up.
static func body(weight: int = REGULAR) -> FontVariation:
	return _variation("body", BODY, weight, {}, {"lnum": 1, "tnum": 1})


static func italic(weight: int = REGULAR) -> FontVariation:
	return _variation("italic", BODY_ITALIC, weight, {}, {"lnum": 1, "tnum": 1})


static func _variation(
	kind: String, base: FontFile, weight: int, axes: Dictionary, features: Dictionary
) -> FontVariation:
	var key := "%s:%d" % [kind, weight]
	if _cache.has(key):
		return _cache[key]
	var server := TextServerManager.get_primary_interface()
	var coordinates := {server.name_to_tag("wght"): weight}
	for axis: String in axes:
		coordinates[server.name_to_tag(axis)] = axes[axis]
	var tags := {}
	for feature: String in features:
		tags[server.name_to_tag(feature)] = features[feature]
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = coordinates
	font.opentype_features = tags
	_cache[key] = font
	return font
