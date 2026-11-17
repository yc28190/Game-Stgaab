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

- [ ] **EXP is earned once per monster species**, "like filling a bestiary". Repeat kills give nothing. A rank 9
  monster gives 1 EXP and each rank higher gives +1. You run out of new species to farm (ch. 22, 50). Our
  prototype currently gives EXP for every kill.
- [ ] **Cumulative EXP thresholds:** 6 → level 2, 30 → level 3, 150 → level 4, then it "explodes". You cannot
  reach level 5 even by killing every species below the 4th floor (ch. 50, 133).
- [ ] **Bonus EXP sources:** opening a floor stele first gives +2 EXP and is a repeatable achievement (ch. 22).
  Guardian kill gives +3, high variant or mutant +1, killer bonus, Floor Lord bonus +15, first opening of a
  hidden area +99, Book of Souls +3 (ch. 35, 300, 489, 507, 587). Replace our current "first portal = free
  level".
- [ ] **Level up:** +10 Soul Power per level up to level 5, +1 essence slot, and **no HP refill** (ch. 35,
  202).
- [ ] **The 1st floor has four edge portals:** north → Goblin Forest, east → Beasts' Lair, west → Rocky
  Desert, south → Land of the Dead. The wiki has conflicting accounts for Blackrock Mountain. Your start
  direction hints at which one you'll reach (ch. 12, 50, 216–222, 455). We currently have north → Goblin
  Forest and west → "Deadlands".
- [ ] **Each floor closes at its own time.** 1F closes at 24:00 on Day 7, and its return portal still works on
  Day 7. 2F closes on Day 10, 3F on Day 15 (ch. 13, 53, 115). We use one 7-day timer.
- [ ] **Monster groups grow every day.** On the Land of the Dead the count triples from Day 3; deathfiends come
  alone, then in pairs, then in threes (ch. 8, 23–24).
- [ ] **Thirst** alongside hunger, with a water flask. There is a dehydration warning, and corpse flowers on 2F
  are the only water source (ch. 6, 24). Hunger and thirst only apply inside the labyrinth.
- [ ] **Potions take time to drink** and can't really be used mid-fight; high-grade potions cure paralysis
  (ch. 5, 26).
- [ ] **Essence colour:** one species drops several colours. The colour decides the active skill; the passive is
  the same for all colours. Guardian essences are **rainbow** (ch. 69, 103–104, 583).
- [ ] **No duplicate essences** (ch. 622). A dropped essence **fades after about 30 minutes** if nobody
  absorbs it (ch. 104, 374).
- [ ] **Magic stone values follow the novel:** a goblin stone is worth about 1 bread (20 stones) and a deathfiend
  about 100 (ch. 4, 24). Our values are inflated, so rebalance the whole economy together.
- [ ] **Bonding** (party link) instead of always starting together. Without Bonding, each member starts at a
  separate random point (ch. 4, 22).
- [ ] **Party size:** 5 at first, 6 after the Bonding update (ch. 11, 351, 871).
- [~] **SP vs MP.** In the novel, skills and spells spend **MP**. **Soul Power** is a stat that raises MP and
  is checked when casting ("Soul Power is insufficient", ch. 71). MP regeneration is proportional to total MP
  (ch. 383). Rename our "SP" bar to MP, and keep Soul Power as the stat feeding it.
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
- [ ] **MP** for skills and spells (see §1).
- [ ] **Mental Power:** drained by fear auras, and spent during the death countdown.
- [ ] **Stamina:** an important stat. Below 10% the character can't move (ch. 56, 127).
- [ ] **Fatigue and sleep:** you need sleep and a **night companion** to keep watch. "Night Companion" is shown
  as a status (ch. 6, 8–10). [~] Camping with Ainar on watch already exists.
- [ ] **Death countdown:** at 0% HP a countdown starts that drains Mental Power each second. Natural
  Regeneration rises in proportion to Mental Power, and getting back above 1% cancels it. A PMD-style "last
  chance" (ch. 35, 857).
- [ ] **Instant-death vital spots** (head, heart) and hyper-regeneration bonuses (ch. 881).

### 2.4 Achievements: permanent rewards for conditions (ch. 5, 7, 25, 35, 56, 64, 107, 143, 166, 281, 381, 406, 461, 464, 558, 622, 785, 829)
- [ ] HP below 2% → Mental Power +1 · HP below 0.1% → Mental +3 · survive the countdown → Mental +10
- [ ] First murder · first player kill · first companion death (Mental +1 each) · kill count 10 · stamina
  below 5%
- [ ] Reach 5th floor (Soul Power +20) · reach 8th floor (Soul Power +50, "Baptism") · first Floor Lord
  (Soul Power +50) · first rank 3 kill · first rank 1 kill
- [ ] Hidden achievements: Mythical Discovery 1/5 (Soul Power +10) · Witch's Cabin after Riakis (Mental
  Resistance +50) · Archives 15% progress (permanent access) · Dragon Heart (engraving stage 9+) · Land of the
  Primeval Spirit (Soul Power +20, Earth Resistance +10)
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
  622, 856).
- [ ] **Guild rank** is derived from the essences engraved on your soul (§8.3).
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
    soul (Flame, Steel or Wildness). From stage 6 you need gathered materials (e.g. Vaiterion claws for stage
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
- [ ] **No skills in the city** (fine ≈300k) except at the Training Center (ch. 17, 207).
- [ ] **Corpses vanish into light.** Gear only drops from killed explorers (ch. 13).
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
- [ ] **Floor Lords:** one per floor with a hidden summon condition and phases. Drops: Floor Treasure, Floor
  Stone (opens a rift) or Floor Essence. First kill promotes a clan. Raids need guild approval (ch. 65, 217,
  460–461).
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
- [ ] **Opening:** they open naturally from Day 3 (the floor shakes and thousands of portals appear), or you
  trigger them with an offering. Each has a cooldown of about 3 months. Party slots are filled first come,
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
- [ ] **Byproducts** (eyes, hearts…) only with **Distortion magic**, at the cost of the essence and stone
  (ch. 115, 262, 664).

---

## 8. Rafdonia: the outer loop (details in wiki `Places/Rafdonia/…`)

### 8.1 Calendar, taxes and law
- [x] Monthly runs, living costs, annual tax, game over if unpaid.
- [ ] One city day per expedition (return at noon). Real calendar: 13 months + the 13th month of festivals (the
  last cycle lasts 35 days) (ch. 16, 231).
- [ ] Tax by race and age (starts at 20); second year 800k plus exchange fee (ch. 18).
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
- [ ] **Explorer rank 9 → 1** based on the essences on your soul. Rank 5+ promotion needs a test unlocked by
  **achievement points** from guild requests (ch. 22, 40, 48, 57, 77, 205).
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
  get special gear (ch. 42, 300, 490, 625, 735). The wiki has 56 pages in `number_item/`, for example:
  - No. 9999 Beginner's Luck (extra drop rolls)
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
- [ ] **Relics and legendary items:** Primordial Relics (one per tribe, ch. 43), Stone of Resurrection (revives
  you but wipes memories and intimacy, ch. 158, 566), Philosopher's Stone (ch. 614).

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
