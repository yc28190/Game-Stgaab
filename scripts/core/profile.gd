class_name Profile
extends RefCounted
## The persistent character and town state. Stored as a plain Dictionary so it saves to JSON
## (note: JSON turns ints into floats, so always read numbers through int()).

const BASE_HP := 50
const HP_PER_LEVEL := 8
const BASE_ATK := 6
const BASE_DEF := 1


static func create() -> Dictionary:
	return {
		"version": 1,
		"year": 1,
		"month": 1,
		"stones": 5000,
		"level": 1,
		"exp": 0,
		"essences": [],
		"engravings": [],
		"equipment": {"weapon": "club", "shield": "round_shield", "body": "", "head": ""},
		"inventory": [{"id": "bread", "count": 6}, {"id": "potion", "count": 1}],
		"mana_stones": {},
		"vials": [],
		"allies": [],
		"portals_opened": [],
		"runs": 0,
		"game_over": "",
	}


static func exp_to_next(level: int) -> int:
	return 15 + level * level * 10


static func essence_slots(p: Dictionary) -> int:
	return int(p["level"])


## Adds EXP and returns the number of levels gained.
static func add_exp(p: Dictionary, amount: int) -> int:
	p["exp"] = int(p["exp"]) + amount
	var gained := 0
	while int(p["exp"]) >= exp_to_next(int(p["level"])):
		p["exp"] = int(p["exp"]) - exp_to_next(int(p["level"]))
		p["level"] = int(p["level"]) + 1
		gained += 1
	return gained


static func player_stats(p: Dictionary) -> Dictionary:
	var lvl := int(p["level"])
	var s := {
		"max_hp": BASE_HP + (lvl - 1) * HP_PER_LEVEL,
		"atk": BASE_ATK + (lvl - 1),
		"def": BASE_DEF,
		"regen_every": Rules.PLAYER_REGEN_EVERY,
	}
	for slot in p["equipment"]:
		var item_id: String = p["equipment"][slot]
		if item_id == "":
			continue
		var it := GameData.item(item_id)
		s["atk"] += int(it.get("atk", 0))
		s["def"] += int(it.get("def", 0))
		s["max_hp"] += int(it.get("hp", 0))
	for e in p["essences"]:
		var stats: Dictionary = GameData.essence(e).get("stats", {})
		for k in stats:
			s[k] = int(s.get(k, 0)) + int(stats[k])
	if has_passive(p, "preservation"):
		s["regen_every"] = mini(int(s["regen_every"]), 4)
	if "undying_1" in p["engravings"]:
		s["max_hp"] = int(s["max_hp"] * 1.2)
		s["regen_every"] = mini(int(s["regen_every"]), 5)
	return s


static func has_passive(p: Dictionary, passive: String) -> bool:
	for e in p["essences"]:
		if GameData.essence(e).get("passive", "") == passive:
			return true
	return false


## Active skills granted by absorbed essences, in absorption order.
static func active_skills(p: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in p["essences"]:
		var a: String = GameData.essence(e).get("active", "")
		if a != "" and not a in out:
			out.append(a)
	return out


# --- Inventory helpers (an inventory is an Array of {"id", "count"}) ---

static func count_item(inv: Array, id: String) -> int:
	for e in inv:
		if e["id"] == id:
			return int(e["count"])
	return 0


static func add_item(inv: Array, id: String, count: int = 1) -> bool:
	for e in inv:
		if e["id"] == id:
			e["count"] = int(e["count"]) + count
			return true
	if inv.size() >= Rules.INVENTORY_SLOTS:
		return false
	inv.append({"id": id, "count": count})
	return true


static func remove_item(inv: Array, id: String, count: int = 1) -> bool:
	for i in inv.size():
		if inv[i]["id"] == id:
			var c := int(inv[i]["count"])
			if c < count:
				return false
			if c == count:
				inv.remove_at(i)
			else:
				inv[i]["count"] = c - count
			return true
	return false


static func mana_stone_value(stones: Dictionary) -> int:
	var total := 0
	for m in stones:
		total += int(stones[m]) * int(GameData.monster(m)["stone"])
	return total


## Called when the party comes back to town: a month passes, living costs are paid and,
## once a year, the tax collector comes (novel ch. 18: those who can't pay are executed).
static func advance_month(p: Dictionary) -> Array[String]:
	var msgs: Array[String] = []
	p["month"] = int(p["month"]) + 1
	p["stones"] = int(p["stones"]) - Rules.MONTHLY_LIVING_COST
	msgs.append("Living costs for the month: -%s stones." % GameData.format_stones(Rules.MONTHLY_LIVING_COST))
	if int(p["month"]) > Rules.MONTHS_PER_YEAR:
		if int(p["stones"]) >= Rules.ANNUAL_TAX:
			p["stones"] = int(p["stones"]) - Rules.ANNUAL_TAX
			p["year"] = int(p["year"]) + 1
			p["month"] = 1
			msgs.append("The tax collector takes %s stones. You live to see another year." % GameData.format_stones(Rules.ANNUAL_TAX))
		else:
			p["game_over"] = "tax"
			msgs.append("You can't pay the annual tax of %s stones. The city guards drag you to the square..." % GameData.format_stones(Rules.ANNUAL_TAX))
	return msgs


static func months_until_tax(p: Dictionary) -> int:
	return Rules.MONTHS_PER_YEAR - int(p["month"]) + 1
