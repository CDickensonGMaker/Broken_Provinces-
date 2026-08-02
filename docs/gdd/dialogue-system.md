# Dialogue System GDD

**Version:** 1.0
**Last Updated:** 2026-05-25
**Status:** Implemented

---

## 1. Overview

Broken Provinces uses a hybrid dialogue system combining:
1. **Scripted Dialogue Trees** - Traditional branching dialogue with conditions and actions
2. **Topic-Based Conversations** - Morrowind/Oblivion-style topic selection with dynamic responses

The system supports skill checks, faction reputation gates, quest integration, and NPC memory.

**Core Files:**
- `scripts/systems/dialogue/dialogue_data.gd` - DialogueData resource class
- `scripts/systems/dialogue/dialogue_manager.gd` - Tree dialogue orchestration
- `scripts/systems/dialogue/conversation_system.gd` - Topic-based conversation orchestration

---

## 2. Player Fantasy

NPCs feel like real inhabitants of the world who remember past conversations, have opinions based on faction relationships, and offer different information depending on the player's skills and reputation.

---

## 3. Scripted Dialogue Trees

### 3.1 Data Structure

```
DialogueData (Resource)
├── id: String
├── display_name: String
├── start_node_id: String
└── nodes: Array[DialogueNode]
    ├── id: String
    ├── speaker: String
    ├── text: String (supports {placeholders})
    ├── is_end: bool
    ├── auto_continue_to: String
    ├── choices: Array[DialogueChoice]
    │   ├── text: String
    │   ├── next_node_id: String
    │   ├── conditions: Array[DialogueCondition]
    │   └── actions: Array[DialogueAction]
    └── actions: Array[DialogueAction] (execute on node enter)
```

### 3.2 Condition Types

| Type | Description | Parameters |
|------|-------------|------------|
| NONE | Always available | - |
| QUEST_STATE | Quest in specific state | quest_id, state |
| QUEST_COMPLETE | Quest completed | quest_id |
| HAS_ITEM | Player has item | item_id, quantity |
| HAS_GOLD | Player has gold | amount |
| FLAG_SET | Global flag is true | flag_name |
| FLAG_NOT_SET | Global flag is false | flag_name |
| STAT_CHECK | Stat meets threshold | stat_id, min_value |
| SKILL_CHECK | Skill meets threshold | skill_id, min_value |
| TIME_OF_DAY | Current time period | time_string |
| REPUTATION | Faction reputation | faction_id, min_rep |
| FACTION_MEMBERSHIP | Is faction member | faction_id |
| FACTION_RANK | Has rank in faction | faction_id:rank_name |
| LORE_DISCOVERED | Lore entry found | lore_id |
| BESTIARY_DISCOVERED | Creature entry found | creature_id |
| RANDOM_CHANCE | Percentage chance | percent (0-100) |
| PLAYER_RACE | Check player race | race_string |
| PLAYER_CAREER | Check player career | career_string |
| MORALITY | Check morality tier | tier_string |
| GUILD_RANK | Check guild rank | guild_id, min_rank |

### 3.3 Action Types

| Type | Description | Parameters |
|------|-------------|------------|
| NONE | No action | - |
| GIVE_ITEM | Give item to player | item_id, quantity |
| TAKE_ITEM | Remove from inventory | item_id, quantity |
| GIVE_GOLD | Give gold | amount |
| TAKE_GOLD | Remove gold | amount |
| START_QUEST | Begin quest | quest_id |
| COMPLETE_QUEST | Complete quest | quest_id |
| ADVANCE_QUEST | Progress objective | quest_id, objective_id |
| COMPLETE_QUEST_OBJECTIVE | Complete specific objective | quest_id:objective_id |
| SET_FLAG | Set global flag | flag_name |
| CLEAR_FLAG | Clear global flag | flag_name |
| SKILL_CHECK | Perform skill check | skill_id, dc, success_node, fail_node |
| MODIFY_REPUTATION | Change faction rep | faction_id, amount |
| GIVE_XP | Award experience | amount |
| HEAL_PLAYER | Restore HP | amount (0 = full) |
| TELEPORT | Move player | location_id |
| OPEN_SHOP | Open shop UI | shop_id |
| PLAY_SOUND | Play sound effect | sound_path |
| SET_NPC_STATE | Change NPC behavior | state_string |
| SPAWN_ERRAND | Create errand quest | errand_id |
| START_BOAT_VOYAGE | Begin boat travel | route_id |
| DISCOVER_LORE | Unlock lore entry | lore_id |
| DISCOVER_RECIPE | Unlock crafting recipe | recipe_id |
| DISCOVER_BESTIARY | Unlock bestiary | creature_id |
| START_DUEL | Start non-lethal duel | duel_id, yield_threshold |

---

## 4. Topic-Based Conversations

### 4.1 Topic Types

| Topic | Description | Availability |
|-------|-------------|--------------|
| LOCAL_NEWS | Area-specific information | Always |
| RUMORS | Gossip and hearsay | Always |
| PERSONAL | NPC's personal life | Always |
| DIRECTIONS | Location information | Always |
| TRADE | Shop/merchant topics | Merchants only |
| WEATHER | Weather discussion | Always |
| QUESTS | Available work/bounties | NPCs with quests |
| GOODBYE | End conversation | Always |

### 4.2 Response Selection

Responses are selected in priority order:
1. **Unique Responses** - Specific to this NPC
2. **Archetype Responses** - Based on NPC type (merchant, guard, priest)
3. **Generic Responses** - Fallback for any NPC

### 4.3 Disposition System

| Range | Label | Effect |
|-------|-------|--------|
| 0-10 | Hostile | Will not talk, may attack |
| 11-25 | Unfriendly | Minimal responses |
| 26-40 | Neutral | Standard responses |
| 41-60 | Warm | Better information |
| 61-75 | Friendly | Quest offers, discounts |
| 76-90 | Allied | Secrets, special options |
| 91-100 | Devoted | Maximum trust |

### 4.4 Persuasion System

| Action | Effect on Success | Risk on Failure |
|--------|-------------------|-----------------|
| ADMIRE | +5 to +15 disposition | -2 disposition |
| INTIMIDATE | +10 to +20 disposition | -5 to -15 disposition |
| BRIBE | +5 to +25 disposition | Gold lost, -5 disposition |
| TAUNT | Variable | -10 disposition |

Formula:
```
Success Chance = 50% + (Speech × 2) + (Skill × 3) - (NPC_Will × 2)
Disposition Change = Base + (Speech / 5)
```

---

## 5. NPC Memory System

NPCs remember what they've told the player:
- Memory key format: `"npc_id:response_id"`
- When the same response would repeat, show reminder: "You already know this"
- Memory persists across saves

---

## 6. Skill Checks in Dialogue

### 6.1 Check Process

1. Action specifies skill, DC, success_node, failure_node
2. DiceManager rolls d10 + skill bonus
3. Visual feedback shows roll result
4. Dialogue branches based on success/failure

### 6.2 Formula

```
Roll = d10
Bonus = Stat + Skill
Total = Roll + Bonus
Success = Total >= DC OR Roll == 10 (critical)
Auto-Fail = Roll == 1 (critical failure)
```

---

## 7. Context Variables

Dialogue text supports placeholder substitution:
```
Context: {"merchant_id": "blacksmith_01", "item_name": "Iron Sword"}
Text: "I see you've brought the {item_name}. {merchant_id} will be pleased."
Result: "I see you've brought the Iron Sword. blacksmith_01 will be pleased."
```

---

## 8. Scene Transition Pattern

For dialogue that triggers scene changes (boat travel, teleport):

1. Actions placed on END nodes (not choices)
2. Player sees final text, presses Continue
3. `_execute_node_actions()` runs all actions
4. Pending flag set (e.g., `_pending_boat_voyage:route_id`)
5. `end_dialogue()` closes UI
6. Deferred check triggers scene change

---

## 9. Integration Points

| System | Integration |
|--------|-------------|
| QuestManager | START_QUEST, COMPLETE_QUEST, ADVANCE_QUEST actions |
| InventoryManager | GIVE_ITEM, TAKE_ITEM, HAS_ITEM conditions |
| FactionManager | REPUTATION conditions, MODIFY_REPUTATION actions |
| FlagManager | FLAG_SET conditions, SET_FLAG actions |
| DiceManager | SKILL_CHECK actions |
| BountyManager | QUESTS topic bounty generation |
| ShopUI | OPEN_SHOP action |
| BoatTravelManager | START_BOAT_VOYAGE action |
| DuelManager | START_DUEL action |

---

## 10. Edge Cases

### Empty Choices
- If no choices pass conditions, show "..." and auto-close

### Mid-Dialogue Save
- Dialogue state is not saved; save during dialogue ends conversation

### NPC Death Mid-Dialogue
- Dialogue ends immediately

### Concurrent Dialogues
- Only one dialogue active at a time; new dialogue requests fail

---

## 11. Dependencies

| File | Purpose |
|------|---------|
| dialogue_data.gd | DialogueData resource |
| dialogue_node.gd | DialogueNode resource |
| dialogue_choice.gd | DialogueChoice resource |
| dialogue_condition.gd | DialogueCondition resource |
| dialogue_action.gd | DialogueAction resource |
| dialogue_manager.gd | Tree dialogue autoload |
| conversation_system.gd | Topic conversation autoload |
| dialogue_box.gd | UI component |

---

## 12. Tuning Knobs

| Parameter | Location | Default |
|-----------|----------|---------|
| Default disposition | conversation_system.gd:49 | 50 |
| Hostile threshold | conversation_system.gd:56 | 10 |
| Friendly threshold | conversation_system.gd:60 | 75 |
| Skill check crit (d10) | dice_manager.gd | 10 |
| Skill check crit fail | dice_manager.gd | 1 |

---

## 13. Acceptance Criteria

- [ ] Scripted dialogue trees branch correctly based on conditions
- [ ] All action types execute correctly
- [ ] Topic-based conversations select appropriate responses
- [ ] Disposition affects available responses
- [ ] Persuasion system modifies disposition
- [ ] Skill checks branch dialogue correctly
- [ ] NPC memory prevents duplicate information
- [ ] Scene transitions work from dialogue actions
- [ ] Flags persist across saves
