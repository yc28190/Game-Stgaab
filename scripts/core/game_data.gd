class_name GameData
extends RefCounted
## Read-only access to the JSON files in res://data.

static var _cache := {}


static func table(table_name: String) -> Dictionary:
	if not _cache.has(table_name):
		var f := FileAccess.open("res://data/%s.json" % table_name, FileAccess.READ)
		assert(f != null, "missing data file: " + table_name)
		var parsed = JSON.parse_string(f.get_as_text())
		_cache[table_name] = parsed if parsed is Dictionary else {}
	return _cache[table_name]


static func monster(id: String) -> Dictionary:
	return table("monsters")[id]


static func essence(id: String) -> Dictionary:
	return table("essences")[id]


static func item(id: String) -> Dictionary:
	return table("items")[id]


static func floor_def(id: String) -> Dictionary:
	return table("floors")[id]


static func format_stones(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out
