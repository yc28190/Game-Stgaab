extends SceneTree
## Headless test suite: godot --headless -s res://tests/run_tests.gd
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	test_generation()
	test_inventory()
	test_stats()
	test_exp_and_levels()
	test_essences()
	test_combat_time_and_closing()
	test_countdown()
	test_potion_pain()
	test_ainar()
	test_monster_behaviour()
	test_steles()
	test_month_and_tax()
	test_migration()
	test_simulated_runs()
	await test_held_key_near_enemy()
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + what)


## A run on the 1st floor with every monster removed, so tests can stage fights.
func _quiet_run(p: Dictionary, seed_value: int, bonded := true) -> DungeonRun:
	var run := DungeonRun.new(p, seed_value, bonded)
	for a in run.actors.duplicate():
		if a.faction == Actor.MONSTER:
			run.actors.erase(a)
	run._next_respawn[run.map.floor_id] = 1 << 40
	run._update_fov()
	return run


func _free_dir(run: DungeonRun) -> Vector2i:
	for d in DungeonRun.DIRS8:
		if run.can_step(run.player.pos, run.player.pos + d) and run.actor_at(run.player.pos + d) == null:
			return d
	return Vector2i.ZERO


func _place(run: DungeonRun, monster_id: String, at: Vector2i) -> Actor:
	var m := Actor.from_monster(monster_id)
	m.status.erase("hidden")
	m.pos = at
	m.home = at
	run.actors.append(m)
	run._update_fov()
	return m


func test_generation() -> void:
	for floor_id in GameData.table("floors"):
		for s in 20:
			var rng := RandomNumberGenerator.new()
			rng.seed = s
			var m := DungeonGenerator.generate(floor_id, rng)
			var label := "%s seed %d" % [floor_id, s]
			check(m.rooms.size() >= 8, label + ": enough rooms (%d)" % m.rooms.size())
			check(m.portals.size() == (GameData.floor_def(floor_id)["portals"] as Array).size(), label + ": all portals placed")
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
			if floor_id == "crystal_cave":
				# Crystals light the 1st floor except the outer area and the central dark zone (ch. 4, 27).
				var lit_rooms := 0
				for i in m.rooms.size():
					var c := m.rooms[i].get_center()
					var should_be_dark := DungeonGenerator.is_outer(m, c) or m.room_regions[i] == "C"
					check(m.is_dark(c) == should_be_dark, label + ": room %d darkness follows outer/centre rule" % i)
					if not m.is_dark(c):
						lit_rooms += 1
				check(lit_rooms > 0, label + ": some rooms are lit by crystals")
	var dests := []
	for pd in GameData.floor_def("crystal_cave")["portals"]:
		dests.append("%s:%s" % [pd["region"], pd["to"]])
	check(dests == ["N:goblin_forest", "E:beast_den", "W:land_of_the_dead", "S:rock_desert"], "1F has the four novel portals (got %s)" % [dests])


func test_inventory() -> void:
	var inv: Array = []
	check(Profile.add_item(inv, "bread", 3), "add item")
	check(Profile.count_item(inv, "bread") == 3, "count item")
	check(Profile.remove_item(inv, "bread", 2), "remove item")
	check(Profile.count_item(inv, "bread") == 1, "count after remove")
	check(not Profile.remove_item(inv, "bread", 5), "can't remove more than owned")


func test_stats() -> void:
	var p := Profile.create()
	var s := Profile.player_stats(p)
	check(int(s["max_hp"]) == 50, "level 1 HP is 50")
	check(int(s["atk"]) == 7, "level 1 attack is 7 (Strength 12 / 2 + club 1), got %d" % int(s["atk"]))
	check(int(s["max_sp"]) == 20, "level 1 SP is 20")
	check(int(s["mental"]) == 35, "base Mental Power 35 (ch. 2)")
	for k in Stats.ORDER:
		check(s.has(k), "stat %s computed" % k)
	# Levels give Soul Power only (ch. 22), not HP or Strength.
	p["level"] = 4
	var s4 := Profile.player_stats(p)
	check(int(s4["max_hp"]) == 50 and int(s4["strength"]) == 12, "levels don't raise HP or Strength")
	check(int(s4["max_sp"]) == 50, "level 4 = +30 Soul Power (got %d)" % int(s4["max_sp"]))
	check(Stats.soul_power_from_levels(6) == 70, "+10 per level to 5, +30 at level 6")
	# Undying stage 1: regeneration and physical stats, not +20% HP (ch. 21).
	p["engravings"].append("undying_1")
	var su := Profile.player_stats(p)
	check(int(su["max_hp"]) == 50, "Undying doesn't add HP")
	check(int(su["regen"]) > int(s4["regen"]) and int(su["strength"]) > int(s4["strength"]), "Undying raises regeneration and Strength")
	check(Stats.potion_pain_turns(0) == 4 and Stats.potion_pain_turns(45) == 2 and Stats.potion_pain_turns(100) == 0, "potion pain turns")


func test_exp_and_levels() -> void:
	var p := Profile.create()
	check(Profile.record_kill(p, "goblin", 9) == 1, "first goblin gives 1 EXP (rank 9)")
	check(Profile.record_kill(p, "goblin", 9) == 0, "second goblin gives nothing (ch. 22)")
	check(Profile.record_kill(p, "deathfiend", 8) == 2, "rank 8 gives 2 EXP (ch. 23)")
	check(Profile.level_for_exp(5) == 1 and Profile.level_for_exp(6) == 2, "level 2 at 6 EXP")
	check(Profile.level_for_exp(30) == 3 and Profile.level_for_exp(150) == 4, "levels 3 and 4 at 30 and 150")
	check(Profile.level_for_exp(100000) == 4, "levels are capped at 4 for now")
	# In a run, a level up doesn't heal (ch. 35).
	var run := _quiet_run(Profile.create(), 1)
	run.player.hp = 20
	run._gain_exp(6)
	check(int(run.profile["level"]) == 2, "run level up")
	check(run.player.hp == 20, "level up doesn't refill HP (hp %d)" % run.player.hp)
	check(run.player.max_sp == 30, "level 2 gives +10 Soul Power")
	# Killing a known species gives nothing; party kills are shared.
	var q := Profile.create()
	q["allies"].append("ainar")
	var run2 := _quiet_run(q, 2)
	var g := _place(run2, "goblin", run2.player.pos + _free_dir(run2))
	run2._hurt(g, 999, run2.ally(), "dead")
	check(int(q["exp"]) == 1, "Ainar's kill gives Bjorn the species EXP")
	check("goblin" in q["companions"]["ainar"]["bestiary"], "Ainar learns the species too")
	var g2 := _place(run2, "goblin", run2.player.pos + _free_dir(run2))
	run2._hurt(g2, 999, run2.player, "dead")
	check(int(q["exp"]) == 1, "a second goblin gives no EXP")


func test_essences() -> void:
	var p := Profile.create()
	p["level"] = 2
	var run := _quiet_run(p, 3)
	run.map.add_ground(run.player.pos, {"kind": "essence", "id": "goblin", "color": "green", "dropped_at": run.seconds})
	check(run.absorb_essence(), "absorb an essence")
	run.map.add_ground(run.player.pos, {"kind": "essence", "id": "goblin", "color": "green", "dropped_at": run.seconds})
	check(not run.absorb_essence(), "can't absorb the same essence twice (ch. 622)")
	check(Profile.can_absorb(p, "goblin") != "", "duplicate is refused by the rules")
	# Fading after about 30 minutes.
	var here := run.player.pos
	run.map.ground.erase(here)
	run.map.add_ground(here, {"kind": "essence", "id": "gnome", "color": "brown", "dropped_at": run.seconds})
	for _i in 11:
		run.wait_turn()
	check(not run.map.ground.has(here), "an unabsorbed essence fades after 30 minutes")
	# Colour decides the active skill.
	check(GameData.essence_active("goblin_archer", "white") == "thief_step", "colour maps to the active skill")
	check(float(GameData.monster("goblin")["essence_chance"]) == 0.005, "essence drop chance is 0.5%")
	# Postpone and reopen.
	run.map.add_ground(here, {"kind": "essence", "id": "gnome", "color": "brown", "dropped_at": run.seconds})
	run.pending_essence = "gnome"
	run.postpone_essence()
	check(run.pending_essence == "" and not run.essence_here().is_empty(), "postponed essence stays on the ground")
	check(run.reopen_essence() and run.pending_essence == "gnome", "essence can be reopened")


func test_combat_time_and_closing() -> void:
	var run := _quiet_run(Profile.create(), 4)
	var t0 := run.seconds
	run.wait_turn()
	check(run.seconds - t0 == Rules.EXPLORE_SECONDS, "exploring turn = 3 minutes")
	_place(run, "goblin", run.player.pos + _free_dir(run))
	t0 = run.seconds
	run.wait_turn()
	check(run.seconds - t0 == Rules.COMBAT_SECONDS, "combat turn = 6 seconds")
	# On the 2nd floor, the 1st floor's closing doesn't eject you; Day 10 does.
	var p := Profile.create()
	p["inventory"] = [{"id": "bread", "count": 99}]
	var run2 := _quiet_run(p, 5)
	run2._enter_floor("goblin_forest", "crystal_cave")
	for a in run2.actors.duplicate():
		if a.faction == Actor.MONSTER:
			run2.actors.erase(a)
	run2._next_respawn["goblin_forest"] = 1 << 40
	run2.player.max_hp = 100000
	run2.player.hp = 100000
	run2.seconds = 7 * Rules.DAY_SECONDS - 10
	run2.wait_turn()
	check(not run2.over, "1F closing doesn't end the run on the 2nd floor")
	check("crystal_cave" in run2.closed_floors, "1F is closed")
	var back := Vector2i(-1, -1)
	for pp in run2.map.portals:
		back = pp
	run2.player.pos = back
	check(not run2.use_portal(), "the way back to the closed 1st floor is gone")
	run2.seconds = 10 * Rules.DAY_SECONDS - 10
	run2.wait_turn()
	check(run2.over and run2.end_reason == "closed", "2nd floor closes at the end of Day 10")
	var run3 := _quiet_run(Profile.create(), 6)
	run3.player.max_hp = 100000
	run3.player.hp = 100000
	run3.seconds = 7 * Rules.DAY_SECONDS - 10
	run3.wait_turn()
	check(run3.over and run3.end_reason == "closed", "1st floor closes at the end of Day 7")


func test_countdown() -> void:
	var run := _quiet_run(Profile.create(), 7)
	run._hurt(run.player, 999, null, "dead")
	check(run.player.in_countdown and not run.over, "0 HP starts the countdown")
	var m0 := run.player.mental
	run.wait_turn()
	check(is_equal_approx(m0 - run.player.mental, 18.0), "countdown burns 18 Mental Power per 6-second turn (got %.1f)" % (m0 - run.player.mental))
	var guard := 0
	while not run.over and guard < 20:
		guard += 1
		run.wait_turn()
	check(run.over and run.end_reason == "dead", "without help, the countdown ends in death")
	# A potion during the countdown brings you back above 1%.
	var p := Profile.create()
	var run2 := _quiet_run(p, 8)
	run2._hurt(run2.player, 999, null, "dead")
	run2.use_item("potion")
	check(not run2.player.in_countdown and run2.player.hp > 0 and not run2.over, "healing ends the countdown")
	check("survive_countdown" in p["achievements"] and int(p["mental_bonus"]) >= 10, "surviving gives Mental Power +10 (ch. 35)")
	# Strong regeneration (Undying) can pull you through on its own.
	var q := Profile.create()
	q["engravings"].append("undying_1")
	var run3 := _quiet_run(q, 9)
	run3._hurt(run3.player, 999, null, "dead")
	for _i in 3:
		if run3.over or not run3.player.in_countdown:
			break
		run3.wait_turn()
	check(not run3.over and run3.player.hp > 0, "Undying regeneration survives the countdown")


func test_potion_pain() -> void:
	var run := _quiet_run(Profile.create(), 10)
	run.player.hp = 10
	var t0 := run.turn
	run.use_item("potion")
	check(run.turn - t0 == 1 + Rules.POTION_PAIN_TURNS, "a potion costs 4 turns of pain (got %d)" % (run.turn - t0 - 1))
	check(run.player.hp > 10, "the potion healed")


func test_ainar() -> void:
	var p := Profile.create()
	p["allies"].append("ainar")
	p["inventory"] = [{"id": "bread", "count": 20}]
	var run := _quiet_run(p, 11)
	var a := run.ally()
	check(a != null and a.threat == 12, "Ainar has a barbarian's threat")
	check(DungeonRun.cheb(a.pos, run.player.pos) <= 2, "bonded: Ainar starts next to you")
	a.satiety = 20.0
	run.wait_turn()
	check(a.satiety > 20.0 and Profile.count_item(run.inventory, "bread") == 19, "Ainar eats from your bag")
	# Permanent death.
	run._hurt(a, 999, null, "dead")
	check(a.in_countdown, "Ainar gets a countdown too")
	var guard := 0
	while a.in_countdown and guard < 20:
		guard += 1
		run.wait_turn()
	check(run.ally() == null and run.ally_died, "Ainar dies when her countdown runs out")
	run._end("closed")
	run.finish()
	check(not "ainar" in p["allies"] and not p["companions"]["ainar"]["alive"], "her death is permanent")
	check("first_companion_death" in p["achievements"], "first companion death achievement")
	# Without bonding she starts elsewhere.
	var far := 0
	for s in 6:
		var q := Profile.create()
		q["allies"].append("ainar")
		var r := DungeonRun.new(q, 100 + s, false)
		if DungeonRun.cheb(r.ally().pos, r.player.pos) > 3:
			far += 1
	check(far >= 4, "without bonding Ainar usually starts away from you (%d/6)" % far)


func test_monster_behaviour() -> void:
	# Ghouls wait motionless until someone comes close (ch. 11).
	var run := _quiet_run(Profile.create(), 12)
	var spot := Vector2i(-1, -1)
	for r in run.map.rooms:
		var c := r.get_center()
		if DungeonRun.cheb(c, run.player.pos) in range(5, 7) and run.los(c, run.player.pos) and not run.map.is_dark(c):
			spot = c
	if spot != Vector2i(-1, -1):
		var g := _place(run, "ghoul", spot)
		run.wait_turn()
		check(g.pos == spot, "an ambushing ghoul doesn't move when you're 5+ tiles away")
	# Deathfiends summon ghouls when hurt (ch. 24): 10 of them.
	var run2 := _quiet_run(Profile.create(), 13)
	var df := _place(run2, "deathfiend", run2.player.pos + _free_dir(run2))
	var before := run2.actors.size()
	run2._hurt(df, 35, run2.player, "dead")
	check(run2.actors.size() - before == 10, "deathfiend summons 10 ghouls below half HP (got %d)" % (run2.actors.size() - before))
	run2._hurt(df, 5, run2.player, "dead")
	check(run2.actors.size() - before == 10, "only once")
	# Suppression is broken by damage and resisted by Magic Resistance.
	var run3 := _quiet_run(Profile.create(), 14)
	run3.player.status["paralyzed"] = 5
	run3._hurt(run3.player, 1, null, "dead")
	check(not run3.player.status.has("paralyzed"), "damage breaks paralysis")
	run3.player.magic_res = 1000
	var golem := _place(run3, "stone_golem", run3.player.pos + _free_dir(run3))
	var stuck := 0
	for _i in 100:
		run3.player.status.erase("paralyzed")
		run3._try_suppress(golem, run3.player)
		if run3.player.status.has("paralyzed"):
			stuck += 1
	check(stuck < 25, "high Magic Resistance resists Suppression most of the time (%d/100)" % stuck)
	run3.player.magic_res = 0
	run3.player.status.erase("paralyzed")
	run3._try_suppress(golem, run3.player)
	check(run3.player.status.has("paralyzed"), "without Magic Resistance Suppression lands")
	# Mutants.
	var mu := Actor.from_monster("goblin", true)
	check(mu.mutant and mu.max_hp > int(GameData.monster("goblin")["hp"]), "mutants are stronger")


func test_steles() -> void:
	var p := Profile.create()
	var run := _quiet_run(p, 15)
	var portal := Vector2i(-1, -1)
	for pp in run.map.portals:
		portal = pp
	run.map.stele_rival_time[portal] = 1 << 40
	run._touch_stele(portal)
	check(int(p["exp"]) == Rules.STELE_EXP, "first opener of a stele gets 2 EXP")
	var p2 := Profile.create()
	var run2 := _quiet_run(p2, 16)
	for pp in run2.map.portals:
		run2.map.stele_rival_time[pp] = 0
		run2._touch_stele(pp)
	check(int(p2["exp"]) == 0, "no EXP once a rival opened it")


func test_month_and_tax() -> void:
	var p := Profile.create()
	p["stones"] = 5000000
	for i in Rules.MONTHS_PER_YEAR:
		Profile.advance_month(p)
	check(int(p["year"]) == 2 and int(p["month"]) == 1, "a year passes after 12 runs")
	var living := 11 * 30 * Rules.LIVING_COST_PER_DAY + 35 * Rules.LIVING_COST_PER_DAY
	check(int(p["stones"]) == 5000000 - living - 700000, "living costs (last cycle 35 days) and 700k first-year tax")
	check(Profile.annual_tax(p) == 800000, "second-year tax is 800k (ch. 18)")
	check(is_equal_approx(Profile.exchange_fee(p), 0.1), "exchange fee from the second year")
	p["year"] = 3
	check(Profile.annual_tax(p) == 900000, "tax keeps rising by 100k")
	var poor := Profile.create()
	poor["stones"] = 1000
	Profile.advance_month(poor)
	check(int(poor["stones"]) == 0 and poor["slept_rough"], "can't pay the inn: sleep rough, never negative")
	var run := DungeonRun.new(poor, 17)
	check(run.satiety == Rules.ROUGH_SLEEP_BELLY and run.player.hp < run.player.max_hp, "sleeping rough weakens the next run")
	var broke := Profile.create()
	broke["stones"] = 0
	for i in Rules.MONTHS_PER_YEAR:
		Profile.advance_month(broke)
	check(broke["game_over"] == "tax", "unpaid tax ends the game")


func test_migration() -> void:
	var old := {"version": 1, "level": 6, "exp": 40, "essences": ["goblin", "goblin"], "allies": ["ainar"],
		"portals_opened": ["goblin_forest"], "stones": 1234}
	var p := Profile.migrate(old)
	check(int(p["version"]) == Profile.VERSION, "migrated version")
	check(int(p["level"]) == 4, "old level capped at 4")
	check((p["essences"] as Array).count("goblin") == 1, "duplicate essences removed")
	check(p["companions"].has("ainar"), "Ainar gets her own record")
	check(int(p["stones"]) == 1234, "money kept")


## A simple bot plays several runs: it fights what it sees, eats when hungry, and explores.
func test_simulated_runs() -> void:
	for s in 6:
		var p := Profile.create()
		p["inventory"] = [{"id": "bread", "count": 30}, {"id": "potion", "count": 2}]
		if s % 2 == 0:
			p["allies"].append("ainar")
		var run := DungeonRun.new(p, 300 + s)
		var guard := 0
		while not run.over and guard < 6000:
			guard += 1
			if run.pending_essence != "":
				if not run.absorb_essence():
					run.postpone_essence()
				continue
			if run.satiety < 30 and Profile.count_item(run.inventory, "bread") > 0:
				run.use_item("bread")
				continue
			if not run.in_combat() and run.player.hp < run.player.max_hp / 3 and Profile.count_item(run.inventory, "potion") > 0:
				run.use_item("potion")
				continue
			if not run.in_combat() and run.player.hp < run.player.max_hp / 2:
				if run.rest() > 0:
					continue
			if run.map.portals.has(run.player.pos) and run.rng.randf() < 0.3:
				if run.use_portal():
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
		for a in run.actors:
			check(run.map.is_walkable(a.pos), "run %d: %s stands on floor" % [s, a.name])
		var positions := {}
		for a in run.actors:
			check(not positions.has(a.pos), "run %d: no two actors share a tile" % s)
			positions[a.pos] = true
		var report := run.finish()
		print("sim run %d: day %d, kills=%d exp=%d level=%d stones=%s reason=%s floor=%s" % [
			s, run.day(), run.kills, int(p["exp"]), int(p["level"]),
			GameData.format_stones(Profile.mana_stone_value(report["stones"])), report["reason"], run.map.floor_id])


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
	screen.run = _quiet_run(p, 3)
	root.add_child(screen)
	await process_frame
	var run := screen.run
	var dir := _free_dir(run)
	var g := _place(run, "goblin", run.player.pos + dir)
	g.max_hp = 1000
	g.hp = 1000
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
	run.actors.erase(g)
	run._update_fov()
	var t1 := run.turn
	screen._unhandled_input(_key(KEY_KP_5, false))
	for i in 3:
		screen._unhandled_input(_key(KEY_KP_5, true))
	check(run.turn == t1 + 4, "held key repeats when no monster is near (turn %d)" % (run.turn - t1))
	screen.queue_free()
