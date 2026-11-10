extends GutTest
## The sound bank holds what the game asks for: data/audio.json loads cleanly, every file it
## names exists, every id of the catalogue is there, the stems of a track are equally long,
## and no script under src/ plays a sound or a track the bank does not know.

const SOURCES := "res://src"
const UI_SOUNDS := "res://src/render/audio/ui_sounds.gd"
## The catalogue: every sound a scene may play.
const SOUNDS: Array[StringName] = [
	&"ui_click", &"ui_hover", &"ui_focus", &"ui_tab", &"ui_slider", &"ui_back", &"ui_confirm",
	&"ui_error", &"ui_modal_open", &"ui_save",
	&"map_select", &"map_army_move", &"map_phase_end", &"map_turn_handover", &"map_settlement",
	&"map_event_card", &"map_build_order", &"map_build_done", &"map_recruit", &"map_coin",
	&"map_conquest",
	&"battle_horn", &"battle_charge", &"battle_impact", &"battle_volley", &"battle_treb_shot",
	&"battle_blast", &"battle_formation", &"battle_rout", &"battle_rally",
	&"battle_leader_captured", &"battle_klong",
	&"joust_fanfare", &"joust_spur", &"joust_spur_off", &"joust_gallop", &"joust_impact",
	&"joust_lance_break", &"joust_shield_block", &"joust_unseat", &"joust_crowd_cheer",
	&"siege_release", &"siege_whoosh", &"siege_hit_stone", &"siege_hit_wood", &"siege_miss",
	&"siege_ignite", &"siege_collapse", &"siege_counterfire",
	&"raid_swing", &"raid_hit", &"raid_block", &"raid_parry", &"raid_down", &"raid_alarm",
	&"raid_door", &"raid_sneak", &"raid_deed",
	&"merchant_horn", &"merchant_wagon_stop", &"merchant_crossbow", &"merchant_hit",
	&"merchant_block", &"merchant_down",
	&"sting_battle_won", &"sting_battle_lost", &"sting_success", &"sting_fail",
	&"sting_coronation", &"sting_victory", &"sting_defeat",
]
## Track -> number of stems.
const TRACKS: Dictionary[StringName, int] = {
	&"menu": 1, &"map": 2, &"battle": 3, &"joust": 2, &"siege": 2, &"raid": 2, &"merchant": 2,
}
## Section of data/audio.json -> the key that lists an entry's files.
const FILE_KEYS: Dictionary[String, String] = {"sounds": "files", "music": "layers"}
const UI_PREFIX := "ui_"
const UI_SECONDS := 0.25
const STEM_TOLERANCE_SECONDS := 0.001

var _bank: AudioBank


## One place where a script names a sound or a track.
class AudioUse:
	const CALL := "\\bAudio\\s*\\.\\s*(play_at|play|music)\\s*\\("
	const META := "\\bSOUND_META\\s*,\\s*&?\"([^\"]*)\""
	const LITERAL := "&?\"([^\"]*)\""
	const CONSTANT_NAME := "\\b[A-Z][A-Z0-9_]*\\b"
	const CONSTANT_VALUE := "\\bconst\\s+%s\\b[^=\\n]*=\\s*&?\"([^\"]*)\""

	var path := ""
	var line := 0
	var id: StringName = &""
	var is_track := false

	func describe() -> String:
		return "%s:%d: %s \"%s\"" % [path, line, "track" if is_track else "sound", id]

	## Every id the source names: the literals in the first argument of Audio.play,
	## Audio.play_at and Audio.music (written there or in a constant of the same file) and
	## the values set as a button's UiSounds.SOUND_META. Comment lines do not count.
	static func find_all(script_path: String, source: String) -> Array[AudioUse]:
		var result: Array[AudioUse] = []
		var code := _without_comment_lines(source)
		for call: RegExMatch in RegEx.create_from_string(CALL).search_all(code):
			var argument := _first_argument(code, call.get_end())
			var ids := _captures(LITERAL, argument)
			if ids.is_empty():
				ids = _constant_values(code, argument)
			for found: String in ids:
				var use := _at(script_path, code, call.get_start(), found)
				use.is_track = call.get_string(1) == "music"
				result.append(use)
		for meta: RegExMatch in RegEx.create_from_string(META).search_all(code):
			result.append(_at(script_path, code, meta.get_start(), meta.get_string(1)))
		return result

	static func _at(script_path: String, code: String, offset: int, found: String) -> AudioUse:
		var use := AudioUse.new()
		use.path = script_path
		use.line = code.substr(0, offset).count("\n") + 1
		use.id = StringName(found)
		return use

	static func _without_comment_lines(source: String) -> String:
		var lines := source.split("\n")
		for i: int in lines.size():
			if lines[i].strip_edges().begins_with("#"):
				lines[i] = ""
		return "\n".join(lines)

	## The text from `from` up to the comma or bracket that ends the first argument.
	static func _first_argument(code: String, from: int) -> String:
		var depth := 0
		var quoted := false
		for i: int in range(from, code.length()):
			var letter := code[i]
			if letter == "\"":
				quoted = not quoted
			elif quoted:
				continue
			elif letter in "([{":
				depth += 1
			elif letter in ")]}" or letter == ",":
				if depth == 0:
					return code.substr(from, i - from)
				if letter != ",":
					depth -= 1
		return code.substr(from)

	## The texts of the file's own constants that the argument names.
	static func _constant_values(code: String, argument: String) -> Array[String]:
		var result: Array[String] = []
		for constant: RegExMatch in RegEx.create_from_string(CONSTANT_NAME).search_all(argument):
			result.append_array(_captures(CONSTANT_VALUE % constant.get_string(), code))
		return result

	static func _captures(pattern: String, text: String) -> Array[String]:
		var result: Array[String] = []
		for hit: RegExMatch in RegEx.create_from_string(pattern).search_all(text):
			result.append(hit.get_string(1))
		return result


func before_all() -> void:
	_bank = AudioBank.load_file()


func test_the_bank_loads_without_errors_or_warnings() -> void:
	var bank := AudioBank.load_file()
	assert_push_error_count(0, "data/audio.json has no mistakes")
	assert_push_warning_count(0, "and names no missing file")
	assert_eq(bank.sounds.size(), _section("sounds").size(), "no sound was left out")
	assert_eq(bank.music.size(), _section("music").size(), "no track was left out")


func test_every_file_the_data_names_exists() -> void:
	var missing: Array[String] = []
	var named := 0
	for section: String in FILE_KEYS:
		var entries := _section(section)
		for id: String in entries:
			var entry: Dictionary = entries[id]
			for path: Variant in entry.get(FILE_KEYS[section], []):
				named += 1
				if not ResourceLoader.exists(str(path), "AudioStream"):
					missing.append("%s.%s: %s" % [section, id, path])
	assert_gt(named, SOUNDS.size(), "the data names files")
	assert_true(missing.is_empty(), "missing or not imported:\n%s" % "\n".join(missing))


func test_every_sound_of_the_catalogue_is_in_the_bank_on_its_bus() -> void:
	for id: StringName in SOUNDS:
		var sound: AudioBank.Sound = _bank.sounds.get(id)
		assert_not_null(sound, "sound %s" % id)
		if sound == null:
			continue
		var is_ui := str(id).begins_with(UI_PREFIX)
		var bus := AudioBank.BUS_UI if is_ui else AudioBank.BUS_SFX
		assert_eq(sound.bus, bus, "%s plays on the bus %s" % [id, bus])
		for stream: AudioStream in sound.streams:
			if is_ui:
				assert_lt(stream.get_length(), UI_SECONDS, "%s is a short interface sound" % id)


func test_every_track_has_its_stems_and_they_are_equally_long() -> void:
	for id: StringName in TRACKS:
		var track: AudioBank.Track = _bank.music.get(id)
		assert_not_null(track, "track %s" % id)
		if track == null:
			continue
		assert_eq(track.layers.size(), TRACKS[id], "stems of %s" % id)
		var seconds := track.layers[0].get_length()
		assert_gt(seconds, 1.0, "%s is a loop, not a sound" % id)
		for stem: AudioStream in track.layers:
			assert_almost_eq(
				stem.get_length(), seconds, STEM_TOLERANCE_SECONDS, "%s: stems stay in step" % id
			)


func test_scripts_only_play_sounds_and_tracks_the_bank_knows() -> void:
	var uses: Array[AudioUse] = []
	var own_path: String = (get_script() as Script).resource_path
	for path: String in _scripts(SOURCES):
		# This file spells calls out as test data.
		if path != own_path:
			uses.append_array(AudioUse.find_all(path, FileAccess.get_file_as_string(path)))
	var unknown: Array[String] = []
	for use: AudioUse in uses:
		if not _knows(use):
			unknown.append(use.describe())
	assert_gt(uses.size(), 5, "the scan finds the calls that exist")
	assert_true(unknown.is_empty(), "not in data/audio.json:\n%s" % "\n".join(unknown))
	var constants := (load(UI_SOUNDS) as Script).get_script_constant_map()
	for constant: String in constants:
		if constants[constant] is StringName and constant != "SOUND_META":
			assert_true(_bank.sounds.has(constants[constant]), "UiSounds.%s" % constant)


func test_the_scan_reads_calls_in_all_their_spellings() -> void:
	var source := "\n".join([
		"const BLAST := &\"battle_blast\"",
		"func _hit() -> void:",
		"\tAudio.play(&\"battle_impact\", -3.0)",
		"\tAudio.play_at(",
		"\t\t&\"siege_miss\" if missed else &\"siege_hit_stone\", place.get(&\"spot\")",
		"\t)",
		"\t# Audio.play(&\"only_a_comment\")",
		"\tAudio.music(&\"battle\", 0.5)",
		"\tAudio.music(&\"\")",
		"\tAudio.play(BLAST)",
		"\tAudio.play(sound_of(unit))",
		"\tbutton.set_meta(UiSounds.SOUND_META, &\"ui_confirm\")",
	])
	var found: Array[String] = []
	for use: AudioUse in AudioUse.find_all("res://x.gd", source):
		found.append(use.describe())
	assert_eq(found, [
		"res://x.gd:3: sound \"battle_impact\"",
		"res://x.gd:4: sound \"siege_miss\"",
		"res://x.gd:4: sound \"siege_hit_stone\"",
		"res://x.gd:8: track \"battle\"",
		"res://x.gd:9: track \"\"",
		"res://x.gd:10: sound \"battle_blast\"",
		"res://x.gd:12: sound \"ui_confirm\"",
	] as Array[String])


## An empty track id is the way to ask for silence.
func _knows(use: AudioUse) -> bool:
	if use.is_track:
		return use.id.is_empty() or _bank.music.has(use.id)
	return _bank.sounds.has(use.id)


func _section(key: String) -> Dictionary:
	var data: Dictionary = DataReader.load_json(AudioBank.PATH)
	return data[key]


func _scripts(folder: String) -> Array[String]:
	var result: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "gd":
			result.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		result.append_array(_scripts(folder.path_join(sub)))
	return result
