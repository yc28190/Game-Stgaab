class_name TownScreen
extends Control
## Rafdonia, the hub between runs: sell loot, shop, recruit, upgrade, then enter the labyrinth.

signal enter_labyrinth

const CONSUMABLES := ["bread", "potion", "antidote", "torch", "vial"]
const EQUIPMENT := ["club", "hammer", "mace", "round_shield", "tower_shield", "half_plate", "helmet"]

var notice := ""

var _p: Dictionary
var _status: VBoxContainer
var _tabs: TabContainer
var _notice_label: Label


func _ready() -> void:
	_p = Game.profile
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = UI.theme()
	UI.full_rect_bg(self)
	var margin := UI.margin(16)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(margin)
	var root := UI.hbox(16)
	margin.add_child(root)

	var left := PanelContainer.new()
	left.custom_minimum_size.x = 330
	root.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_status = UI.vbox(4)
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_status)

	var right := UI.vbox(10)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(right)
	right.add_child(UI.label("Rafdonia", 32, UI.ACCENT))
	_notice_label = UI.label(notice, 15, UI.GOOD, true)
	right.add_child(_notice_label)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(_tabs)
	_refresh()


func _say(text: String, good := true) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override("font_color", UI.GOOD if good else UI.BAD)


func _refresh() -> void:
	Game.save_game()
	var tab := _tabs.current_tab
	for c in _status.get_children():
		_status.remove_child(c)
		c.queue_free()
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_build_status()
	_build_gate()
	_build_character()
	_build_exchange()
	_build_market()
	_build_inn()
	_build_sanctuary()
	_tabs.current_tab = clampi(tab, 0, _tabs.get_tab_count() - 1)


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := UI.vbox(10)
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _stones() -> int:
	return int(_p["stones"])


func _row(parent: Control, text: String, sub: String, buttons: Array) -> void:
	var row := UI.hbox(10)
	var texts := UI.vbox(0)
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	texts.add_child(UI.label(text, 16, UI.TEXT, true))
	if sub != "":
		texts.add_child(UI.label(sub, 13, UI.DIM, true))
	row.add_child(texts)
	for b in buttons:
		row.add_child(b)
	parent.add_child(row)


# --- Left column -------------------------------------------------------------------------------

func _build_status() -> void:
	var s := Profile.player_stats(_p)
	var add := func(text: String, size := 15, color := UI.TEXT) -> void:
		_status.add_child(UI.label(text, size, color, true))
	add.call("Bjorn, son of Yandel", 20, UI.ACCENT)
	add.call("Level %d    EXP %d / %d" % [int(_p["level"]), int(_p["exp"]), Profile.exp_to_next(int(_p["level"]))])
	add.call("HP %d    SP %d    Attack %d" % [int(s["max_hp"]), int(s["max_sp"]), int(s["atk"])])
	var sheet_btn := UI.button("Character sheet", func(): _tabs.current_tab = 1)
	_status.add_child(sheet_btn)
	add.call("Stones: %s" % GameData.format_stones(_stones()), 17, UI.ACCENT)
	add.call("Year %d, month %d" % [int(_p["year"]), int(_p["month"])])
	var months := Profile.months_until_tax(_p)
	var tax_color := UI.BAD if months <= 3 and _stones() < Rules.ANNUAL_TAX else UI.DIM
	add.call("Annual tax of %s due in %d month%s" % [GameData.format_stones(Rules.ANNUAL_TAX), months, "" if months == 1 else "s"], 14, tax_color)
	_status.add_child(UI.separator())

	var ess: Array = _p["essences"]
	add.call("Essences (%d / %d slots)" % [ess.size(), Profile.essence_slots(_p)], 16, UI.ACCENT)
	if ess.is_empty():
		add.call("  none yet", 14, UI.DIM)
	for e in ess:
		add.call("  " + GameData.essence(e)["name"], 14)
	var skills := Profile.active_skills(_p)
	if not skills.is_empty():
		add.call("Skills: " + ", ".join(skills.map(func(k): return DungeonRun.SKILLS[k]["name"])), 14, UI.DIM)
	_status.add_child(UI.separator())

	add.call("Equipment", 16, UI.ACCENT)
	for slot in ["weapon", "shield", "body", "head"]:
		var id: String = _p["equipment"][slot]
		add.call("  %s: %s" % [slot.capitalize(), GameData.item(id)["name"] if id != "" else "-"], 14)
	add.call("Engravings: " + ("Undying Imprint" if "undying_1" in _p["engravings"] else "none"), 14, UI.DIM)
	add.call("Party: " + ("Bjorn + Ainar" if "ainar" in _p["allies"] else "Bjorn alone"), 14, UI.DIM)
	_status.add_child(UI.separator())

	var inv: Array = _p["inventory"]
	add.call("Bag (%d / %d)" % [inv.size(), Rules.INVENTORY_SLOTS], 16, UI.ACCENT)
	if inv.is_empty():
		add.call("  empty", 14, UI.DIM)
	for e in inv:
		add.call("  %s x%d" % [GameData.item(e["id"])["name"], int(e["count"])], 14)


# --- Tabs --------------------------------------------------------------------------------------

func _build_gate() -> void:
	var box := _page("Labyrinth Gate")
	box.add_child(UI.label("The labyrinth opens once a month, for 7 days.", 18, UI.ACCENT))
	box.add_child(UI.label(
		"1st floor, Crystal Cave: goblins in the north (beware their traps), ghouls in the west, "
		+ "blade wolves in the east, hidden gnomes in the south. Many areas are pitch dark.\n"
		+ "Portals to the 2nd floor: north leads to the Goblin Forest (goblin packs and archers), "
		+ "west leads to the Deadlands (ghouls and deathfiends). The first time you go through a portal, you gain a level.",
		15, UI.TEXT, true))
	box.add_child(UI.label(
		"When the 7 days are up, the labyrinth closes and you return here with your loot. "
		+ "If you die, you are dragged out but lose everything you carried.",
		15, UI.DIM, true))
	var bread := Profile.count_item(_p["inventory"], "bread")
	if bread < 8:
		box.add_child(UI.label("Warning: you only have %d rock-bread. A full belly lasts about a day, and the run lasts 7." % bread, 15, UI.BAD, true))
	var enter := UI.button("Enter the labyrinth (month %d)" % int(_p["month"]), func(): enter_labyrinth.emit())
	enter.custom_minimum_size.y = 48
	box.add_child(enter)
	box.add_child(UI.separator())
	box.add_child(UI.label(UI.CONTROLS_HELP, 14, UI.DIM, true))


func _build_character() -> void:
	var box := _page("Character")
	box.add_child(StatSheet.build(_p))


func _build_exchange() -> void:
	var box := _page("Exchange")
	box.add_child(UI.label("The adventurers' exchange buys mana stones and essences.", 15, UI.DIM, true))
	var stones: Dictionary = _p["mana_stones"]
	var total := Profile.mana_stone_value(stones)
	if stones.is_empty():
		box.add_child(UI.label("You have no mana stones.", 15))
	for m in stones:
		var d := GameData.monster(m)
		_row(box, "%s mana stone x%d" % [d["name"], int(stones[m])], "grade %d - %s stones each" % [int(d["grade"]), GameData.format_stones(int(d["stone"]))], [])
	box.add_child(UI.button("Sell all mana stones (+%s)" % GameData.format_stones(total), _sell_stones, total > 0))
	box.add_child(UI.separator())
	var vials: Array = _p["vials"]
	for i in vials.size():
		var ess := GameData.essence(vials[i])
		var idx := i
		_row(box, ess["name"] + " (in a vial)", "Grade %d essence" % int(ess["grade"]),
			[UI.button("Sell (+%s)" % GameData.format_stones(int(ess["sell"])), func(): _sell_vial(idx))])


func _sell_stones() -> void:
	var total := Profile.mana_stone_value(_p["mana_stones"])
	_p["stones"] = _stones() + total
	_p["mana_stones"] = {}
	_say("Sold mana stones for %s stones." % GameData.format_stones(total))
	_refresh()


func _sell_vial(i: int) -> void:
	var e: String = _p["vials"][i]
	var price := int(GameData.essence(e)["sell"])
	_p["vials"].remove_at(i)
	_p["stones"] = _stones() + price
	_say("Sold the %s for %s stones!" % [GameData.essence(e)["name"], GameData.format_stones(price)])
	_refresh()


func _build_market() -> void:
	var box := _page("Market")
	box.add_child(UI.label("Supplies", 18, UI.ACCENT))
	for id in CONSUMABLES:
		var it := GameData.item(id)
		var price := int(it["price"])
		var item_id: String = id
		_row(box, "%s - %s stones   (you have %d)" % [it["name"], GameData.format_stones(price), Profile.count_item(_p["inventory"], id)], it["desc"], [
			UI.button("Buy", func(): _buy(item_id, 1), _stones() >= price),
			UI.button("Buy x5", func(): _buy(item_id, 5), _stones() >= price * 5),
		])
	box.add_child(UI.separator())
	box.add_child(UI.label("Equipment (your old piece is sold back for half its price)", 18, UI.ACCENT))
	for id in EQUIPMENT:
		var it := GameData.item(id)
		var slot: String = it["type"]
		var equipped: bool = _p["equipment"][slot] == id
		var bonus := []
		var item_stats: Dictionary = it.get("stats", {})
		for k in item_stats:
			bonus.append("%s %+d" % [Stats.LABELS.get(k, k), int(item_stats[k])])
		var item_id: String = id
		var btn := UI.button("Equipped" if equipped else "Buy & equip", func(): _buy_equipment(item_id),
			not equipped and _stones() >= int(it["price"]))
		_row(box, "%s (%s) - %s stones   %s" % [it["name"], slot, GameData.format_stones(int(it["price"])), ", ".join(bonus)], it["desc"], [btn])


func _buy(id: String, n: int) -> void:
	var it := GameData.item(id)
	var cost := int(it["price"]) * n
	if _stones() < cost:
		_say("You can't afford that.", false)
		return
	if not Profile.add_item(_p["inventory"], id, n):
		_say("Your bag is full (%d different items max)." % Rules.INVENTORY_SLOTS, false)
		return
	_p["stones"] = _stones() - cost
	_say("Bought %s x%d." % [it["name"], n])
	_refresh()


func _buy_equipment(id: String) -> void:
	var it := GameData.item(id)
	var slot: String = it["type"]
	var old: String = _p["equipment"][slot]
	var refund := int(GameData.item(old)["price"]) / 2 if old != "" else 0
	_p["stones"] = _stones() - int(it["price"]) + refund
	_p["equipment"][slot] = id
	_say("You equip the %s." % it["name"] + (" (old one sold for %s)" % GameData.format_stones(refund) if refund > 0 else ""))
	_refresh()


func _build_inn() -> void:
	var box := _page("Angry Rhino Inn")
	box.add_child(UI.label("The inn where the barbarians of Rafdonia sleep, ten to a room. It smells like sweat and beer.", 15, UI.DIM, true))
	if "ainar" in _p["allies"]:
		box.add_child(UI.label("Ainar is in your party.", 18, UI.GOOD))
		box.add_child(UI.label(
			"She follows you, fights anything that comes near you, and keeps watch while you sleep in camp, "
			+ "so you wake up before the monsters reach you. She takes 20% of the mana stones from each run. "
			+ "If she falls, she is carried back to the city and rejoins you next month.",
			15, UI.TEXT, true))
	else:
		box.add_child(UI.label("Ainar Frenelin", 18, UI.ACCENT))
		box.add_child(UI.label(
			"Second daughter of Frenelin, a young barbarian swordswoman who wants to learn about the world (ch. 19-20). "
			+ "Ask her to team up: she fights at your side and is your night friend while you camp. "
			+ "In exchange she takes 20% of the mana stones (an 8/2 split, as in the novel).",
			15, UI.TEXT, true))
		box.add_child(UI.button("Ask Ainar to team up", _recruit_ainar))


func _recruit_ainar() -> void:
	_p["allies"].append("ainar")
	_say("\"Bjorn, son of Yandel! I'll follow you into the labyrinth!\" Ainar joins your party.")
	_refresh()


func _build_sanctuary() -> void:
	var box := _page("Sanctuary")
	box.add_child(UI.label("The barbarians' sanctuary, where the shaman carves spirit engravings into warriors.", 15, UI.DIM, true))
	var has: bool = "undying_1" in _p["engravings"]
	_row(box, "Undying Imprint, stage 1 - %s stones" % GameData.format_stones(Rules.UNDYING_PRICE),
		"Max HP +20% and faster regeneration (1 HP every 5 turns). The path Bjorn chose (ch. 20-21).",
		[UI.button("Engraved" if has else "Receive the engraving", _buy_undying, not has and _stones() >= Rules.UNDYING_PRICE)])
	box.add_child(UI.separator())
	box.add_child(UI.label("Essence removal (temple service, ch. 41): 10,000,000 stones each. Frees a slot.", 15, UI.DIM, true))
	var ess: Array = _p["essences"]
	for i in ess.size():
		var idx := i
		_row(box, GameData.essence(ess[i])["name"], "", [UI.button("Remove", func(): _remove_essence(idx), _stones() >= 10000000)])


func _buy_undying() -> void:
	_p["stones"] = _stones() - Rules.UNDYING_PRICE
	_p["engravings"].append("undying_1")
	_say("The shaman carves the Undying Imprint into your skin. It burns, then you feel tougher.")
	_refresh()


func _remove_essence(i: int) -> void:
	var e: String = _p["essences"][i]
	_p["essences"].remove_at(i)
	_p["stones"] = _stones() - 10000000
	_say("The %s is torn out of your soul." % GameData.essence(e)["name"])
	_refresh()
