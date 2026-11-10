extends GutTest
## The bytes of a save file: what was written decodes back, and whatever else a file may hold
## — cut short, emptied, changed, foreign, hand-edited or from another save version — is told
## apart without an error in the log (GUT fails a test on any) and never hands out a header
## with fields of the wrong type.

var _state: GameState


func before_all() -> void:
	var rules := GameRules.load_files()
	_state = GameSetup.create(rules.map, rules.economy, 9)


func test_what_was_encoded_decodes_back() -> void:
	_state.turn = 6
	var bytes := _state.to_bytes()
	var file := SaveFile.decode(SaveFile.encode(SaveFile.header_for(_state, bytes), bytes))
	assert_eq(file.kind, SaveFile.Kind.VALID)
	assert_eq(file.state_bytes, bytes)
	assert_eq(file.header["turn"], 6)
	assert_eq(file.header["version"], GameState.SAVE_VERSION)
	assert_eq(
		file.header["game_version"], ProjectSettings.get_setting("application/config/version")
	)
	assert_gt(float(file.header["saved_unix"]), 0.0)
	assert_eq(str(file.header["saved_at"]).length(), 19, "date and time, to the second")
	assert_false(file.header.has("checksum"), "the checksum is the file's own business")


func test_a_file_cut_short_anywhere_is_broken() -> void:
	var data := _encoded()
	for size: int in [0, 1, 3, 4, 11, data.size() >> 1, data.size() - 1]:
		var file := SaveFile.decode(data.slice(0, size))
		assert_eq(file.kind, SaveFile.Kind.BROKEN, "%d of %d bytes" % [size, data.size()])
		assert_true(file.header.is_empty())
		assert_true(file.state_bytes.is_empty())


func test_bytes_after_the_end_break_the_file() -> void:
	var data := _encoded()
	data.append_array(PackedByteArray([1, 2, 3, 4]))
	assert_eq(SaveFile.decode(data).kind, SaveFile.Kind.BROKEN)


func test_an_emptied_file_of_the_right_size_is_broken() -> void:
	var zeros := PackedByteArray()
	zeros.resize(_encoded().size())
	assert_eq(SaveFile.decode(zeros).kind, SaveFile.Kind.BROKEN)


func test_a_state_that_changed_on_disk_fails_its_checksum() -> void:
	var data := _encoded()
	data[data.size() - 1] ^= 0xFF
	assert_eq(SaveFile.decode(data).kind, SaveFile.Kind.BROKEN)


func test_a_save_from_before_the_checksum_is_taken_as_it_is() -> void:
	var header := {"version": GameState.SAVE_VERSION, "turn": 2, "humans": ["welfen"]}
	var file := SaveFile.decode(SaveFile.encode(header, _state.to_bytes()))
	assert_eq(file.kind, SaveFile.Kind.VALID)
	assert_eq(file.header["turn"], 2)
	assert_eq(file.header["game_version"], "")


func test_foreign_content_is_broken() -> void:
	var bytes := _state.to_bytes()
	var header := {"version": GameState.SAVE_VERSION}
	var foreign: Array[PackedByteArray] = [
		"not a save".to_utf8_buffer(),
		SaveFile.encode({}, bytes),
		SaveFile.encode({"version": "eight"}, bytes),
		SaveFile.encode(header, PackedByteArray()),
		_two_variants(["a", "list"], bytes),
		_two_variants(header, "no state"),
		_two_variants(header, 7),
		_one_variant("not a save"),
	]
	for index: int in foreign.size():
		assert_eq(SaveFile.decode(foreign[index]).kind, SaveFile.Kind.BROKEN, "case %d" % index)


func test_another_save_version_is_told_apart_and_keeps_its_header() -> void:
	var header := {
		"version": GameState.SAVE_VERSION + 1, "game_version": "9.9.9", "turn": 14,
		"humans": ["staufer"],
	}
	var file := SaveFile.decode(SaveFile.encode(header, _state.to_bytes()))
	assert_eq(file.kind, SaveFile.Kind.OTHER_VERSION)
	assert_eq(file.header["turn"], 14)
	assert_eq(file.header["game_version"], "9.9.9")
	assert_eq(file.header["humans"], ["staufer"])
	assert_true(file.state_bytes.is_empty(), "its state is never handed out")


func test_a_hand_edited_header_comes_out_with_the_right_types() -> void:
	var header := {
		"version": float(GameState.SAVE_VERSION), "game_version": 8, "turn": "twelve",
		"saved_at": 20261109, "saved_unix": "yesterday", "humans": ["welfen", 3, null, "staufer"],
	}
	var file := SaveFile.decode(SaveFile.encode(header, _state.to_bytes()))
	assert_eq(file.kind, SaveFile.Kind.VALID)
	assert_eq(
		file.header,
		{
			"version": GameState.SAVE_VERSION, "game_version": "", "turn": 0, "saved_at": "",
			"saved_unix": 0.0, "humans": ["welfen", "staufer"],
		}
	)
	assert_eq(typeof(file.header["version"]), TYPE_INT)
	assert_eq(typeof(file.header["saved_unix"]), TYPE_FLOAT)
	for humans: Variant in [7, "welfen", {"a": 1}]:
		header["humans"] = humans
		file = SaveFile.decode(SaveFile.encode(header, _state.to_bytes()))
		assert_eq(file.header["humans"], [], str(humans))


func test_numbers_out_of_range_are_tamed() -> void:
	var header := {
		"version": GameState.SAVE_VERSION, "turn": -5, "saved_unix": INF, "humans": [],
	}
	var file := SaveFile.decode(SaveFile.encode(header, _state.to_bytes()))
	assert_eq(file.header["turn"], 0)
	assert_eq(file.header["saved_unix"], 0.0)
	header["turn"] = 1.0e300
	header["saved_unix"] = NAN
	file = SaveFile.decode(SaveFile.encode(header, _state.to_bytes()))
	assert_eq(file.header["turn"], SaveFile.WHOLE_LIMIT)
	assert_eq(file.header["saved_unix"], 0.0)


func test_a_file_written_by_store_var_reads_the_same() -> void:
	var path := "user://test_save_file.sav"
	var header := {"version": GameState.SAVE_VERSION, "turn": 3, "humans": ["welfen"]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(header)
	file.store_var(_state.to_bytes())
	file.close()
	var loaded := SaveFile.load_file(path)
	DirAccess.remove_absolute(path)
	assert_eq(loaded.kind, SaveFile.Kind.VALID, "the format of the saves written so far")
	assert_eq(loaded.state_bytes, _state.to_bytes())
	assert_eq(SaveFile.load_file(path).kind, SaveFile.Kind.MISSING)


func test_store_writes_the_bytes_and_reports_a_file_it_cannot_open() -> void:
	var folder := "user://test_save_file"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("a.sav")
	var data := _encoded()
	assert_eq(SaveFile.store(path, data), OK)
	assert_eq(FileAccess.get_file_as_bytes(path), data)
	assert_ne(SaveFile.store(folder, data), OK, "a folder is no file")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)


func _encoded() -> PackedByteArray:
	var bytes := _state.to_bytes()
	return SaveFile.encode(SaveFile.header_for(_state, bytes), bytes)


func _one_variant(value: Variant) -> PackedByteArray:
	var encoded := var_to_bytes(value)
	var data := PackedByteArray()
	data.resize(SaveFile.LENGTH_BYTES)
	data.encode_u32(0, encoded.size())
	data.append_array(encoded)
	return data


func _two_variants(first: Variant, second: Variant) -> PackedByteArray:
	var data := _one_variant(first)
	data.append_array(_one_variant(second))
	return data
