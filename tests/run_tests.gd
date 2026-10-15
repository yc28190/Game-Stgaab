extends SceneTree
## Headless test suite: godot --headless -s res://tests/run_tests.gd
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	test_generation()
	test_combat_and_progression()
	test_inventory()
	test_stats()
	test_simulated_runs()
	test_camp_until_closing()
	test_month_and_tax()
	await test_held_key_near_enemy()
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + what)


func test_generation() -> void:
	for floor_id in GameData.table("floors"):
		for s in 25:
			var rng := RandomNumberGenerator.new()
			rng.seed = s
			var m := DungeonGenerator.generate(floor_id, rng)
			var label := "%s seed %d" % [floor_id, s]
			check(m.rooms.size() >= 8, label + ": enough rooms (%d)" % m.rooms.size())
			check(m.portals.size() == (GameData.floor_def(floor_id)["portals"] as Array).size(), label + ": all portals placed")
			# Every floor tile must be reachable from the first room.
			var start := m.rooms[0].get_center()
			var seen := {start: true}
			var queue: Array[Vector2i] = [start]
			while not queue.is_empty():
				var p: Vector2i = queue.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if m.is_walkable(q) and not seen.has(q):
						seen[q] = true
						queue.append(q)
			var walkable := 0
			for i in m.tiles.size():
				if m.tiles[i] == FloorMap.FLOOR:
					walkable += 1
			check(seen.size() == walkable, label + ": floor fully connected")
			for p in m.portals:
				check(m.is_walkable(p), label + ": portal on floor")


func test_combat_and_progression() -> void:
	var p := Profile.create()
	var run := DungeonRun.new(p, 1)
	check(run.player.hp == run.player.max_hp, "player starts at full HP")
	var g := Actor.from_monster("goblin")
	g.pos = run.player.pos
	var hp_before := g.hp
	for i in 30:
		run._attack(run.player, g)
		if not g.alive():
			break
	check(g.hp < hp_before, "attacks deal damage")
	check(not g.alive(), "goblin dies eventually")
	var lv := Profile.add_exp(p, 1000)
	check(lv > 0 and int(p["level"]) > 1, "EXP levels up")
	check(Profile.essence_slots(p) == int(p["level"]), "one essence slot per level")
	var before := Profile.player_stats(p)
	p["essences"].append("deathfiend")
	var after := Profile.player_stats(p)
	check(int(after["max_hp"]) == int(before["max_hp"]) + 15, "essence stats apply")
	check("call_of_the_dead" in Profile.active_skills(p), "essence grants active skill")


func test_inventory() -> void:
	var inv: Array = []
	check(Profile.add_item(inv, "bread", 3), "add item")
	check(Profile.count_item(inv, "bread") == 3, "count item")
	check(Profile.remove_item(inv, "bread", 2), "remove item")
	check(Profile.count_item(inv, "bread") == 1, "count after remove")
	check(not Profile.remove_item(inv, "bread", 5), "can't remove more than owned")


## A simple bot plays several runs: it fights what it sees, eats when hungry, and explores.
func test_simulated_runs() -> void:
	for s in 6:
		var p := Profile.create()
		if s % 2 == 0:
			p["allies"].append("ainar")
		var run := DungeonRun.new(p, 100 + s)
		var guard := 0
		while not run.over and guard < 4000:
			guard += 1
			if run.pending_essence != "":
				if not run.absorb_essence():
					run.leave_essence()
				continue
			if run.satiety < 30 and Profile.count_item(run.inventory, "bread") > 0:
				run.use_item("bread")
				continue
			if run.player.hp < run.player.max_hp / 3 and Profile.count_item(run.inventory, "potion") > 0:
				run.use_item("potion")
				continue
			if run.map.portals.has(run.player.pos) and run.rng.randf() < 0.5:
				run.use_portal()
				continue
			var target := _nearest_monster(run)
			var goal: Vector2i = target.pos if target != null else run.map.random_floor_tile(run.rng)
			var path := run.map.astar.get_id_path(run.player.pos, goal)
			var moved := false
			if path.size() >= 2:
				moved = run.try_move(path[1] - run.player.pos)
			if not moved:
				run.wait_turn()
		check(run.turn > 0, "run %d advanced" % s)
		check(run.player.hp <= run.player.max_hp, "run %d hp within bounds" % s)
		for a in run.actors:
			check(run.map.is_walkable(a.pos), "run %d: %s stands on floor" % [s, a.name])
		var positions := {}
		for a in run.actors:
			check(not positions.has(a.pos), "run %d: no two actors share a tile" % s)
			positions[a.pos] = true
		var report := run.finish()
		check(int(p["runs"]) == 1, "run %d recorded" % s)
		print("sim run %d: turns=%d kills=%d level=%d reason=%s floor=%s" % [s, run.turn, run.kills, int(p["level"]), report["reason"], run.map.floor_id])


func _nearest_monster(run: DungeonRun) -> Actor:
	var best: Actor = null
	var bd := 999
	for a in run.actors:
		if a.faction == Actor.MONSTER and run.is_visible_to_player(a):
			var d := DungeonRun.cheb(a.pos, run.player.pos)
			if d < bd:
				bd = d
				best = a
	return best


## Camping over and over must eventually hit the 7-day closing time.
func test_camp_until_closing() -> void:
	var p := Profile.create()
	p["allies"].append("ainar")
	p["inventory"] = [{"id": "bread", "count": 99}]
	var run := DungeonRun.new(p, 7)
	run.player.max_hp = 100000
	run.player.hp = 100000
	var guard := 0
	while not run.over and guard < 20000:
		guard += 1
		if run.satiety < 50:
			run.use_item("bread")
		elif run.camp() == 0:
			run.wait_turn()
	check(run.over, "run ends")
	check(run.end_reason == "closed", "labyrinth closes after 7 days (got '%s')" % run.end_reason)
	check(run.turn == Rules.TURNS_PER_RUN, "closing happens exactly at turn %d (got %d)" % [Rules.TURNS_PER_RUN, run.turn])
	run.mana_stones = {"goblin": 10}
	var report := run.finish()
	check(int(p["mana_stones"]["goblin"]) == 8, "Ainar takes her 20% share")
	check(int(report["ally_share"]["goblin"]) == 2, "share reported")


func test_month_and_tax() -> void:
	var p := Profile.create()
	p["stones"] = 2000000
	for i in Rules.MONTHS_PER_YEAR:
		Profile.advance_month(p)
	check(int(p["year"]) == 2 and int(p["month"]) == 1, "a year passes after 12 runs")
	check(int(p["stones"]) == 2000000 - 12 * Rules.MONTHLY_LIVING_COST - Rules.ANNUAL_TAX, "costs and tax paid")
	var poor := Profile.create()
	for i in Rules.MONTHS_PER_YEAR:
		Profile.advance_month(poor)
	check(poor["game_over"] == "tax", "unpaid tax ends the game")


func _key(code: int, echo: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	return e


## Holding a direction must not repeat attacks or moves while a monster is close.
func test_held_key_near_enemy() -> void:
	var p := Profile.create()
	var screen := DungeonScreen.new()
	screen.run = DungeonRun.new(p, 3)
	root.add_child(screen)
	await process_frame
	var run := screen.run
	# Clear the floor, then put a goblin right next to the player in a free direction.
	for a in run.actors.duplicate():
		if a.faction == Actor.MONSTER:
			run.actors.erase(a)
	var dir := Vector2i.ZERO
	for d in DungeonRun.DIRS8:
		if run.can_step(run.player.pos, run.player.pos + d):
			dir = d
			break
	var g := Actor.from_monster("goblin")
	g.status.erase("hidden")
	g.max_hp = 1000
	g.hp = 1000
	g.pos = run.player.pos + dir
	run.actors.append(g)
	run._update_fov()
	var key: int = {Vector2i(0, -1): KEY_UP, Vector2i(0, 1): KEY_DOWN, Vector2i(-1, 0): KEY_LEFT, Vector2i(1, 0): KEY_RIGHT,
		Vector2i(-1, -1): KEY_KP_7, Vector2i(1, -1): KEY_KP_9, Vector2i(-1, 1): KEY_KP_1, Vector2i(1, 1): KEY_KP_3}[dir]
	var t0 := run.turn
	screen._unhandled_input(_key(key, false))
	check(run.turn == t0 + 1, "a fresh key press attacks the adjacent monster")
	for i in 5:
		screen._unhandled_input(_key(key, true))
	check(run.turn == t0 + 1, "held key (echo) is ignored next to a monster (turn %d)" % run.turn)
	screen._unhandled_input(_key(key, false))
	check(run.turn == t0 + 2, "pressing again attacks again")
	# Far from any monster, holding a key keeps walking.
	run.actors.erase(g)
	run._update_fov()
	var t1 := run.turn
	screen._unhandled_input(_key(KEY_KP_5, false))
	for i in 3:
		screen._unhandled_input(_key(KEY_KP_5, true))
	check(run.turn == t1 + 4, "held key repeats when no monster is near (turn %d)" % (run.turn - t1))
	screen.queue_free()


func test_stats() -> void:
	var p := Profile.create()
	var s := Profile.player_stats(p)
	# Level 1 Bjorn must match the original prototype numbers (difficulty unchanged).
	check(int(s["max_hp"]) == 50, "level 1 HP is 50")
	check(int(s["atk"]) == 7, "level 1 attack is 7 (Strength 12 / 2 + club 1), got %d" % int(s["atk"]))
	check(int(s["phys_res"]) == 2, "level 1 physical resistance is 2 (base + shield)")
	check(int(s["max_sp"]) == 20, "level 1 SP is 20")
	for k in Stats.ORDER:
		check(s.has(k), "stat %s computed" % k)
	var src := Profile.stat_sources(p)
	var total := 0
	for e in src["strength"]:
		total += int(e[1])
	check(total == int(s["strength"]), "strength breakdown adds up")

	p["essences"].append("goblin_archer")
	var s2 := Profile.player_stats(p)
	check(int(s2["perception"]) == int(s["perception"]) + 4, "essence perception applies")
	check(int(s2["poison_res"]) == 4, "essence poison resistance applies")

	check(Stats.hunger_per_turn(20) > Stats.hunger_per_turn(10), "higher appetite empties the belly faster")
	check(Stats.energy_per_player_action(100, 200) == 50, "a faster player gives monsters fewer actions")
	check(Stats.hit_chance(20, 10) > Stats.hit_chance(10, 10), "agility improves hit chance")
	check(Stats.trap_spot_chance(20) > Stats.trap_spot_chance(10), "perception improves trap spotting")

	# Threat: with Bjorn and Ainar at the same distance, a monster goes for Bjorn.
	var q := Profile.create()
	q["allies"].append("ainar")
	var run := DungeonRun.new(q, 11)
	for a in run.actors.duplicate():
		if a.faction == Actor.MONSTER:
			run.actors.erase(a)
	var ainar := run.ally()
	var g := Actor.from_monster("goblin")
	g.pos = run.player.pos
	var placed := false
	for d in DungeonRun.DIRS8:
		var spot := run.player.pos + d * 2
		if run.map.is_walkable(spot) and run.los(spot, run.player.pos) and run.los(spot, ainar.pos) \
				and DungeonRun.cheb(spot, ainar.pos) == 2:
			g.pos = spot
			placed = true
			break
	check(placed, "threat test found a spot for the goblin")
	if placed:
		run.actors.append(g)
		check(run._find_target(g) == run.player, "monsters prefer the high-threat barbarian")

	# SP is spent by skills.
	var r := Profile.create()
	r["level"] = 3
	r["essences"].append("goblin_archer")
	var run2 := DungeonRun.new(r, 12)
	var sp0 := run2.player.sp
	check(run2.use_skill("thief_step"), "skill usable with enough SP")
	check(run2.player.sp == sp0 - 10, "Thief Step costs 10 SP")
	run2.player.cooldowns.clear()
	run2.player.sp = 3
	check(not run2.use_skill("thief_step"), "skill refused without enough SP")
