class_name LicenceTexts
extends RefCounted
## The licence notices that must ship with the game: the Godot Engine's licence, the notices
## and licence texts of the components built into the engine (Jolt Physics among them) and the
## licences of the two typefaces. The legal texts exist in English only.

## Typeface -> its licence file.
const FONTS: Dictionary[String, String] = {
	"Texturina": "res://assets/ui/font_texturina_license.txt",
	"Vollkorn": "res://assets/ui/font_vollkorn_license.txt",
}


static func engine() -> String:
	return Engine.get_license_text().strip_edges()


## The licence text of a typeface in FONTS.
static func font(font_name: String) -> String:
	var text := FileAccess.get_file_as_string(FONTS[font_name]).strip_edges()
	if text.is_empty():
		push_error("credits: the licence of %s is missing (%s)" % [font_name, FONTS[font_name]])
	return text


## One block per component of the engine: its name, then for each part who holds the
## copyright and the name of its licence (a key of licences()).
static func components() -> String:
	var lines := PackedStringArray()
	for component: Dictionary in Engine.get_copyright_info():
		lines.append(str(component.get("name", "")))
		var parts: Array = component.get("parts", [])
		for part: Dictionary in parts:
			var holders := PackedStringArray()
			var copyright: Array = part.get("copyright", [])
			for holder: Variant in copyright:
				holders.append(str(holder))
			lines.append("    © %s. %s" % ["; ".join(holders), str(part.get("license", ""))])
	return "\n".join(lines)


## Licence name -> text, for every licence the components name.
static func licences() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var texts := Engine.get_license_info()
	for licence: Variant in texts:
		result[str(licence)] = str(texts[licence]).strip_edges()
	return result
