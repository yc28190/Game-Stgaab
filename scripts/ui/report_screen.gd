class_name ReportScreen
extends Control
## Summary shown after a run, before going back to town.

signal done

var report: Dictionary
var month_messages: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = UI.theme()
	UI.full_rect_bg(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 620
	center.add_child(panel)
	var box := UI.vbox(8)
	panel.add_child(box)

	var titles := {
		"closed": "Back in Rafdonia",
		"dead": "You were dragged out of the labyrinth, barely alive",
		"starved": "You collapsed from hunger and were dragged out",
	}
	box.add_child(UI.label(titles.get(report["reason"], "Back in Rafdonia"), 26, UI.ACCENT, true))
	var minutes := int(report["turns"]) * Rules.MINUTES_PER_TURN
	box.add_child(UI.label("Time in the labyrinth: %d days %d hours" % [int(minutes / 1440.0), int((minutes % 1440) / 60.0)], 16))
	box.add_child(UI.label("Monsters killed: %d    EXP gained: %d    Levels gained: %d" % [int(report["kills"]), int(report["exp"]), int(report["levels"])], 16))
	for e in report["essences"]:
		box.add_child(UI.label("Essence absorbed: " + GameData.essence(e)["name"], 16, UI.GOOD))
	var stones: Dictionary = report["stones"]
	if not stones.is_empty():
		box.add_child(UI.separator())
		box.add_child(UI.label("Mana stones collected:", 16))
		for m in stones:
			box.add_child(UI.label("   %s x%d" % [GameData.monster(m)["name"], int(stones[m])], 15, UI.DIM))
		box.add_child(UI.label("   Worth about %s stones at the exchange" % GameData.format_stones(Profile.mana_stone_value(stones)), 15, UI.DIM))
	var share: Dictionary = report["ally_share"]
	if not share.is_empty():
		var n := 0
		for m in share:
			n += int(share[m])
		box.add_child(UI.label("Ainar takes her share (8/2 split): %d mana stones." % n, 15, UI.DIM))
	if report["lost"]:
		box.add_child(UI.label("Everything you carried was lost: your bag and your mana stones. Essences and levels stay with you.", 16, UI.BAD, true))
	for e in report["stored"]:
		if not report["lost"]:
			box.add_child(UI.label("Essence in a vial: " + GameData.essence(e)["name"], 16, UI.GOOD))
	box.add_child(UI.separator())
	for msg in month_messages:
		box.add_child(UI.label(msg, 15, UI.TEXT, true))
	var game_over: String = Game.profile.get("game_over", "")
	if game_over != "":
		box.add_child(UI.label("GAME OVER", 30, UI.BAD))
		box.add_child(UI.button("Start over", func(): done.emit()))
	else:
		box.add_child(UI.button("Continue to Rafdonia", func(): done.emit()))
