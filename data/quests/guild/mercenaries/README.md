# Iron Company - Mercenary Guild Quest Chain

## Overview
The Iron Company is a professional mercenary guild based in Dalhurst. Led by Captain Roderick Steele, they take military contracts - protection, warfare, and tactical missions. Unlike the Adventurer's Guild (exploration/monster hunting), the Iron Company focuses on disciplined military operations.

**Headquarters:** The Iron Hall, Dalhurst
**Guildmaster:** Captain Roderick Steele
**Faction ID:** `iron_company`

---

## Rank Progression

### Rank 1: Recruit (Quests 1-3)
Basic training and initiation into mercenary life.

**Quest 01: Sign the Contract** (`mercenary_01_enlistment.json`)
- Apply to join the Iron Company
- Combat trial against training soldiers (kill 3)
- Prove discipline and skill
- **Rewards:** 100g, 300 XP, Company Token, +50 Iron Company rep

**Quest 02: Sword and Shield** (`mercenary_02_drill.json`)
- Formation combat drills with veterans (kill 5)
- Complete obstacle course
- Learn Iron Company fighting style
- **Rewards:** 75g, 250 XP, Iron Company Sword & Shield, +25 rep

**Quest 03: Baptism of Steel** (`mercenary_03_first_blood.json`)
- First real combat mission: clear bandit outpost near Elder Moor
- Kill 8 bandits + 1 bandit leader
- Follow orders, stay in formation
- **Rewards:** 150g, 400 XP, Iron Company Armor, +50 rep
- **Promotion:** → Soldier

---

### Rank 2: Soldier (Quests 4-6)
Standard mercenary contracts and combat missions.

**Quest 04: Gold on the Road** (`mercenary_04_caravan_guard.json`)
- Guard caravan from Dalhurst to Thornfield
- Defend against 2 bandit ambushes (6 bandits + 4 scouts)
- Protect cargo at all costs
- **Rewards:** 200g, 500 XP, +30 rep

**Quest 05: Breach the Walls** (`mercenary_05_siege_support.json`)
- Assault fortified bandit stronghold near Willow Dale
- Tactical siege mission: destroy defenses, clear keep
- Kill 10 defenders + 5 elites + 1 commander
- **Rewards:** 250g, 600 XP, Siege Veteran Medal, +40 rep

**Quest 06: No One Left Behind** (`mercenary_06_hostage_rescue.json`)
- Rescue kidnapped merchant from Bandit Hideout
- Stealth or assault approach
- Escort hostage to safety in Elder Moor
- **Rewards:** 300g, 700 XP, Sergeant Insignia, +50 rep
- **Promotion:** → Sergeant

---

### Rank 3: Sergeant (Quests 7-9)
Lead small units and make tactical decisions.

**Quest 07: Lead from the Front** (`mercenary_07_command_trial.json`)
- Command a squad of recruits in live combat
- Clear goblin camp near Thornfield (12 warriors + 1 shaman)
- Keep at least 3 squad members alive
- **Rewards:** 350g, 800 XP, Sergeant Cloak, +40 rep

**Quest 08: Blood and Honor** (`mercenary_08_rival_company.json`)
- Confront rival Black Wolves mercenary company
- Multiple resolution paths: combat, negotiation, or contract competition
- Kill 8 rival mercenaries (optional based on choice)
- **Rewards:** 400g, 900 XP, Black Wolf Trophy, +50 rep

**Quest 09: The Turncloak** (`mercenary_09_betrayal.json`)
- Find traitor selling Iron Company information
- Investigate in Dalhurst and Elder Moor
- Gather evidence, confront traitor
- Execute or exile (player choice)
- **Rewards:** 450g, 1000 XP, Lieutenant Badge, +60 rep
- **Promotion:** → Lieutenant

---

### Rank 4: Lieutenant (Quests 10-12)
High-value contracts and large-scale battles.

**Quest 10: Proxy War** (`mercenary_10_noble_war.json`)
- Rival nobles hiring mercenaries for proxy war
- Lead Iron Company forces in skirmishes near Millbrook
- 3 battles: 10 mercenaries, 6 heavy infantry, 1 commander
- Optional negotiation with enemy commander
- **Rewards:** 600g, 1200 XP, War Veteran Medal, +70 rep

**Quest 11: The Horde** (`mercenary_11_monster_battalion.json`)
- Defend Millbrook against goblin/orc warband
- Large-scale tactical combat (15 goblins + 12 orcs + 3 siege operators + 1 warchief)
- Hold the line against overwhelming force
- **Rewards:** 700g, 1400 XP, Horde Breaker Blade, +80 rep

**Quest 12: Hold the Line** (`mercenary_12_legendary_battle.json`)
- Epic defense of Crossroads against coalition attack
- Bandits + deserters + dark cultists assault (20 + 15 + 10)
- Final duel with enemy warlord
- Legendary last stand scenario
- **Rewards:** 800g, 1600 XP, Crossroads Defender Shield, +100 rep

---

### Rank 5: Captain's Right Hand (Quest 13)
Final test to become second-in-command.

**Quest 13: The Iron Will** (`mercenary_13_second_command.json`)
- Honorable duel with Captain Roderick Steele
- Prove worthy of leading the Iron Company
- Ceremonial combat at Iron Hall Arena
- **Rewards:** 1000g, 2000 XP, Iron Lieutenant Armor + Sword + Cloak, +100 rep
- **Title:** Iron Lieutenant - Captain's second-in-command

---

### Repeatable Content

**Quest 14: Company Contracts** (`mercenary_repeatable_contracts.json`)
- Ongoing mercenary work for consistent income
- Random protection/combat jobs
- Kill 10 contract enemies, return for payment
- **Rewards:** 150g, 300 XP, +10 rep
- **Repeatable:** Yes

---

## Geographic Distribution

All quests restricted to northern region:
- **Dalhurst** - Iron Hall headquarters, quest hub
- **Elder Moor** - Starting area missions
- **Thornfield** - Eastern contracts
- **Millbrook** - Defense missions
- **Crossroads** - Pivotal battles
- **Willow Dale** - Tactical operations
- **Bandit Hideout** - Infiltration missions
- **Kazer-Dun Entrance** - Boundary (do NOT go south)

---

## Quest Design Philosophy

**Iron Company vs Adventurer's Guild:**
| Iron Company | Adventurer's Guild |
|--------------|-------------------|
| Military contracts | Exploration & hunting |
| Tactical warfare | Monster slaying |
| Disciplined formations | Solo/small party work |
| Honor & loyalty | Treasure & glory |
| Protection & siege | Dungeon delving |

**Combat Focus:** All quests involve tactical combat or military operations.

**Escalation:** Quests increase in scale from small skirmishes to epic battles.

**Choice Moments:** Several quests offer multiple resolution paths (negotiation, combat, stealth).

**Reputation Scaling:** Total +725 Iron Company reputation across the chain.

---

## Required NPCs & Locations

### NPCs (to be created)
- Captain Roderick Steele (quest giver) - Dalhurst
- Training Soldiers (combat trials)
- Veteran Soldiers (drill instructors)
- Black Wolf Captain & Mercenaries (quest 8)
- Iron Company Traitor (quest 9)
- Noble Client (quest 10)
- Rival Commanders (quests 10-12)
- Kidnapped Merchant (quest 6)
- Squad Recruits (quest 7)

### Locations (markers/zones to add)
- Iron Hall - Dalhurst (guild headquarters)
- Iron Hall Training Grounds - Dalhurst
- Iron Hall Arena - Dalhurst (duel location)
- Bandit Outpost - Elder Moor area
- Bandit Stronghold - Willow Dale area
- Hostage Cell - Bandit Hideout interior

### Enemy Types Used
- Bandits (various types: scouts, defenders, elites, leaders, commanders)
- Goblins (warriors, shamans, scouts)
- Orcs (warriors, warchief)
- Black Wolf Mercenaries
- Rival Mercenaries & Heavy Infantry
- Dark Cultists
- Deserter Mercenaries
- Enemy Warlord

---

## Implementation Notes

1. **Faction System Integration:** All quests grant `iron_company` reputation
2. **Quest Chaining:** Each quest uses `next_quest` field for automatic progression
3. **Prerequisites:** Each quest requires the previous one (except quest 1)
4. **Optional Objectives:** Some quests have optional paths (stealth vs combat, negotiate vs fight)
5. **Repeatable Content:** Quest 14 can be taken infinitely after joining

---

## Files Created

**Quest JSON Files (14 total):**
- `mercenary_01_enlistment.json`
- `mercenary_02_drill.json`
- `mercenary_03_first_blood.json`
- `mercenary_04_caravan_guard.json`
- `mercenary_05_siege_support.json`
- `mercenary_06_hostage_rescue.json`
- `mercenary_07_command_trial.json`
- `mercenary_08_rival_company.json`
- `mercenary_09_betrayal.json`
- `mercenary_10_noble_war.json`
- `mercenary_11_monster_battalion.json`
- `mercenary_12_legendary_battle.json`
- `mercenary_13_second_command.json`
- `mercenary_repeatable_contracts.json`

**NPC Blueprint:**
- `data/blueprints/npcs/captain_roderick_steele.json`

**Documentation:**
- This file (`README.md`)

---

## Next Steps for Implementation

1. Create Captain Roderick Steele NPC in Dalhurst
2. Build Iron Hall headquarters scene
3. Create required enemy types (if not already exist)
4. Add location markers for quest objectives
5. Wire quest chain to dialogue system
6. Create Iron Company items (token, armor, weapons, medals)
7. Test quest progression and reputation scaling
