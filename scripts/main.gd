extends Node
## Switches between the title, town, dungeon and report screens.

var _screen: Node


func _ready() -> void:
	_show_title()


func _show(node: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = node
	add_child(node)


func _show_title() -> void:
	var s := TitleScreen.new()
	s.start_game.connect(_on_start)
	_show(s)


func _on_start(continue_save: bool) -> void:
	if not continue_save or not Game.load_game() or Game.profile.get("game_over", "") != "":
		Game.new_game()
	_show_town("Welcome to Rafdonia. The labyrinth opens tonight.")


func _show_town(notice: String = "") -> void:
	var s := TownScreen.new()
	s.notice = notice
	s.enter_labyrinth.connect(_start_run)
	_show(s)


func _start_run() -> void:
	var s := DungeonScreen.new()
	s.run = DungeonRun.new(Game.profile)
	s.run_over.connect(_on_run_over)
	_show(s)


func _on_run_over(run: DungeonRun) -> void:
	var report := run.finish()
	var msgs := Profile.advance_month(Game.profile)
	Game.save_game()
	var s := ReportScreen.new()
	s.report = report
	s.month_messages = msgs
	s.done.connect(_after_report)
	_show(s)


func _after_report() -> void:
	if Game.profile.get("game_over", "") != "":
		Game.delete_save()
		_show_title()
	else:
		_show_town("You're back. Sell your loot at the Exchange and get ready for next month.")
