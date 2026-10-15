class_name DungeonRun
extends RefCounted
## One trip into the labyrinth. This is the turn engine: it holds no rendering code, so it can be
## driven by the UI or by the headless tests.
##
## Each player action calls _end_turn(), which advances time (3 minutes per turn), hunger,
## statuses, then lets every other actor act according to its speed.

signal message_logged(text: String)

const DIRS8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const NOWHERE := Vector2i(-1, -1)
const START_FLOOR := "crystal_cave"
const TRACKER_NOSE_RANGE := 12

const SKILLS := {
	"thief_step": {
		"name": "Thief Step", "cooldown": 60,
		"desc": "Stealth for 15 turns: monsters only notice you when adjacent. Attacking breaks it.",
	},
	"earth_gnome": {
		"name": "Earth Gnome", "cooldown": 40,
		"desc": "Blend into the ground (stealth) until you move, up to 40 turns.",
	},
	"call_of_the_dead": {
		"name": "Call of the Dead", "cooldown": 120,
		"desc": "Two ghouls crawl out of the ground and fight for you for 40 turns.",
	},
}

const PASSIVES := {
	"poison_strike": "Your attacks poison the target.",
	"tracker_nose": "You smell monsters up to %d tiles away, even through walls." % TRACKER_NOSE_RANGE,
	"preservation": "Faster regeneration (1 HP every 4 turns).",
}

var profile: Dictionary
var rng := RandomNumberGenerator.new()
var floors := {}
var map: FloorMap
var actors: Array[Actor] = []
var player: Actor
var turn := 0
var satiety := Rules.SATIETY_MAX
var torch_turns := 0
var inventory: Array = []
## Mana stones picked up during this run: monster id -> count.
var mana_stones := {}
## Essences put in vials during this run.
var stored_essences: Array[String] = []
## Tiles the player currently sees: Vector2i -> true.
var fov := {}
var log_lines: Array[String] = []
var over := false
## "closed", "dead" or "starved".
var end_reason := ""
## Essence lying under the player, waiting for the absorb / store / leave decision.
var pending_essence := ""
var exp_gained := 0
var levels_gained := 0
var kills := 0
var essences_absorbed: Array[String] = []
var sleeping := false

var _regen_every := Rules.PLAYER_REGEN_EVERY
var _tracker_nose := false
var _player_attacked := false


func _init(p_profile: Dictionary, seed_value: int = -1) -> void:
	profile = p_profile
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	inventory = (profile["inventory"] as Array).duplicate(true)

	player = Actor.new()
	player.id = "player"
	player.name = "Bjorn"
	player.is_player = true
	player.faction = Actor.PARTY
	player.glyph = "B"
	player.color = Color("#e8a33d")
	_apply_player_stats(true)
	actors.append(player)
	if "ainar" in profile["allies"]:
		actors.append(Actor.make_ainar(int(profile["level"])))

	_enter_floor(START_FLOOR, "")
	say("You wake up somewhere in the labyrinth. It will close in %d days." % Rules.LABYRINTH_DAYS)


# --- Queries used by the UI -------------------------------------------------------------------

func say(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 200:
		log_lines.pop_front()
	message_logged.emit(text)


func actor_at(p: Vector2i) -> Actor:
	for a in actors:
		if a.pos == p and a.alive():
			return a
	return null


func ally() -> Actor:
	for a in actors:
		if a.id == "ainar":
			return a
	return null


func is_visible_to_player(a: Actor) -> bool:
	if a.faction == Actor.PARTY:
		return true
	if a.status.has("hidden") and cheb(a.pos, player.pos) > 2:
		return false
	return fov.has(a.pos)


## True when a monster outside the field of view is still known thanks to the Blade Wolf nose.
func is_smelled(a: Actor) -> bool:
	return _tracker_nose and a.faction == Actor.MONSTER and cheb(a.pos, player.pos) <= TRACKER_NOSE_RANGE \
		and not a.status.has("hidden")


func vision_radius() -> int:
	if map.is_dark(player.pos):
		return Rules.TORCH_RADIUS if torch_turns > 0 else Rules.DARK_RADIUS
	return Rules.LIGHT_RADIUS


func time_string() -> String:
	var minutes := turn * Rules.MINUTES_PER_TURN
	var day := int(minutes / 1440.0) + 1
	return "Day %d, %02d:%02d" % [day, int((minutes % 1440) / 60.0), minutes % 60]


func time_left_string() -> String:
	var minutes := maxi(0, Rules.TURNS_PER_RUN - turn) * Rules.MINUTES_PER_TURN
	return "%dd %02dh %02dm" % [int(minutes / 1440.0), int((minutes % 1440) / 60.0), minutes % 60]


func player_skills() -> Array[String]:
	return Profile.active_skills(profile)


func skill_cooldown(skill_id: String) -> int:
	return int(player.cooldowns.get(skill_id, 0))


func hostile_in_view() -> bool:
	for a in actors:
		if a.faction == Actor.MONSTER and a.alive() and is_visible_to_player(a):
			return true
	return false


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _dist_sq(a: Vector2i, b: Vector2i) -> int:
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)


## Movement rule from Mystery Dungeon: one tile in 8 directions, no cutting diagonally past walls.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not map.is_walkable(to):
		return false
	var d := to - from
	if absi(d.x) > 1 or absi(d.y) > 1 or d == Vector2i.ZERO:
		return false
	if d.x != 0 and d.y != 0:
		if not map.is_walkable(Vector2i(from.x + d.x, from.y)) or not map.is_walkable(Vector2i(from.x, from.y + d.y)):
			return false
	return true


## Bresenham line of sight: every tile strictly between a and b must be open.
func los(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		if x == b.x and y == b.y:
			return true
		if (x != a.x or y != a.y) and not map.is_walkable(Vector2i(x, y)):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true


# --- Player actions. Each returns true when it used up the turn. ------------------------------

func try_move(dir: Vector2i) -> bool:
	if over or pending_essence != "":
		return false
	var to := player.pos + dir
	var other := actor_at(to)
	if other != null and other.faction == Actor.MONSTER:
		if not can_step(player.pos, to):
			return false
		_attack(player, other)
		_end_turn()
		return true
	if not can_step(player.pos, to):
		return false
	if player.status.has("immobile"):
		say("You struggle against the trap.")
		_end_turn()
		return true
	if other != null:
		other.pos = player.pos  # swap places with an ally, like in Mystery Dungeon
	player.pos = to
	_break_earth_gnome()
	_on_player_entered(to)
	_end_turn()
	return true


func wait_turn() -> bool:
	if over or pending_essence != "":
		return false
	_end_turn()
	return true


func use_portal() -> bool:
	if over or pending_essence != "" or not map.portals.has(player.pos):
		return false
	var dest: String = map.portals[player.pos]
	var from_id := map.floor_id
	var deeper := int(GameData.floor_def(dest)["depth"]) > int(map.def()["depth"])
	_enter_floor(dest, from_id)
	if deeper and not dest in profile["portals_opened"]:
		# Novel ch. 22: opening a portal for the first time grants a level.
		profile["portals_opened"].append(dest)
		var need := Profile.exp_to_next(int(profile["level"])) - int(profile["exp"])
		say("[color=gold]First time through this portal! Power surges through you.[/color]")
		_gain_exp(need)
	_end_turn()
	return true


func use_item(item_id: String) -> bool:
	if over or Profile.count_item(inventory, item_id) <= 0:
		return false
	var it := GameData.item(item_id)
	match it["type"]:
		"food":
			if satiety >= Rules.SATIETY_MAX - 1.0:
				say("You're not hungry.")
				return false
			satiety = minf(Rules.SATIETY_MAX, satiety + float(it["satiety"]))
			say("You eat the %s. Crunch." % it["name"])
		"heal":
			if player.hp >= player.max_hp:
				say("You're already at full health.")
				return false
			var healed := mini(int(it["heal"]), player.max_hp - player.hp)
			player.hp += healed
			say("You drink the %s and recover %d HP." % [it["name"], healed])
		"cure":
			if not player.status.has("poison"):
				say("You're not poisoned.")
				return false
			player.status.erase("poison")
			say("The poison fades.")
		"torch":
			torch_turns += int(it["duration"])
			say("You light a magic torch. You can see in the dark, but monsters can see you.")
		_:
			say("You can't use that here.")
			return false
	Profile.remove_item(inventory, item_id)
	_end_turn()
	return true


func use_skill(skill_id: String) -> bool:
	if over or pending_essence != "" or not skill_id in player_skills():
		return false
	if skill_cooldown(skill_id) > 0:
		say("%s is not ready (%d turns)." % [SKILLS[skill_id]["name"], skill_cooldown(skill_id)])
		return false
	match skill_id:
		"thief_step":
			player.status["stealth"] = 15
			say("[Thief Step] Your presence fades.")
		"earth_gnome":
			player.status["stealth"] = 40
			player.status["earth_gnome"] = 40
			say("[Earth Gnome] You blend into the ground. Moving will break it.")
		"call_of_the_dead":
			var summoned := 0
			for _i in 2:
				var p := _free_tile_near(player.pos)
				if p == player.pos:
					break
				var g := Actor.from_monster("ghoul")
				g.faction = Actor.PARTY
				g.name = "Your ghoul"
				g.color = Color("#6fd6a0")
				g.lifetime = 40
				g.pos = p
				actors.append(g)
				summoned += 1
			say("[Call of the Dead] %d ghouls crawl out of the ground to serve you." % summoned)
	player.cooldowns[skill_id] = int(SKILLS[skill_id]["cooldown"])
	_end_turn()
	return true


func absorb_essence() -> bool:
	if pending_essence == "":
		return false
	if (profile["essences"] as Array).size() >= Profile.essence_slots(profile):
		say("No free essence slot. You have one slot per level.")
		return false
	var e := pending_essence
	var ess := GameData.essence(e)
	profile["essences"].append(e)
	essences_absorbed.append(e)
	_remove_ground_essence(player.pos, e)
	pending_essence = ""
	_apply_player_stats(false)
	var gained := "Stats: " + ", ".join(_format_stats(ess.get("stats", {})))
	if ess.get("active", "") != "":
		gained += " | New skill: " + SKILLS[ess["active"]]["name"]
	if ess.get("passive", "") != "":
		gained += " | Passive: " + PASSIVES[ess["passive"]]
	say("[color=gold]You absorb the %s![/color] %s" % [ess["name"], gained])
	return true


func store_essence() -> bool:
	if pending_essence == "":
		return false
	if Profile.count_item(inventory, "vial") <= 0:
		say("You need an empty Essence Vial.")
		return false
	Profile.remove_item(inventory, "vial")
	stored_essences.append(pending_essence)
	_remove_ground_essence(player.pos, pending_essence)
	say("You seal the %s in a vial. It will sell for a fortune." % GameData.essence(pending_essence)["name"])
	pending_essence = ""
	return true


func leave_essence() -> void:
	if pending_essence == "":
		return
	_remove_ground_essence(player.pos, pending_essence)
	say("You let the %s go. It fades into the air." % GameData.essence(pending_essence)["name"])
	pending_essence = ""


func can_rest() -> bool:
	return not over and pending_essence == "" and not hostile_in_view()


## Wait until healed (or interrupted). Returns the number of turns spent.
func rest() -> int:
	if not can_rest():
		say("You can't rest with enemies in sight.")
		return 0
	var n := 0
	while n < Rules.REST_TURNS and player.hp < player.max_hp and not over:
		_player_attacked = false
		_end_turn()
		n += 1
		if _player_attacked or hostile_in_view():
			say("Your rest is interrupted!")
			break
	if n > 0:
		say("You rest for %d minutes." % (n * Rules.MINUTES_PER_TURN))
	return n


## Sleep for up to 6 hours. Healing is faster, but without a night friend on watch
## (novel ch. 8: Ainar or Erwen) you only wake up when something hits you.
func camp() -> int:
	if not can_rest():
		say("You can't make camp with enemies in sight.")
		return 0
	var watcher := ally()
	sleeping = true
	if watcher != null:
		say("You make camp. Ainar keeps watch: your night friend.")
	else:
		say("You make camp alone and close your eyes...")
	var n := 0
	while n < Rules.CAMP_TURNS and not over:
		_player_attacked = false
		_end_turn()
		n += 1
		if _player_attacked:
			say("[color=tomato]You wake up to an attack![/color]")
			break
		if watcher != null and watcher.alive() and hostile_in_view():
			say("Ainar shakes you awake: monsters are coming!")
			break
	sleeping = false
	if n > 0 and not over:
		say("You slept %d hours %d minutes." % [int(n * Rules.MINUTES_PER_TURN / 60.0), (n * Rules.MINUTES_PER_TURN) % 60])
	return n


## Applies the run's outcome to the profile and returns a report for the summary screen.
func finish() -> Dictionary:
	var report := {
		"reason": end_reason,
		"turns": turn,
		"kills": kills,
		"exp": exp_gained,
		"levels": levels_gained,
		"essences": essences_absorbed.duplicate(),
		"stored": stored_essences.duplicate(),
		"stones": mana_stones.duplicate(),
		"ally_share": {},
		"lost": false,
	}
	if end_reason != "closed":
		# Death in the labyrinth: someone drags you out, but everything you carried is gone.
		report["lost"] = true
		profile["inventory"] = []
	else:
		profile["inventory"] = inventory
		var stones := mana_stones.duplicate()
		if "ainar" in profile["allies"]:
			for m in stones:
				var cut := int(floor(int(stones[m]) * Rules.ALLY_SHARE))
				if cut > 0:
					stones[m] = int(stones[m]) - cut
					report["ally_share"][m] = cut
		for m in stones:
			profile["mana_stones"][m] = int(profile["mana_stones"].get(m, 0)) + int(stones[m])
		for e in stored_essences:
			profile["vials"].append(e)
	profile["runs"] = int(profile["runs"]) + 1
	return report


# --- Turn processing ---------------------------------------------------------------------------

func _end_turn() -> void:
	turn += 1
	satiety = maxf(0.0, satiety - Rules.SATIETY_PER_TURN)
	if satiety <= 0.0:
		player.hp -= 1
		if turn % 10 == 0:
			say("[color=tomato]You are starving![/color]")
		if player.hp <= 0:
			_end("starved")
	elif player.hp < player.max_hp and (turn % _regen_every == 0 or (sleeping and turn % 2 == 0)):
		player.hp += 1
	if torch_turns > 0:
		torch_turns -= 1
		if torch_turns == 0:
			say("Your torch burns out.")

	for a in actors.duplicate():
		if a in actors:
			_tick(a)

	for a in actors.duplicate():
		if over:
			break
		if a == player or not a.alive() or not a in actors:
			continue
		a.energy += a.speed
		while a.energy >= 100 and a.alive() and not over and a in actors:
			a.energy -= 100
			_act(a)

	var d := map.def()
	if turn % int(d["respawn_every"]) == 0 and _monster_count() < int(d["max_monsters"]):
		_spawn_group(12)

	if not over and turn >= Rules.TURNS_PER_RUN:
		say("[color=gold]A blinding light: the labyrinth is closing. You are pulled back to Rafdonia.[/color]")
		_end("closed")
	_update_fov()


func _end(reason: String) -> void:
	if not over:
		over = true
		end_reason = reason


func _tick(a: Actor) -> void:
	if a.status.has("poison"):
		a.hp -= 1
		if a.hp <= 0:
			if a.is_player:
				say("[color=tomato]The poison finishes you off.[/color]")
			_kill(a, null)
			return
	for k in a.status.keys():
		var v := int(a.status[k])
		if v > 0:
			v -= 1
			if v == 0:
				a.status.erase(k)
				if a.is_player and k == "stealth":
					say("You're no longer hidden.")
			else:
				a.status[k] = v
	for k in a.cooldowns.keys():
		a.cooldowns[k] = maxi(0, int(a.cooldowns[k]) - 1)
	if a.regen > 0 and a.hp < a.max_hp:
		a.hp = mini(a.max_hp, a.hp + a.regen)
	if not a.is_player and a.regen_every > 0 and turn % a.regen_every == 0 and a.hp < a.max_hp:
		a.hp += 1
	if a.lifetime > 0:
		a.lifetime -= 1
		if a.lifetime == 0:
			actors.erase(a)
			if is_visible_to_player(a):
				say("%s crumbles to dust." % a.name)


func _act(a: Actor) -> void:
	if a.status.has("paralyzed"):
		return
	if a.faction == Actor.PARTY:
		_ally_act(a)
	else:
		_monster_act(a)


func _monster_act(m: Actor) -> void:
	var tgt := _find_target(m)
	if tgt != null:
		m.last_seen = tgt.pos
		if m.data.has("summon") and int(m.cooldowns.get("summon", 0)) <= 0:
			_summon(m)
			return
		var dist := cheb(m.pos, tgt.pos)
		if dist == 1 and can_step(m.pos, tgt.pos):
			_attack(m, tgt)
			return
		if m.attack_range > 1 and dist <= m.attack_range and los(m.pos, tgt.pos):
			_attack(m, tgt, true)
			return
		_step_toward(m, tgt.pos)
		return
	if m.last_seen != NOWHERE:
		if m.pos == m.last_seen or not _step_toward(m, m.last_seen):
			m.last_seen = NOWHERE
		return
	_wander(m)


func _find_target(m: Actor) -> Actor:
	var best: Actor = null
	var best_d := 999
	for a in actors:
		if a.faction != Actor.PARTY or not a.alive():
			continue
		var d := cheb(m.pos, a.pos)
		if d > m.sight or d >= best_d:
			continue
		if a.status.has("stealth") and d > 1:
			continue
		var lit := not map.is_dark(a.pos) or (a.is_player and torch_turns > 0)
		if not lit and d > Rules.DARK_DETECT_RADIUS:
			continue
		if los(m.pos, a.pos):
			best = a
			best_d = d
	return best


func _ally_act(a: Actor) -> void:
	var target: Actor = null
	var best_d := 999
	for m in actors:
		if m.faction != Actor.MONSTER or not m.alive():
			continue
		var d := cheb(a.pos, m.pos)
		if m.status.has("hidden") and d > 1:
			continue
		if d == 1 and can_step(a.pos, m.pos):
			_attack(a, m)
			return
		if d <= 5 and d < best_d and cheb(m.pos, player.pos) <= 6 and los(a.pos, m.pos):
			target = m
			best_d = d
	if target != null:
		_step_toward(a, target.pos)
	elif cheb(a.pos, player.pos) > 1:
		_step_toward(a, player.pos)


func _wander(m: Actor) -> void:
	if rng.randf() < 0.5:
		return
	if cheb(m.pos, player.pos) > 24:
		# Far from the player: a cheap random step instead of path-finding.
		var n := m.pos + DIRS8[rng.randi_range(0, 7)]
		if can_step(m.pos, n) and actor_at(n) == null:
			m.pos = n
		return
	if m.wander_goal == NOWHERE or m.pos == m.wander_goal:
		m.wander_goal = map.random_floor_tile(rng)
	if not _step_toward(m, m.wander_goal):
		m.wander_goal = NOWHERE


func _step_toward(a: Actor, goal: Vector2i) -> bool:
	if a.status.has("immobile") or a.status.has("earth_gnome"):
		return false
	var path := map.astar.get_id_path(a.pos, goal)
	if path.size() >= 2:
		var nxt: Vector2i = path[1]
		if actor_at(nxt) == null and can_step(a.pos, nxt):
			a.pos = nxt
			return true
	# Path blocked by someone: take the free neighbouring tile that gets closest.
	var best := a.pos
	var best_d := _dist_sq(a.pos, goal)
	for d in DIRS8:
		var n := a.pos + d
		if can_step(a.pos, n) and actor_at(n) == null:
			var dd := _dist_sq(n, goal)
			if dd < best_d:
				best = n
				best_d = dd
	if best != a.pos:
		a.pos = best
		return true
	return false


func _summon(m: Actor) -> void:
	var sid: String = m.data["summon"]
	for _i in int(m.data.get("summon_count", 2)):
		var p := _free_tile_near(m.pos)
		if p == m.pos:
			break
		var s := Actor.from_monster(sid)
		s.pos = p
		actors.append(s)
	m.cooldowns["summon"] = int(m.data.get("summon_cooldown", 30))
	if is_visible_to_player(m):
		say("[color=violet]The %s calls the dead! Ghouls crawl out of the ground.[/color]" % m.name)


func _attack(a: Actor, d: Actor, ranged := false) -> void:
	if a.is_player:
		_break_earth_gnome()
		if player.status.has("stealth"):
			player.status.erase("stealth")
	a.status.erase("hidden")
	var shown := fov.has(a.pos) or fov.has(d.pos) or a.faction == Actor.PARTY or d.faction == Actor.PARTY
	var a_name := "You" if a.is_player else a.name
	var d_name := "you" if d.is_player else d.name
	if d.is_player:
		_player_attacked = true
	if rng.randf() > 0.9:
		if shown:
			say("%s %s %s." % [a_name, "miss" if a.is_player else "misses", d_name])
		return
	var dmg := maxi(1, int(round(a.atk * rng.randf_range(0.8, 1.25))) - d.def)
	var crit := rng.randf() < 0.06
	if crit:
		dmg = int(dmg * 1.5)
	d.hp -= dmg
	d.status.erase("hidden")
	if a.poison_on_hit and d.alive():
		d.status["poison"] = 4
	if shown:
		var verb := "shoot" if ranged else "hit"
		if not a.is_player:
			verb += "s"
		var col := "tomato" if d.faction == Actor.PARTY else "white"
		say("[color=%s]%s %s %s for %d%s.[/color]" % [col, a_name, verb, d_name, dmg, " (critical!)" if crit else ""])
	if not d.alive():
		_kill(d, a)


func _kill(d: Actor, killer: Actor) -> void:
	actors.erase(d)
	if d.is_player:
		say("[color=tomato]You collapse...[/color]")
		_end("dead")
		return
	if d.faction == Actor.PARTY:
		if d.id == "ainar":
			say("[color=tomato]Ainar collapses! She'll be carried back to the city.[/color]")
		else:
			say("%s falls apart." % d.name)
		return
	if killer != null and killer.faction == Actor.PARTY:
		kills += 1
		if fov.has(d.pos):
			say("The %s dies." % d.name)
		_gain_exp(int(d.data.get("exp", 1)))
	map.add_ground(d.pos, {"kind": "stone", "monster": d.id})
	var ess: String = d.data.get("essence", "")
	if ess != "" and rng.randf() < float(d.data.get("essence_chance", 0.0)):
		map.add_ground(d.pos, {"kind": "essence", "id": ess})
		say("[color=gold]An essence rises from the %s's body![/color]" % d.name)


func _gain_exp(amount: int) -> void:
	exp_gained += amount
	var gained := Profile.add_exp(profile, amount)
	if gained > 0:
		levels_gained += gained
		_apply_player_stats(false)
		player.hp = mini(player.max_hp, player.hp + 10 * gained)
		say("[color=gold]Level up! You are now level %d (%d essence slots).[/color]" % [int(profile["level"]), Profile.essence_slots(profile)])


func _apply_player_stats(full_heal: bool) -> void:
	var s := Profile.player_stats(profile)
	var ratio := float(player.hp) / player.max_hp if player.max_hp > 1 else 1.0
	player.max_hp = int(s["max_hp"])
	player.atk = int(s["atk"])
	player.def = int(s["def"])
	_regen_every = int(s["regen_every"])
	player.hp = player.max_hp if full_heal else clampi(int(round(ratio * player.max_hp)), 1, player.max_hp)
	player.poison_on_hit = Profile.has_passive(profile, "poison_strike")
	_tracker_nose = Profile.has_passive(profile, "tracker_nose")


func _break_earth_gnome() -> void:
	if player.status.has("earth_gnome"):
		player.status.erase("earth_gnome")
		player.status.erase("stealth")
		say("Your camouflage breaks.")


func _on_player_entered(p: Vector2i) -> void:
	if map.traps.has(p):
		map.traps.erase(p)
		player.hp -= 6
		player.status["immobile"] = 3
		say("[color=tomato]Snap! A goblin trap bites your leg (6 damage). You're stuck for a moment.[/color]")
		if player.hp <= 0:
			_kill(player, null)
			return
	if map.ground.has(p):
		var rest: Array = []
		for e in map.ground[p]:
			match e["kind"]:
				"stone":
					var mid: String = e["monster"]
					mana_stones[mid] = int(mana_stones.get(mid, 0)) + 1
					say("You pick up a %s mana stone." % GameData.monster(mid)["name"])
				"item":
					var it := GameData.item(e["id"])
					if Profile.add_item(inventory, e["id"]):
						say("You pick up: %s." % it["name"])
					else:
						say("Your bag is full. You leave the %s." % it["name"])
						rest.append(e)
				"essence":
					pending_essence = e["id"]
					rest.append(e)
		if rest.is_empty():
			map.ground.erase(p)
		else:
			map.ground[p] = rest
	if map.portals.has(p):
		say("A portal shimmers here, leading to the %s. Press Enter to step through." % GameData.floor_def(map.portals[p])["name"])


func _remove_ground_essence(p: Vector2i, essence_id: String) -> void:
	if not map.ground.has(p):
		return
	var list: Array = map.ground[p]
	for i in list.size():
		if list[i]["kind"] == "essence" and list[i]["id"] == essence_id:
			list.remove_at(i)
			break
	if list.is_empty():
		map.ground.erase(p)


func _format_stats(stats: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var labels := {"max_hp": "HP", "atk": "ATK", "def": "DEF"}
	for k in stats:
		out.append("%s %+d" % [labels.get(k, k), int(stats[k])])
	return out


# --- Floors and spawning ----------------------------------------------------------------------

func _enter_floor(floor_id: String, from_floor: String) -> void:
	if map != null:
		map.monsters.clear()
		var party: Array[Actor] = []
		for a in actors:
			if a.faction == Actor.MONSTER:
				map.monsters.append(a)
			else:
				party.append(a)
		actors = party
	var first_visit := not floors.has(floor_id)
	if first_visit:
		floors[floor_id] = DungeonGenerator.generate(floor_id, rng)
	map = floors[floor_id]

	var start := map.random_floor_tile(rng)
	for p in map.portals:
		if map.portals[p] == from_floor:
			start = p
	player.pos = start
	for a in actors:
		if a != player:
			a.pos = player.pos
			a.pos = _free_tile_near(player.pos)
	if first_visit:
		_update_fov()
		var tries := 0
		while _monster_count() < int(map.def()["initial_monsters"]) and tries < 400:
			tries += 1
			_spawn_group(10)
	else:
		for m in map.monsters:
			actors.append(m)
		map.monsters.clear()
	_update_fov()
	say("[b]%s[/b]" % map.def()["name"])


func _monster_count() -> int:
	var n := 0
	for a in actors:
		if a.faction == Actor.MONSTER:
			n += 1
	return n


func _spawn_group(min_dist: int) -> void:
	var d := map.def()
	var p := map.random_floor_tile(rng)
	if cheb(p, player.pos) < min_dist or fov.has(p) or actor_at(p) != null:
		return
	var regions: Dictionary = d["regions"]
	var table: Array = regions.get(map.region_at(p), regions["C"])
	var pack: Array = d["pack"]
	for i in rng.randi_range(int(pack[0]), int(pack[1])):
		var spot := p if i == 0 else _free_tile_near(p)
		if actor_at(spot) != null:
			continue
		var m := Actor.from_monster(table[rng.randi_range(0, table.size() - 1)])
		m.pos = spot
		actors.append(m)


func _free_tile_near(p: Vector2i) -> Vector2i:
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := p + Vector2i(dx, dy)
				if map.is_walkable(q) and actor_at(q) == null:
					return q
	return p


func _update_fov() -> void:
	fov.clear()
	var far := maxi(Rules.LIGHT_RADIUS, Rules.TORCH_RADIUS)
	var torch_r := Rules.TORCH_RADIUS if torch_turns > 0 else 0
	for dy in range(-far, far + 1):
		for dx in range(-far, far + 1):
			var p := player.pos + Vector2i(dx, dy)
			if not map.in_bounds(p):
				continue
			var d2 := dx * dx + dy * dy
			var seen := d2 <= Rules.DARK_RADIUS * Rules.DARK_RADIUS + Rules.DARK_RADIUS \
				or d2 <= torch_r * torch_r + torch_r \
				or (not map.is_dark(p) and d2 <= Rules.LIGHT_RADIUS * Rules.LIGHT_RADIUS + Rules.LIGHT_RADIUS)
			if seen and los(player.pos, p):
				fov[p] = true
				map.explored[map.idx(p)] = 1
