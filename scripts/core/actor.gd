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
var sp := 0
var atk := 1
var phys_res := 0
var magic_res := 0
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
var regen := 0
var regen_every := 0
var data := {}
## Status name -> turns left (-1 = until removed).
var status := {}
var cooldowns := {}
var last_seen := Vector2i(-1, -1)
var wander_goal := Vector2i(-1, -1)
## Turns before a summoned actor disappears (-1 = permanent).
var lifetime := -1


func alive() -> bool:
	return hp > 0


static func from_monster(monster_id: String) -> Actor:
	var d := GameData.monster(monster_id)
	var a := Actor.new()
	a.id = monster_id
	a.name = d["name"]
	a.faction = MONSTER
	a.glyph = d["glyph"]
	a.color = Color(d["color"])
	a.max_hp = int(d["hp"])
	a.hp = a.max_hp
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
	return a


static func make_ainar(level: int) -> Actor:
	var a := Actor.new()
	a.id = "ainar"
	a.name = "Ainar"
	a.faction = PARTY
	a.glyph = "A"
	a.color = Color("#e05a4f")
	a.max_hp = 55 + (level - 1) * 8
	a.hp = a.max_hp
	a.atk = 7 + level
	a.phys_res = 2
	a.agility = 11
	a.threat = 9
	a.sight = 7
	a.regen_every = Rules.PLAYER_REGEN_EVERY
	return a
