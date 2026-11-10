class_name SaveFile
extends RefCounted
## One save file: a header for the load screen and the GameState's bytes, each stored the way
## FileAccess.store_var does (its length, then the Variant). decode() checks the lengths, the
## types and the state's checksum before it decodes anything, so a truncated, emptied or
## foreign file is told apart without an engine error, and the header it hands out has the
## types its readers rely on, whatever a hand-edited file holds.

enum Kind { MISSING, VALID, BROKEN, OTHER_VERSION }

const LENGTH_BYTES := 4
## The Variant type sits in the lowest byte of an encoded Variant; flags follow above it.
const TYPE_MASK := 0xFF
## Whole numbers of a header are kept within this, so nothing computed from them overflows.
const WHOLE_LIMIT := 1_000_000_000

var kind := Kind.MISSING
## version, game_version, turn, saved_at, saved_unix and humans; empty unless the file is
## VALID or of another version.
var header: Dictionary = {}
## GameState.to_bytes(); empty unless VALID.
var state_bytes := PackedByteArray()


## The header of a save of `state` written now; `bytes` are its GameState.to_bytes().
static func header_for(state: GameState, bytes: PackedByteArray) -> Dictionary:
	var humans: Array[String] = []
	for house: HouseState in state.houses.values():
		if not house.is_computer() and not house.is_eliminated:
			humans.append(house.id)
	return {
		"version": GameState.SAVE_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"turn": state.turn,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"saved_unix": Time.get_unix_time_from_system(),
		"humans": humans,
		"checksum": checksum(bytes),
	}


static func checksum(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## The bytes of a save file.
static func encode(file_header: Dictionary, bytes: PackedByteArray) -> PackedByteArray:
	var data := PackedByteArray()
	for part: Variant in [file_header, bytes]:
		var encoded := var_to_bytes(part)
		var length := PackedByteArray()
		length.resize(LENGTH_BYTES)
		length.encode_u32(0, encoded.size())
		data.append_array(length)
		data.append_array(encoded)
	return data


## What a file with these bytes is; never MISSING.
static func decode(data: PackedByteArray) -> SaveFile:
	var result := SaveFile.new()
	result.kind = Kind.BROKEN
	var parts := _parts(data)
	if parts.size() != 2 or not _holds_dictionary(parts[0]) or not _holds_bytes(parts[1]):
		return result
	var raw: Variant = bytes_to_var(parts[0])
	var body: Variant = bytes_to_var(parts[1])
	if not raw is Dictionary or not body is PackedByteArray:
		return result
	var head: Dictionary = raw
	var bytes: PackedByteArray = body
	var version: Variant = head.get("version")
	if not (version is int or version is float) or bytes.is_empty():
		return result
	if _whole(version, -1) != GameState.SAVE_VERSION:
		result.kind = Kind.OTHER_VERSION
		result.header = _clean(head)
		return result
	# Saves from before the checksum was written carry none; they are taken as they are.
	var expected: Variant = head.get("checksum")
	if expected is String and _text(expected) != checksum(bytes):
		return result
	result.kind = Kind.VALID
	result.header = _clean(head)
	result.state_bytes = bytes
	return result


static func load_file(file_path: String) -> SaveFile:
	if not FileAccess.file_exists(file_path):
		return SaveFile.new()
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return decode(PackedByteArray())
	return decode(file.get_buffer(file.get_length()))


## Writes the bytes and reads them back; OK only if the file holds exactly these.
static func store(file_path: String, data: PackedByteArray) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_buffer(data)
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if not stored or FileAccess.get_file_as_bytes(file_path) != data:
		return ERR_FILE_CANT_WRITE
	return OK


## The length-prefixed parts of a file; none unless they fill it exactly.
static func _parts(data: PackedByteArray) -> Array[PackedByteArray]:
	var parts: Array[PackedByteArray] = []
	var at := 0
	while at + LENGTH_BYTES <= data.size():
		var end := at + LENGTH_BYTES + data.decode_u32(at)
		if end > data.size():
			break
		parts.append(data.slice(at + LENGTH_BYTES, end))
		at = end
	if at != data.size():
		parts.clear()
	return parts


## The type of an encoded Variant, read from its first bytes without decoding it.
static func _stored_type(encoded: PackedByteArray) -> int:
	return encoded.decode_u32(0) & TYPE_MASK if encoded.size() >= LENGTH_BYTES else TYPE_NIL


static func _holds_dictionary(encoded: PackedByteArray) -> bool:
	return _stored_type(encoded) == TYPE_DICTIONARY


## An encoded PackedByteArray whose count fits what follows it.
static func _holds_bytes(encoded: PackedByteArray) -> bool:
	if _stored_type(encoded) != TYPE_PACKED_BYTE_ARRAY or encoded.size() < 2 * LENGTH_BYTES:
		return false
	return encoded.decode_u32(LENGTH_BYTES) <= encoded.size() - 2 * LENGTH_BYTES


## The header with the types its readers rely on: what is missing or of another type gets a
## harmless value.
static func _clean(raw: Dictionary) -> Dictionary:
	var humans: Array[String] = []
	var listed: Variant = raw.get("humans")
	if listed is Array:
		for house: Variant in listed as Array:
			if house is String:
				humans.append(_text(house))
	return {
		"version": _whole(raw.get("version"), -1),
		"game_version": _text(raw.get("game_version")),
		"turn": maxi(_whole(raw.get("turn"), 0), 0),
		"saved_at": _text(raw.get("saved_at")),
		"saved_unix": _number(raw.get("saved_unix")),
		"humans": humans,
	}


static func _whole(value: Variant, fallback: int) -> int:
	var number := _number(value, NAN)
	return fallback if is_nan(number) else int(clampf(number, -WHOLE_LIMIT, WHOLE_LIMIT))


static func _number(value: Variant, fallback: float = 0.0) -> float:
	if value is int:
		var whole: int = value
		return float(whole)
	if value is float:
		var number: float = value
		return number if is_finite(number) else fallback
	return fallback


static func _text(value: Variant) -> String:
	if value is String:
		var text: String = value
		return text
	return ""
