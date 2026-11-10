class_name OptionsAudio
extends OptionsTab
## The audio page of the options: the four volumes and silence while the window is not in
## front.


func _build() -> void:
	_add_percent(UserSettings.VOLUME_MASTER, "OPTIONS_VOLUME_MASTER")
	_add_percent(UserSettings.VOLUME_MUSIC, "OPTIONS_VOLUME_MUSIC")
	_add_percent(UserSettings.VOLUME_SFX, "OPTIONS_VOLUME_SFX")
	_add_percent(UserSettings.VOLUME_UI, "OPTIONS_VOLUME_UI")
	_add_toggle(UserSettings.MUTE_UNFOCUSED, "OPTIONS_MUTE_UNFOCUSED")
