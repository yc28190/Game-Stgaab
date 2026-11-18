class_name Profile
extends RefCounted
## The persistent character and town state. Stored as a plain Dictionary so it saves to JSON
## (note: JSON turns ints into floats, so always read numbers through int()).

const VERSION := 2
const AINAR_WEAPON := "greatsword"


static func create() -> Dictionary:
	return {
		"version": VERSION,
		"year": 1,
		"month": 1,
		"stones": 5000,
		"level": 1,
		"exp": 0,  # cumulative
		"bestiary": [],  # species that already gave their EXP (novel ch. 22)
		"essences": [],
		"essence_colors": {},
		"engravings": [],
		"achievements": [],
		"mental_bonus": 0,  # permanent Mental Power from achievements
		"equipment": {"weapon": "club", "shield": "round_shield", "body": "", "head": ""},
		"inventory": [{"id": "bread", "count": 6}, {"id": "potion", "count": 1}],
		"mana_stones": {},
		"vials": [],
		"allies": [],
		"companions": {},
		"runs": 0,
		"slept_rough": false,
		"game_over": "",
	}


static func create_companion(id: String) -> Dictionary:
	return {"id": id, "level": 1, "exp": 0, "bestiary": [], "essences": [], "alive": true}


## Upgrades a save from an older version of the game.
static func migrate(p: Dictionary) -> Dictionary:
	var fresh := create()
	fresh.merge(p, true)
	if int(fresh.get("version", 1)) < 2:
		# v1 gave EXP for every kill on a different curve: keep the level (capped) and restart its EXP.
		var lvl := mini(int(fresh["level"]), Rules.MAX_LEVEL)
		fresh["level"] = lvl
		fresh["exp"] = Rules.LEVEL_THRESHOLDS[lvl]
		fresh.erase("portals_opened")
		for e in fresh["essences"].duplicate():
			if (fresh["essences"] as Array).count(e) > 1:
				fresh["essences"].erase(e)
		if "ainar" in fresh["allies"] and not fresh["companions"].has("ainar"):
			fresh["companions"]["ainar"] = create_companion("ainar")
		fresh["version"] = VERSION
	return fresh


# --- Levels and EXP --------------------------------------------------------------------------------

static func level_for_exp(total_exp: int) -> int:
	var lvl := 1
	for l in range(2, Rules.MAX_LEVEL + 1):
		if total_exp >= int(Rules.LEVEL_THRESHOLDS[l]):
			lvl = l
	return lvl


static func exp_for_next(level: int) -> int:
	if level >= Rules.MAX_LEVEL:
		return -1
	return int(Rules.LEVEL_THRESHOLDS[level + 1])


## Rank 9 gives 1 EXP, and each rank higher +1 (ch. 22, 50).
static func species_exp(rank: int) -> int:
	return maxi(1, 10 - rank)


## Adds EXP to a character dict (the profile or a companion) and returns the number of levels gained.
static func add_exp(c: Dictionary, amount: int) -> int:
	var before := int(c["level"])
	c["exp"] = int(c["exp"]) + amount
	c["level"] = maxi(before, level_for_exp(int(c["exp"])))
	return int(c["level"]) - before


## Records a kill in a character's bestiary. Returns the species EXP earned (0 if already known).
static func record_kill(c: Dictionary, species: String, rank: int) -> int:
	if species in c["bestiary"]:
		return 0
	c["bestiary"].append(species)
	return species_exp(rank)


static func essence_slots(c: Dictionary) -> int:
	return int(c["level"])


static func can_absorb(c: Dictionary, essence_id: String) -> String:
	if essence_id in c["essences"]:
		return "already has this essence"
	if (c["essences"] as Array).size() >= essence_slots(c):
		return "no free essence slot"
	return ""


# --- Stats ---------------------------------------------------------------------------------------

## Final stat values (see Stats.ORDER), plus "regen" in HP per hour.
static func player_stats(p: Dictionary) -> Dictionary:
	return compute_stats(p)["values"]


## Where each stat comes from, for the character sheet: stat -> Array of [source label, amount].
static func stat_sources(p: Dictionary) -> Dictionary:
	return compute_stats(p)["sources"]


static func compute_stats(p: Dictionary) -> Dictionary:
	return _compute(int(p["level"]), p["essences"], p["equipment"], p["engravings"], int(p.get("mental_bonus", 0)))


static func companion_stats(c: Dictionary) -> Dictionary:
	return _compute(int(c["level"]), c["essences"], {"weapon": AINAR_WEAPON}, [], 0)["values"]


static func _compute(level: int, essences: Array, equipment: Dictionary, engravings: Array, mental_bonus: int) -> Dictionary:
	var values := {}
	var sources := {}
	for k in Stats.ORDER:
		values[k] = 0
		sources[k] = []
	var add := func(stat: String, label: String, amount: int) -> void:
		if amount == 0:
			return
		values[stat] = int(values.get(stat, 0)) + amount
		if not sources.has(stat):
			sources[stat] = []
		sources[stat].append([label, amount])

	for k in Stats.BASE:
		add.call(k, "Base", int(Stats.BASE[k]))
	add.call("max_sp", "Level %d" % level, Stats.soul_power_from_levels(level))
	add.call("mental", "Achievements", mental_bonus)
	for slot in equipment:
		var item_id: String = equipment[slot]
		if item_id == "":
			continue
		var it := GameData.item(item_id)
		var item_stats: Dictionary = it.get("stats", {})
		for k in item_stats:
			add.call(k, it["name"], int(item_stats[k]))
	for e in essences:
		var ess := GameData.essence(e)
		var ess_stats: Dictionary = ess.get("stats", {})
		for k in ess_stats:
			add.call(k, ess["name"], int(ess_stats[k]))
	if _has_passive(essences, "preservation"):
		add.call("regen", "Preservation of the Flesh", 4)
	if "undying_1" in engravings:
		# Ch. 21: "Natural Regeneration greatly increases. Physical Stats increase by +20."
		add.call("regen", "Undying Imprint", 4)
		add.call("strength", "Undying Imprint", 2)
		add.call("phys_res", "Undying Imprint", 1)
	add.call("atk", "Strength %d / 2" % int(values["strength"]), Stats.attack_from_strength(int(values["strength"])))
	return {"values": values, "sources": sources}


static func has_passive(p: Dictionary, passive: String) -> bool:
	return _has_passive(p["essences"], passive)


static func _has_passive(essences: Array, passive: String) -> bool:
	for e in essences:
		if GameData.essence(e).get("passive", "") == passive:
			return true
	return false


## Active skills granted by absorbed essences, in absorption order. An essence's colour decides its active.
static func active_skills(p: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e in p["essences"]:
		var a := GameData.essence_active(e, essence_color(p, e))
		if a != "" and not a in out:
			out.append(a)
	return out


## Colour of an absorbed essence (stored when it was absorbed; defaults to the essence's first colour).
static func essence_color(p: Dictionary, essence_id: String) -> String:
	var colors: Dictionary = p.get("essence_colors", {})
	return colors.get(essence_id, GameData.essence_colors(essence_id)[0])


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


# --- Economy -------------------------------------------------------------------------------------

static func mana_stone_value(stones: Dictionary) -> int:
	var total := 0
	for m in stones:
		total += int(stones[m]) * int(GameData.monster(m)["stone"])
	return total


## Magic stone exchange fee: none in the first year, 10% after (ch. 18).
static func exchange_fee(p: Dictionary) -> float:
	return 0.0 if int(p["year"]) <= 1 else Rules.EXCHANGE_FEE


static func annual_tax(p: Dictionary) -> int:
	return Rules.FIRST_YEAR_TAX + Rules.TAX_INCREASE_PER_YEAR * (int(p["year"]) - 1)


## The last cycle of the year lasts 35 days because of the 5-day 13th month (ch. 231).
static func month_days(month: int) -> int:
	return 35 if month == Rules.MONTHS_PER_YEAR else 30


static func living_cost(p: Dictionary) -> int:
	return month_days(int(p["month"])) * Rules.LIVING_COST_PER_DAY


## Called when the party comes back to town: the month's living costs are paid (or you sleep rough),
## the month passes and, after the 13th-month festival, the tax collector comes (ch. 18: or execution).
static func advance_month(p: Dictionary) -> Array[String]:
	var msgs: Array[String] = []
	var cost := living_cost(p)
	if int(p["stones"]) >= cost:
		p["stones"] = int(p["stones"]) - cost
		p["slept_rough"] = false
		msgs.append("Living costs for %d days: -%s stones." % [month_days(int(p["month"])), GameData.format_stones(cost)])
	else:
		msgs.append("You can't pay the inn (%s stones). You spend what you have and sleep in the street; you'll start the next expedition hungry and sore." % GameData.format_stones(cost))
		p["stones"] = 0
		p["slept_rough"] = true
	if int(p["month"]) == Rules.MONTHS_PER_YEAR:
		msgs.append("The 13th month: five days of festival before the new year.")
	p["month"] = int(p["month"]) + 1
	if int(p["month"]) > Rules.MONTHS_PER_YEAR:
		var tax := annual_tax(p)
		if int(p["stones"]) >= tax:
			p["stones"] = int(p["stones"]) - tax
			p["year"] = int(p["year"]) + 1
			p["month"] = 1
			msgs.append("The tax collector takes %s stones. You live to see another year." % GameData.format_stones(tax))
			msgs.append("Next year's tax: %s stones. Magic stone exchanges now cost a %d%% fee." % [GameData.format_stones(annual_tax(p)), int(Rules.EXCHANGE_FEE * 100)])
		else:
			p["game_over"] = "tax"
			msgs.append("You can't pay the annual tax of %s stones. The city guards drag you to the square..." % GameData.format_stones(tax))
	return msgs


static func months_until_tax(p: Dictionary) -> int:
	return Rules.MONTHS_PER_YEAR - int(p["month"]) + 1


## Permanent Mental Power rewards (novel achievements, ch. 5, 7, 64, 107, 143...).
static func grant_achievement(p: Dictionary, id: String, mental: int) -> bool:
	if id in p["achievements"]:
		return false
	p["achievements"].append(id)
	p["mental_bonus"] = int(p.get("mental_bonus", 0)) + mental
	return true
