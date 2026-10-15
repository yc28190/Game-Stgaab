class_name Hud
extends CanvasLayer
## Status panel, minimap, message log, skill list and the pop-up panels (bag, essence, help, end).

signal overlay_action(action: String, arg: String)

var run: DungeonRun
var overlay := ""

var _root: Control
var _name: Label
var _hp_bar: ProgressBar
var _belly_bar: ProgressBar
var _ally_bar: ProgressBar
var _info: Label
var _minimap: MiniMap
var _log: RichTextLabel
var _skills: Label
var _overlay_node: Control


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(320, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var box := UI.vbox(4)
	panel.add_child(box)
	_name = UI.label("", 16, UI.ACCENT)
	box.add_child(_name)
	_hp_bar = UI.bar(Color("#c94343"))
	box.add_child(_hp_bar)
	_belly_bar = UI.bar(Color("#c98a3a"))
	box.add_child(_belly_bar)
	_ally_bar = UI.bar(Color("#4f9e5a"))
	box.add_child(_ally_bar)
	_info = UI.label("", 14)
	box.add_child(_info)

	_minimap = MiniMap.new()
	_minimap.run = run
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.offset_left = -10 - run.map.width * MiniMap.PX
	_minimap.offset_right = -10
	_minimap.offset_top = 10
	_minimap.offset_bottom = 10 + run.map.height * MiniMap.PX
	_root.add_child(_minimap)

	var log_panel := PanelContainer.new()
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.anchor_right = 1.0
	log_panel.offset_left = 10
	log_panel.offset_right = -390
	log_panel.offset_top = -160
	log_panel.offset_bottom = -10
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	log_panel.add_child(_log)
	for line in run.log_lines:
		_log.append_text(line + "\n")
	run.message_logged.connect(func(t: String): _log.append_text(t + "\n"))

	var skill_panel := PanelContainer.new()
	skill_panel.anchor_left = 1.0
	skill_panel.anchor_right = 1.0
	skill_panel.anchor_top = 1.0
	skill_panel.anchor_bottom = 1.0
	skill_panel.offset_left = -380
	skill_panel.offset_right = -10
	skill_panel.offset_top = -160
	skill_panel.offset_bottom = -10
	skill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(skill_panel)
	_skills = UI.label("", 14)
	_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_panel.add_child(_skills)
	refresh()


func refresh() -> void:
	var p := run.profile
	var pl := run.player
	_name.text = "Bjorn   Lv %d   EXP %d/%d" % [int(p["level"]), int(p["exp"]), Profile.exp_to_next(int(p["level"]))]
	UI.set_bar(_hp_bar, pl.hp, pl.max_hp, "HP %d / %d" % [maxi(0, pl.hp), pl.max_hp])
	UI.set_bar(_belly_bar, run.satiety, Rules.SATIETY_MAX, "Belly %d / %d" % [ceili(run.satiety), int(Rules.SATIETY_MAX)])
	var ainar := run.ally()
	_ally_bar.visible = ainar != null
	if ainar != null:
		UI.set_bar(_ally_bar, ainar.hp, ainar.max_hp, "Ainar %d / %d" % [maxi(0, ainar.hp), ainar.max_hp])
	var lines: Array[String] = []
	lines.append(run.map.def()["name"])
	lines.append("%s   (closes in %s)" % [run.time_string(), run.time_left_string()])
	var stone_count := 0
	for m in run.mana_stones:
		stone_count += int(run.mana_stones[m])
	lines.append("Mana stones: %d  (~%s stones)" % [stone_count, GameData.format_stones(Profile.mana_stone_value(run.mana_stones))])
	var st: Array[String] = []
	if run.map.is_dark(pl.pos):
		st.append("in the dark")
	if run.torch_turns > 0:
		st.append("torch %dh" % ceili(run.torch_turns * Rules.MINUTES_PER_TURN / 60.0))
	for k in ["stealth", "poison", "immobile"]:
		if pl.status.has(k):
			st.append(k)
	if run.satiety <= 0.0:
		st.append("STARVING")
	if not st.is_empty():
		lines.append(", ".join(st))
	_info.text = "\n".join(lines)

	var sk: Array[String] = []
	var skills := run.player_skills()
	if skills.is_empty():
		sk.append("No skills yet: absorb essences to gain them.")
	for i in skills.size():
		var cd := run.skill_cooldown(skills[i])
		sk.append("[%d] %s - %s" % [i + 1, DungeonRun.SKILLS[skills[i]]["name"], "ready" if cd == 0 else "%d turns" % cd])
	sk.append("")
	sk.append("I bag   R rest   T camp   Enter portal   H help")
	_skills.text = "\n".join(sk)
	_minimap.queue_redraw()


# --- Overlays ----------------------------------------------------------------------------------

func close_overlay() -> void:
	if _overlay_node != null:
		_overlay_node.queue_free()
		_overlay_node = null
	overlay = ""


func _open(kind: String, title: String) -> VBoxContainer:
	close_overlay()
	overlay = kind
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var box := UI.vbox(8)
	panel.add_child(box)
	box.add_child(UI.label(title, 22, UI.ACCENT))
	_root.add_child(center)
	_overlay_node = center
	return box


func show_inventory() -> void:
	var box := _open("inventory", "Bag (%d / %d)" % [run.inventory.size(), Rules.INVENTORY_SLOTS])
	if run.inventory.is_empty():
		box.add_child(UI.label("Your bag is empty.", 15, UI.DIM))
	for e in run.inventory:
		var id: String = e["id"]
		var it := GameData.item(id)
		var usable: bool = it["type"] in ["food", "heal", "cure", "torch"]
		var verb: String = {"food": "Eat", "heal": "Drink", "cure": "Drink", "torch": "Light"}.get(it["type"], "")
		var text := "%s x%d" % [it["name"], int(e["count"])]
		if usable:
			box.add_child(UI.button("%s  -  %s" % [text, verb], func(): overlay_action.emit("use", id)))
		else:
			box.add_child(UI.label(text, 15, UI.DIM))
	if not run.mana_stones.is_empty():
		box.add_child(UI.separator())
		for m in run.mana_stones:
			box.add_child(UI.label("%s mana stone x%d" % [GameData.monster(m)["name"], int(run.mana_stones[m])], 14, UI.DIM))
	box.add_child(UI.button("Close (Esc)", close_overlay))


func show_essence() -> void:
	var e := GameData.essence(run.pending_essence)
	var box := _open("essence", "An essence: " + e["name"])
	var stats: Array[String] = []
	var labels := {"max_hp": "HP", "atk": "ATK", "def": "DEF"}
	for k in e.get("stats", {}):
		stats.append("%s %+d" % [labels.get(k, k), int(e["stats"][k])])
	box.add_child(UI.label("Grade %d.  Stats: %s" % [int(e["grade"]), ", ".join(stats)], 15))
	if e.get("active", "") != "":
		var s: Dictionary = DungeonRun.SKILLS[e["active"]]
		box.add_child(UI.label("Active skill - %s: %s" % [s["name"], s["desc"]], 15, UI.TEXT, true))
	if e.get("passive", "") != "":
		box.add_child(UI.label("Passive: " + DungeonRun.PASSIVES[e["passive"]], 15, UI.TEXT, true))
	box.add_child(UI.label(e.get("source", ""), 13, UI.DIM, true))
	var used := (run.profile["essences"] as Array).size()
	var slots := Profile.essence_slots(run.profile)
	box.add_child(UI.label("Essence slots used: %d / %d (one per level). Absorbing is permanent." % [used, slots], 14, UI.DIM, true))
	box.add_child(UI.button("Absorb it  [Y]", func(): overlay_action.emit("absorb", ""), used < slots))
	var vials := Profile.count_item(run.inventory, "vial")
	box.add_child(UI.button("Seal it in a vial to sell  [V]  (vials: %d)" % vials, func(): overlay_action.emit("store", ""), vials > 0))
	box.add_child(UI.button("Leave it  [N]", func(): overlay_action.emit("leave", "")))


func show_help() -> void:
	var box := _open("help", "How to play")
	box.add_child(UI.label(UI.CONTROLS_HELP, 15, UI.TEXT, true))
	box.add_child(UI.separator())
	box.add_child(UI.label(
		"Survive 7 days. Each action takes 3 minutes. Your belly empties over time: eat rock-bread or starve.\n"
		+ "Dark zones hide you from monsters, but you only see 2 tiles. A torch lights them up, for you and for them.\n"
		+ "Monsters drop mana stones (sell them in town) and, rarely, an essence. You get one essence slot per level.\n"
		+ "Camp to sleep and heal fast. Alone, you only wake when you're hit. With Ainar on watch, she wakes you.\n"
		+ "Find the portals on the edges of the floor. Going through one for the first time gives you a level.",
		14, UI.DIM, true))
	box.add_child(UI.button("Close (Esc)", close_overlay))


func show_end() -> void:
	var titles := {
		"closed": "The labyrinth closes",
		"dead": "You died",
		"starved": "You starved",
	}
	var box := _open("end", titles.get(run.end_reason, "The end"))
	var text := "A blinding light pulls you out of the labyrinth, back to Rafdonia." if run.end_reason == "closed" \
		else "Another party finds your body still breathing and drags you to the city. Everything you carried is gone."
	box.add_child(UI.label(text, 15, UI.TEXT, true))
	box.add_child(UI.button("Return to Rafdonia  [Enter]", func(): overlay_action.emit("finish", "")))
