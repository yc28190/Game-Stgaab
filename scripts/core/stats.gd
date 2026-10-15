class_name Stats
extends RefCounted
## The character stats from the novel and the rules that turn them into gameplay.

## Display order on the character sheet.
const ORDER := [
	"max_hp", "max_sp", "atk", "strength", "phys_res", "magic_res",
	"agility", "speed", "perception", "poison_res", "appetite", "threat",
]
## Shown in the short summaries (town status panel).
const SUMMARY := ["max_hp", "max_sp", "atk"]

const LABELS := {
	"max_hp": "HP",
	"max_sp": "SP (Soul Power)",
	"atk": "Attack",
	"strength": "Strength",
	"phys_res": "Physical Resistance",
	"magic_res": "Magical Resistance",
	"agility": "Agility",
	"speed": "Speed",
	"perception": "Perception",
	"poison_res": "Poison Resistance",
	"appetite": "Appetite",
	"threat": "Threat Level",
}

const EFFECTS := {
	"max_hp": "Health. At 0 you collapse.",
	"max_sp": "Soul power spent by essence skills. Recovers 1 every 5 turns, faster while sleeping.",
	"atk": "Damage per hit: Strength / 2 + weapon.",
	"strength": "Raw power. Every 2 points add 1 Attack.",
	"phys_res": "Removed from every physical hit you take.",
	"magic_res": "Removed from every magic hit you take (no monster uses magic yet).",
	"agility": "Each point above the enemy's: +1.5% to hit it and +1.5% to dodge it.",
	"speed": "100 = normal. Higher speed means monsters act less often per action you take.",
	"perception": "Spot hidden traps next to you (3% per point each turn), see hidden gnomes from further, see further in the dark.",
	"poison_res": "Each point gives a 3% chance to shake off poison.",
	"appetite": "10 = normal. Your belly empties faster with higher appetite.",
	"threat": "Monsters attack the party member with the highest threat, unless another is much closer.",
}

## Bjorn at level 1: a barbarian (high threat, no magic resistance).
const BASE := {
	"max_hp": 50, "max_sp": 20, "strength": 12, "phys_res": 1, "magic_res": 0,
	"agility": 10, "speed": 100, "perception": 10, "poison_res": 0, "appetite": 10, "threat": 12,
}
const PER_LEVEL := {"max_hp": 8, "max_sp": 5, "strength": 2}


static func attack_from_strength(strength: int) -> int:
	return int(strength / 2.0)


static func hit_chance(attacker_agility: int, defender_agility: int) -> float:
	return clampf(0.9 + (attacker_agility - defender_agility) * 0.015, 0.6, 0.98)


static func poison_resist_chance(poison_res: int) -> float:
	return clampf(poison_res * 0.03, 0.0, 0.9)


static func hunger_per_turn(appetite: int) -> float:
	return Rules.SATIETY_PER_TURN * maxi(1, appetite) / 10.0


static func trap_spot_chance(perception: int) -> float:
	return clampf(perception * 0.03, 0.0, 0.9)


## Distance at which a hidden monster (gnome) becomes visible.
static func hidden_reveal_range(perception: int) -> int:
	return 2 + maxi(0, int((perception - 10) / 5.0))


static func dark_radius(perception: int) -> int:
	return Rules.DARK_RADIUS + maxi(0, int((perception - 10) / 10.0))


## How many energy points an actor gains each time the player acts.
static func energy_per_player_action(actor_speed: int, player_speed: int) -> int:
	return int(round(actor_speed * 100.0 / maxi(1, player_speed)))
