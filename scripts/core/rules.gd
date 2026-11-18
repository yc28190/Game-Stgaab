class_name Rules
extends RefCounted
## Tunable game rules. Values marked "novel" come from Surviving the Game as a Barbarian.

# --- Time ------------------------------------------------------------------------------------------
## A turn while exploring lasts 3 minutes. In combat the game slows down to 6-second turns (D&D-style),
## so fights, the death countdown and potion pain play out in seconds while travel eats hours.
const EXPLORE_SECONDS := 180
const COMBAT_SECONDS := 6
const DAY_SECONDS := 86400

const SATIETY_MAX := 100.0
const SATIETY_PER_HOUR := 2.5  # a full belly lasts ~40 hours

const INVENTORY_SLOTS := 16

const LIGHT_RADIUS := 7
const DARK_RADIUS := 2
const TORCH_RADIUS := 6
const DARK_DETECT_RADIUS := 3  # monsters spot an unlit target in the dark from this far

const CAMP_TURNS := 120  # 6 hours of sleep (exploration turns)
const REST_TURNS := 40

# --- Progression (novel ch. 22, 35, 50, 166, 264) -----------------------------------------------------
## Cumulative EXP needed to reach each level: index = level. Levels are capped at 4 for now.
const LEVEL_THRESHOLDS := [0, 0, 6, 30, 150]
const MAX_LEVEL := 4
const SOUL_POWER_PER_LEVEL := 10  # +10 per level up to level 5, +30 from level 6
const SOUL_POWER_PER_LEVEL_HIGH := 30
const STELE_EXP := 2  # first opener of a floor stele in a cycle (ch. 22, 89)
## Rival explorers open each stele between these many hours after the labyrinth opens (ch. 49, 89, 151).
const RIVAL_STELE_HOURS := [6.0, 30.0]
const MUTANT_BONUS_EXP := 1  # high variant / mutant bonus (ch. 35, 587)

# --- Essences (novel ch. 24, 35, 104, 374, 518, 622) ---------------------------------------------------
const ESSENCE_DROP_CHANCE := 0.005  # "abysmal" outside rifts
const ESSENCE_FADE_SECONDS := 1800  # an unabsorbed essence fades after about 30 minutes

# --- Death countdown (ch. 35, 428, 802, 857, 917) -------------------------------------------------------
const COUNTDOWN_MENTAL_PER_SECOND := 3
const BASE_MENTAL_POWER := 35  # Bjorn's "Mind 35" at ch. 2

# --- Potions (ch. 5, 35) --------------------------------------------------------------------------------
const POTION_PAIN_TURNS := 4  # combat turns lost writhing in pain
const PAIN_RES_PER_TURN := 20  # each 20 Pain Resistance removes one of them

# --- City (ch. 18, 20, 22, 231) --------------------------------------------------------------------------
const MONTHS_PER_YEAR := 12  # 12 openings; the 13th month is a 5-day festival, so the last cycle lasts 35 days
const FIRST_YEAR_TAX := 700000
const TAX_INCREASE_PER_YEAR := 100000
const EXCHANGE_FEE := 0.10  # charged on magic stones from the second year (ch. 18)
const LIVING_COST_PER_DAY := 300  # Angry Rhino Inn bed (ch. 20)
const BONDING_COST := 15000  # binding spell for two rank-9 explorers (ch. 22)
const ALLY_SHARE := 0.2  # Ainar's 8/2 split (ch. 20)
## Sleeping rough after failing to pay living costs: the next run starts weakened.
const ROUGH_SLEEP_BELLY := 60.0
const ROUGH_SLEEP_HP := 0.8

const UNDYING_PRICE := 600000  # ch. 21: discounted from 800,000
