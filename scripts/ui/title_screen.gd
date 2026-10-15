class_name TitleScreen
extends Control

signal start_game(continue_save: bool)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = UI.theme()
	UI.full_rect_bg(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := UI.vbox(14)
	box.custom_minimum_size.x = 640
	center.add_child(box)
	var title := UI.label("DUNGEON AND STONE", 52, UI.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UI.label("A fan game of Surviving the Game as a Barbarian  -  prototype", 17, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(UI.separator())
	if Game.has_save():
		box.add_child(UI.button("Continue", func(): start_game.emit(true)))
		box.add_child(UI.button("New game (erases your save)", func(): start_game.emit(false)))
	else:
		box.add_child(UI.button("New game", func(): start_game.emit(false)))
	box.add_child(UI.separator())
	var intro := UI.label(
		"You are Bjorn, son of Yandel: a gamer who woke up as a barbarian inside Dungeon and Stone. "
		+ "The labyrinth opens once a month for 7 days. Hunt monsters, collect mana stones and essences, "
		+ "and come back alive. The yearly tax is 700,000 stones, and those who can't pay are executed.",
		15, UI.TEXT, true)
	box.add_child(intro)
	box.add_child(UI.label(UI.CONTROLS_HELP, 14, UI.DIM, true))
