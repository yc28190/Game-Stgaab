class_name DungeonRun
extends RefCounted
## One trip into the labyrinth. This is the turn engine: it holds no rendering code, so it can be
## driven by the UI or by the headless tests.
##
## Each player action calls _end_turn(), which advances the clock (3 minutes while exploring, 6 seconds in
## combat), hunger, regeneration and statuses, then lets every other actor act according to its speed.

signal message_logged(text: String)

const DIRS8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
const NOWHERE := Vector2i(-1, -1)
const START_FLOOR := "crystal_cave"
const TRACKER_NOSE_RANGE := 12
const AMBUSH_RANGE := 3
const TERRITORY_RADIUS := 10

const SKILLS := {
	"thief_step": {
		"name": "Thief Step", "cooldown": 60, "sp": 10,
		"desc": "Stealth for 15 turns: monsters only notice you when adjacent. Attacking breaks it.",
	},
	"earth_gnome": {
		"name": "Earth Gnome", "cooldown": 40, "sp": 8,
		"desc": "Blend into the ground (stealth) until you move, up to 40 turns.",
	},
	"call_of_the_dead": {
		"name": "Call of the Dead", "cooldown": 120, "sp": 25,
		"desc": "Two ghouls crawl out of the ground and fight for you for 40 turns.",
	},
	"suppression": {
		"name": "Suppression", "cooldown": 30, "sp": 12,
		"desc": "Paralyses the nearest monster within 2 tiles for 5 turns. Any damage breaks it.",
	},
}

const PASSIVES := {
	"poison_strike": "Your attacks poison the target.",
	"tracker_nose": "You smell monsters up to %d tiles away, even through walls." % TRACKER_NOSE_RANGE,
	"preservation": "Natural Regeneration +4 HP per hour.",
}

var profile: Dictionary
var rng := RandomNumberGenerator.new()
var floors := {}
var map: FloorMap
var actors: Array[Actor] = []
var player: Actor
## Number of turns played (actions).
var turn := 0
## Game time since the labyrinth opened, in seconds.
var seconds := 0
var satiety := Rules.SATIETY_MAX
var torch_seconds := 0
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
## Essence lying under the player that the decision window is open for ("" = none).
var pending_essence := ""
var exp_gained := 0
var levels_gained := 0
var kills := 0
var essences_absorbed: Array[String] = []
var sleeping := false
var bonded := true
var ally_died := false
## Floors closed so far this run (their portals are gone).
var closed_floors: Array[String] = []

var _appetite := 10
var _tracker_nose := false
var _player_attacked := false
var _hunger_note := 0
var _next_respawn := {}
var _death_reason := "dead"


func _init(p_profile: Dictionary, seed_value: int = -1, p_bonded: bool = true) -> void:
	profile = p_profile
	bonded = p_bonded
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
		if not profile.has("companions"):
			profile["companions"] = {}
		if not profile["companions"].has("ainar"):
			profile["companions"]["ainar"] = Profile.create_companion("ainar")
		var c: Dictionary = profile["companions"]["ainar"]
		if c.get("alive", true):
			actors.append(Actor.make_companion(c))
	if profile.get("slept_rough", false):
		satiety = Rules.ROUGH_SLEEP_BELLY
		player.hp = int(player.max_hp * Rules.ROUGH_SLEEP_HP)

	_enter_floor(START_FLOOR, "")
	say("You wake up somewhere in the labyrinth. The 1st floor closes at the end of Day %d." % int(map.def()["closes_day"]))
	if profile.get("slept_rough", false):
		say("A night in the street left you hungry and sore.")
	if ally() != null and not bonded:
		say("Without a binding spell, Ainar woke up somewhere else on the floor. She'll look for you.")


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
	if a.status.has("hidden") and cheb(a.pos, player.pos) > Stats.hidden_reveal_range(player.perception):
		return false
	return fov.has(a.pos)


## True when a monster outside the field of view is still known thanks to the Blade Wolf nose.
func is_smelled(a: Actor) -> bool:
	return _tracker_nose and a.faction == Actor.MONSTER and cheb(a.pos, player.pos) <= TRACKER_NOSE_RANGE \
		and not a.status.has("hidden")


func vision_radius() -> int:
	if map.is_dark(player.pos):
		return Rules.TORCH_RADIUS if torch_seconds > 0 else Stats.dark_radius(player.perception)
	return Rules.LIGHT_RADIUS


func day() -> int:
	return int(seconds / float(Rules.DAY_SECONDS)) + 1


func time_string() -> String:
	var s := seconds % Rules.DAY_SECONDS
	return "Day %d, %02d:%02d" % [day(), int(s / 3600.0), int((s % 3600) / 60.0)]


## Seconds until the floor you are on closes.
func seconds_left() -> int:
	return maxi(0, int(map.def()["closes_day"]) * Rules.DAY_SECONDS - seconds)


func time_left_string() -> String:
	var s := seconds_left()
	return "%dd %02dh %02dm" % [int(s / float(Rules.DAY_SECONDS)), int((s % Rules.DAY_SECONDS) / 3600.0), int((s % 3600) / 60.0)]


## Combat slows the clock to 6-second turns.
func in_combat() -> bool:
	if hostile_in_view():
		return true
	for a in actors:
		if a.faction == Actor.PARTY and a.in_countdown:
			return true
	return false


func player_skills() -> Array[String]:
	return Profile.active_skills(profile)


func skill_cooldown(skill_id: String) -> int:
	return int(player.cooldowns.get(skill_id, 0))


func hostile_in_view() -> bool:
	for a in actors:
		if a.faction == Actor.MONSTER and a.alive() and is_visible_to_player(a):
			return true
	return false


## The essence entry lying under the player, if any.
func essence_here() -> Dictionary:
	for e in map.ground.get(player.pos, []):
		if e["kind"] == "essence":
			return e
	return {}


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

## Paralysis (Suppression) skips the player's turns until it wears off or is broken by damage.
func _blocked() -> bool:
	if over or pending_essence != "":
		return true
	if player.status.has("paralyzed"):
		say("You're paralysed and can't move!")
		_end_turn()
		return true
	return false


func try_move(dir: Vector2i) -> bool:
	if pending_essence != "" or over:
		return false
	if _blocked():
		return true
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
	if pending_essence != "" or over:
		return false
	if _blocked():
		return true
	_end_turn()
	return true


func use_portal() -> bool:
	if over or pending_essence != "" or not map.portals.has(player.pos):
		return false
	if _blocked():
		return true
	var dest: String = map.portals[player.pos]
	if dest in closed_floors:
		say("The way back has vanished: the %s is closed." % GameData.floor_def(dest)["name"])
		return false
	_enter_floor(dest, map.floor_id)
	_end_turn()
	return true


func use_item(item_id: String) -> bool:
	if over or Profile.count_item(inventory, item_id) <= 0:
		return false
	if _blocked():
		return true
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
			if player.in_countdown and player.hp > 0:
				_end_countdown(player)
			say("You drink the %s and recover %d HP." % [it["name"], healed])
		"cure":
			if not player.status.has("poison"):
				say("You're not poisoned.")
				return false
			player.status.erase("poison")
			say("The poison fades.")
		"torch":
			torch_seconds += int(it["duration"]) * Rules.EXPLORE_SECONDS
			say("You light a magic torch. You can see in the dark, but monsters can see you.")
		_:
			say("You can't use that here.")
			return false
	Profile.remove_item(inventory, item_id)
	_end_turn()
	if it.get("pain", false):
		_suffer_potion_pain()
	return true


## Ch. 5: the regeneration of a potion is agonising. You lose 4 combat turns, 1 fewer per 20 Pain Resistance.
func _suffer_potion_pain() -> void:
	var n := Stats.potion_pain_turns(player.pain_res)
	if n == 0:
		say("The regeneration burns, but your Pain Resistance lets you shrug it off.")
		return
	say("[color=tomato]Your whole body feels like it's melting. You writhe in pain (%d turns).[/color]" % n)
	for _i in n:
		if over:
			return
		_end_turn(Rules.COMBAT_SECONDS)


func use_skill(skill_id: String) -> bool:
	if over or pending_essence != "" or not skill_id in player_skills():
		return false
	if skill_cooldown(skill_id) > 0:
		say("%s is not ready (%d turns)." % [SKILLS[skill_id]["name"], skill_cooldown(skill_id)])
		return false
	var cost := int(SKILLS[skill_id]["sp"])
	if player.sp < cost:
		say("The character's Soul Power is insufficient (%d needed)." % cost)
		return false
	if _blocked():
		return true
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
				g.ai = "melee"
				g.lifetime = 40
				g.pos = p
				actors.append(g)
				summoned += 1
			say("[Call of the Dead] %d ghouls crawl out of the ground to serve you." % summoned)
		"suppression":
			var target: Actor = null
			for a in actors:
				if a.faction == Actor.MONSTER and a.alive() and is_visible_to_player(a) and cheb(a.pos, player.pos) <= 2:
					if target == null or cheb(a.pos, player.pos) < cheb(target.pos, player.pos):
						target = a
			if target == null:
				say("No monster close enough to suppress.")
				return false
			_try_suppress(player, target)
	player.sp -= cost
	player.cooldowns[skill_id] = int(SKILLS[skill_id]["cooldown"])
	_end_turn()
	return true


## Absorb the essence under the player (whether or not the decision window is open).
func absorb_essence() -> bool:
	var entry := essence_here()
	if entry.is_empty():
		return false
	var e: String = entry["id"]
	var why := Profile.can_absorb(profile, e)
	if why != "":
		say("You can't absorb it: %s." % why)
		return false
	var ess := GameData.essence(e)
	profile["essences"].append(e)
	profile["essence_colors"][e] = entry.get("color", GameData.essence_colors(e)[0])
	essences_absorbed.append(e)
	_remove_ground_essence(player.pos, e)
	pending_essence = ""
	_apply_player_stats(false)
	say("[color=gold]The %s seeps into the character's soul.[/color] %s" % [ess["name"], _describe_essence(e, entry.get("color", ""))])
	return true


## Ainar absorbs the essence under the player (she must be next to you).
func give_essence_to_ally() -> bool:
	var entry := essence_here()
	var a := ally()
	if entry.is_empty() or a == null or not a.alive() or cheb(a.pos, player.pos) > 1:
		say("Ainar must be next to you to take it.")
		return false
	var e: String = entry["id"]
	var why := Profile.can_absorb(a.companion, e)
	if why != "":
		say("Ainar can't absorb it: %s." % why)
		return false
	a.companion["essences"].append(e)
	_remove_ground_essence(player.pos, e)
	pending_essence = ""
	_refresh_companion(a)
	say("[color=gold]The %s seeps into Ainar's soul.[/color]" % GameData.essence(e)["name"])
	return true


func store_essence() -> bool:
	var entry := essence_here()
	if entry.is_empty():
		return false
	if Profile.count_item(inventory, "vial") <= 0:
		say("You need an empty Essence Vial.")
		return false
	var e: String = entry["id"]
	Profile.remove_item(inventory, "vial")
	stored_essences.append(e)
	_remove_ground_essence(player.pos, e)
	say("You seal the %s in a vial. It will sell for a fortune." % GameData.essence(e)["name"])
	pending_essence = ""
	return true


## Close the decision window; the essence stays on the ground until it fades.
func postpone_essence() -> void:
	if pending_essence != "":
		say("You leave the essence floating there for now. It will fade in about 30 minutes.")
	pending_essence = ""


## Reopen the decision window for the essence under the player.
func reopen_essence() -> bool:
	var entry := essence_here()
	if entry.is_empty():
		return false
	pending_essence = entry["id"]
	return true


func pending_essence_color() -> String:
	return essence_here().get("color", "")


func can_rest() -> bool:
	return not over and pending_essence == "" and not in_combat()


## Wait until healed (or interrupted). Returns the number of turns spent.
func rest() -> int:
	if not can_rest():
		say("You can't rest with enemies in sight.")
		return 0
	var n := 0
	while n < Rules.REST_TURNS and (player.hp < player.max_hp or player.sp < player.max_sp) and not over:
		_player_attacked = false
		_end_turn()
		n += 1
		if _player_attacked or hostile_in_view():
			say("Your rest is interrupted!")
			break
	if n > 0:
		say("You rest for %d minutes." % int(n * Rules.EXPLORE_SECONDS / 60.0))
	return n


## Sleep for up to 6 hours. Healing is faster, but without a night friend on watch
## (novel ch. 8: Ainar or Erwen) you only wake up when something hits you.
func camp() -> int:
	if not can_rest():
		say("You can't make camp with enemies in sight.")
		return 0
	var watcher := ally()
	if watcher != null and cheb(watcher.pos, player.pos) > 3:
		watcher = null
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
		var mins := int(n * Rules.EXPLORE_SECONDS / 60.0)
		say("You slept %d hours %d minutes." % [int(mins / 60.0), mins % 60])
	return n


## Applies the run's outcome to the profile and returns a report for the summary screen.
func finish() -> Dictionary:
	var report := {
		"reason": end_reason,
		"seconds": seconds,
		"kills": kills,
		"exp": exp_gained,
		"levels": levels_gained,
		"essences": essences_absorbed.duplicate(),
		"stored": stored_essences.duplicate(),
		"stones": mana_stones.duplicate(),
		"ally_share": {},
		"ally_died": ally_died,
		"lost": false,
	}
	if ally_died:
		profile["allies"].erase("ainar")
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

func _end_turn(force_seconds: int = -1) -> void:
	var dt := force_seconds if force_seconds > 0 else (Rules.COMBAT_SECONDS if in_combat() else Rules.EXPLORE_SECONDS)
	turn += 1
	seconds += dt
	_pass_time(dt)
	if over:
		return

	for a in actors.duplicate():
		if a in actors:
			_tick(a, dt)

	for a in actors.duplicate():
		if over:
			break
		if a == player or not a.alive() or not a in actors:
			continue
		a.energy += Stats.energy_per_player_action(a.speed, player.speed)
		while a.energy >= 100 and a.alive() and not over and a in actors:
			a.energy -= 100
			_act(a)

	_fade_essences()
	_respawn()
	_check_closing()
	_update_fov()


## Hunger, regeneration, soul power, torch and the death countdown for the party.
func _pass_time(dt: int) -> void:
	var hours := dt / 3600.0
	satiety = maxf(0.0, satiety - Stats.hunger_per_second(_appetite) * dt)
	if satiety <= 0.0:
		_hunger_note += dt
		if _hunger_note >= 1800:
			_hunger_note = 0
			say("[color=tomato]You are starving![/color]")
		_damage_over_time(player, dt / float(Rules.EXPLORE_SECONDS), "starved")
	elif not player.in_countdown:
		_regenerate(player, player.regen_per_hour * hours * (3.0 if sleeping else 1.0))
	player.sp = minf(player.max_sp, player.sp + player.max_sp * 0.2 * hours * (2.5 if sleeping else 1.0))
	if not player.in_countdown:
		player.mental = minf(player.max_mental, player.mental + player.max_mental * hours)
	if torch_seconds > 0:
		torch_seconds = maxi(0, torch_seconds - dt)
		if torch_seconds == 0:
			say("Your torch burns out.")
	_spot_traps()

	var a := ally()
	if a != null and a.alive():
		a.satiety = maxf(0.0, a.satiety - Stats.hunger_per_second(10) * dt)
		if a.satiety < 30.0 and Profile.count_item(inventory, "bread") > 0:
			Profile.remove_item(inventory, "bread")
			a.satiety = minf(Rules.SATIETY_MAX, a.satiety + float(GameData.item("bread")["satiety"]))
			say("Ainar eats a rock-bread from your bag.")
		if a.satiety <= 0.0:
			_damage_over_time(a, dt / float(Rules.EXPLORE_SECONDS), "starved")
		elif not a.in_countdown:
			_regenerate(a, a.regen_per_hour * hours * (3.0 if sleeping else 1.0))
		if not a.in_countdown:
			a.mental = minf(a.max_mental, a.mental + a.max_mental * hours)

	for b in actors.duplicate():
		if b.faction == Actor.PARTY and b.in_countdown and b in actors:
			_countdown_step(b, dt)


func _regenerate(a: Actor, amount: float) -> void:
	if a.hp >= a.max_hp:
		a._regen_acc = 0.0
		return
	a._regen_acc += amount
	var whole := int(a._regen_acc)
	if whole > 0:
		a._regen_acc -= whole
		a.hp = mini(a.max_hp, a.hp + whole)


func _damage_over_time(a: Actor, amount: float, reason: String) -> void:
	a._regen_acc -= amount
	while a._regen_acc <= -1.0:
		a._regen_acc += 1.0
		_hurt(a, 1, null, reason)
		if not a.alive():
			return


## Ch. 35, 428, 857: at 0 HP a countdown burns 3 Mental Power per second; regeneration is boosted in
## proportion to Mental Power, and getting back above 1% HP cancels it. Mental Power at 0 = death.
func _countdown_step(a: Actor, dt: int) -> void:
	a._regen_acc += Stats.countdown_regen_per_turn(a.regen_per_hour, a.mental) * dt / float(Rules.COMBAT_SECONDS)
	if a._regen_acc >= a.max_hp * 0.01:
		a.hp = maxi(1, int(a._regen_acc))
		a._regen_acc = 0.0
		_end_countdown(a)
		return
	a.mental -= Rules.COUNTDOWN_MENTAL_PER_SECOND * dt
	if a.is_player:
		say("[color=tomato]Consuming %d Mental Power per second. (%d/%d)[/color]" % [Rules.COUNTDOWN_MENTAL_PER_SECOND, maxi(0, int(a.mental)), a.max_mental])
	if a.mental <= 0.0:
		a.mental = 0.0
		a.in_countdown = false
		_kill(a, null)


func _end_countdown(a: Actor) -> void:
	a.in_countdown = false
	if a.is_player:
		say("[color=gold]The character's HP has been restored to 1% or higher. The countdown has ended.[/color]")
		if Profile.grant_achievement(profile, "survive_countdown", 10):
			say("[color=gold]Achievement Unlocked — Survive after the countdown. Mental Power permanently +10.[/color]")
			_apply_player_stats(false)
	else:
		say("%s's HP has recovered above 1%%. Countdown canceled." % a.name)


func _end(reason: String) -> void:
	if not over:
		over = true
		end_reason = reason


func _tick(a: Actor, dt: int) -> void:
	if a.status.has("poison"):
		_hurt(a, 1, null, "dead")
		if not a.alive():
			if a.is_player:
				say("[color=tomato]The poison finishes you off.[/color]")
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
	if a.faction == Actor.MONSTER and a.regen > 0 and a.hp < a.max_hp:
		a.hp = mini(a.max_hp, a.hp + a.regen)
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
	if tgt != null and m.data.get("territorial", false) and m.home != NOWHERE and cheb(tgt.pos, m.home) > TERRITORY_RADIUS:
		tgt = null  # Deathfiends don't chase anyone out of their territory (ch. 24).
	if tgt != null and m.ai == "ambush" and m.last_seen == NOWHERE and cheb(m.pos, tgt.pos) > AMBUSH_RANGE:
		return  # Ghouls sit motionless until someone comes close (ch. 11).
	if tgt != null:
		m.last_seen = tgt.pos
		if m.data.has("skill") and int(m.cooldowns.get("skill", 0)) <= 0 and cheb(m.pos, tgt.pos) <= 2:
			_try_suppress(m, tgt)
			m.cooldowns["skill"] = int(m.data.get("skill_cooldown", 20))
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
	if m.data.get("territorial", false) and m.home != NOWHERE and cheb(m.pos, m.home) > 3:
		_step_toward(m, m.home)
		return
	if m.ai == "ambush":
		return
	_wander(m)


func _find_target(m: Actor) -> Actor:
	# Pick the party member with the best threat-minus-distance score among those it can see.
	var best: Actor = null
	var best_score := -INF
	for a in actors:
		if a.faction != Actor.PARTY or not a.alive():
			continue
		var d := cheb(m.pos, a.pos)
		if d > m.sight:
			continue
		if a.status.has("stealth") and d > 1:
			continue
		var lit := not map.is_dark(a.pos) or (a.is_player and torch_seconds > 0)
		if not lit and d > Rules.DARK_DETECT_RADIUS:
			continue
		var score := a.threat - 2.0 * d
		if score > best_score and los(m.pos, a.pos):
			best = a
			best_score = score
	return best


func _ally_act(a: Actor) -> void:
	if a.in_countdown:
		return  # down at 0 HP, clinging to life
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
		if d <= 5 and d < best_d and (cheb(m.pos, player.pos) <= 6 or cheb(a.pos, player.pos) > 6) and los(a.pos, m.pos):
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
	var n := 0
	for _i in int(m.data.get("summon_count", 2)):
		var p := _free_tile_near(m.pos)
		if p == m.pos:
			break
		var s := Actor.from_monster(sid)
		s.pos = p
		s.last_seen = m.last_seen
		actors.append(s)
		n += 1
	if is_visible_to_player(m):
		say("[color=violet]The %s senses danger and uses Call of the Dead! %d ghouls crawl out of the ground.[/color]" % [m.name, n])


## Stone golem [Suppression]: paralysis, resisted by Magic Resistance, broken by any damage (ch. 25, 103).
func _try_suppress(user: Actor, target: Actor) -> void:
	var u_name := "You" if user.is_player else "The " + user.name
	var t_name := "you" if target.is_player else "the " + target.name
	if rng.randf() < Stats.magic_resist_chance(target.magic_res):
		if fov.has(target.pos):
			say("%s use%s [Suppression], but %s resist%s." % [u_name, "" if user.is_player else "s", t_name, "" if target.is_player else "s"])
		return
	target.status["paralyzed"] = 5
	if fov.has(target.pos) or target.is_player:
		say("[color=violet]%s use%s [Suppression]: %s %s paralysed![/color]" % [u_name, "" if user.is_player else "s", t_name, "are" if target.is_player else "is"])


func _attack(a: Actor, d: Actor, ranged := false) -> void:
	if a.is_player:
		_break_earth_gnome()
		if player.status.has("stealth"):
			player.status.erase("stealth")
	a.status.erase("hidden")
	var shown := fov.has(a.pos) or fov.has(d.pos) or a.faction == Actor.PARTY or d.faction == Actor.PARTY
	var a_name := "You" if a.is_player else a.name
	var d_name := "you" if d.is_player else d.name
	if rng.randf() > Stats.hit_chance(a.agility, d.agility):
		if shown:
			say("%s %s %s." % [a_name, "miss" if a.is_player else "misses", d_name])
		return
	var dmg := maxi(1, int(round(a.atk * rng.randf_range(0.8, 1.25))) - d.phys_res)
	var crit := rng.randf() < 0.06
	if crit:
		dmg = int(dmg * 1.5)
	d.status.erase("hidden")
	if a.poison_on_hit and d.alive():
		if rng.randf() < Stats.poison_resist_chance(d.poison_res):
			if d.is_player:
				say("You shake off the poison.")
		else:
			d.status["poison"] = 4
	if shown:
		var verb := "shoot" if ranged else "hit"
		if not a.is_player:
			verb += "s"
		var col := "tomato" if d.faction == Actor.PARTY else "white"
		say("[color=%s]%s %s %s for %d%s.[/color]" % [col, a_name, verb, d_name, dmg, " (critical!)" if crit else ""])
	_hurt(d, dmg, a, "dead")


## All damage goes through here: it breaks paralysis, wakes sleepers, starts countdowns and kills.
func _hurt(d: Actor, dmg: int, attacker: Actor, reason: String) -> void:
	if d.is_player:
		_player_attacked = attacker != null
	if d.status.has("paralyzed"):
		d.status.erase("paralyzed")
		if fov.has(d.pos):
			say("The pain breaks %s paralysis." % ("your" if d.is_player else "the %s's" % d.name))
	if d.in_countdown:
		d._regen_acc = 0.0  # repeated damage keeps you from recovering (ch. 917)
		return
	d.hp -= dmg
	if d.is_player and d.hp > 0 and d.hp < d.max_hp * 0.02:
		if Profile.grant_achievement(profile, "hp_below_2", 1):
			say("[color=gold]Achievement Unlocked — HP has fallen below 2%. Mental Power permanently +1.[/color]")
			_apply_player_stats(false)
	if d.faction == Actor.MONSTER and d.data.has("summon") and not d.status.has("summoned") \
			and d.hp > 0 and d.hp < d.max_hp * float(d.data.get("summon_below", 0.5)):
		d.status["summoned"] = -1
		_summon(d)
	if d.hp <= 0:
		if d.faction == Actor.PARTY and d.lifetime < 0 and d.max_mental > 0:
			d.hp = 0
			d.in_countdown = true
			d._regen_acc = 0.0
			if d.is_player:
				_death_reason = reason
				say("[color=tomato]Warning: the character's HP has reached 0%. The countdown begins.[/color]")
			else:
				say("[color=tomato]%s's HP has reached 0%%. Countdown begins.[/color]" % d.name)
			return
		_kill(d, attacker)



func _kill(d: Actor, killer: Actor) -> void:
	actors.erase(d)
	if d.is_player:
		say("[color=tomato]You collapse...[/color]")
		_end(_death_reason)
		return
	if d.faction == Actor.PARTY:
		if d.id == "ainar":
			d.companion["alive"] = false
			ally_died = true
			say("[color=tomato]Ainar is dead.[/color]")
			if Profile.grant_achievement(profile, "first_companion_death", 1):
				say("[color=gold]Achievement Unlocked — First companion character death. Mental Power permanently +1.[/color]")
				_apply_player_stats(false)
		else:
			say("%s falls apart." % d.name)
		return
	if killer != null and killer.faction == Actor.PARTY:
		kills += 1
		if fov.has(d.pos):
			say("You have defeated %s." % ("the " + d.name))
		_reward_party(d)
	map.add_ground(d.pos, {"kind": "stone", "monster": d.id})
	var ess: String = d.data.get("essence", "")
	if ess != "" and rng.randf() < float(d.data.get("essence_chance", 0.0)):
		var colors := GameData.essence_colors(ess)
		var col: String = colors[rng.randi_range(0, colors.size() - 1)]
		map.add_ground(d.pos, {"kind": "essence", "id": ess, "color": col, "dropped_at": seconds})
		say("[color=gold]An essence rises from the %s's body![/color]" % d.name)


## EXP is shared by the bonded party; each member only learns a species once (ch. 22, 23).
func _reward_party(d: Actor) -> void:
	var rank := int(d.data.get("grade", 9))
	var gain := Profile.record_kill(profile, d.id, rank)
	if d.mutant:
		gain += Rules.MUTANT_BONUS_EXP
	if gain > 0:
		say("EXP +%d%s" % [gain, " (mutant bonus)" if d.mutant else ""])
		_gain_exp(gain)
	var a := ally()
	if a != null and a.alive():
		var g2 := Profile.record_kill(a.companion, d.id, rank) + (Rules.MUTANT_BONUS_EXP if d.mutant else 0)
		if g2 > 0 and Profile.add_exp(a.companion, g2) > 0:
			say("[color=gold]Ainar's level has increased (level %d).[/color]" % int(a.companion["level"]))
			_refresh_companion(a)


func _gain_exp(amount: int) -> void:
	exp_gained += amount
	var gained := Profile.add_exp(profile, amount)
	if gained > 0:
		levels_gained += gained
		_apply_player_stats(false)
		say("[color=gold]The character's level has increased. Soul Power +%d. Maximum absorbable Essences +%d.[/color]" % [
			Stats.soul_power_from_levels(int(profile["level"])) - Stats.soul_power_from_levels(int(profile["level"]) - gained), gained])


func _apply_player_stats(full: bool) -> void:
	var s := Profile.player_stats(profile)
	var ratio := float(player.hp) / player.max_hp if player.max_hp > 1 else 1.0
	player.max_hp = int(s["max_hp"])
	player.max_sp = int(s["max_sp"])
	player.atk = int(s["atk"])
	player.phys_res = int(s["phys_res"])
	player.magic_res = int(s["magic_res"])
	player.pain_res = int(s["pain_res"])
	player.agility = int(s["agility"])
	player.speed = maxi(10, int(s["speed"]))
	player.perception = int(s["perception"])
	player.poison_res = int(s["poison_res"])
	player.threat = int(s["threat"])
	player.regen_per_hour = float(s["regen"])
	player.max_mental = int(s["mental"])
	_appetite = int(s["appetite"])
	if full:
		player.hp = player.max_hp
		player.sp = player.max_sp
		player.mental = player.max_mental
	else:
		if not player.in_countdown:
			player.hp = clampi(int(round(ratio * player.max_hp)), 1, player.max_hp)
		player.sp = minf(player.sp, player.max_sp)
		player.mental = minf(player.mental, player.max_mental)
	player.poison_on_hit = Profile.has_passive(profile, "poison_strike")
	_tracker_nose = Profile.has_passive(profile, "tracker_nose")


## Rebuilds Ainar's stats after a level up or an essence.
func _refresh_companion(a: Actor) -> void:
	var fresh := Actor.make_companion(a.companion)
	var ratio := float(a.hp) / a.max_hp if a.max_hp > 0 else 1.0
	a.max_hp = fresh.max_hp
	a.hp = clampi(int(round(ratio * a.max_hp)), 0 if a.in_countdown else 1, a.max_hp)
	a.atk = fresh.atk
	a.phys_res = fresh.phys_res
	a.magic_res = fresh.magic_res
	a.agility = fresh.agility
	a.poison_res = fresh.poison_res
	a.max_mental = fresh.max_mental
	a.regen_per_hour = fresh.regen_per_hour


func _break_earth_gnome() -> void:
	if player.status.has("earth_gnome"):
		player.status.erase("earth_gnome")
		player.status.erase("stealth")
		say("Your camouflage breaks.")


## Perception: every turn, a chance to notice each hidden trap next to you.
func _spot_traps() -> void:
	for d in DIRS8:
		var p := player.pos + d
		if map.traps.has(p) and not map.traps[p] and rng.randf() < Stats.trap_spot_chance(player.perception):
			map.traps[p] = true
			say("You spot a goblin trap.")


func _on_player_entered(p: Vector2i) -> void:
	if map.traps.has(p) and map.traps[p]:
		map.traps.erase(p)
		say("You carefully disarm the goblin trap.")
	elif map.traps.has(p):
		map.traps.erase(p)
		player.status["immobile"] = 3
		say("[color=tomato]Snap! A goblin trap bites your leg (6 damage). You're stuck for a moment.[/color]")
		_hurt(player, 6, null, "dead")
		if over:
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
		_touch_stele(p)


## Floor steles: the first explorer to touch one in a cycle opens it for everyone and earns EXP. Rival
## parties race for them too; the fastest guides reach one in about 6 hours (ch. 22, 49, 89, 151).
func _touch_stele(p: Vector2i) -> void:
	var dest: String = map.portals[p]
	var deeper := int(GameData.floor_def(dest)["depth"]) > int(map.def()["depth"])
	if deeper and not map.steles_opened.has(p):
		map.steles_opened[p] = true
		if seconds < int(map.stele_rival_time.get(p, 0)):
			say("You touch the floor stele. It turns into a sphere of light: you're the first to open it this cycle!")
			say("EXP +%d" % Rules.STELE_EXP)
			_gain_exp(Rules.STELE_EXP)
		else:
			say("The stele is already a sphere of light: another party opened it before you.")
	say("A portal shimmers here, leading to the %s. Press Enter to step through." % GameData.floor_def(dest)["name"])


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


## Unabsorbed essences fade after about 30 minutes (ch. 104, 374, 518).
func _fade_essences() -> void:
	for p in map.ground.keys():
		var list: Array = map.ground[p]
		for i in range(list.size() - 1, -1, -1):
			var e: Dictionary = list[i]
			if e["kind"] == "essence" and seconds - int(e.get("dropped_at", seconds)) >= Rules.ESSENCE_FADE_SECONDS:
				list.remove_at(i)
				if fov.has(p):
					say("The %s fades into the air." % GameData.essence(e["id"])["name"])
				if pending_essence == e["id"] and p == player.pos:
					pending_essence = ""
		if list.is_empty():
			map.ground.erase(p)


func _describe_essence(e: String, color: String) -> String:
	var ess := GameData.essence(e)
	var parts: Array[String] = []
	var stats: Dictionary = ess.get("stats", {})
	for k in stats:
		parts.append("%s %+d" % [Stats.LABELS.get(k, k), int(stats[k])])
	var out := "Stats: " + ", ".join(parts)
	var active := GameData.essence_active(e, color if color != "" else GameData.essence_colors(e)[0])
	if active != "":
		out += " | Active: " + SKILLS[active]["name"]
	if ess.get("passive", "") != "":
		out += " | Passive: " + PASSIVES[ess["passive"]]
	return out


# --- Floors, closing and spawning --------------------------------------------------------------

## Each floor closes at its own time (1F end of Day 7, 2F end of Day 10, ch. 13, 53). When the 1st floor
## closes, the portals leading back to it vanish and people on the 2nd floor stay until it closes too.
func _check_closing() -> void:
	if over:
		return
	for floor_id in floors:
		if floor_id in closed_floors:
			continue
		if seconds >= int(GameData.floor_def(floor_id)["closes_day"]) * Rules.DAY_SECONDS:
			closed_floors.append(floor_id)
			if floor_id == map.floor_id:
				say("[color=gold]A blinding light: the %s is closing. You are pulled back to Rafdonia.[/color]" % map.def()["name"])
				_end("closed")
				return
			say("[color=gold]The %s has closed. The way back is gone; this floor stays open until the end of Day %d.[/color]" % [
				GameData.floor_def(floor_id)["name"], int(map.def()["closes_day"])])


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
		var fm := DungeonGenerator.generate(floor_id, rng)
		for p in fm.portals:
			var lo: float = Rules.RIVAL_STELE_HOURS[0]
			var hi: float = Rules.RIVAL_STELE_HOURS[1]
			fm.stele_rival_time[p] = int(rng.randf_range(lo, hi) * 3600.0)
		floors[floor_id] = fm
	map = floors[floor_id]

	var start := map.random_floor_tile(rng)
	for p in map.portals:
		if map.portals[p] == from_floor:
			start = p
	player.pos = start
	var separate := from_floor == "" and not bonded
	for a in actors:
		if a != player:
			a.pos = map.random_floor_tile(rng) if separate else player.pos
			a.pos = _free_tile_near(a.pos)
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
	say("[b]%s[/b] (closes at the end of Day %d)" % [map.def()["name"], int(map.def()["closes_day"])])


func _monster_count() -> int:
	var n := 0
	for a in actors:
		if a.faction == Actor.MONSTER:
			n += 1
	return n


## Monster numbers grow every day (ch. 8, 23): the cap follows the floor's day multipliers.
func _monster_cap() -> int:
	var mult: Array = map.def().get("cap_by_day", [1.0])
	var m: float = mult[mini(day() - 1, mult.size() - 1)]
	return int(round(int(map.def()["max_monsters"]) * m))


func _respawn() -> void:
	var due: int = _next_respawn.get(map.floor_id, int(map.def()["respawn_every"]))
	if seconds < due:
		return
	_next_respawn[map.floor_id] = seconds + int(map.def()["respawn_every"])
	if _monster_count() < _monster_cap():
		_spawn_group(12)


func _spawn_group(min_dist: int) -> void:
	var d := map.def()
	var p := map.random_floor_tile(rng)
	if cheb(p, player.pos) < min_dist or fov.has(p) or actor_at(p) != null:
		return
	var regions: Dictionary = d["regions"]
	var table: Array = regions.get(map.region_at(p), regions["C"])
	var first: String = table[rng.randi_range(0, table.size() - 1)]
	var pack: Array = d["pack"]
	var count := rng.randi_range(int(pack[0]), int(pack[1]))
	var by_day: Dictionary = d.get("pack_by_day", {})
	if by_day.has(first):
		# e.g. deathfiends come alone on Day 1, in pairs on Day 2 and in threes after (ch. 24).
		var sizes: Array = by_day[first]
		count = int(sizes[mini(day() - 1, sizes.size() - 1)])
	var outer := DungeonGenerator.is_outer(map, p)
	var mutant_chance := float(d.get("mutant_chance", 0.0)) * (2.0 if outer else 0.5)
	for i in count:
		var spot := p if i == 0 else _free_tile_near(p)
		if actor_at(spot) != null:
			continue
		var mid: String = first if by_day.has(first) or i == 0 else table[rng.randi_range(0, table.size() - 1)]
		var m := Actor.from_monster(mid, rng.randf() < mutant_chance)
		m.pos = spot
		m.home = spot
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
	var torch_r := Rules.TORCH_RADIUS if torch_seconds > 0 else 0
	var dark_r := Stats.dark_radius(player.perception)
	for dy in range(-far, far + 1):
		for dx in range(-far, far + 1):
			var p := player.pos + Vector2i(dx, dy)
			if not map.in_bounds(p):
				continue
			var d2 := dx * dx + dy * dy
			var seen := d2 <= dark_r * dark_r + dark_r \
				or d2 <= torch_r * torch_r + torch_r \
				or (not map.is_dark(p) and d2 <= Rules.LIGHT_RADIUS * Rules.LIGHT_RADIUS + Rules.LIGHT_RADIUS)
			if seen and los(player.pos, p):
				fov[p] = true
				map.explored[map.idx(p)] = 1
