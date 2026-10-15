class_name DungeonScreen
extends Node
## Hooks keyboard and mouse input to the DungeonRun and keeps the view and HUD in sync.

signal run_over(run: DungeonRun)

const AUTO_STEP_SECONDS := 0.06
## Holding a key repeats moves, except when a monster is this close: then every step or attack
## needs its own key press, so you can't walk into a fight by accident.
const DANGER_RANGE := 2

var run: DungeonRun
var view: DungeonView
var hud: Hud
var _auto_path: Array[Vector2i] = []
var _auto_timer := 0.0
## Set when a monster shows up while a key is held: repeats stay off until the key is pressed again.
var _hold_stopped := false


func _ready() -> void:
	view = DungeonView.new()
	view.run = run
	add_child(view)
	hud = Hud.new()
	hud.run = run
	add_child(hud)
	hud.overlay_action.connect(_on_overlay_action)
	_after_action()


func _process(delta: float) -> void:
	if _auto_path.is_empty():
		return
	_auto_timer -= delta
	if _auto_timer > 0.0:
		return
	_auto_timer = AUTO_STEP_SECONDS
	var nxt: Vector2i = _auto_path.pop_front()
	var hp_before := run.player.hp
	if not run.try_move(nxt - run.player.pos) or run.hostile_in_view() or run.player.hp < hp_before:
		_auto_path.clear()
	_after_action()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hud.overlay == "":
			_click_tile(view.tile_at_mouse())
		return
	if not (event is InputEventKey and event.pressed):
		return
	var key: int = event.physical_keycode
	if event.echo:
		if _hold_stopped or hud.overlay != "" or _danger_near():
			get_viewport().set_input_as_handled()
			return
	else:
		_hold_stopped = false
	_auto_path.clear()
	match hud.overlay:
		"end":
			if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_finish()
			return
		"essence":
			match key:
				KEY_Y:
					_on_overlay_action("absorb", "")
				KEY_V:
					_on_overlay_action("store", "")
				KEY_N, KEY_ESCAPE:
					_on_overlay_action("leave", "")
			return
		"inventory", "help":
			if key in [KEY_ESCAPE, KEY_I, KEY_H, KEY_F1]:
				hud.close_overlay()
			return

	var seen_before := _visible_hostiles()
	var dir := _dir_for(key)
	if dir != Vector2i.ZERO:
		run.try_move(dir)
	else:
		match key:
			KEY_SPACE, KEY_PERIOD, KEY_KP_5:
				run.wait_turn()
			KEY_ENTER, KEY_KP_ENTER:
				if not run.use_portal():
					run.say("There is no portal here.")
			KEY_I:
				hud.show_inventory()
			KEY_H, KEY_F1:
				hud.show_help()
			KEY_R:
				run.rest()
			KEY_T:
				run.camp()
			KEY_1, KEY_2, KEY_3, KEY_4:
				var skills := run.player_skills()
				var i := key - KEY_1
				if i < skills.size():
					run.use_skill(skills[i])
			_:
				return
	if event.echo and _visible_hostiles() > seen_before:
		_hold_stopped = true
		run.say("A monster appears! You stop.")
	get_viewport().set_input_as_handled()
	_after_action()


func _visible_hostiles() -> int:
	var n := 0
	for a in run.actors:
		if a.faction == Actor.MONSTER and run.is_visible_to_player(a):
			n += 1
	return n


func _danger_near() -> bool:
	for a in run.actors:
		if a.faction == Actor.MONSTER and run.is_visible_to_player(a) \
				and DungeonRun.cheb(a.pos, run.player.pos) <= DANGER_RANGE:
			return true
	return false


func _dir_for(key: int) -> Vector2i:
	match key:
		KEY_UP, KEY_W, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_KP_6:
			return Vector2i(1, 0)
		KEY_Q, KEY_KP_7:
			return Vector2i(-1, -1)
		KEY_E, KEY_KP_9:
			return Vector2i(1, -1)
		KEY_Z, KEY_KP_1:
			return Vector2i(-1, 1)
		KEY_C, KEY_KP_3:
			return Vector2i(1, 1)
	return Vector2i.ZERO


func _click_tile(t: Vector2i) -> void:
	if run.over or not run.map.in_bounds(t):
		return
	if DungeonRun.cheb(t, run.player.pos) == 1:
		run.try_move(t - run.player.pos)
		_after_action()
		return
	if t == run.player.pos or run.map.explored[run.map.idx(t)] == 0 or not run.map.is_walkable(t):
		return
	var path := run.map.astar.get_id_path(run.player.pos, t)
	_auto_path.clear()
	for i in range(1, path.size()):
		_auto_path.append(path[i])
	_auto_timer = 0.0


func _on_overlay_action(action: String, arg: String) -> void:
	match action:
		"use":
			hud.close_overlay()
			run.use_item(arg)
		"absorb":
			if run.absorb_essence():
				hud.close_overlay()
		"store":
			if run.store_essence():
				hud.close_overlay()
		"leave":
			run.leave_essence()
			hud.close_overlay()
		"finish":
			_finish()
			return
	_after_action()


func _after_action() -> void:
	view.refresh()
	hud.refresh()
	if run.over:
		_auto_path.clear()
		if hud.overlay != "end":
			hud.show_end()
	elif run.pending_essence != "" and hud.overlay != "essence":
		_auto_path.clear()
		hud.show_essence()


func _finish() -> void:
	set_process_unhandled_input(false)
	run_over.emit(run)
