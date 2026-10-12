class_name EconomyTerm
extends RefCounted
## One summand of a number the UI explains (EconomyBreakdown): what it is, its value and the
## calculation with its numbers.

## Text key of the line; its %s placeholders take the translated args.
var label_key: String
## Text keys filled into the placeholders of label_key, e.g. a province name key.
var args: Array[String] = []
var value: float
## The calculation with its numbers, e.g. "60 × 15 % × 3 × (0.5 + 55/200)", or "" for a value
## straight from the data. Numbers use "." as the decimal point; the UI localizes it.
var formula: String


static func create(
	label: String, amount: float, calculation: String = "", label_args: Array[String] = []
) -> EconomyTerm:
	var term := EconomyTerm.new()
	term.label_key = label
	term.value = amount
	term.formula = calculation
	term.args = label_args
	return term


static func sum(terms: Array[EconomyTerm]) -> float:
	var total := 0.0
	for term: EconomyTerm in terms:
		total += term.value
	return total


## A number for a formula: at most three decimals, without trailing zeros.
static func num(number: float) -> String:
	var text := String.num(number, 3)
	return text.trim_suffix(".0") if text != "-0.0" and text != "-0" else "0"


## "2 × 1 + 2 × 2": companies per unit type times the unit's value of property.
static func per_unit(cfg: EconomyConfig, units: Array[String], property: StringName) -> String:
	var counts: Dictionary[String, int] = {}
	for id: String in units:
		counts[id] = counts.get(id, 0) + 1
	var parts := PackedStringArray()
	for id: String in counts:
		parts.append("%d × %s" % [counts[id], num(float(cfg.units[id].get(property)))])
	return " + ".join(parts)


static func province_key(province_id: String) -> String:
	return "PROVINCE_" + province_id


static func building_key(building_id: String) -> String:
	return "ECONOMY_BUILDING_" + building_id.to_upper()


static func decoration_key(decoration_id: String) -> String:
	return "ECONOMY_DECORATION_" + decoration_id.to_upper()


static func unit_key(unit_id: String) -> String:
	return "BATTLE_UNIT_" + unit_id.to_upper()


## Name key of a castle level: the home castle table in the home province, else the
## province castle table.
static func castle_key(level: int, is_home: bool) -> String:
	return ("ECONOMY_HOME_CASTLE_%d" if is_home else "ECONOMY_PROVINCE_CASTLE_%d") % level
