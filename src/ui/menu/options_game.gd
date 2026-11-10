class_name OptionsGame
extends OptionsTab
## The game page of the options: language, controller rumble, screen shake, slow motion and
## the advisors' hints.

var _language_locked := false


## The language can only change where the caller can rebuild its screens; elsewhere the row
## says so and a reset leaves the language alone.
func lock_language() -> void:
	_language_locked = true
	var row := _rows[UserSettings.LOCALE]
	row.set_enabled(false)
	row.set_note(tr("OPTIONS_LANGUAGE_LOCKED"))


func _build() -> void:
	var names: Array[String] = [tr("OPTIONS_LANGUAGE_SYSTEM")]
	var locales: Array[String] = [UserSettings.LOCALE_SYSTEM]
	for locale: String in UserSettings.LOCALES:
		names.append(tr("OPTIONS_LANGUAGE_" + locale.to_upper()))
		locales.append(locale)
	_add_choice(UserSettings.LOCALE, "OPTIONS_LANGUAGE", names, locales)
	_add_toggle(UserSettings.RUMBLE, "OPTIONS_RUMBLE")
	_add_percent(UserSettings.SCREEN_SHAKE, "OPTIONS_SCREEN_SHAKE")
	_add_toggle(UserSettings.SLOW_MOTION, "OPTIONS_SLOW_MOTION")
	_add_toggle(UserSettings.ADVISORS, "OPTIONS_ADVISORS")


func _reset_keys() -> Array[String]:
	var keys := super()
	if _language_locked:
		keys.erase(UserSettings.LOCALE)
	return keys
