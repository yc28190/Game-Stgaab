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
| **Dungeon run** (inner) | Turn-based grid exploration. Exploring, a turn is 3 minutes; in combat the clock slows to 6-second turns. Fight, pick up mana stones, find portals. Manage HP, belly, light and the clock: the 1st floor closes at the end of **Day 7**, the 2nd at the end of **Day 10**. |
| **Rafdonia** (outer) | Sell mana stones and essences, buy food, potions, torches and gear, recruit Ainar, pay for a binding spell, get the Undying engraving, then enter the labyrinth again next month. One day passes in the city per run, then about 30 days of living costs. |
| **Year** (meta) | 12 runs a year (the last cycle lasts 35 days because of the 13th-month festival). The tax is **700,000** the first year and rises by 100,000 every year, with a 10% exchange fee on magic stones from year 2. If you can't pay, it's game over (ch. 18). |

### Mechanics from the novel

- **The labyrinth** opens at midnight on the 1st of each month. You start somewhere random on the 1st floor. When your floor closes, you return to the city with your loot. Once the 1st floor closes, the way back down from the 2nd floor is gone.
- **Crystal Cave (1st floor):** goblins in the north (with hidden traps), ghouls in the west (they wait motionless until you come close), fast blade wolves in the east, hidden gnomes in the south. Crystals light the floor, except the dark outer edge and the central dark zone. In the dark you see 2 tiles, but monsters only notice you from 3 tiles away. A **magic torch** lights the dark for both sides.
- **Four 2nd floors:** north to the Goblin Forest, east to the Beast Den, west to the Land of the Dead, south to the Rock Desert (ch. 27, 50, 89, 110). Monster numbers grow every day. **Mutants** (stronger variants, +1 bonus EXP) are more common in the outer areas. Deathfiends stay in their territory and call 10 ghouls when hurt. Stone golems paralyse with [Suppression], which Magic Resistance can resist and any damage breaks.
- **EXP:** each monster **species** gives EXP only once, like filling a bestiary (rank 9 = 1, +1 per rank). The first explorer to touch a floor stele each cycle gets +2 EXP, and rival parties race you for it. Levels need 6 / 30 / 150 EXP (capped at level 4 for now) and give **+10 Soul Power and one essence slot**, nothing else, and no heal (ch. 22, 35, 50).
- **Essences:** drop very rarely (0.5%). Their **colour** decides the active skill. You can't hold the same essence twice, and an essence fades about 30 minutes after it drops. Absorb it, let Ainar absorb it, seal it in a vial to sell, or decide later (G).
- **Death countdown:** at 0 HP you keep acting while the countdown burns 3 Mental Power per second (18 per combat turn). Heal above 1% HP before it runs out, or die. Natural Regeneration, boosted by Mental Power, can pull you through (ch. 35, 857).
- **Potions** heal at once, but the regeneration is agonising: you lose 4 combat turns, 1 fewer per 20 Pain Resistance (ch. 5).
- **Ainar** (Angry Rhino Inn) has her own level, bestiary and essences, eats bread from your bag, and is your **night friend** when you camp. Without a binding spell (15,000 stones) she starts elsewhere on the floor. She takes **20% of the mana stones** (8/2 split). If her countdown runs out, she dies for good.
- **Stats:** HP, SP (Soul Power, the MP of essence skills), Mental Power, Strength, Physical, Magic and Pain Resistance, Natural Regeneration, Agility, Speed, Perception, Poison Resistance, Appetite and Threat Level. Each one has a real effect (see `scripts/core/stats.gd`). The **Character** tab (or **P** in the labyrinth) shows every stat with its sources.
- **Death:** you are dragged out of the labyrinth but lose everything you carried. Levels and essences stay. The result of a run is saved the moment it ends, so a death can't be undone by reloading. Quitting in the middle of a run abandons it.
- **Money:** if you can't pay the month's living costs, you sleep in the street and start the next run hungry and sore.

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
| Reopen the essence under you | G |
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

## Roadmap

See [TODO.md](TODO.md): every mechanic and gameplay loop extracted from the novel (ch. 1–944), with chapter references, what the prototype already does, and priorities.
