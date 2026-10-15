class_name StatSheet
extends RefCounted
## Builds the detailed character sheet: every stat, where it comes from, and what it does.


## When a DungeonRun is given, HP and SP show their current values too.
static func build(p: Dictionary, run: DungeonRun = null) -> Control:
	var calc := Profile.compute_stats(p)
	var values: Dictionary = calc["values"]
	var sources: Dictionary = calc["sources"]
	var box := UI.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(UI.label("Bjorn, son of Yandel  -  Level %d barbarian" % int(p["level"]), 18, UI.ACCENT))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for header in ["Stat", "Value", "Details"]:
		grid.add_child(UI.label(header, 14, UI.DIM))
	for stat in Stats.ORDER:
		var value := int(values[stat])
		var shown := str(value)
		if run != null and stat == "max_hp":
			shown = "%d / %d" % [maxi(0, run.player.hp), value]
		elif run != null and stat == "max_sp":
			shown = "%d / %d" % [run.player.sp, value]
		grid.add_child(UI.label(Stats.LABELS[stat], 15, UI.TEXT))
		var base := int(Stats.BASE.get(stat, value))
		var color := UI.GOOD if value > base else (UI.BAD if value < base else UI.TEXT)
		grid.add_child(UI.label(shown, 15, color))
		var parts: Array[String] = []
		for src in sources[stat]:
			parts.append("%s %s" % [src[0], ("+%d" % int(src[1])) if int(src[1]) > 0 and parts.size() > 0 else str(int(src[1]))])
		if parts.is_empty():
			parts.append("Base %d" % value)
		var details := UI.label(", ".join(parts) + "\n" + Stats.EFFECTS[stat], 13, UI.DIM, true)
		details.custom_minimum_size.x = 420
		grid.add_child(details)
	return box
