class_name Actor
extends RefCounted
## Anything that moves and fights in the dungeon: the player, allies, summons and monsters.

enum { PARTY, MONSTER }

var id := ""
var name := ""
var faction := MONSTER
var is_player := false
var glyph := "?"
var color := Color.WHITE
var pos := Vector2i.ZERO
var hp := 1
var max_hp := 1
var max_sp := 0
var sp := 0.0
## Mental Power: burnt by the death countdown (3 per second).
var mental := 0.0
var max_mental := 0
var atk := 1
var phys_res := 0
var magic_res := 0
var pain_res := 0
## Natural Regeneration in HP per hour.
var regen_per_hour := 0.0
var agility := 10
var speed := 100
var perception := 10
var poison_res := 0
var threat := 5
var energy := 0
var sight := 7
var ai := "melee"
var attack_range := 1
var poison_on_hit := false
## Monster regeneration: HP per turn (deathfiend's Preservation of the Flesh).
var regen := 0
var data := {}
var mutant := false
## Where a territorial monster lives; it won't chase far from here (deathfiends, ch. 24).
var home := Vector2i(-1, -1)
## Status name -> turns left (-1 = until removed).
var status := {}
var cooldowns := {}
var last_seen := Vector2i(-1, -1)
var wander_goal := Vector2i(-1, -1)
## Turns before a summoned actor disappears (-1 = permanent).
var lifetime := -1
## True while at 0 HP: the death countdown is running.
var in_countdown := false
## Companion only: belly and the saved progression dict (level, bestiary, essences...).
var satiety := Rules.SATIETY_MAX
var companion := {}
## Fractional regeneration carried between turns.
var _regen_acc := 0.0


func alive() -> bool:
	return hp > 0 or in_countdown


static func from_monster(monster_id: String, is_mutant: bool = false) -> Actor:
	var d := GameData.monster(monster_id)
	var a := Actor.new()
	a.id = monster_id
	a.name = d["name"]
	a.faction = MONSTER
	a.glyph = d["glyph"]
	a.color = Color(d["color"])
	a.max_hp = int(d["hp"])
	a.atk = int(d["atk"])
	a.phys_res = int(d.get("phys_res", 0))
	a.magic_res = int(d.get("magic_res", 0))
	a.agility = int(d.get("agility", 10))
	a.poison_res = int(d.get("poison_res", 0))
	a.speed = int(d.get("speed", 100))
	a.sight = int(d.get("sight", 7))
	a.ai = d.get("ai", "melee")
	a.attack_range = int(d.get("range", 1))
	a.poison_on_hit = bool(d.get("poison", false))
	a.regen = int(d.get("regen", 0))
	a.data = d
	if d.get("hidden", false):
		a.status["hidden"] = -1
	if is_mutant:
		# Mutants: stronger variants, more common in the outer areas (ch. 12), with a bonus EXP (ch. 35).
		a.mutant = true
		a.name = "Mutant " + a.name
		a.max_hp = int(round(a.max_hp * 1.6))
		a.atk += 2
		a.phys_res += 1
		a.agility += 2
		a.color = a.color.lerp(Color("#ff4fd8"), 0.45)
	a.hp = a.max_hp
	return a


## Builds an ally from its saved companion dict (Ainar has her own level, bestiary and essences).
static func make_companion(c: Dictionary) -> Actor:
	var s := Profile.companion_stats(c)
	var a := Actor.new()
	a.id = c["id"]
	a.name = "Ainar"
	a.faction = PARTY
	a.glyph = "A"
	a.color = Color("#e05a4f")
	a.companion = c
	a.max_hp = int(s["max_hp"])
	a.hp = a.max_hp
	a.atk = int(s["atk"])
	a.phys_res = int(s["phys_res"])
	a.magic_res = int(s["magic_res"])
	a.pain_res = int(s["pain_res"])
	a.agility = int(s["agility"])
	a.poison_res = int(s["poison_res"])
	a.threat = int(s["threat"])
	a.max_mental = int(s["mental"])
	a.mental = a.max_mental
	a.regen_per_hour = float(s["regen"])
	a.sight = 7
	return a
