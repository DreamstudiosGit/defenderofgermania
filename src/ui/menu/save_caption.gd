class_name SaveCaption
extends RefCounted
## One line about a saved campaign for the menu: its round and when it was saved, read from
## the save's header (SaveGames.header). Missing fields are left out, so an older or damaged
## header still gives a caption.


## "Runde 12 · 09.11.2026, 21:14"; "" for an empty header.
static func of(header: Dictionary) -> String:
	if header.is_empty():
		return ""
	var turn: Variant = header.get("turn")
	var round_number := int(turn) + 1 if turn is int or turn is float else 1
	var saved := date(str(header.get("saved_at", "")))
	if saved.is_empty():
		return CampaignFormat.t("MENU_SAVE_ROUND") % round_number
	return CampaignFormat.t("MENU_SAVE_INFO") % [round_number, saved]


## The header's "YYYY-MM-DD HH:MM:SS" the way the language writes a date; "" if it is none.
static func date(saved_at: String) -> String:
	if saved_at.length() < 16:
		return ""
	var parts := Time.get_datetime_dict_from_datetime_string(saved_at, false)
	if int(parts.get("year", 0)) <= 0:
		return ""
	return CampaignFormat.t("MENU_SAVE_DATE").format({
		"day": "%02d" % int(parts["day"]),
		"month": "%02d" % int(parts["month"]),
		"year": "%04d" % int(parts["year"]),
		"hour": "%02d" % int(parts["hour"]),
		"minute": "%02d" % int(parts["minute"]),
	})
