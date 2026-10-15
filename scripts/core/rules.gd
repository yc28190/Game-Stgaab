class_name Rules
extends RefCounted
## Tunable game rules. Values marked "novel" come from Surviving the Game as a Barbarian.

const MINUTES_PER_TURN := 3
const LABYRINTH_DAYS := 7  # novel: the labyrinth stays open 7 days, once a month
const TURNS_PER_RUN := 3360  # 7 days * 24 h * 60 min / 3 min per turn

const SATIETY_MAX := 100.0
const SATIETY_PER_TURN := 0.125  # -1 satiety every 8 turns (~1 day for a full belly)
const PLAYER_REGEN_EVERY := 10  # turns per HP regenerated

const INVENTORY_SLOTS := 16

const LIGHT_RADIUS := 7
const DARK_RADIUS := 2
const TORCH_RADIUS := 6
const DARK_DETECT_RADIUS := 3  # monsters spot an unlit target in the dark from this far

const CAMP_TURNS := 120  # 6 hours of sleep
const REST_TURNS := 40

const ANNUAL_TAX := 700000  # novel ch. 18: first-year tax for a barbarian
const MONTHS_PER_YEAR := 12
const MONTHLY_LIVING_COST := 9000  # novel ch. 20: 300 stones/day at the Angry Rhino Inn
const ALLY_SHARE := 0.2  # novel ch. 20: Bjorn offers Ainar an 8/2 split

const UNDYING_PRICE := 600000  # novel ch. 21: discounted from 800,000
