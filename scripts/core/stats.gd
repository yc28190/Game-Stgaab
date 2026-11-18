class_name Stats
extends RefCounted
## The character stats from the novel and the rules that turn them into gameplay.

## Display order on the character sheet.
const ORDER := [
	"max_hp", "max_sp", "mental", "atk", "strength", "phys_res", "magic_res", "pain_res",
	"regen", "agility", "speed", "perception", "poison_res", "appetite", "threat",
]
## Shown in the short summaries (town status panel).
const SUMMARY := ["max_hp", "max_sp", "atk"]

const LABELS := {
	"max_hp": "HP",
	"max_sp": "SP (Soul Power)",
	"mental": "Mental Power",
	"atk": "Attack",
	"strength": "Strength",
	"phys_res": "Physical Resistance",
	"magic_res": "Magic Resistance",
	"pain_res": "Pain Resistance",
	"regen": "Natural Regeneration",
	"agility": "Agility",
	"speed": "Speed",
	"perception": "Perception",
	"poison_res": "Poison Resistance",
	"appetite": "Appetite",
	"threat": "Threat Level",
}

const EFFECTS := {
	"max_hp": "Health. At 0 the death countdown starts.",
	"max_sp": "Soul power, the MP of essence skills. Regenerates over time (20% of the maximum per hour), faster while sleeping. +10 per level.",
	"mental": "At 0 HP, the countdown burns 3 Mental Power per second (18 per combat turn); regeneration is boosted by it. At 0 you die.",
	"atk": "Damage per hit: Strength / 2 + weapon.",
	"strength": "Raw power. Every 2 points add 1 Attack.",
	"phys_res": "Removed from every physical hit you take.",
	"magic_res": "3% per point to resist magic effects such as a Stone Golem's Suppression.",
	"pain_res": "Potions make you writhe in pain for 4 combat turns; every 20 points remove one.",
	"regen": "HP regenerated per hour.",
	"agility": "Each point above the enemy's: +1.5% to hit it and +1.5% to dodge it.",
	"speed": "100 = normal. Higher speed means monsters act less often per action you take.",
	"perception": "Spot hidden traps next to you (3% per point each turn), see hidden gnomes from further, see further in the dark.",
	"poison_res": "Each point gives a 3% chance to shake off poison.",
	"appetite": "10 = normal. Your belly empties faster with higher appetite.",
	"threat": "Monsters attack the party member with the highest threat, unless another is much closer.",
}

## A barbarian at level 1 (Bjorn and Ainar): high threat, no magic resistance. Levels don't raise these;
## growth comes from essences, engravings, equipment and achievements (novel ch. 22, 35).
const BASE := {
	"max_hp": 50, "max_sp": 20, "mental": Rules.BASE_MENTAL_POWER, "strength": 12, "phys_res": 1,
	"magic_res": 0, "pain_res": 0, "regen": 2, "agility": 10, "speed": 100, "perception": 10,
	"poison_res": 0, "appetite": 10, "threat": 12,
}


static func attack_from_strength(strength: int) -> int:
	return int(strength / 2.0)


## Soul Power gained from levels: +10 per level up to level 5, +30 per level after (ch. 22, 264).
static func soul_power_from_levels(level: int) -> int:
	var total := 0
	for lvl in range(2, level + 1):
		total += Rules.SOUL_POWER_PER_LEVEL if lvl <= 5 else Rules.SOUL_POWER_PER_LEVEL_HIGH
	return total


static func hit_chance(attacker_agility: int, defender_agility: int) -> float:
	return clampf(0.9 + (attacker_agility - defender_agility) * 0.015, 0.6, 0.98)


static func poison_resist_chance(poison_res: int) -> float:
	return clampf(poison_res * 0.03, 0.0, 0.9)


static func magic_resist_chance(magic_res: int) -> float:
	return clampf(magic_res * 0.03, 0.0, 0.9)


static func hunger_per_second(appetite: int) -> float:
	return Rules.SATIETY_PER_HOUR / 3600.0 * maxi(1, appetite) / 10.0


static func potion_pain_turns(pain_res: int) -> int:
	return maxi(0, Rules.POTION_PAIN_TURNS - int(pain_res / float(Rules.PAIN_RES_PER_TURN)))


## HP regenerated during one combat turn of the death countdown: boosted in proportion to Mental Power.
static func countdown_regen_per_turn(regen_per_hour: float, mental: float) -> float:
	return regen_per_hour * Rules.COMBAT_SECONDS / 3600.0 * maxf(1.0, mental)


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
