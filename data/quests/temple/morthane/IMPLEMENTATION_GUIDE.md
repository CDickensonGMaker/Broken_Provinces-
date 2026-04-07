# Morthane Quest Chain - Implementation Guide

Quick reference for implementing the Morthane quest chain in Catacombs of Gore.

---

## Step 1: Create the Priest NPC

**File:** `data/npcs/priest_morthane.tres` (or similar)

**Properties:**
- `npc_id`: `priest_morthane_elder_moor`
- `npc_name`: "Priest of Morthane"
- `npc_type`: "priest"
- `sprite`: Priest sprite with dark/death theme colors
- `location`: Temple of Three Gods in Elder Moor
- `faction`: `church_of_morthane`

**Spawn Location:** Temple interior in Elder Moor

---

## Step 2: Create Missing Enemy Types

### Required Bosses (Custom EnemyData)

1. **Death Knight Commander** (`death_knight_commander`)
   - Level: 25-30
   - HP: 250-300
   - Found in: Bandit Hideout (Quest 9)
   - Faction: Undead
   - Special: Heavy armor, powerful melee

2. **Lich Aspirant Valdris** (`lich_aspirant_valdris`)
   - Level: 20-25
   - HP: 180-220
   - Found in: Willow Dale (Quest 7)
   - Faction: Undead
   - Special: Magic attacks, necromancy

3. **Undead Lord Malthor** (`undead_lord_malthor`)
   - Level: 30-35
   - HP: 400-500
   - Found in: Kazer-Dun Entrance catacombs (Quest 10 final boss)
   - Faction: Undead
   - Special: Strongest undead, multi-phase fight

### Named NPCs for Quests

4. **Necromancer Aeris** (`necromancer_aeris`)
   - Dialogue-enabled enemy (Quest 4)
   - Can be killed, redeemed, or spared
   - Sets flags based on choice

---

## Step 3: Create Quest Items

**File:** Add to `data/items/quest_items.json` or ItemData resources

### Starter Items (Given at Quest Start)
- `burial_incense` - Consumable, used for burial rites
- `holy_water` - Consumable, purifies undead corruption
- `morthane_sacred_flame` - Quest item, one-time use

### Collectible Items (Found in World)
- `ghost_locket` - Quest item for Quest 2
- `necromancer_journal` - Readable item for Quest 4
- `phylactery_research` - Readable item for Quest 7
- `deaths_lily` - Ritual component for Quest 8
- `grave_soil` - Ritual component for Quest 8
- `rebirth_incense` - Ritual component for Quest 8

### Reward Items (Equipment/Usables)
- `ghost_touched_trinket` - Trinket (detect undead nearby?)
- `grave_warden_blessing` - Consumable buff vs undead
- `death_warden_cloak` - Armor, resist death/necrotic
- `morthane_amulet` - Amulet, +Intuition or resist undead
- `speak_with_dead_scroll` - Consumable, talk to corpses
- `anti_undead_longsword` - Weapon, bonus damage vs undead
- `cycle_wisdom_ring` - Ring, death resistance
- `reapers_blade` - Weapon, lifesteal on kill
- `morthane_shroud` - Legendary armor/cloak (champion reward)

---

## Step 4: Create Interactable Markers

These are typically Node3D markers with metadata or Area3D triggers.

### Elder Moor Temple Area
- `shrine_of_endings` - Meditation altar (Quests 5, 10)
- `mortality_trial_altar` - Trial location (Quest 5)
- `death_walk_altar` - Near-death ritual (Quest 10)
- `rebirth_ritual_circle` - Ritual preparation (Quest 8)
- `rebirth_ritual_altar` - Rebirth ceremony (Quest 8)

### Crossroads
- `burial_site_marker` (x3) - Unmarked graves for rites (Quest 1)

### Dalhurst
- `ghost_grave_marker` - Ghost's grave (Quest 2)
- Create chest with `ghost_locket` (spawned on accept)

### Thornfield
- `desecrated_grave_marker` (x3) - Graves to purify (Quest 3)

### Millbrook
- `murder_victim_corpse` - Body to examine (Quest 6)

### Willow Dale Ruins
- `lich_transformation_altar` - Ritual site (Quest 7)
- Chest with `phylactery_research` (spawned on accept)
- Chest with `necromancer_journal` (spawned on accept)

### Bandit Hideout
- `corruption_nexus` - Source of undead (Quest 9)
- `corruption_nexus_purified` - After cleansing (Quest 9)

### Kazer-Dun Entrance
- `kazer_dun_catacombs` - Entrance to deep catacombs (Quest 10)
- `morthane_champion_altar` - Final blessing altar (Quest 10)

---

## Step 5: Create Supporting NPCs

### Dalhurst
- `innkeeper_dalhurst` - Knows about ghost (Quest 2)

### Millbrook
- `guard_captain_millbrook` - Reports murder (Quest 6)
- `merchant_vrell` - The killer (Quest 6)

### Crossroads
- `merchant_elara` - Dying merchant seeking rebirth (Quest 8)

---

## Step 6: Set Up Dialogue Trees

### Priest of Morthane Base Dialogue

**Initial Meeting (No Quests Done):**
- Greeting about Morthane's philosophy
- Offer Quest 1 ("Would you aid me in a sacred duty?")

**After Quest 1-4 (Not Yet Devotee):**
- Acknowledge progress
- Discuss death and the cycle
- Offer next quest in chain

**Offer Devotion (Quest 5 Available):**
- "You have proven yourself... are you ready to dedicate yourself?"
- Choice: Accept or Decline
- If accept: Set `morthane_devotee` flag
- If decline: Set `morthane_devotion_declined` flag, chain ends

**After Becoming Devotee:**
- New greeting: "Keeper of the Cycle, welcome."
- Offer advanced quests (6-10)
- Offer repeatable cleansing quest

**After Becoming Champion:**
- New greeting: "Deathwalker, your presence honors us."
- Acknowledge ultimate dedication
- Repeatable quest always available

### Quest-Specific Dialogue

**Quest 4 - Necromancer Aeris:**
Create dialogue tree with 3 choices:
1. "You must die for this corruption." → Combat, sets `necromancer_aeris_killed`
2. "Give up this dark path and serve the cycle." → Sets `necromancer_aeris_redeemed`
3. "I will not interfere." → Sets `necromancer_aeris_freed`, may spawn hostile later

**Quest 6 - Merchant Vrell (Killer):**
After identifying via Speak with Dead:
1. "You're under arrest." → Sets `merchant_vrell_arrested`
2. "Justice demands your death." → Combat, sets `merchant_vrell_executed`

---

## Step 7: Update FlagManager

Add these flags to the game's flag system:

### Quest Progression Flags
- `morthane_devotee` - Player is devotee (gates Quests 6-10)
- `morthane_devotion_declined` - Player declined (ends chain)
- `morthane_champion` - Player is champion (from Quest 10)
- `deathwalker_title` - Player has Deathwalker title

### Quest Choice Flags
- `necromancer_aeris_killed` - Quest 4 outcome
- `necromancer_aeris_redeemed` - Quest 4 outcome
- `necromancer_aeris_freed` - Quest 4 outcome
- `merchant_vrell_arrested` - Quest 6 outcome
- `merchant_vrell_executed` - Quest 6 outcome

---

## Step 8: Configure FactionManager

Add faction if it doesn't exist:

```gdscript
# In faction_manager.gd or faction definitions
{
    "church_of_morthane": {
        "name": "Church of Morthane",
        "parent_faction": "church_of_three",
        "description": "Devotees of death and rebirth, defenders of the cycle"
    }
}
```

---

## Step 9: Test Quest Chain

### Test Sequence
1. Talk to Priest → Start Quest 1
2. Complete Quest 1 → Auto-starts Quest 2
3. Complete Quests 2-4 sequentially
4. Quest 5: **CRITICAL TEST**
   - Accept devotion → Should set `morthane_devotee` flag
   - Check that Quest 6 becomes available
   - OR decline → Quest chain ends
5. Complete Quests 6-10 (devotee only)
6. Verify repeatable quest available after Quest 5

### Test Checklist
- [ ] All quests load without JSON errors
- [ ] Quest chain auto-advances via `next_quest`
- [ ] Devotee flag properly gates Quests 6-10
- [ ] Choice consequences apply (check flags)
- [ ] Faction reputation increases correctly
- [ ] Spawn-on-accept creates chests with quest items
- [ ] All NPCs exist and are interactable
- [ ] All enemies spawn correctly
- [ ] All markers/interactables trigger properly
- [ ] Repeatable quest has 7-day cooldown

---

## Step 10: Integrate with Temple UI

### Temple Blessing System
If the temple has a blessing system, add:

**Morthane's Blessing:**
- Name: "Blessing of the Cycle"
- Effect: +10% damage vs undead, +5% death resistance
- Duration: 1 hour (in-game)
- Cost: 50 gold
- Available to: Anyone (devotees get discount?)

### Other Priests' Dialogue

**Priest of Chronos:**
If player is `morthane_devotee`:
- "I see you walk with Morthane now. Time and Death are forever intertwined."

**Priest of Gaela:**
If player is `morthane_devotee`:
- "Death feeds the soil, and from it grows new life. You understand this cycle well."

**Do NOT lock out other quests.** Player can be devotee of Morthane AND do quests for other gods.

---

## Content Scaling Recommendations

### Quest Difficulty by Tier

**Tier 1 (Quests 1-3):** Player Level 5-10
- Weak undead (skeleton_warrior)
- Basic bandits
- Simple fetch/escort mechanics

**Tier 2 (Quests 4-5):** Player Level 10-15
- Tougher undead (skeleton_shade)
- Boss-level NPCs with dialogue
- Moral choices

**Tier 3 (Quests 6-8):** Player Level 15-25
- Elite undead
- Investigation mechanics
- Rare rewards

**Tier 4 (Quests 9-10):** Player Level 25-35
- Massive enemy counts
- Boss fights
- Epic rewards

**Repeatable:** Player Level 10+ (scales with player)

---

## Optional: Voice Lines

If adding VO for the Priest of Morthane:

**Greeting Lines:**
- "Death comes for all. It is not to be feared, but understood."
- "Welcome, child of the cycle."
- "The dead whisper their gratitude for your service."

**Quest Assignment:**
- "The cycle has been disrupted. Will you restore balance?"
- "Undeath is an abomination. Help me cleanse it."

**Devotee Greeting:**
- "Keeper of the Cycle, your path grows darker... and more enlightened."
- "Welcome, one who walks between life and death."

**Champion Greeting:**
- "Deathwalker, your legend precedes you."
- "Champion of Morthane, the dead sing your praises."

---

## Summary

**Files Created:**
- 11 quest JSON files in `data/quests/temple/morthane/`
- README.md (full documentation)
- IMPLEMENTATION_GUIDE.md (this file)

**Total Reputation Gain:** 370+ church_of_morthane, 187+ church_of_three

**Total Gold Rewards:** 2,925 gold (if all completed)

**Total XP Rewards:** 10,250 XP (if all completed + repeatable done once)

**Key Unlocks:**
- Quest 5: Devotee status (gates Quests 6-10)
- Quest 10: Champion status and Deathwalker title

**Geographic Coverage:**
- Elder Moor (quest hub)
- Dalhurst, Thornfield, Millbrook, Crossroads
- Willow Dale, Bandit Hideout, Kazer-Dun Entrance

All content stays north of Kazer-Dun as required.
