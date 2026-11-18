extends Node
## Switches between the title, town, dungeon and report screens.

var _screen: Node
var _report := {}
var _month_messages: Array[String] = []


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


func _start_run(bonded: bool) -> void:
	var s := DungeonScreen.new()
	s.run = DungeonRun.new(Game.profile, -1, bonded)
	s.run_ended.connect(_on_run_ended)
	s.run_over.connect(_on_run_over)
	_show(s)


## The run's outcome is applied and saved as soon as it ends, so reloading can't undo a death.
## (Quitting in the middle of a run still abandons it, as before.)
func _on_run_ended(run: DungeonRun) -> void:
	_report = run.finish()
	_month_messages = Profile.advance_month(Game.profile)
	Game.save_game()


func _on_run_over(_run: DungeonRun) -> void:
	var s := ReportScreen.new()
	s.report = _report
	s.month_messages = _month_messages
	s.done.connect(_after_report)
	_show(s)


func _after_report() -> void:
	if Game.profile.get("game_over", "") != "":
		Game.delete_save()
		_show_title()
	else:
		_show_town("You're back. Sell your loot at the Exchange and get ready for next month.")
