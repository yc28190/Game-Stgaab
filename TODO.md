# TODO: game mechanics from the novel

Every game mechanic and gameplay loop found in *Surviving the Game as a Barbarian* (chapters 1–944,
`yc28190/STGAAB-source`), turned into an implementation backlog.

**How this list was built.** The novel prints its game system as plain lines ("Strength increases by +15.",
"EXP +3", "Achievement Unlocked", status windows). We extracted every system message, every stat name, every
bracketed skill or term, and every passage where Bjorn explains a rule ("in the game…"). We cross-checked them
against the "Mechanics" sections of the [STGAAB wiki](https://github.com/yc28190/STGAAB) (514 place pages).
`(ch. N)` points to the chapter. Per-location details such as rooms, boss phases and hidden-piece steps are
in the wiki's `Places/` pages and are only summarised here.

**Legend:** `[x]` done in the prototype · `[~]` partly done or simplified · `[ ]` to do
**Priority:** **P1** next milestones (1st–2nd floor feel like the novel) · **P2** mid game (floors 3–5,
clans, gear) · **P3** late game and story content

---

## 0. The loops and the design pillars

### Gameplay loops
- **Inner loop: a floor.** Explore from a random start → fight → collect magic stones and rare essences →
  find the floor stele or portal → go up or keep farming. Manage HP, MP/Soul Power, stamina, hunger, thirst,
  light, bag space and the clock. Rest with a night companion.
- **Expedition loop: one month.** The labyrinth opens at 00:00 on the 1st of each month. Each floor has its own
  closing time (1F 7 days, 2F 10, 3F 15, 5F 30, 7F 75). Explorers return at noon to the Dimensional Plaza and
  only **one day** passes in the city. Exchange stones at the checkpoint, sell, repair, train, upgrade, re-form
  the party, then enter again next month (ch. 15–16, 19, 146).
- **Year loop.** 12 cycles plus the 5-day **13th month** of festivals, then the race-based tax (≈700k → 800k
  for a barbarian) or public execution (ch. 18, 231).
- **Career loop.** Guild rank 9 → 1, levels, essence build, spirit-engraving stages, Numbers Items, team →
  clan → clan rank, fame, noble titles, tribe chief.
- **Knowledge loop: the meta.** "The difficulty of Dungeon & Stone is determined by how many Hidden Pieces you
  know" (ch. 503). Hidden pieces, special conditions and achievements reward exploration and lore.

### Pillars to respect (Bjorn's own descriptions of the game)
- "Unkind, but not unreasonable" (ch. 485). There are no unbeatable hidden pieces (ch. 483) and every boss has a
  counter.
- "A team game" (ch. 44, 134, 226, 426, 440, 658), forcing party play. "The core is **matchups**" (ch. 590).
- "The core is luck and grinding" (ch. 679). "Time is very important" (ch. 665).
- "Death is part of daily life" (ch. 63). In the game one death meant game over (ch. 208).
- "You have to develop your character flexibly" (ch. 858). Gear matters as much as essences (ch. 761).

---

## 1. Fix the prototype where it contradicts the novel (P1)

Done in the audit fix (see the decisions in brackets, made with the architect where the novel gives no numbers).

- [x] **EXP once per monster species**, like filling a bestiary: rank 9 = 1 EXP, +1 per rank (ch. 22, 50).
  Shared by the bonded party, each member with their own bestiary (ch. 23). Mutants give +1 bonus EXP.
  - [ ] Still to do: rare species with huge EXP (Soul Eater +177, ch. 264), Floor Lords +100, guardian bonus +3,
    a per-playthrough reset (ch. 907).
- [x] **Cumulative EXP thresholds** 6 / 30 / 150. *[Capped at level 4 until the novel's later thresholds are
  known; they "explode" after that (ch. 50).]*
- [x] **Floor steles:** the first explorer to touch one in a cycle gets +2 EXP (ch. 22, 89). Rival parties open
  each stele 6–30 hours after the opening (ch. 49, 89, 151). The "first portal = free level" rule is gone.
- [x] **Level up:** +10 Soul Power (+30 from level 6) and +1 essence slot, nothing else, no HP refill (ch. 22, 35,
  264). HP and Strength no longer grow with levels.
- [ ] **EXP and levels can be lost:** Soul Slash (ch. 32), cursed boxes (ch. 591), petrification (ch. 620).
- [x] **Four edge portals** on the 1st floor: north to Goblin Forest, east to Beast Den, west to Land of the Dead,
  south to Rock Desert (ch. 27, 50, 89, 110). Beast Den and Rock Desert added with the species of ch. 50 and 89;
  "Deadlands" renamed Land of the Dead with its undead from ch. 23.
- [x] **Each floor closes at its own time:** 1F end of Day 7, 2F end of Day 10. When 1F closes, the way back
  vanishes and the 2nd floor stays open (ch. 13, 53). *[Combat slows the clock to 6-second turns.]*
  - [ ] Later floors: 3F Day 15, 5F Day 30, 6F Day 60, 7F Day 75 (ch. 115, 166, 284, 808).
- [x] **Monster groups grow every day**, tripling from Day 3 in the Land of the Dead; deathfiends come alone, then
  in pairs, then in threes (ch. 8, 23–24).
- [x] ~~Thirst~~: not wanted in this game (architect's decision).
- [x] **Potions hurt:** they heal at once, then you lose 4 combat turns writhing, 1 fewer per 20 Pain Resistance
  (ch. 5, 35). *[Numbers chosen by the architect.]*
  - [ ] Divine healing (painless) once priests exist; high-grade potions that cure paralysis (ch. 26).
- [x] **Essence colour** decides the active skill; the passive is the same for every colour. *[The colours of
  our five essences aren't in the novel or the wiki: they're placeholders, one colour each.]*
  - [ ] Rainbow guardian essences once rifts exist (ch. 583).
- [x] **No duplicate essences** (ch. 622); unabsorbed essences **fade after 30 minutes** (ch. 104, 374, 518).
  *[Drop rate 0.5% outside rifts.]* The decision can be postponed and reopened with G.
- [x] **Economy balanced on income:** rank 9 stones 700, rank 8 3,500 (the novel's 1:5 ratio), giving about
  70k–105k for a full 7-day run (ch. 18: about 100,000).
- [x] **Bonding:** a binding spell at the guild costs 15,000 (ch. 22); without it Ainar starts elsewhere.
- [ ] **Party size:** 5 at first, 6 after the Bonding update (ch. 11, 351, 871). Only one companion exists so far.
- [x] **Soul Power is the MP for essence skills** (ch. 22, 70, 71, 100). It now regenerates in proportion to its
  maximum (20% per hour, ch. 383).
  - [ ] Mana for mages, divine power for priests, stamina (ch. 166).
- [x] **Death countdown:** at 0 HP you keep acting while the countdown burns 3 Mental Power per second (18 per
  6-second combat turn); Natural Regeneration, boosted by Mental Power, or a heal above 1% cancels it (ch. 35, 428,
  857). Applies to Ainar too. Achievement for surviving it (Mental +10).
- [x] **Undying Imprint stage 1:** Natural Regeneration greatly increases and physical stats +20 (ch. 21).
  *[Translated as regeneration +4 HP/hour, Strength +2, Physical Resistance +1.]*
- [x] **Ainar:** her own level, bestiary and essences, barbarian threat, eats from your bag, permanent death
  (with the "first companion death" achievement, Mental +1).
- [x] **Monster behaviour:** ghouls wait motionless (ch. 11), deathfiends stay in their territory and call 10
  ghouls when hurt (ch. 24), stone golems use [Suppression], which Magic Resistance resists and damage breaks
  (ch. 25, 103). Mutants, stronger in the outer areas (ch. 12).
- [x] **Darkness on the 1st floor:** only the outer area and the central dark zone (ch. 4, 27).
- [x] **Tax:** 700k, then +100k every year, with a 10% exchange fee from year 2 (ch. 18). The last cycle lasts 35
  days (13th month). *[Increase and fee chosen by the architect.]*
- [x] **Saving:** a run's result is saved the moment it ends, so a death can't be undone; quitting mid-run still
  abandons the run (architect's decision).
- [x] **Sleeping rough:** if you can't pay the month's living costs, you pay what you have and start the next run
  hungry and sore; money never goes negative.
- [x] Magic stone storage stays unlimited (architect's decision).
- [~] **Death.** The original game had permadeath (ch. 208). We currently use "dragged out, lose everything you
  carried". Decide on a difficulty option: permadeath as hardcore mode.

---

## 2. Character

### 2.1 Creation and races
- [ ] Choose a race: Barbarian, Human, Fairy, Dwarf, Beastkin, Dragonkin (the six tribes, ch. 43).
  - Barbarian: coming-of-age ceremony and a weapon choice (melee only, no bow or staff; ch. 2–3). High base
    threat. Spirit engravings. Tribe politics.
  - Fairy: spirit contracts through **Spirit Stones** (≈150k, about 10% success, ch. 19). Spirit element skills.
  - Dragonkin: Dragon Sanctuary blessings (Earth +20% essence stats, Volcano +30% skill effect, Sea +100 Soul
    Power; non-Dragonkin may take only one; ch. 201–203).
  - Dwarf: forge and crafting (Hikurod). Beastkin: tribes with guaranteed skills (ch. 829).
- [ ] **Random base stats** within the race's default range at creation (ch. 136).
- [ ] Race-based tax rules: fairies get 3-year interest-free tax loans, barbarians and humans get none. Two
  years of tax exemption per birth (ch. 202, 248).

### 2.2 Stats
- [x] Basic set in the prototype: HP, SP, Strength, Physical/Magic Resistance, Agility, Speed, Perception,
  Poison Resistance, Appetite, Threat Level, with a character sheet.
- [ ] **Status window like the novel:** Level · Physical / Mental / Supernatural Ability (category scores) ·
  Item Level · Overall Combat Index · Acquired Essences (ch. 2, 35, 187, 446).
- [ ] **Category scores** are computed from detailed stats through per-stat **coefficients** (ch. 463).
- [ ] **Detailed stats seen in the novel**, to add as needed: Bone Density (defence), Weight (knockback, blunt
  damage; ch. 31), Pain Resistance, Natural Regeneration, Soul Regeneration, Fighting Spirit, Cognition,
  Sixth Sense, Luck, Control, Accuracy, Vision, Smell, Hearing, Dynamic Vision, Leaping Power, Endurance,
  Stamina, Absorption, Flexibility, Sensitivity (elemental dealers; ch. 104), Mental Power, Mental Resistance,
  and elemental resistances (Fire, Cold, Lightning, Dark, Earth, Holy/Chaos) and affinities (Cold Affinity).
- [ ] **Invisible special stats** that don't count in the Combat Index (ch. 452):
  - **Fame:** raises the chance of special events (ch. 72, 74).
  - **Reputation:** gained from heroic acts (ch. 73, 99).
  - **Support / Approval:** shoots up when a barbarian becomes Tribe Chief (ch. 452).
- [ ] Stat thresholds unlock effects: "Strength is 300 or higher", "Magic Resistance 500 or higher", "Physical
  Resistance 750 or higher" (ch. 83, 594, 653, 699).

### 2.3 Resources and survival meters
- [x] HP. [x] Hunger (belly).
- [ ] **Mana** (mages) and **Divine Power** (priests) as separate pools next to Soul Power (see §1).
- [ ] **Mental Power:** drained by fear auras, and spent during the death countdown.
- [ ] **Stamina:** an important stat. Below 10% the character can't move (ch. 56, 127).
- [ ] **Fatigue and sleep:** you need sleep and a **night companion** to keep watch. "Night Companion" is shown
  as a status (ch. 6, 8–10). [~] Camping with Ainar on watch already exists.
- [ ] **Death countdown:** at 0% HP a countdown starts that drains Mental Power each second. Natural
  Regeneration rises in proportion to Mental Power, and getting back above 1% cancels it. A PMD-style "last
  chance" (ch. 35, 857). Variants: [Disapproval] only ends the countdown at 10% HP; [Source of Darkness] means
  you can't die until your heart is destroyed (ch. 35).
- [ ] **Instant-death vital spots** (head, heart) and hyper-regeneration bonuses (ch. 881).

### 2.4 Achievements: permanent rewards for conditions (ch. 5, 7, 25, 35, 56, 64, 107, 143, 166, 281, 381, 406, 461, 464, 558, 622, 785, 829)
- [ ] HP below 2% → Mental Power +1 · HP below 0.1% → Mental +3 · survive the countdown → Mental +10
- [ ] Mental +1 each for: first murder, first player kill, first companion death, kill count 10, stamina below
  5%, first rank 3 kill
- [ ] Reach 5th floor (Soul Power +20) · reach 8th floor (Soul Power +50, "Baptism") · first Floor Lord
  (Soul Power +50) · first rank 1 kill (Soul Power +10)
- [ ] Hidden achievements:
  - **Mythical Discovery** 1/5, 2/5, 3/5 → Soul Power +10 / +20 / +30 (ch. 381, 829, 927)
  - **Defeat Riakis** → reward "???" until revealed in the Witch's Cabin: Mental Resistance +50 (ch. 461–464)
  - **Archives 15% progress** → permanent access (ch. 622)
  - **Enter the Land of the Primeval Spirit** → Earth Resistance +10 (ch. 829)
- [ ] **Quests with failure penalties**, e.g. "Dragon Heart": unlocks engraving stage 9+, and failure kills the
  old shaman (ch. 785).
- [ ] **Stone of Honor:** first-time feats engraved in the world (ch. 490–491).

---

## 3. Essences: the skill system (ch. 13)
- [x] Drop from monsters, absorb, one slot per level, stats + passive + active.
- [x] Seal in a vial to sell (test tube, ch. 31). [x] Removal at a temple (10–15M, ch. 41).
- [ ] **Colours** decide the active skill, and guardian essences are rainbow (see §1).
- [ ] **Drop rates:** extremely rare in normal areas, much higher in rifts. A guardian drops an essence about
  33% of the time (ch. 13, 35, 541). Essences fade after 30 minutes.
- [ ] **Rank (grade) 9 → 1.** Higher ranks give stronger effects, and EXP scales with rank.
- [ ] **No duplicates.** Only **one Floor Lord essence** per character, and it can't be removed (ch. 461,
  622, 856). **Corrupted** essences are locked for 180 days and can never be removed (ch. 803–804). For
  barbarians, removal was once a tribal taboo (ch. 153).
- [ ] **Guild rank** follows the essences you have absorbed and your equipment (§8.3).
- [ ] **Synergies** between essences (e.g. the Yeti's Cold Condensation, ch. 110). Essences specific to one
  tribe (ch. 228). Transformation-type abilities (Discharge, ch. 35).
- [ ] **Latent abilities** that awaken under conditions (wiki: Ainar's "Best Friend").
- [ ] **Re-roll items:** Hundred Fruits re-roll one essence's base stats, usually for the worse (ch. 300–301).
- [ ] Late game: storing only an essence's stats (B1), and a custom-essence machine combining three stones into
  stats, passive and active (ch. 620, 625).
- [ ] **Essence Compendium** in the library: rank 9 entries without exact numbers. Rank 8+ information is sold by
  the guild (ch. 19).
- [ ] Faithful data for every essence already documented in the wiki's `essence/` folder (100+ pages).

---

## 4. Other permanent growth
- [~] **Spirit Engraving** (barbarian, shaman's tent). Choosing a path (Undying/Immortal, Slayer…) locks out the
  others (ch. 21).
  - [x] Stage 1 Undying.
  - [ ] Stages 2–8: stage 2 1M, stage 3 2M (Physical +50, much higher base threat; ch. 79), stage 4 4M (Mental
    +30, Ability +10, Soul Power), stage 5 8M (Physical +30, Mental +30, Stamina). Every 3rd stage you choose a
    trait, and the options depend on the path: Immortal offers the Soul of Flames, Steel or the Wild (ch. 79),
    while Slayer gave Ainar the skill [Devour] (ch. 174). From stage 6 you need gathered materials (e.g. Vaiterion claws for stage
    8); stage 9+ needs a Dragon Heart (ch. 77, 100, 115, 127, 666, 785).
- [ ] **Soul Inheritance and "tempering":** 6 months of seclusion that greatly raises Physical and lets you
  inherit a master's essence (ch. 152).
- [ ] **Permanent consumables** found as hidden pieces: Gob Quartz (Poison Resistance +3), Ice Shard and Ice
  Crystal (Cold Resistance/Affinity), Mercurial Liquid (Magic Resistance +3), Blessing of Iron (Physical
  Resistance +3), Fragment of Earth, Book of Souls. Each kind doesn't stack (ch. 103, 109, 300, 374, 456).
- [ ] **Blessings:** Dragon Sanctuary blessings, Earth Dragon energy in the Lignaracia Cave (ch. 202, 250).
- [ ] **Martial arts:** passive boosts to crit, accuracy, evasion and defence (ch. 279).

---

## 5. Combat
- [x] Turn-based grid, melee and ranged, poison, stealth, traps, threat targeting, regeneration.
- [x] Held key won't repeat moves or attacks next to monsters.
- [ ] **Roles and aggro:** a main tank holds the line ("you couldn't do anything if the main tank didn't hold",
  ch. 456). Taunts, the [Swing] and [Wild Surge] style threat skills (×3 threat, ch. 82). Healers need the tank
  close.
- [ ] **Damage types and resistances:** blade/blunt/pierce (blades resisted 50%, ch. 594), fire, cold,
  lightning, dark, holy, chaos, earth, acid, poison levels (Low/Medium/High). Monsters with weaknesses: the
  frogman is immune to blunt, Tarunbas has negative lightning resistance (ch. 108, 115).
- [ ] **Status effects:** Stun, Paralysis, Fear (stacks), Confusion, Disorientation, auditory and visual
  hallucinations, Pain Amplification, Hypothermia, Curses (stacking; warning at 15+), Soul Exhaustion (all
  stats −70%), Lethargy, Exhaustion, Prey/Target Lock, Suppression (broken by any damage), tracking marks
  (ch. 35, 56, 106, 129, 140, 420, 481).
- [ ] **Knockback and weight**, critical hits, accuracy and evasion as detailed stats (ch. 31, 171, 244).
- [ ] **Buff skills:** Gigantification / Giant Form (size raises threat and Physical), [Transcendence], Aura
  (the "strongest skill", knights; costly), Darkening Mode (ch. 69, 71, 242, 427, 854).
- [ ] **Skills sealed** by field effects; passives always work (ch. 221, 427, 914).
- [ ] **No skills in the city** except at the Training Center (ch. 17, 207). The penalty is a fine (≈300k) or
  exile to Bifron for 20 days (ch. 191, 194, 204).
- [ ] **Corpses vanish into light** with their clothes and weapons (ch. 13). Gear comes from killed explorers,
  Numbers Items and crafting. Exceptions: unranked deadmen (ch. 29), B1 "intact-corpse" monsters (ch. 509–528),
  outside-the-wall monsters (ch. 664).
- [ ] **Matchups:** monster kits with specific counters (fire burns the Corpse Golem's shell, holy water vs evil
  spirits, the heart must be destroyed for vampires and rank 3+; ch. 30–35, 59, 279).
- [ ] **Instant-death and "must survive" boss mechanics:** Crack of Evil, timed phases, rage meters, enrage
  stacks (ch. 65–70, 480–482).

---

## 6. Party, companions and other explorers
- [x] One AI ally (Ainar): follow, fight, keep watch, 8/2 split.
- [ ] **Classes and roles:** Tank (Shield Barbarian…), Damage Dealer (physical, elemental), Mage (MP, spell
  ranks, schools; "a mage's rank counts +1.5", ch. 117), Priest (divine power; churches of Reatlas/Leathlas,
  Tobera, Heindel and the Three Gods, and Karui, whose priests run on offerings; healing, holy damage), Archer, **Scout/Guide** (finds portals; essential on upper floors,
  ch. 120, 163, 178), **Porter** (carries loot, non-combatant, ch. 28, 313), Summoner.
- [ ] **Ally tactics** like PMD's (follow, go after foes, avoid trouble) and per-companion AI personalities.
- [ ] **Recruitment:** guild listings matched to criteria, members wear recorders to deter betrayal (ch.
  44–47). Recruiting a temple priest needs three or more members of rank 5+ and church achievement points
  (ch. 151). Recruitment vouchers from quests (ch. 306).
- [ ] **Favorability:** relationship values capped at 90% until special events (ch. 639). Companion death
  matters and gives an achievement.
- [ ] **Loot split rules** (9/1, 8/2, by clan rank; ch. 9, 20, 312). Promises and oaths.
- [ ] **Night companions:** temporary partnerships with strangers who may betray you (Hans tries to kill Bjorn
  for his barbarian heart; ch. 6–7).
- [ ] **Other explorers in the labyrinth:** an unwritten rule not to interact (ch. 6). Pillagers and raiders
  ambush at portal exits (ch. 24–26, 51). PK achievement. ID tags from ch. 177: anyone without a tag can be
  killed without penalty. The Explorer's Oath obliges the strong to protect the weak in emergencies (ch. 458).
- [ ] **Teams → Clans:** registration with a minimum roster, clan ranks (4th-rank clan = "real benefits"),
  clans granted hunting-ground rights by the crown (taking one without permission is illegal) (ch. 52, 167,
  217, 442).
- [ ] **Expeditions and raids:** multi-clan operations, Floor Lord raids approved by the guild (ch. 162–168,
  458).

---

## 7. The labyrinth

### 7.1 Rules shared by every floor
- [x] Random start, dark zones, torches, traps, portals, hunger, closing timer, return to city.
- [ ] **Floor steles:** touch the monolith at a dead end and it turns into a sphere of light. First opener gets
  EXP and an achievement (ch. 5, 22, 398).
- [ ] **Dimensional instability exploit:** entering just as the plaza portal closes drops you in the dark outer
  zone next to an unopened stele. Later "patched" by the Magic Tower (ch. 5, 19, 22, 263).
- [ ] **Light:** crystals light 1F. Light orbs make everything bright but draw goblins (ch. 4, 163). Stairway
  and portal areas swallow light (ch. 24).
- [ ] **Navigation skill:** wide passages vs dead ends, compasses, the guide's senses. A record run to the portal
  takes 6 hours, about a day is normal (ch. 151, 163, 789).
- [ ] **Homeostasis:** damaged terrain is restored next cycle, except special points; a wall that doesn't regrow
  marks a hidden piece (ch. 162, 504, 554).
- [ ] **Special zones and field effects** applied on entry (Witch's Forest, Glacier Cave, Abyssal Fog, Recoil,
  Daemagyeong…) (ch. 56, 106, 221, 227, 600).
- [ ] **Floor Lords:** one per floor with a hidden summon condition and phases. Drops: a **Floor Lord Artifact**,
  a **Floor Lord Stone** (opens a rift on that floor once) or a **Floor Lord Essence** (ch. 461). The 1st-floor
  Lord drops nothing significant (ch. 217). First kill promotes a clan. Raids need guild approval (ch. 65, 217,
  460–461). Floor Lords normally stay on their own floor, but **Dimensional Collapse events** can bring one
  elsewhere (Lord of Tears, ch. 912).
- [ ] **Special Conditions and Hidden Pieces:** scripted secrets with cooldowns (ch. 27, 789).
- [ ] **Dimensional Collapse:** unpredictable world catastrophe events (ch. 44, 90, 533, 833).
- [ ] **Labyrinth closures** (sealed by the crown) disrupt the economy, and rift spawn rates spike after them
  (ch. 645–657, 789).

### 7.2 Floors (details in wiki `Places/The Labyrinth/…`)
- [~] **1F Crystal Cave** (P1). Four monster districts [x]. Dark outer zone [x]. Goblin traps [x].
  - [ ] Central Dark Zone with all four species.
  - [ ] Great Sage Monument rift altar: four 1F stones + one 8th-grade stone pick the rift, with a cooldown of
    3+ months.
  - [ ] Floor Lord **Dreadfear**: "Five Believers" summon after Day 3, three phases, respawns every 6 hours,
    takes about 30 explorers.
  - [ ] Hidden: "Nine Fears" → Verzak and the Abyssal Fog. "Ancient Memories" / "Distorted Memories" → Pilgrim's
    Cave. Dimensional Stele → B1 (ch. 27, 65–66, 217–224, 478–490, 504–507, 790).
- [ ] **2F** (P1): four fields, closing on Day 10.
  - Goblin Forest: traps everywhere, packs, 8 steles (only one is real), arrival throws you 3 m up (ch. 12–13,
    163).
  - Beasts' Lair: pits and forks; you need a scout (ch. 50).
  - Rocky Desert: Sandworms → Deathworm event (ch. 456).
  - Land of the Dead: banshee "mark of grief", corpse-flower water, the Death Knight stele at 00:00 on Day 7
    (ch. 23–25, 113).
  - (Blackrock Mountain: stone golem Suppression; ch. 25, 27.)
- [ ] **3F Pilgrim's Path** (P2), closes on Day 15, solo play impractical.
  - Pitch-black Estuary tides; Orc Colony (777 magic stones summon the Orc Heroes); Witch's Forest
    (hallucination field, Witch's Eye timer, the Witch's Cabin safe room powered by corpse "offerings").
  - Floor Lord **Riakis** (7 offerings): erosion, Gate of Chaos, Crack of Evil.
  - White Temple rift (competitive stages, curses, Knight of Doom), Sculpture Temple (Nameless Fragments), silver
    orbs on Day 3 (ch. 51–71, 115, 298–301, 457–464, 505).
- [ ] **4F Tower of Heaven** (P2): choose the Stairway of Wisdom, Courage or Patience as a trial. Doppelganger
  Forest, Golden Ruins, Larkaze's Labyrinth. A place to farm EXP from many species (ch. 132, 179, 902).
- [ ] **5F Great Demon Realm / Great Magical Forest** (P2): closes after Day 30. Frost, Hellfire and Specter
  canyons. Distortion on the Millaroden (20%) (ch. 165–168).
- [ ] **6F Great Sea** (P3): islands, ships, sea events (Parune Island), farming islands, Skull Island, Arta
  Island (ch. 267–284, 789–815).
- [ ] **7F** (P3): Dark Continent, Ice Rock, Panthelion Ruins (mechanical monsters), closes after Day 75
  (ch. 350–366, 893).
- [ ] **8F Dawn Land** (P3): no monsters outside the always-open random rift, which reopens after each clear.
  High variants in every rift. Dragons as guardians (ch. 406, 414, 537–541).
- [ ] **9F Star Grave**, **10F Abyss**, **B1 Archives**, **B2**, unknown floors (P3) (see §12).

### 7.3 Rifts: instance dungeons (P1 for the Blood Citadel, P2 for the rest)
- [ ] **Opening:** a rift opens on its own at a random time (the floor shakes and thousands of portals appear),
  or you trigger it with an offering at the monument. The cooldown is at least 3 cycles; natural openings usually
  happen every 5–6 cycles (ch. 27–28). One rift opened on Day 1 (ch. 102), and the 2nd-floor rift won't open
  after Day 7 (ch. 457). Party slots are filled first come,
  first served (5 per instance), and the portal closes when the team is full (ch. 27–28, 100–102, 218, 374).
- [ ] **Structure:** chapters, a mid-boss, a guardian. The only exit is to kill the guardian. A cleared rift is
  the safest place to sleep (ch. 29, 34, 109).
- [ ] **Drops:** the guardian gives a rainbow essence (≈33%), Numbers Items, or Rift Stones. Essences fade after
  30 minutes (ch. 35, 541).
- [ ] **Special guardians:** an odd doorknob colour means a high variant (Vampire Duke instead of Death Knight)
  with bonus EXP (ch. 33, 35).
- [ ] **Hidden pieces in rifts:** breakable walls hide secrets. Junk can only be taken out with Distortion
  magic, real items leave freely (ch. 30, 32, 374).
- [ ] **Red/blue exit portals** (blue is safe, red is risky with extra reward), statue rifts, and the Rift
  Generator (ch. 540, 603, 606).
- [ ] 1F rifts to build: **Blood Citadel** (drawbridge, castle town, dungeon, demonic shrine, Corpse Golem,
  Vampire Duke; ch. 27–35), **Glacier Cave** (waves, Tarunbas; ch. 101–110), **Green Mine** (King Slime;
  ch. 374–375), **Steel Tomb** (ch. 456).

### 7.4 Monsters
- [x] Grade, HP, attack, speed, sight, melee/ranged, poison, regeneration, summons, hidden gnomes.
- [ ] **Ranks 9 → 1** across all floors (the wiki bestiary has 462 pages).
- [ ] **Categories:** normal, variant, higher species, rare species, **mutant / high variant**, named, guardian,
  Floor Lord. Mutants increase further from the portal (ch. 12, 33, 419, 457).
- [ ] **Behaviour:** attack only within a range (ch. 11). Ambushes near traps. Ghouls wait motionless. Goblins
  are drawn to light. Deathfiends don't leave their territory (ch. 11, 24, 163). Monsters spawn from holes that
  collapse if dug into (ch. 12–13).
- [ ] **Kill conditions:** heart or head (vampire, rank 3+); a deathfiend tackled to the ground can't get up
  (ch. 24, 279).
- [ ] **Unranked monsters** (deadmen) give no stones or EXP and their bodies stay (ch. 29).
- [ ] **Byproducts** (eyes, hearts…) only with **Distortion magic**, at the cost of the essence and stone.
  Success is a chance roll: "extremely low" in general, 20% on a Millaroden, better with Advanced Distortion
  (ch. 115, 159, 191, 262). **Outside the walls it's inverted:** monsters always drop byproducts, and Distortion
  is what gives essences or stones (ch. 664).

---

## 8. Rafdonia: the outer loop (details in wiki `Places/Rafdonia/…`)

### 8.1 Calendar, taxes and law
- [x] Monthly runs, living costs, annual tax, game over if unpaid.
- [ ] One city day per expedition (return at noon), then about 30 city days until the next opening (ch. 16, 808,
  919). Real calendar: 13 months + the 13th month of festivals, with a clan-war tournament (the last cycle lasts
  35 days) (ch. 16, 231). Exceptions: the B1 Archives run 1:1 with the city (ch. 525). From ch. 786 the crown
  opens the labyrinth unannounced. The crown can also seal it for months (ch. 645–657, 773–774).
- [ ] Tax by race and age (starts at 20, due at the new year); second year 800k plus exchange fee (ch. 18).
  Exemptions: royal rewards (3 years of tax and exchange-fee exemption, ch. 173), births (2 years for barbarians,
  more for humans, ch. 173, 248), minors (ch. 633), and a general exemption after the war (ch. 789).
- [ ] Laws: no essence skills in town; duels need a notary; public executions; evil spirits are executed when
  discovered (ch. 17, 74–75, 174, 177).

### 8.2 Economy
- [x] Exchange (sell stones), market, equipment, inn.
- [ ] **Dimensional Plaza checkpoint:** stones exchanged by grade, mana measured, loot inspected, alarm on
  suspicious hauls, ID tags issued per entry (ch. 16, 36–37, 89, 205).
- [ ] **Alminus Central Exchange:** search fee 3,000 per item, appraiser 300k, sealed-bid auctions,
  pawn-and-collateral loans (ch. 47, 150, 172, 331–347).
- [ ] **Sky Auction House** (Double Numbered Items, anonymous bidding) (ch. 300, 331, 335).
- [ ] **Bank:** six-month high-interest secured loans (ch. 349–350). **Black market:** anonymous contracts and
  bounties (ch. 482, 493).
- [ ] **Shops:** custom armour costs double and takes 3 days (ch. 18, 21). **Blacksmith repairs**, with
  durability and corrosion (ch. 72, 122). Forges and materials (mithril, adamantium) (ch. 468).
- [ ] Living costs by lifestyle: an inn bed costs 300–9,000 a night by district, a meal 300–450 (ch. 20, 72,
  120).

### 8.3 Explorers' Guild
- [ ] **Explorer rank 9 → 1**, reflecting your essences *and* your equipment (ch. 48). The guild can promote you
  as a reward (ch. 40). **Promotion evaluations start from 6th rank** (ch. 102: 6th = seasoned, 5th = high rank,
  4th = top tier) and use **achievement points** from guild requests (ch. 22, 57, 77, 205).
- [ ] **Bonding service** (15k for two rank 9s, ≈100k for five), party finder, team and clan registration
  (ch. 22, 88, 442).
- [ ] **Requests and bounties** (paid once a temple confirms the kill), information sales (rank 8+ essences),
  wills and heirs (ch. 19, 85, 146).
- [ ] Floor Lord raid approval, and rescue missions that give achievement points (ch. 219, 504–506).

### 8.4 Other places in the city
- [x] Angry Rhino Inn (recruit Ainar). [x] Sanctuary (Undying stage 1).
- [ ] **Temples:** paid healing, essence removal (bishop rank or higher), priest recruitment, church achievement
  points (ch. 41, 119, 151, 335).
- [ ] **Barbarian Sanctuary:** coming of age, engravings, Grounds of Proof duels, **Tribe Chief** by duel (the
  Support stat), land plots (2M by lottery), the tribal council (ch. 2–3, 21, 247–248, 451–455).
- [ ] **Royal Library:** compendiums, book detection costs 3,000, deposits (ch. 19, 86, 366).
- [ ] **Training Center** (the only place skills are allowed; monthly membership) (ch. 207, 242).
- [ ] **Magic Tower:** visitor pass, stat checks, long-distance messages (ch. 44, 100, 392, 556).
- [ ] **Administration requests** that raise credibility (ch. 79, 85).
- [ ] Travel between districts (carriage 250 a seat, barbarians pay for two; military transfer station) (ch. 47,
  387, 391).

### 8.5 Status and politics (P2–P3)
- [ ] **Nobility:** titles (Baron → Viscount…), merit points from noble quests, the royal treasury reward (one
  rank-matched essence or item; Golden Treasury 3rd-grade, Silver 4th-grade), the Imperial City entry
  requirements, the council seat order (ch. 87, 232–242, 644).
- [ ] **Clan politics**, noble alliances, competitions (construction contest), festivals (ch. 653, 780).

---

## 9. Items and equipment
- [x] Consumables (bread, potion, antidote, torch, vial) and 4 equipment slots.
- [ ] **Item Level** per piece and in total, feeding the Combat Index (ch. 8, 21, 59, 187).
- [ ] **More slots:** greaves, boots, bracers, necklace, rings, and **charms** (ch. 59, 457, 701, 797). Shields
  count as weapons (ch. 785).
- [ ] **Numbers Items:** about 9,999 unique numbered items. Single-, double- and triple-digit tiers, Secret
  Numbers, and binding ("permanently bound to you"). Along with crafting and discovery they are the only way to
  get special gear (ch. 42, 300, 490, 625, 735). They drop from guardians and also from some ordinary monsters
  (ch. 682, 879). Each number is unique: No. 16 makes 29 temporary "tokens", not copies (ch. 794). The wiki has 56 pages in `number_item/`, for example:
  - No. 9999 Beginner's Luck (a charm, about +5% drop rate, ch. 457)
  - No. 3 Wall of Aegis
  - No. 12 Trust (shared by bound teammates)
  - No. 444 Deadrius's Invitation (undead won't attack)
  - No. 8645 Purification Torch
- [ ] **Durability, repair, corrosion, enchantments** (temporary or permanent, ×20 price; ch. 72, 100, 688).
- [ ] **Consumables to add:**
  - Scrolls: combat, support, lightning (stuns Tarunbas), Return Scroll / Return ale, Return Stone.
  - High-grade potions (cure paralysis), herbs (Thunder Herb), holy water, light orbs.
  - Explosives, compasses, water flasks, rope, Golden Mask (change your face).
  - Rift Generator, Rift Stones, Floor Stones.
  - (ch. 26, 59, 108, 163, 374, 540, 695)
- [ ] **Inventory:** limited bag; expansion bags (a year's wages, ch. 63); pocket dimension (high-level mages,
  ch. 330); porters.
- [ ] **Relics and legendary items:** Primordial Relics (one per tribe, ch. 43), Stone of Resurrection (works only
  right after death on an intact body, and wipes memories and intimacy, ch. 158, 566), Philosopher's Stone (ch. 614).

---

## 10. Meta and social systems (P2–P3)
- [ ] **Evil spirits:** other people from Earth live in this world. Keep your secret, because saying "Dungeon &
  Stone" gets you executed (ch. 2, 74).
- [ ] **Ghostbusters community:** on the 15th of each month (in-game) you join a players' forum. Hint posts,
  a **GP exchange** for information and items (100,000 GP ≈ 2M stones), and chat rooms by race or class
  (ch. 75–76, 90–92). It's a natural in-game **hint and tutorial system**.
- [ ] **Round Table:** an information-trading mini-game. Each member shares something more than half of the
  others don't know, and a truth jewel judges it (ch. 124–126).
- [ ] **Special events** whose chance rises with Fame (ch. 72). **Quests with choices** (ch. 306, 800).
- [ ] **Dimensional Collapse, wars** (Noark invasion, siege of the sanctuary) as world events (ch. 623–656,
  706–773).

---

## 11. Noark: the second hub (P3)
- [ ] An underground criminal city reached through the sewers. Aliases instead of names, looters who prey on
  newcomers in the back alleys, child "runners" (ch. 81–84, 293–305).
- [ ] **Its own labyrinth portal** (no checkpoint, entrance fee). Magic stones buy goods rather than money, and
  fences pay about 1/3 of surface value (ch. 294, 302).
- [ ] **Lethe's Blessing** (erases memory), joining the Lord's faction, clans with rank-based shares (ch. 83,
  304, 312).

---

## 12. Late game and story content (P3)
- [ ] **B1 Archives:** the Silver Sea and ships, islands, the rainy season of falling monsters, the Library
  Island summoning books (a bestiary grind up to rank 1), the Hall of Guardian Statues (41 boss-only rifts), the
  Seventh Archive, the custom-essence machine (ch. 505–622).
- [ ] **Outside the walls:** forbidden zones, intelligent monsters (aggro barely works, kills must be
  confirmed), byproducts, dimensional steles (ch. 661–672).
- [ ] **Spiritual realms:** the Underworld (a 24-hour duel space), the Earth Witch's Field (ch. 464, 733–734).
- [ ] **The Hall:** an afterlife hub where Soul Power is both level and currency, with rank-gated areas and
  reincarnation (ch. 933–944).
- [ ] **Alternate character:** play a second, weaker body (Peter) in parallel with your main character
  (ch. 881–892).
- [ ] **Playthroughs:** repeat a scenario with knowledge from the previous run, Regression-style (ch. 839–842,
  892–912).
- [ ] **Story progression:** arcs gated by floor and rank (Blood Citadel → Witch's Forest → Riakis → sea…).

---

## 13. Content pipeline
- [ ] Import the wiki data (essences, bestiary, numbered items, prices) into `data/*.json`, keeping chapter
  sources and marking placeholders.
- [ ] One data file per floor and per rift: fields, monster tables per region and day, events, hidden pieces,
  bosses.
- [ ] Tests for every new rule (EXP-once rule, floor timers, essence fading…), following `tests/run_tests.gd`.

---

## 14. Verification against the full story (ch. 1–944)

Each rule above was checked against the whole text: by searching every chapter for passages that limit or
contradict it, then reading those passages. Results:

### Corrected (the first version of this TODO was wrong)
| Rule | What the story actually says |
|---|---|
| 1F portals | District → field link is consistent; ghouls (west) → Land of the Dead, gnomes (south) → Rock Desert. The prototype's west → Land of the Dead was right. The text itself contradicts the directions in ch. 110 and 219. |
| Soul Power on level up | +10 up to level 5, then **+30** from level 6 (ch. 264, 365, 529). |
| SP vs MP | Soul Power **is** the MP for essence skills (ch. 22, 70, 71, 100). No rename needed. |
| Potions in combat | Usable, but painful. The game blocked them; Bjorn drinks them while tanking (ch. 5, 35). |
| Rank promotion | Evaluations start from **6th** rank, not 5th (ch. 102). Equipment counts too (ch. 48). |
| Rift opening "from Day 3" | Not supported. Cooldown ≥3 cycles, usually 5–6; one opened on Day 1 (ch. 27, 102). |
| Goblin stone = 20 stones | True for the *game*, but in-world earnings are ≈100k–180k per week (ch. 16, 18). Balance on income. |
| Achievements | Land of the Primeval Spirit gives only Earth Resistance +10. Mythical Discovery scales +10/+20/+30. Rank 1 first kill gives Soul Power +10. "Dragon Heart" is a quest with a failure penalty (ch. 558, 785, 829, 927). |
| Floor Lord drops | Artifact / Stone / Essence (ch. 461), not "Floor Treasure". |
| "Hunger and thirst only inside" | Not stated anywhere in the novel; removed. |
| Beginner's Luck | ≈ +5% drop rate (ch. 457), not "extra rolls". |

### Confirmed, with exceptions to implement
| Rule | Exceptions found |
|---|---|
| EXP once per species | Tracked per character (alternate character) and reset by playthroughs (ch. 907). Bonuses repeat (ch. 583). Rare species (+177, ch. 264) and Floor Lords (+100) break the rank formula. EXP and levels can be lost (ch. 32, 591, 620). |
| One city day per run | B1 Archives run 1:1 (ch. 525). Unannounced openings from ch. 786. Labyrinth closures (ch. 645–657, 773–774). |
| Floor closing times | Add 6F = Day 60 (ch. 284, 890, 921). |
| Essence removal at temples | Floor Lord and corrupted essences can't be removed (ch. 461, 803–804). Old barbarian taboo (ch. 153). |
| Essence fades after 30 min | Applies everywhere, not just rifts (ch. 518). |
| Taxes or execution | Several exemptions (ch. 173, 248, 633, 789). |
| Skill ban in the city | Penalty can be 20 days of exile to Bifron (ch. 194). |
| Corpses vanish | Deadmen, B1 corpse monsters, outside monsters (ch. 29, 509–528, 664). |
| Distortion → byproducts | Chance-based (ch. 115, 191). Inverted outside the walls (ch. 664). One item only in some zones (ch. 169). |
| Floor Lords stay on their floor | Not during Dimensional Collapse events (ch. 912). |
| Engraving "3rd-stage soul" | The options depend on the path (ch. 79, 174). |
| Numbers Items | Also dropped by some ordinary monsters (ch. 682, 879). Uniqueness holds (No. 16 tokens, ch. 794). |
| Stone of Resurrection | Only right after death, with an intact body (ch. 566). |
| Death countdown | [Disapproval] variant ends at 10% (ch. 35). |

### Confirmed with no contradiction found
- EXP rank formula for normal monsters, cumulative thresholds 6/30/150, no HP refill on level up, one essence
  slot per level (ch. 22, 35, 50)
- Essence colour → active skill, same passive across colours (ch. 70, 104, 139, 332, 620); no duplicates (ch. 622)
- Bonding limit of 5, later 6 (ch. 57, 157, 351); the dimensional-instability exploit stops after the Magic Tower
  fix (ch. 263)
- Spirit engraving prices for stages 3–5 (ch. 79, 100, 127); taxes from age 20 with execution (several chapters);
  the 13-month calendar (ch. 231)
- Only one exit from a rift, by killing the guardian (ch. 34); one Floor Lord essence per character (ch. 461, 856)

### Taken from the wiki and not re-checked line by line
Per-location details in §7.2 (field effects, boss phases, hidden-piece steps) and city prices in §8 come from the
wiki's place pages, which cite their chapters. One wiki claim looks wrong: the timeline says a clan was
suspected of owning "3 copies of No. 16 Ebony Emblem". The text describes one item creating 29 tokens (ch. 794).
