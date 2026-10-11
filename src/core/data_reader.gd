class_name DataReader
extends RefCounted
## Reads typed values from parsed JSON and collects one error per missing or mistyped key,
## so a broken data file reports all problems at once instead of failing on the first.

var errors: PackedStringArray = []
var context: String = ""


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("data file not found: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error(
			"%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]
		)
		return null
	return json.data


func number(data: Dictionary, key: String, fallback: float = NAN) -> float:
	if not data.has(key):
		if is_nan(fallback):
			_fail(key, "missing")
		return 0.0 if is_nan(fallback) else fallback
	var value: Variant = data[key]
	if not (value is float or value is int):
		_fail(key, "expected a number")
		return 0.0
	return float(value)


func integer(data: Dictionary, key: String, fallback: int = -1) -> int:
	if not data.has(key):
		if fallback < 0:
			_fail(key, "missing")
		return maxi(fallback, 0)
	var value: float = number(data, key)
	if value != floorf(value):
		_fail(key, "expected a whole number")
	return int(value)


func text(data: Dictionary, key: String, fallback: String = "") -> String:
	if not data.has(key):
		return fallback
	var value: Variant = data[key]
	if not value is String:
		_fail(key, "expected a string")
		return fallback
	return value


func flag(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return false
	var value: Variant = data[key]
	if not value is bool:
		_fail(key, "expected true or false")
		return false
	return value


func object(data: Dictionary, key: String, required: bool = true) -> Dictionary:
	if not data.has(key):
		if required:
			_fail(key, "missing")
		return {}
	var value: Variant = data[key]
	if not value is Dictionary:
		_fail(key, "expected an object")
		return {}
	return value


func list(data: Dictionary, key: String, required: bool = true) -> Array:
	if not data.has(key):
		if required:
			_fail(key, "missing")
		return []
	var value: Variant = data[key]
	if not value is Array:
		_fail(key, "expected a list")
		return []
	return value


func strings(data: Dictionary, key: String, required: bool = true) -> Array[String]:
	var result: Array[String] = []
	for item: Variant in list(data, key, required):
		if item is String:
			result.append(item)
		else:
			_fail(key, "expected a list of strings")
	return result


func numbers(data: Dictionary, key: String) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for item: Variant in list(data, key):
		if item is float or item is int:
			result.append(float(item))
		else:
			_fail(key, "expected a list of numbers")
	return result


func _fail(key: String, problem: String) -> void:
	var path := key if context.is_empty() else "%s.%s" % [context, key]
	errors.append("%s: %s" % [path, problem])
