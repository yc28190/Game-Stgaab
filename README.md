# Dungeon and Stone

A Pokémon Mystery Dungeon-style roguelike based on the novel **Surviving the Game as a Barbarian**
(*게임 속 바바리안으로 살아남기*). You play Bjorn, son of Yandel, inside *Dungeon and Stone*, the game
from the novel. Monster, essence and price data come from the [STGAAB wiki](https://github.com/yc28190/STGAAB).

Fan project, prototype stage. Graphics are placeholder shapes.

## Play it

**In the browser:** every push builds the game and publishes it to GitHub Pages
(`https://yc28190.github.io/Game-Stgaab/`) once Pages is enabled. See [Publishing](#publishing).

**In the Godot editor:** install [Godot 4.4](https://godotengine.org/download), open `project.godot`, press F5.

## Game loops

| Loop | What happens |
|---|---|
| **Dungeon run** (inner) | Turn-based grid exploration. Every action = 3 minutes. Fight, pick up mana stones, find portals. Manage HP, belly, light, bag space and the clock: the labyrinth closes after **7 days**. |
| **Rafdonia** (outer) | Sell mana stones and essences, buy food, potions, torches and gear, recruit Ainar, get the Undying engraving, then enter the labyrinth again next month. |
| **Year** (meta) | Each run is one month. After 12 months the **700,000-stone tax** is due. If you can't pay, it's game over (novel ch. 18). |

### Mechanics from the novel

- **The labyrinth** opens once a month for 7 days. You start somewhere random on the 1st floor. When it closes, you return to the city with your loot.
- **Crystal Cave (1st floor):** goblins in the north (with hidden traps), ghouls in the west, fast blade wolves in the east, hidden gnomes in the south. Dark zones: you see 2 tiles, but monsters only notice you from 3 tiles away. A **magic torch** lights the dark for both sides.
- **Portals:** north leads to the Goblin Forest (goblin packs and poison archers), west to the Deadlands (ghouls and regenerating deathfiends that summon ghouls). Your first trip through a portal **gives a level** (ch. 22).
- **Essences:** monsters rarely drop one. Absorb it (permanent, **1 slot per level**), seal it in a vial to sell, or leave it. Essences give stats, passives (poison strikes, tracker's nose, regeneration) and active skills (Thief Step, Earth Gnome, Call of the Dead).
- **Ainar** (Angry Rhino Inn) follows you, fights, and is your **night friend**: when you camp, she wakes you before monsters arrive. Alone, you only wake up when you're hit. She takes **20% of the mana stones** (8/2 split).
- **Stats:** HP, SP (soul power), Strength, Physical and Magical Resistance, Agility, Speed, Perception,
  Poison Resistance, Appetite and Threat Level. Each one has a real effect (see `scripts/core/stats.gd`).
  Town shows HP, SP and Attack; the **Character** tab (or **P** in the labyrinth) shows every stat with its sources.
- **Death:** you are dragged out of the labyrinth but lose everything you carried. Levels and essences stay.

## Controls

| Action | Keys |
|---|---|
| Move / attack | Arrow keys, WASD (ZQSD on AZERTY), numpad, or click a tile |
| Diagonals | Q E Z C (A E W C on AZERTY) or numpad 7 9 1 3 |
| Wait | Space, numpad 5 |
| Portal | Enter |
| Bag | I |
| Character stats | P |
| Essence skills | 1-4 |
| Rest / camp | R / T |
| Help | H |

Movement uses physical key positions, so it works on QWERTY and AZERTY keyboards.
Holding a key keeps walking, but when a monster is within 2 tiles every step or attack needs its own key press,
and a held key stops as soon as a new monster comes into view.

## Project layout

```
data/                 Game data (JSON): monsters, essences, items, floors. Each entry cites its chapter.
scripts/core/         Game logic with no rendering, testable headless
  rules.gd            Tunable constants (time, hunger, tax, prices)
  profile.gd          Persistent character: level, essences, equipment, money, months
  dungeon_generator.gd  Random floors: rooms, corridors, regions, dark zones, portals, traps, items
  dungeon_run.gd      Turn engine: movement, combat, AI, hunger, time, essences, camping
  actor.gd, floor_map.gd, game_data.gd
scripts/ui/           Title, town, dungeon view, HUD, report screens (built in code, no art assets)
scripts/autoload/game.gd  Save/load (user://save.json, browser storage on the web)
tests/run_tests.gd    Headless test suite, including a bot that plays whole runs
```

To balance the game, edit `data/*.json` and `scripts/core/rules.gd`. Stat values the novel doesn't give
(for example the Goblin essence) are placeholders and are marked as such in `data/essences.json`.

## Development

```sh
godot --headless --import                       # first time: build the class cache
godot --headless -s res://tests/run_tests.gd    # run the tests
godot --headless --export-release "Web" build/web/index.html
```

## Publishing

`.github/workflows/web.yml` runs the tests, exports the Web build and deploys it to GitHub Pages on every push.
One-time setup: in the repo on GitHub, open **Settings → Pages** and set **Source** to **GitHub Actions**.
The `github-pages` environment only accepts deployments from the default branch unless you add other
branches under **Settings → Environments → github-pages**.

## Roadmap ideas

- Real pixel-art tiles and sprites, animations, sound
- More floors (Beasts' Lair, Rock Desert, 3rd floor+), rifts as special dungeons (Blood Citadel), floor bosses
- Equipment drops, numbered items, Erwen and more recruitable companions with ally tactics
- Other adventurers and pillagers as smart enemies
- Spirit engraving tree, more essence skills, a selectable "essence build"
