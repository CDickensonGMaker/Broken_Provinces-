# Adventurer's Guild Quest Chain

**Faction:** `adventurers_guild`
**Headquarters:** Dalhurst (Adventurer's Guild Hall)
**Quest Giver:** Guildmaster Vorn (`guildmaster_vorn_dalhurst`)
**Geographic Scope:** Elder Moor, Dalhurst, Thornfield, Millbrook, Crossroads, Willow Dale, Bandit Hideout, Kazer-Dun Entrance

---

## Overview

The Adventurer's Guild is the most accessible faction - mercenary work, monster hunting, and dungeon delving. This 14-quest chain (13 story + 1 repeatable) takes the player from Initiate to Champion through escalating contracts and challenges.

---

## Rank Progression

| Rank | Quests | Requirements | Rewards |
|------|--------|--------------|---------|
| **Initiate** | 1-3 | Entry level | Guild Token, basic contracts |
| **Member** | 4-6 | Complete Escort Duty | Member Badge, standard contracts |
| **Veteran** | 7-9 | Complete Monster Hunt | Veteran Badge, dangerous contracts |
| **Elite** | 10-12 | Complete Rival Guild | Elite Badge, legendary contracts |
| **Champion** | 13+ | Defeat Vorn in trial | Champion Circlet, repeatable bounties |

---

## Quest Chain

### Rank: Initiate (Entry Level)

#### 1. `adventurers_01_proving_ground.json` - "Proving Ground"
**Objective:** Kill 8 wolves on the road to Thornfield
**Rewards:** 100g, 300 XP, Guild Token, +50 Adventurer's Guild rep
**Notes:** Basic combat test. Entry quest to the guild.

**Required NPCs:**
- `guildmaster_vorn_dalhurst` (Dalhurst)

**Required Enemies:**
- `wolf` (spawns on roads between Dalhurst and Thornfield)

---

#### 2. `adventurers_02_pest_control.json` - "Pest Control"
**Objective:** Clear 12 giant rats from Dalhurst warehouse
**Rewards:** 75g, 250 XP, +25 Guild / +10 Merchant rep
**Prerequisites:** Quest 1
**Notes:** Indoor combat. Teaches dungeon clearing mechanics.

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `giant_rat` (spawns in Dalhurst warehouse)

**Required Locations:**
- `dalhurst_warehouse` (interior scene or marker in Dalhurst)

---

#### 3. `adventurers_03_escort_duty.json` - "Safe Passage"
**Objective:** Escort merchant Halvard from Dalhurst to Thornfield, defend from bandits
**Rewards:** 125g, 400 XP, Member Badge, +75 Guild / +25 Merchant rep
**Prerequisites:** Quest 2
**Notes:** **PROMOTION TO MEMBER.** Scripted ambush on Crossroads.

**Required NPCs:**
- `guildmaster_vorn_dalhurst` (turn-in)
- `halvard_the_supplier` (escort target)

**Required Enemies:**
- `human_bandit` (4x, scripted ambush)

**Required Locations:**
- `thornfield` (destination)

---

### Rank: Member (Standard Contracts)

#### 4. `adventurers_04_bandit_contract.json` - "Bandit Elimination"
**Objective:** Clear bandit camp near Crossroads, kill captain
**Rewards:** 200g, 500 XP, +50 Guild / +20 Merchant rep
**Prerequisites:** Quest 3
**Choice Consequences:**
- Stealth approach: +15 Guild rep
- Frontal assault: +10 Guild rep

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `human_bandit` (8x)
- `bandit_captain` (1x, boss)

**Required Locations:**
- `crossroads_bandit_camp` (near Crossroads)

---

#### 5. `adventurers_05_missing_team.json` - "Missing in Action"
**Objective:** Find missing Guild team in Willow Dale, recover tokens, avenge them
**Rewards:** 175g, 450 XP, +60 Guild rep
**Prerequisites:** Quest 4
**Notes:** Emotional stakes. Optional revenge objective (kill 5 giant spiders).

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `giant_spider` (5x, optional revenge)

**Required Locations:**
- `willow_dale` (dungeon entrance)
- `willow_dale_corpse_site` (interior marker with corpses)

**Required Items:**
- `guild_token` (collectible from corpses, 3x)

---

#### 6. `adventurers_06_monster_hunt.json` - "The Beast of Millbrook"
**Objective:** Hunt dire wolf terrorizing Millbrook
**Rewards:** 250g, 600 XP, Veteran Badge, Dire Wolf Cloak, +100 Guild rep
**Prerequisites:** Quest 5
**Notes:** **PROMOTION TO VETERAN.** Monster hunt with tracking.

**Required NPCs:**
- `guildmaster_vorn_dalhurst` (turn-in)
- `millbrook_elder` (quest info NPC)

**Required Enemies:**
- `dire_wolf` (1x, boss)
- `wolf` (6x, optional pack clearing)

**Required Locations:**
- `millbrook_beast_lair` (near Millbrook)

**Required Items:**
- `dire_wolf_pelt` (dropped by dire wolf)
- `dire_wolf_cloak` (reward item)

---

### Rank: Veteran (Dangerous Contracts)

#### 7. `adventurers_07_dungeon_delve.json` - "Into the Deep"
**Objective:** Explore new section of Willow Dale, defeat undead, recover artifact
**Rewards:** 300g, 750 XP, Enchanted Explorer Boots, +75 Guild rep
**Prerequisites:** Quest 6
**Notes:** Dungeon exploration with traps and puzzles. Optional puzzle for bonus.

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `skeleton_warrior` (8x)

**Required Locations:**
- `willow_dale_deep` (new section entrance)
- `willow_dale_deep_end` (exploration endpoint)
- `willow_dale_vault_puzzle` (optional puzzle room)

**Required Items:**
- `ancient_amulet` (vault treasure)
- `enchanted_explorer_boots` (reward, grants trap detection)

---

#### 8. `adventurers_08_ogre_problem.json` - "Giant Troubles"
**Objective:** Deal with ogre blocking Crossroads trade route
**Rewards:** 350g, 850 XP, +80 Guild / +30 Merchant rep
**Prerequisites:** Quest 7
**Choice Consequences:**
- Kill ogre: +20 Guild rep
- Negotiate: +40 Guild rep (best outcome)
- Bribe: +15 Guild rep, costs gold

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `ogre` (1x, can be fought or negotiated with)

**Required Locations:**
- `crossroads_ogre_camp` (near Crossroads)

**Notes:** Requires `allows_dialogue = true` on ogre for negotiation path.

---

#### 9. `adventurers_09_rival_guild.json` - "Professional Rivalry"
**Objective:** Resolve conflict with rival adventuring company (Iron Blades)
**Rewards:** 400g, 900 XP, Elite Badge, +100 Guild rep
**Prerequisites:** Quest 8
**Notes:** **PROMOTION TO ELITE.** 5 resolution paths with major consequences.

**Choice Consequences:**
- Duel victory: +30 Guild rep
- Negotiate territory: +40 Guild rep
- Bribe to leave: +10 Guild rep
- Violent confrontation: +20 Guild, -15 Town Guard rep
- Alliance formed: +50 Guild rep (BEST, requires Charisma 60+)

**Required NPCs:**
- `guildmaster_vorn_dalhurst`
- `iron_blades_leader` (Thornfield)

**Required Locations:**
- `iron_blades_resolution` (interaction trigger)

---

### Rank: Elite (High-Risk, High-Reward)

#### 10. `adventurers_10_dragon_rumor.json` - "Smoke on the Horizon"
**Objective:** Investigate dragon sighting, discover it's a wyvern, hunt it
**Rewards:** 500g, 1200 XP, Dragonscale Shield, +150 Guild rep
**Prerequisites:** Quest 9
**Notes:** Major boss fight. Wyvern is extremely dangerous (recommend level 20+).

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `wyvern` (1x, raid-tier boss)

**Required Locations:**
- `kazer_dun_entrance` (investigation start)
- `wyvern_nest` (boss lair near Kazer-Dun)
- `wyvern_observation` (tracking marker)

**Required Items:**
- `wyvern_scales` (harvest 5x from corpse)
- `dragonscale_shield` (legendary reward)

---

#### 11. `adventurers_11_guild_politics.json` - "Internal Affairs"
**Objective:** Investigate corruption in the Guild, expose or accept bribe
**Rewards:** 450g, 1000 XP, Guild Officer Seal, +100 Guild rep
**Prerequisites:** Quest 10
**Notes:** Investigation quest with moral choices. Exposing traitor gives Officer rank.

**Choice Consequences:**
- Expose traitor: +50 Guild rep (BEST)
- Accept bribe: 1000g, -25 Guild, +20 Thieves rep
- Kill traitor: +30 Guild rep

**Required NPCs:**
- `guildmaster_vorn_dalhurst`
- `guild_witness` (4x different NPCs)
- `guild_traitor` (corrupt officer)

**Required Locations:**
- `secret_meeting_site` (stealth objective)
- `corruption_resolution` (confrontation trigger)

**Required Items:**
- `guild_ledger_evidence` (3x different ledgers)
- `guild_officer_seal` (reward item)

---

#### 12. `adventurers_12_legendary_contract.json` - "The Impossible Contract"
**Objective:** Clear deepest level of Willow Dale, defeat Ancient Guardian
**Rewards:** 750g, 1500 XP, Legendary Adventurer Cloak, +200 Guild rep
**Prerequisites:** Quest 11
**Notes:** Multi-stage epic quest. Ancient Guardian is raid-tier boss.

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- `ancient_guardian` (1x, ultimate boss)

**Required Locations:**
- `willow_dale_sealed_door` (locked entrance)
- `willow_dale_throne_room` (final chamber)

**Required Items:**
- `ancient_key_fragment` (3x, hidden in Willow Dale levels 1-3)
- `blade_of_legends` (ultimate weapon, throne room treasure)
- `legendary_adventurer_cloak` (reward, massive stat bonuses)

---

### Rank: Champion (Final Promotion)

#### 13. `adventurers_13_champion.json` - "Legend in the Making"
**Objective:** Defeat Guildmaster Vorn in champion trial combat
**Rewards:** 1000g, 2000 XP, Champion Circlet, Vorn's Battleaxe, +300 Guild rep
**Prerequisites:** Quest 12
**Notes:** **FINAL PROMOTION TO CHAMPION.** Boss fight against Vorn at full power.

**Required NPCs:**
- `guildmaster_vorn_dalhurst` (also as boss: `vorn_champion_form`)

**Required Locations:**
- `guild_arena` (Dalhurst Guild Hall arena)

**Required Items:**
- `champion_circlet` (reward, +5 all combat stats)
- `vorns_battleaxe` (unique legendary weapon)

---

### Repeatable Content

#### 14. `adventurers_repeatable_bounty.json` - "Guild Bounty Board"
**Objective:** Complete rotating bounty contracts
**Rewards:** 200g, 500 XP, +25 Guild rep per completion
**Prerequisites:** Quest 13 (Champion rank)
**Notes:** REPEATABLE. Integrates with BountyManager. Weekly rotation.

**Required NPCs:**
- `guildmaster_vorn_dalhurst`

**Required Enemies:**
- Varies based on bounty (uses BountyManager system)

---

## Integration Requirements

### NPCs to Create/Verify

| NPC ID | Location | Role |
|--------|----------|------|
| `guildmaster_vorn_dalhurst` | Dalhurst Guild Hall | Quest giver, turn-in, final boss |
| `halvard_the_supplier` | Dalhurst gate | Escort target (Quest 3) |
| `millbrook_elder` | Millbrook | Quest info NPC (Quest 6) |
| `iron_blades_leader` | Thornfield | Rival guild leader (Quest 9) |
| `guild_witness` | Dalhurst (4x) | Investigation targets (Quest 11) |
| `guild_traitor` | Dalhurst | Corrupt officer (Quest 11) |

### Enemies to Verify

All enemies already exist in `data/enemies/`:
- `wolf` ✓
- `giant_rat` ✓
- `human_bandit` ✓
- `bandit_captain` ✓
- `giant_spider` ✓
- `dire_wolf` ✓
- `skeleton_warrior` (may need creation)
- `ogre` ✓
- `wyvern` ✓
- `ancient_guardian` (needs creation - raid boss)
- `vorn_champion_form` (needs creation - special Vorn boss variant)

### Locations to Create

| Location ID | Zone | Description |
|-------------|------|-------------|
| `dalhurst_warehouse` | Dalhurst | Rat-infested building interior |
| `crossroads_bandit_camp` | Crossroads | Bandit encampment |
| `willow_dale_corpse_site` | Willow Dale | Dead adventurers + tokens |
| `millbrook_beast_lair` | Near Millbrook | Dire wolf den |
| `willow_dale_deep` | Willow Dale | New unexplored section |
| `willow_dale_deep_end` | Willow Dale | Exploration endpoint |
| `willow_dale_vault_puzzle` | Willow Dale | Optional puzzle room |
| `crossroads_ogre_camp` | Crossroads | Ogre's camp |
| `secret_meeting_site` | Dalhurst outskirts | Corruption meeting place |
| `wyvern_nest` | Kazer-Dun entrance area | Wyvern lair |
| `wyvern_observation` | Near nest | Tracking marker |
| `willow_dale_sealed_door` | Willow Dale | Locked entrance to deepest level |
| `willow_dale_throne_room` | Willow Dale | Final boss chamber |
| `guild_arena` | Dalhurst Guild Hall | Champion trial arena |

### Items to Create

| Item ID | Type | Quest | Notes |
|---------|------|-------|-------|
| `guild_token` | Quest Item | 1, 5 | Proof of membership |
| `adventurer_badge_member` | Badge | 3 | Member rank badge |
| `dire_wolf_pelt` | Material | 6 | Trophy from dire wolf |
| `dire_wolf_cloak` | Armor | 6 | Reward item |
| `adventurer_badge_veteran` | Badge | 6 | Veteran rank badge |
| `ancient_amulet` | Artifact | 7 | Vault treasure |
| `enchanted_explorer_boots` | Armor | 7 | Trap detection bonus |
| `adventurer_badge_elite` | Badge | 9 | Elite rank badge |
| `wyvern_scales` | Material | 10 | Harvested from wyvern |
| `dragonscale_shield` | Shield | 10 | Legendary defensive item |
| `guild_ledger_evidence` | Quest Item | 11 | Investigation evidence (3x) |
| `guild_officer_seal` | Badge | 11 | Officer rank seal |
| `ancient_key_fragment` | Quest Item | 12 | Unlocks sealed door (3x) |
| `blade_of_legends` | Weapon | 12 | Best weapon in game |
| `legendary_adventurer_cloak` | Armor | 12 | Massive stat bonuses |
| `champion_circlet` | Helmet | 13 | +5 all combat stats |
| `vorns_battleaxe` | Weapon | 13 | Unique legendary |

---

## Faction Reputation Totals

Completing the entire quest chain (1-13) grants:
- **Adventurer's Guild:** +1,575 reputation
- **Merchant Guild:** +85 reputation (side benefit)
- **Thieves Guild:** +20 reputation (if bribed in Quest 11)
- **Town Guard:** -15 reputation (if violent in Quest 9)

Additional reputation from repeatable bounties scales infinitely.

---

## Design Philosophy

1. **Escalating Difficulty:** Each quest tier increases combat and objective complexity
2. **Meaningful Choices:** Quests 4, 8, 9, 11 have multiple resolution paths with consequences
3. **Emotional Investment:** Quest 5 creates attachment to fallen Guild members
4. **Epic Payoff:** Final quests (12-13) feel legendary and rewarding
5. **Replayability:** Repeatable bounties provide endgame content

---

## Geographic Constraints (ENFORCED)

All quests stay within the specified region:
- Elder Moor ✓
- Dalhurst ✓
- Thornfield ✓
- Millbrook ✓
- Crossroads ✓
- Willow Dale ✓
- Bandit Hideout (referenced)
- Kazer-Dun Entrance ✓

**NO quests send players south of Kazer-Dun.**

---

## Next Steps for Implementation

1. **Create missing NPCs** (see table above)
2. **Create missing enemies** (`skeleton_warrior`, `ancient_guardian`, `vorn_champion_form`)
3. **Create quest items** (see item table)
4. **Build location markers** in existing zones
5. **Implement special mechanics:**
   - Escort system for Quest 3
   - Ogre dialogue for Quest 8
   - Investigation mechanics for Quest 11
   - Multi-fragment key system for Quest 12
   - Boss fight AI for Vorn (Quest 13)
6. **Hook up to QuestManager** (all quests use standard JSON format)
7. **Test progression chain** (ensure prerequisites work)
8. **Balance rewards** based on playtesting

---

## Lore Notes

**Guildmaster Vorn:**
- Gruff but fair veteran adventurer
- Values proven skill over talk
- Has cleared Willow Dale's upper levels personally
- Deeply cares about Guild members (Quest 5 motivation)
- Corruption in his ranks pains him (Quest 11)
- Champion trial is his way of ensuring worthy successors

**Adventurer's Guild Culture:**
- Meritocracy - rank earned through deeds
- Mutual support - "Guild takes care of its own"
- Professional reputation matters
- Contracts range from mundane (rats) to legendary (impossible contract)
- Champion title is recognized realm-wide

**The Impossible Contract:**
- On the board for years, many have died trying
- Willow Dale's deepest level is ancient elven ruins
- Ancient Guardian is a magical construct, not living
- Blade of Legends was wielded by an elven hero centuries ago
- Completing it makes player a living legend
