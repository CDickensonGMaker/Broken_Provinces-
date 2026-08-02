# Duplicate and parallel systems audit

*Read-only sweep, 2026-08-02, against Caleb's ruling of the same day:*

> **One concept, one authority. Rewrite beats tack-on. Consolidate what works.**

This document finds every place where two mechanisms own one concept, ranks
them, and prescribes one of three dispositions for each. It changes no code.
The fix wave runs after the close-out agent, off this document.

**The prescriptions:**

| Verdict | Meaning |
|---|---|
| **CONSOLIDATE-NOW** | One owner is already correct. The other is a fossil, a copy, or a shim. Mechanical, safe, verifiable by a gate that exists or is cheap to write. |
| **REWRITE** | Neither owner is right on its own. The concept needs one new owner that absorbs both. |
| **KEEP-SPLIT** | Genuinely two concepts that happen to share vocabulary. Justified below. |

**Effort:** S = under half a day. M = one to three days. L = more than three.

---

## The ranked findings

Ordered as the fix wave should run them: safest first, the dialogue call last.

| # | Concept | Owners | Verdict | Effort | Live defect today |
|---|---|---|---|---|---|
| 1 | Current weather | `GameManager.current_weather` (dead) / `WeatherManager.current_weather` (live) | CONSOLIDATE-NOW | S | NPC weather small-talk always says "clear"; encounter danger modifier always 1.0 |
| 2 | Pending-shop protocol | FlagManager / ConversationSystem / DialogueManager | CONSOLIDATE-NOW | S | Two dicts, two poppers; a shop opened from a pool line is invisible to the FlagManager popper |
| 3 | Stat/skill display names | 7 hand-copies | CONSOLIDATE-NOW | S | Drift already happened once (governing-stat map, fixed) |
| 4 | Audio settings | `SaveData.audio_settings` / `GameSettings` | CONSOLIDATE-NOW | S | Loading a save **resets the player's volumes** to hardcoded defaults |
| 5 | Discovered locations | `SaveManager.discovered_locations` / `PlayerGPS.discovered_locations` | CONSOLIDATE-NOW | S | Second copy is permanently empty and round-trips through every save |
| 6 | NPC registry | `WorldData.registered_npcs` | CONSOLIDATE-NOW (delete) | S | Fully dead: zero writers, zero readers, hex-era schema |
| 7 | Dead dialogue presenter | `QuestGiver._create_dialogue_panel` | CONSOLIDATE-NOW (delete) | S | Grond's authored lines in `falkenhaften.gd` are unreachable |
| 8 | `use_legacy_dialogue` | quest_giver | CONSOLIDATE-NOW (delete) | S | Never set true anywhere; a dead branch in the routing switch |
| 9 | Biome selection | `set_biome_from_terrain` (dead) / `set_biome_from_world_biome` (live) | CONSOLIDATE-NOW (delete) | S | Dead table maps a different enum; calling it gives coast sounds on a road |
| 10 | Death / rest / play-time counters | SaveManager / StatsTracker | CONSOLIDATE-NOW | S | Journal's "Deaths" is permanently 0; two clocks disagree by menu time |
| 11 | Notification | `HUD.show_notification` / 5 forwarders / a nonexistent `show_message` | CONSOLIDATE-NOW | S | "Out of ammo!" never prints — the method it calls does not exist |
| 12 | Music key vocabulary | `AudioManager.MUSIC` (6 keys) / level scripts (11) | CONSOLIDATE-NOW | S | Boss music, victory sting and mystic theme all play the wilderness loop |
| 13 | Zone ambience vs biome bed | `AudioManager.play_ambient` / `AmbientSoundscape` | CONSOLIDATE-NOW | S/M | `stop_ambient` has zero callers: walk out of any town and the town murmur follows you into the woods |
| 14 | NPC name pools | `data/npc_names.json` / `WorldLexicon` | CONSOLIDATE-NOW (delete) | S | JSON generates nothing; it exists only to feed the grounding lint |
| 15 | Quest availability gate | `is_quest_available` / `start_quest` | CONSOLIDATE-NOW | S | Cooled-down bounties are offered by every board, then silently refused |
| 16 | Autosave guards | 3 hand-copied guard sets | CONSOLIDATE-NOW | S | Exit-autosave fires while paused in a menu; the periodic one does not |
| 17 | NPC position registry | `PlayerGPS.registered_npcs` | CONSOLIDATE-NOW (delete) | S/M | Write-only, and origin-blind: every cell value is wrong after the first floating-origin shift |
| 18 | Item catalogue | hardcoded id lists / directory walks ×2 | CONSOLIDATE-NOW | M | 11 `.tres` on disk the game cannot load; 6 are named by shipped quests |
| 19 | Quest loaders | 1 runtime + 4 tool walkers | CONSOLIDATE-NOW | M | Town editor sees only flat-dir quests — most of the corpus is invisible when assigning givers |
| 20 | Schedule validation | `validate_content.gd` / `check_living_world.gd` | CONSOLIDATE-NOW | M | Two copies of the action vocabulary and the day band; the two disagree about who is a quest NPC by 44 records |
| 21 | Quest rank gate | `rank_required` / `flag_prerequisites` / auto rank flags | REWRITE | M | Three vocabularies, three stores, one question; the mage ladder's flags never meet FlagManager's |
| 22 | Pause + mouse capture | `BasePopupUI` + 8 others | REWRITE | M | Closing a popup opened over the pause menu unpauses the game with the pause menu still on screen |
| 23 | NPC disposition | ConversationSystem / DispositionCalculator / `npc.disposition_modifier` | REWRITE | M | Three stores, two scales; `base_disposition` is authored at 93 sites and read by nobody |
| 24 | Flag storage | FlagManager / WorldState / `conversation_flags` | REWRITE | M/L | The mirror drops every non-bool and **clears a same-named FlagManager flag on every load** |
| 25 | Civilian / guard spawning | `civilian_npc.gd` (60 factories) / TownSpawner / TownGenerator | REWRITE | M/L | Procedural-town guards get no patrol and report crimes to Elder Moor |
| 26 | Damage application | `CombatManager` / ~30 direct sites | REWRITE | L | Two arity crashes; 12 classes charge no armour at all; Dodge cannot roll against any NPC |
| 27 | **Dialogue substrate** | DialogueManager / ConversationSystem | **REWRITE (substrate) + KEEP-SPLIT (front-ends)** | **L** | 15 of 32 action types silently do nothing on the conversation side; an unreadable condition with `invert` **passes** there |

---

## Top 5 CONSOLIDATE-NOW

These five are mechanical, each fixes a defect a player can feel, and each has a
gate that proves the merge. Do them first, in this order.

### 1. `current_weather` — delete the dead owner

`GameManager.current_weather` (`scripts/core/game_manager.gd:34`) is written only
by `GameManager.set_weather()` (`:339`), which has **zero callers**. It is
permanently `CLEAR`. `WeatherManager.current_weather`
(`scripts/world/weather_manager.gd:10`) is the live owner — it runs transitions,
emits `weather_changed`, and is what `SaveManager._collect_weather_data`
(`scripts/core/save_manager.gd:1541`) saves.

Three consumers read the dead one:

| File:line | What breaks |
|---|---|
| `scripts/systems/dialogue/conversation_system.gd:2604` | `context.weather` is always `"clear"`, so every weather small-talk line in the pools is a lie |
| `scripts/systems/events/encounter_manager.gd:460` | `_get_weather_danger_modifier()` always returns 1.0 — weather never affects encounters |
| `scripts/core/game_manager.gd:526` | `get_weather_effects()` — rain's fire resistance, snow's movement penalty. Zero callers, so dead code, not a live bug |

**Prescription.** Delete `GameManager.current_weather`, `set_weather()` and
`get_weather_effects()`. Repoint the two live readers at
`WeatherManager.current_weather`.

**Gate.** `check_autoload_api.tscn` already resolves every `Autoload.member`
by reflection and fails on anything that does not exist — deleting the field
makes it fail on any surviving reader. Add one assertion to
`check_living_world.gd`: set `WeatherManager` to STORM, build a conversation
context, assert `context.weather == "stormy"`.

### 2. Audio settings — stop the save file overwriting the player's volumes

`GameSettings` (`scripts/data/game_settings.gd:168-172`, `:215-217`) owns the
four volumes in `user://settings.cfg` and applies them at boot. CLAUDE.md says
so, and says not to add preferences to SaveData.

But `SaveManager._apply_save_data()` (`scripts/core/save_manager.gd:748`) still
runs `AudioManager.load_settings(save_data.audio_settings)` **unconditionally**,
and `AudioManager.load_settings` (`scripts/core/audio_manager.gd:1276-1281`)
uses `data.get(key, <default>)`. So loading any save whose `audio_settings` is
`{}` — every old save, and every save written before the field was retired —
resets the player's volumes to 1.0 / 0.7 / 1.0 / 0.5. Nothing writes
`settings.cfg` back afterwards, so the change is silently reverted at the next
boot too. The player's audio preferences are destroyed by loading a game.

**Prescription.** Delete the read at `:748`. Keep `SaveData.audio_settings` as a
dead field for old-save compatibility, written no longer.

**Gate.** `check_serialization.tscn` already round-trips real saves on disk.
Add: set a non-default master volume through `GameSettings`, `save_game()`,
`load_game()`, assert the volume is unchanged.

### 3. Notifications — one HUD entry point, and one that does not exist

`HUD.show_notification` (`scripts/ui/hud.gd:1152`) is the real mechanism, with a
queue. Five files carry a byte-identical six-line forwarder that re-derives the
HUD by group lookup and re-tests `has_method`:

`scripts/characters/ai/follower_manager.gd:624`, `scripts/ui/pause_menu.gd:461`,
`scripts/world/interactables/enchanting_station.gd:139`,
`scripts/world/interactables/spell_making_altar.gd:144`,
`scripts/characters/player/player_controller.gd:977`.

Worse, `scripts/characters/player/player_controller.gd:647-650` calls a second,
invented API:

```gdscript
if hud and hud.has_method("show_message"):
    hud.show_message("Out of %s!" % ammo_name)
```

**`HUD` has no `show_message`.** The `has_method` guard means it fails silently
forever. This is exactly the "guard that guards nothing" shape CLAUDE.md
documents as having cost real money twice.

**Prescription.** Put one `UIManager.notify(text)` in front of the HUD queue,
replace the five forwarders with calls to it, and repoint the `show_message`
call at it.

**Gate.** `check_autoload_api.tscn` covers `UIManager.notify` by reflection the
moment the call sites go through an autoload — which is the point of routing it
through one. The `has_method("show_message")` site disappears with the call.

### 4. Music keys — five requests that silently become wilderness

`AudioManager.play_zone_music` (`scripts/core/audio_manager.gd:881`) falls back
to `MUSIC["wilderness"]` for any key it does not recognise. `MUSIC`
(`:473-492`) has six keys: `menu`, `village`, `wilderness`, `dungeon`, `ruins`,
`horror`. Level scripts request five that do not exist:

| Requested | File:line |
|---|---|
| `"boss"` | `scripts/levels/crossroads_ruins.gd:30` |
| `"boss_fight"` | `scripts/levels/crossroads_ruins.gd:187` |
| `"victory"` | `scripts/levels/crossroads_ruins.gd:210` |
| `"mystic"` | `scripts/levels/athenaeum.gd:25` |
| `"town"` | `scripts/levels/iron_hall.gd:25` |

Three distinct musical beats in the Crossroads Ruins boss fight — the arena
entry, the fight, and the victory sting — all play the same wilderness loop.
The level scripts believe they own a music vocabulary; AudioManager owns a
different one; nothing errors.

**Prescription.** One vocabulary in `AudioManager`. `"town"` is an alias of
`"village"`. `"boss"`, `"boss_fight"`, `"victory"` and `"mystic"` either get
assets (synthesised under `assets/audio/generated/`, per the standing rule) or
an honest declared substitute. Make the fallback **warn once and name the key**
rather than quietly serving wilderness.

**Gate.** Extend `check_audio_events.tscn`: scan every `play_zone_music` literal
across `scripts/` and fail on any key not in `MUSIC` or its alias table. This is
the same shape as the event-name resolution it already gates.

### 5. Ambience — `stop_ambient` has zero callers, so the biome bed never comes back

`AudioManager` arbitrates between the zone ambience (`play_ambient`,
`scripts/core/audio_manager.gd:1010`) and the `AmbientSoundscape` biome bed with
a single boolean, `_biome_ambience_allowed` (`:601`). It is set `false` inside
`play_ambient` (`:1025`) and set back to `true` only by `_on_scene_load_started`
(`:622`) and `stop_ambient` (`:1033`).

**`stop_ambient` has zero call sites outside `audio_manager.gd`.** The file's own
comment (`:615-618`) says so. Eleven town scripts claim the player on entry —
`aberdeen.gd:29`, `dalhurst.gd:37`, `duncaster.gd:20`, `elder_moor.gd:40`,
`falkenhaften.gd:24`, `larton.gd:39`, `millbrook.gd:28`, `pola_perron.gd:25`,
`riverside_village.gd:20`, `thornfield.gd:45`, `town_generator.gd:1010`.

Cell streaming does not fire `scene_load_started`. So walking out of Elder Moor
into the forest — the game's core traversal — leaves the flag `false`, the town
murmur playing over the woods, and the fifteen biome beds shipped on 8/2 muted
until a real scene change. The feature is present, wired, and inaudible.

**Prescription.** The boolean is the wrong shape: it is a lock with no key.
Make `AmbientSoundscape` the sole owner of the ambient slot and let a zone
*push a named bed* into it rather than seize the player. Failing that (smaller,
still correct): have `PlayerGPS.cell_changed` release the lock when the player
leaves the cell whose script took it.

**Gate.** `check_audio_events.tscn`: start in a town, assert the town ambience
plays; emit `PlayerGPS.cell_changed` to a forest cell; assert the biome bed is
audible and the town ambience is not.

---

## The dialogue systems: the verdict

### The question

Two autoloads both render NPC speech:

- **`DialogueManager`** (`scripts/systems/dialogue/dialogue_manager.gd`, 1179
  lines) — authored branching trees. Named nodes, per-choice conditions,
  actions, skill checks with delayed transitions, portraits.
- **`ConversationSystem`** (`scripts/systems/dialogue/conversation_system.gd`,
  2944 lines) — topic pools. Three-tier response selection, disposition,
  anti-repeat memory, persuasion, bounties, quest offers and turn-ins,
  greetings and farewells, the reactive layer.

This was called "deliberately layered". Under the new law, measured.

### The measurement: it is not two systems, it is two front-ends over a duplicated substrate

Neither front-end can do the other's job, and I found no serious argument that
one should. But **four smaller concepts underneath them each have two or three
authorities**, and all four have already diverged.

#### (a) Evaluate a `DialogueCondition` — two owners

`DialogueManager.evaluate_condition` (`dialogue_manager.gd:319`) and
`ConversationSystem._evaluate_condition` (`conversation_system.gd:2771`) are two
independent `match` statements over the same `DialogueData.ConditionType` enum,
backing the same authored JSON shape.

**The divergence is a live bug.** DialogueManager guards `INVALID` *before*
applying `invert`, with a comment saying why:

```gdscript
# dialogue_manager.gd:320-331
# An unreadable condition fails closed, and `invert` must not turn it back
# into an open door.
if condition.type == DialogueData.ConditionType.INVALID:
    return false
var result := _evaluate_condition_internal(condition)
if condition.invert:
    result = not result
```

ConversationSystem has no such guard:

```gdscript
# conversation_system.gd:2771-2778
func _evaluate_condition(condition: DialogueCondition) -> bool:
	var result := _evaluate_condition_internal(condition)
	if condition.invert:
		result = not result
	return result
```

`INVALID` returns `false` from `_evaluate_condition_internal` (`:2863-2865`),
`invert` flips it to `true`. **An unreadable condition with `invert` set passes
in a conversation pool.** That is precisely the failure class the 8/2
fail-closed work existed to close, closed on one side only.

Lesser divergences in the same pair: `MORALITY` routes to
`MoralityManager.allows_action` in one and to a hand-written
`_evaluate_morality_condition` (`:1431`) in the other; `GUILD_RANK` guards an
empty guild id in one and not the other; `FACTION_RANK` splits on `":"` with
different maxsplit.

#### (b) Execute a `DialogueAction` — three vocabularies, 15 of 32 types dead

`DialogueData.ActionType` declares **32** action types. `DialogueManager.execute_action`
(`dialogue_manager.gd:609`) handles all 32. `ConversationSystem.execute_action`
(`conversation_system.gd:2438`) handles 18, and one of those is a stub:

```gdscript
# conversation_system.gd:2476-2478
DialogueData.ActionType.MODIFY_REPUTATION:
    # Future: modify faction reputation
    pass
```

The 14 unhandled types fall through the `match` to `return ""` and do nothing,
silently: `COMPLETE_QUEST_OBJECTIVE`, `START_BOAT_VOYAGE`, `DISCOVER_LORE`,
`DISCOVER_RECIPE`, `DISCOVER_BESTIARY`, `START_DUEL`,
`APPLY_CHOICE_CONSEQUENCE`, `RECRUIT_FOLLOWER`, `COMMAND_FOLLOWER`,
`SET_WORLD_FLAG`, `JOIN_FACTION`, `APPLY_BUFF`, `RENOUNCE_DEVOTION`, `TELEPORT`.

**Fifteen of thirty-two action types are dead on the conversation side.** Ten
of the twelve pool files author `actions` blocks. A pool line that joins a
faction, sets a world flag, hands out a blessing or renounces a god does
nothing at all, and warns about nothing.

There is a **third** action vocabulary — scripted mode's
`_execute_scripted_action` (`conversation_system.gd:1713`) — which does not use
the enum. It matches eleven *strings*: `set_flag`, `clear_flag`, `give_gold`,
`take_gold`, `give_item`, `take_item`, `start_quest`, `complete_quest`,
`modify_disposition`, `turn_hostile`, `arrest`. Two of those
(`modify_disposition`, `turn_hostile`, `arrest`) exist in no other vocabulary.

And `SET_FLAG` means two different things depending on which executor runs it:
DialogueManager's writes to **FlagManager** (`dialogue_manager.gd:1076`),
ConversationSystem's writes to **`conversation_flags`**
(`conversation_system.gd:1291-1293`). See finding 24.

#### (c) Roll a dialogue skill check — two owners, different arithmetic

`DialogueManager._execute_skill_check` (`dialogue_manager.gd:868`) applies
morality modifiers before the roll:

```gdscript
match skill_enum:
    Enums.Skill.PERSUASION:
        morality_bonus = MoralityManager.get_persuasion_modifier(npc_alignment)
    Enums.Skill.INTIMIDATION:
        morality_bonus = MoralityManager.get_intimidation_modifier()
...
DiceManager.make_check(..., skill_value + morality_bonus, ..., bonus_list, true)
```

`ConversationSystem._execute_skill_check_action` (`conversation_system.gd:2513`)
passes `skill_value` raw and `[]` for the bonus list. **The same Persuasion
check against the same NPC succeeds at a different rate depending on which
front-end asked it,** and the player is shown a different bonus breakdown.

Three helper functions are hand-copied alongside them — `_get_stat_name`,
`_get_skill_name`, `_get_skill_governing_stat` — in seven files total
(`dialogue_manager.gd:939/950/934`, `conversation_system.gd:2390/2402/2385`,
`dialogue_box.gd:603`, `innkeeper.gd:779/790`, `rentable_bed.gd:535/546`,
`rest_spot.gd:1182/1193`). The governing-stat map already drifted once and was
consolidated onto `DiceManager.get_stat_for_skill`; the comment at
`dialogue_manager.gd:932-933` records it. The name maps were not.

#### (d) Present a branching choice — three live presenters and one dead one

| Presenter | Driver | UI | Call sites |
|---|---|---|---|
| Node graph | `DialogueManager` | `dialogue_box.gd` (630 lines) | **5** |
| Scripted lines | `ConversationSystem.start_scripted_dialogue` | `conversation_ui.gd` (1450 lines) | **28** |
| Combat parley | `CombatManager` | `humanoid_dialogue.gd` (359 lines) | 1 |
| Hand-built panel | `QuestGiver._create_dialogue_panel` | its own `CanvasLayer` | **0 — dead** |

Scripted mode is a full branching choice tree: lines with `choices`, choices
with `text`, `next_index` and `actions`, an end flag, and a callback. It is
`DialogueData` / `DialogueNode` / `DialogueChoice` re-expressed as untyped
Dictionaries with array indices instead of node ids, authored in GDScript
instead of JSON, and it has **five and a half times as many call sites as the
system built for the job**. `conversation_ui.gd:1120` renders its choices by
*repurposing the topic buttons*.

The fourth is dead: `QuestGiver._open_dialogue` and `_create_dialogue_panel`
(`quest_giver.gd:400`, `:458`) have zero callers — but
`scripts/levels/falkenhaften.gd:257` still authors `grond.quest_dialogues`,
whose only consumer is `_get_dialogue_text`, whose only consumer is the dead
panel. Grond's written lines are unreachable.

#### (e) The routing switch that hides all of this

`QuestGiver.interact()` (`quest_giver.gd:303-343`) chooses between the
mechanisms per NPC:

```gdscript
if turnin_quests: if dialogue_data: DialogueManager... else: _show_quest_turnin_dialogue(...)   # scripted
if dialogue_data and not use_legacy_dialogue: DialogueManager.start_dialogue(...)
_open_conversation()                                                                            # topics
```

So an NPC that has a `dialogue_data` tree **never reaches the reactive layer at
all** — no disposition, no `npc_memory`, no anti-repeat, no caught-lying
greeting, no bounties, no computed flags, none of `reactions.json`. The
game's best-written NPCs are exactly the ones excluded from the reactivity that
8/2 was spent building. An NPC without a tree can never have an authored scene.
Nobody chose this; it is what the `if` does.

`use_legacy_dialogue` is set `false` at eight sites and `true` at none. The
branch is dead.

### The blast radius

| | DialogueManager side | ConversationSystem side |
|---|---|---|
| Autoload | 1179 lines | 2944 lines |
| Shared resource classes | `DialogueData` / `Node` / `Choice` / `Condition` / `Action` / `Loader` — 799 lines, **used by both** | same |
| UI | `dialogue_box.gd` 630 | `conversation_ui.gd` 1450 |
| Data files | 45 tree JSON + 16 `.tres` resources | 12 pool JSON + `pools/unique/` + 1 `.tres` |
| Game call sites | 5 (`quest_giver` ×3, `apprentice_marcus_npc`, `assassin_encounter`) | 7 topic + **28 scripted** |
| Save fields | **none** — delegates entirely to FlagManager | `npc_memory`, `npc_memory_heard_count`, `conversation_flags`, `player_known_topics` |
| Gate | **none** | `check_conversation_tiers.tscn` |

Total dialogue surface: **8504 lines** across the two autoloads, six shared
resource classes and four UIs.

Two asymmetries decide the plan. First, DialogueManager holds **no save state**
— it is a pure executor over FlagManager, so merging into it costs no save
migration. Second, DialogueManager has **no gate at all**, while the pool side
has one; any consolidation must ship a tree-side gate or it is unverifiable.

### The verdict

**KEEP-SPLIT the two front-ends. REWRITE the substrate into one owner. Delete
the third and fourth presenters.**

The concept with two authorities is not "dialogue". "Present an authored
branching scene" and "answer a topic from a weighted pool with memory and
disposition" are genuinely two concepts, and neither implementation contains the
other's essential machinery: DialogueManager has no notion of a pool, a tier, a
disposition or an anti-repeat count; ConversationSystem has no notion of a named
node, a graph edge or a delayed transition. Collapsing them into one would mean
writing the union from scratch and re-authoring 45 trees plus 12 pools. That is
the "rewrite" the law permits but does not require, and it buys nothing a
shared substrate does not.

**What actually violates the law is underneath.** Four concepts, each with two
or three authorities, each already divergent, each divergence currently costing
the player something:

| Concept | Authorities | Prescription |
|---|---|---|
| Evaluate a `DialogueCondition` | 2 | **REWRITE** → one `DialogueRules.evaluate(condition)` |
| Execute a `DialogueAction` | 3 (2 enum + 1 string) | **REWRITE** → one `DialogueRules.execute(action)` |
| Roll a dialogue skill check | 2 | **REWRITE** → one `DialogueRules.skill_check(action)` |
| Present a branching choice | 3 live + 1 dead | **CONSOLIDATE** → scripted mode retires onto `DialogueData`; delete the dead panel |
| Flag storage behind `SET_FLAG` | 2 destinations | **REWRITE** → finding 24 |

### The plan sketch

Six steps. Each is independently shippable and independently verifiable; stop
after any of them and the game is in a better state than before.

**Step 0 — build the missing gate first.** `check_dialogue_engine.tscn`, modelled
on `check_quest_engine.tscn`. Load every tree in `data/dialogue/trees/` and every
pool in `data/dialogue/pools/`; assert every node id referenced by a choice
exists; assert every `condition_type` and every action `type` string parses to a
non-`INVALID` enum value; and — the assertion that bites — **run every authored
action type through both executors and fail if they disagree about whether it is
handled.** That single assertion would have caught all fifteen dead types the
day they diverged. Write this before touching any code; it is the damage report
for everything that follows.

**Step 1 — the fossils (S).** Delete `QuestGiver._open_dialogue`,
`_create_dialogue_panel`, `_get_dialogue_text`, `generic_dialogues`; rehome
Grond's lines from `falkenhaften.gd:257` into a real presenter. Delete
`use_legacy_dialogue` and the dead branch. Delete
`ConversationSystem.pop_pending_shop` and `DialogueManager.pop_pending_shop`;
FlagManager's is the one. Collapse the seven `_get_skill_name` /
`_get_stat_name` copies onto `DiceManager`, beside `get_stat_for_skill` which
already won this argument once. **Nothing behavioural changes; the gate from
step 0 stays green.**

**Step 2 — `DialogueRules`, conditions only (M).** A new plain class (not an
autoload — it is stateless) that owns `evaluate(condition) -> bool`. Seed it
with DialogueManager's version, which is the correct one: it has the
`INVALID`-before-`invert` guard, the empty-id guards, and
`MoralityManager.allows_action`. Point both front-ends at it. Delete
`ConversationSystem._evaluate_condition` and `_evaluate_condition_internal`.
`_evaluate_computed_flag` stays on ConversationSystem for now — it needs
`current_npc`, which is conversation state. **This step alone closes the
`INVALID` + `invert` hole.**

*Verified by:* `check_conversation_tiers.tscn` already asserts a gated line is
ineligible with its state off and eligible with it on, and that an unreadable
condition fails closed — that assertion should now also pass with `invert` set.
Add the mirror of it to `check_dialogue_engine.tscn`.

**Step 3 — `DialogueRules.execute(action)` (M).** Move DialogueManager's
32-branch executor onto `DialogueRules`. Point both front-ends at it.
Delete `ConversationSystem.execute_action`. **This is the step that makes
fifteen action types start working in conversation pools for the first time** —
which is a behaviour change, not a refactor, and it is the reason this step
must land after step 0's gate and be play-tested rather than assumed. Audit
every `actions` block in the twelve pool files for a line that authored one of
the fifteen and has been silently doing nothing: some of those may have been
written *around* by a designer who saw it not work.

Fold the skill-check owner in at the same time — one
`DialogueRules.skill_check(action)`, DialogueManager's version, morality
modifiers included. The conversation side gains the modifiers it should always
have had.

**Step 4 — retire scripted mode onto `DialogueData` (L).** 28 call sites build
`Array[Dictionary]` by hand. `create_scripted_line` / `create_scripted_choice`
are already static factories, so the seam is clean: reimplement those two to
build `DialogueNode` / `DialogueChoice` and hand the result to
`DialogueManager.start_dialogue`, keeping the callback contract
(`get_last_scripted_choice_index` maps to the last `choice_made` signal). The 28
call sites need not change in the first pass. `conversation_ui.gd`'s scripted
branch and its topic-button repurposing then delete; `dialogue_box.gd` becomes
the single choice presenter.

This is the largest step and the one to defer if the wave runs short — but it
is what actually ends "present a branching choice" having three owners.

**Step 5 — the routing switch (M).** With one substrate and one presenter,
`QuestGiver.interact()` stops choosing between engines and starts choosing
between *content*: an NPC with a tree gets the tree **and** the reactive
layer — greeting from the pools, disposition, memory, caught-lying — with the
authored tree as one topic among them, rather than instead of them. That is the
change the grounding law and the reactive layer were both built for and neither
currently reaches the game's 45 authored NPCs.

**What stays split, permanently.** `DialogueManager` owns graphs.
`ConversationSystem` owns pools, topics, disposition, memory and the reactive
layer. `CombatManager`'s `humanoid_dialogue` owns combat parley — it is a
different interaction (it interrupts a fight, it has no NPC id, it ends in
violence or flight) and it should consume `DialogueRules` like the others rather
than be merged into either.

---

## The rest of the findings, in detail

### 21. Quest gating ×5 — mostly sound, one real duplicate, one broken gate

Measured across 228 quest files:

| Gate | Declared | Evaluated against | Files using it |
|---|---|---|---|
| `prerequisites` | `quest_manager.gd:76` | `QuestManager.quests`, state `COMPLETED` | **128** |
| `flag_prerequisites` | `:77` | FlagManager only | **32** |
| `forbidden_flags` | `:78` | FlagManager only | **22** |
| `rank_required` | `:127` | `GuildRankManager.get_guild_rank_level` | **14** |
| `world_condition` (per objective) | `:191` | WorldState only | **2** |

**KEEP-SPLIT: `prerequisites`.** Quest ids, not flags. A distinct concept with
128 users. Leave it.

**KEEP-SPLIT: `flag_prerequisites` / `forbidden_flags`.** They are exact
inverses over one store, evaluated by two functions on one owner
(`flag_manager.gd:473` and `:483`). That is sugar with a single authority, not
two authorities — and the temple chains do author both at once, which reads
clearly. The cost of collapsing them is a 54-file data migration for one word.
**Keeping is cheaper than being wrong** (PROJECT_LAYOUT principle 6).

**REWRITE: guild rank has three vocabularies and three stores.** This is the
real duplicate.

- Thieves' ladder: `rank_required: 2` + `"faction": "thieves_guild"`
  (`data/quests/guild/thieves/thieves_07_noble_heist.json:7-8`), read against
  `GuildRankManager`.
- Mages' ladder: `flag_prerequisites: ["arcane_circle_apprentice"]`
  (`data/quests/guild/mages/mage_04_enchantment_task.json:63`), read against
  FlagManager, raised by hand from a previous quest's `on_complete_flags`.
- And FlagManager *automatically* maintains a **third** family,
  `arcane_circle_rank_novice` / `_apprentice` / … (`flag_manager.gd:52-56`, set
  by `_update_guild_rank_flag` `:193-206`), which is **not** what the mage
  quests test — they test `arcane_circle_novice`, no `_rank_`.

Two ladders, one question, three answers, and the automatic family never meets
the hand-raised one. The notes in `mage_02_library_duty.json` and
`mage_repeatable_research.json:51` record earlier casualties of exactly this
confusion. **Prescription:** `rank_required` is the authority. Migrate the 13
mage quests onto it, delete the hand-raised `arcane_circle_*` flags, keep
FlagManager's automatic family for dialogue conditions only. Effort M. Gate:
`check_quest_engine.tscn` — assert no quest's `flag_prerequisites` contains a
string matching a known guild-rank pattern.

**CONSOLIDATE-NOW: `world_condition` does not gate availability.** CLAUDE.md and
`quest_manager.gd:1704-1706` both say the pre-completion check runs "when the
quest is offered". It does not. `_apply_world_pre_completion()` (`:1707`) is
called only from `start_quest` (`:956`), never from `is_quest_available`
(`:2336`). The New Vegas "you already did this, here's your money" moment
requires the player to accept the quest first. Two files use it, so the fix is
cheap; the doc is what is wrong, or the call site is. Effort S.

**And the two gate sets are hand-duplicated** — `quest_manager.gd:808-813` says
so in a comment. `start_quest` (`:826-853`) checks the same six gates as
`is_quest_available` (`:2336-2360`) **plus** `is_bounty_on_cooldown` (`:835`).
So `get_available_quests()` lists cooled-down bounties on every board and
`start_quest` then refuses them with no message. Effort S; that is finding 15.

### 23. Disposition — three stores, two scales, and 93 dropped authoring sites

| Store | Where | Scale | Persisted? |
|---|---|---|---|
| `conversation_flags["disposition:<npc_id>"]` | `conversation_system.gd:1181`, `:1188` | 0–100, bands at 10/25/40/60/75/90 (six) | yes, in the conversation save section |
| `npc.disposition_modifier` | `civilian_npc.gd:115`, written by `DispositionCalculator.modify_npc_disposition` (`:479-483`) | −50…+50 | **no** — dies with the scene |
| `DispositionCalculator.calculate_disposition()` | `scripts/systems/factions/disposition_calculator.gd:33` | 0–100, bands at 20/40/60/80 (five) | recomputed per call from faction rep, morality, race, career, bounty, weapon drawn, + store 2 |

`ConversationSystem.get_disposition` (`:1160`) reads store 1 and nothing else.
`CivilianNPC.get_disposition` (`civilian_npc.gd:425`) returns store 3 and
ignores store 1. `GameSystems.allows_interaction` (`:490`) gates trade, quests
and rumours off store 3.

**Three consequences, all live:**

1. **Persuasion does not change how an NPC treats you, only what they say.**
   `ConversationSystem.perform_persuasion` and `record_caught_lying`
   (`:1196-1203`) write store 1. Trade prices, quest offers and rumour access
   read store 3. Succeeding at an ADMIRE check moves nothing the player can
   spend it on.
2. **The two scales mean different things by the same number.** 50 is
   "neutral, just below warm" on ConversationSystem's bands and
   "the UNFRIENDLY→NEUTRAL boundary" on DispositionCalculator's. A pool line
   gated at `disposition >= 60` and an `allows_interaction("rumor")` check are
   asking different questions with the same-looking numbers.
3. **`base_disposition` is authored 93 times and read by nobody.** It is
   declared on `CivilianNPC` (`:118`) and exported on `NPCData` (`:31`), and set
   at 93 sites across the level scripts and NPC classes —
   `dalhurst.gd` alone sets it 14 times, from 40 for the wary dockworkers to 60
   for the acolyte. `ConversationSystem` never reads it. **Every NPC in the game
   starts at `DEFAULT_DISPOSITION = 50`** regardless of what the designer wrote.

Also: storing disposition inside `conversation_flags` pollutes the flag
namespace. `has_flag` returns `true` for any non-bool stored value
(`:1322-1325`), so `has_flag("disposition:bob")` is true at any value including
zero.

**Prescription: REWRITE.** One `DispositionManager` owning a per-NPC persisted
value, seeded from `profile.base_disposition` on first contact, moved by
persuasion and by caught-lying, and *modified* — not replaced — by
DispositionCalculator's situational factors (bounty, weapon drawn, faction
standing) at read time. One band table. Effort M.

**Gate.** `check_serialization.tscn` for the new save section, plus an
assertion in `check_conversation_tiers.tscn`: build an NPC with
`base_disposition = 40`, assert `get_disposition` returns 40 not 50; run a
successful persuasion; assert `GameSystems.allows_interaction(npc, "rumor")`
changes.

### 24. Flag storage — three stores and a mirror that deletes

Three writable dictionaries live in one namespace:

| Store | File | Saved as |
|---|---|---|
| `FlagManager.flags` | `scripts/core/flag_manager.gd:124` | `flags.flags` |
| `WorldState.flags` | `scripts/core/world_state.gd:53` | `world_state.flags` |
| `ConversationSystem.conversation_flags` | `conversation_system.gd:162` | `conversation.conversation_flags` |

`ConversationSystem.has_flag` (`:1318-1334`) reads all three plus a computed
layer, in fixed precedence. `DialogueManager.has_flag` (`:1087`) reads
**FlagManager only**. So the same `FLAG_SET` condition, on the same authored
JSON shape, fires in a pool and never fires in a tree — for
`caught_lying_<npc>`, for every `<npc>_witnessed_crime` flag written by
`crime_manager.gd:220`, and for every non-boolean world fact.

**Four concrete defects in the mirror** (`world_state.gd:117-126`):

1. **Non-bool values are dropped.** `if value is bool` — so
   `WorldState.set_flag("kazan_dun_state", "fallen")`, a shape CLAUDE.md
   documents and `dialogue_manager.gd:828` supports authoring from data, puts
   nothing on FlagManager. It can therefore never satisfy a
   `flag_prerequisites` gate, which is FlagManager-only.
2. **Two truthiness rules.** `WorldState.has_flag` treats ints, floats and
   Strings as truthy (`:85-97`); `FlagManager.has_flag` demands `== true`
   strictly (`:255-257`). One name, two answers.
3. **The mirror deletes.** Mirroring `false` calls `flag_mgr.clear_flag(flag)`
   unconditionally (`:124-125`), and `WorldState.from_dict` re-runs the mirror
   for **every** restored flag (`:246-247`). `_apply_flag_data` runs at
   `save_manager.gd:756` and `_apply_world_state_data` at `:833`. **A dialogue
   flag that shares a name with a `false` world fact is silently cleared on
   every load.** The load order is correct only by accident and nothing enforces
   it.
4. **The mirror cannot heal.** `world_state.gd:70-71` returns early when the
   value is unchanged, *before* mirroring. If FlagManager's copy is cleared
   independently, re-writing the same world value is a no-op forever.

**Every boolean world fact is also saved twice** — once in `WorldState.flags`,
once in `FlagManager.flags` by way of the mirror — into two independently
serialised sections with no reconciliation.

`production/NEXT_50_TASKS.md:341-351` already recorded the call: *"three
parallel flag stores now exist… Decide which two survive."* It was never
actioned. It is still three.

**Two documented bugs this has already caused.** `docs/audits/faction_exclusivity_audit.md:186-196`
— the temple chains authored the devotion gate under a key nothing reads, so a
devotee of Gaela could take the whole Chronos chain and end up sworn to two
gods. And `conversation_system.gd:1313-1317`, the 8/2 fix's own comment: *"a
pool line gated on `gaela_devotee` or `kazan_dun_fallen` could never fire — the
flag was set, in a store nobody asked."*

**Prescription: REWRITE.** One `FlagManager` owning one dictionary of
`Variant`-valued facts, with one truthiness rule. `WorldState` keeps
`world_modifications` — genuinely a different concept, a structured description
of terrain change — and loses `flags` entirely; its `evaluate_condition` reads
FlagManager. `conversation_flags` folds in, with `disposition:*` moving to
finding 23's new owner. `ConversationSystem.get_flag` and `clear_flag` stop
being asymmetric with its own `has_flag` (today
`has_flag("gaela_devotee")` is `true`, `get_flag` returns `null`, and
`clear_flag` silently does nothing). Effort M/L — the save migration is the
cost, and `check_serialization.tscn` plus a format bump covers it.

**Also found under this lens: eight dead flag reads.**
`Merchant.get_dialogue_price_modifier` (`merchant.gd:676-699`) and its
traveling-merchant twin test `<merchant_id>_haggle_success`,
`_intimidate_success`, `_befriend` and `_angered`. **Nothing writes any of
them.** The modifier is permanently 1.0. There is also a spelling split: the
code reads `mid + "_befriend"` while the docs and the context-variable
machinery use `{merchant_id}:befriend`.

### 26. Damage application — the melee claim is true and much narrower than it reads

Routed correctly: player melee (`hitbox.gd:139` → `apply_melee_damage`), enemy
melee (`hitbox.gd:155`, `hurtbox.gd:74`, `enemy_base.gd:2301` →
`deliver_melee_hit`), and spells (`spell_caster.gd` ×7, `spell_projectile.gd` ×2
→ `apply_spell_damage`).

**Two call sites throw at runtime.** `PlayerController.take_damage`
(`player_controller.gd:828`) takes three required arguments. These pass one:

- `scripts/systems/puzzles/puzzle_portal.gd:190` — `player.take_damage(trap_damage)`
- `scripts/world/interactables/triggered_trap.gd:282` — `target.take_damage(damage)`

Both sit behind `has_method("take_damage")`, which returns `true`, so the guard
does not save them — and in the portal's case the `elif` fallback that *would*
have worked is unreachable for the same reason. Every triggered trap in the
game and the puzzle portal are hard-broken behind a guard that looks careful.
This is the shape CLAUDE.md says has cost real money twice.

**A fourth, incompatible signature.** `boat_crew_member.gd:194` declares
`take_damage(amount, _attacker = null) -> void`, and `:173-176` dispatches by
trying both arities behind an always-true `has_method` — so the 2-arg form is
called against `EnemyBase` and `PlayerController`, both of which require three.

**Two invented vocabularies.** `triggered_trap.gd:283-288` and
`damage_zone.gd:154-160` both fall back to `target.apply_damage(damage, type)`
and then to `target.health -= damage`. **Neither `apply_damage` nor a bare
`health` property exists anywhere in the codebase** — every combatant uses
`current_health` or `current_hp`.

**Twelve classes charge no armour at all.** `CombatManager.is_armor_already_applied`
(`combat_manager.gd:668`) exists so armour is paid once. Three receivers honour
it (`enemy_base.gd:2325`, `guard_npc.gd:804`, `player_controller.gd:855`).
These twelve do their own `current_health -= actual_damage` with no armour step
whatsoever: `civilian_npc.gd:526`, `quest_giver.gd:919`, `village_elder.gd:453`,
`merchant.gd:994`, `arena_master.gd:440`, `thief_npc.gd:438`,
`tharin_ironbeard.gd:394`, `jail_guard.gd:721`, `follower_npc.gd:308`,
`companion_npc.gd:699`, `cursed_totem.gd:262`, `enemy_spawner.gd:437`.
`CivilianNPC` and `GuardNPC` sit in the same directory, one inheriting from the
other, with two different damage models.

**Nine NPC attack paths bypass the melee marker**, so `Enums.Skill.DODGE` —
ruled passive on 8/2 and rolled inside `PlayerController.take_damage` — **cannot
roll against any NPC**: `guard_npc.gd:341`, `jail_guard.gd:338`,
`gladiator_npc.gd:244`, `follower_npc.gd:424/497/527/611`,
`companion_npc.gd:447/469`, `apprentice_marcus_npc.gd:216`. The guard one is
self-refuting — the comment says "use CombatManager" and the line does not.

**Five sites reach past the controller into the raw data object**
(`boat_travel_manager.gd:402`, `boat_voyage.gd:1861/1897/1904`,
`puzzle_portal.gd:192`). `CharacterData.take_damage` (`character_data.gd:331`)
applies no armour, no resistance, no buff resistance, no dodge, no block, no
duel clamp, and emits none of the HUD signals.

**Prescription: REWRITE.** One `CombatManager.apply_damage(target, amount, type,
source, flags)` that every door goes through — traps, hazards, zones, DOTs,
projectiles, NPC swings, boat crews. `take_damage` on a receiver becomes what
CombatManager calls, never what a caller calls, and gains defaults so the arity
crashes become impossible. Effort L; sequence the two crashing call sites first
as a standalone S fix. Gate: `check_combat.gd` — enumerate every `take_damage(`
call site outside `CombatManager` and fail on any that is not in a declared
allow-list, the same ratchet shape `check_no_broken_paths` uses.

### 25. Spawning — four generations of one factory, and two town builders

`civilian_npc.gd` declares **60+ static `spawn_*` factories** (lines 928–2062),
including six competing "random" entry points that do not delegate to one
another: `spawn_random` (:1225), `spawn_random_new` (:1580), `spawn_any_random`
(:1596), `spawn_random_newest` (:1761), `spawn_truly_random` (:1786),
`spawn_gendered_random` (:1852). The names are the evidence.

Two town builders choose between them and diverge in ways that reach the
player:

- `TownSpawner` (`town_spawner.gd:89`) — `GuardNPC.spawn_guard(self, pos, patrol_array, region_id)`
- `TownGenerator` (`town_generator.gd:860`) — `GuardNPCClass.spawn_guard(self, pos)`

`spawn_guard`'s signature (`guard_npc.gd:970`) defaults `patrol := []` and
`p_region_id := "elder_moor"`. So **every guard in a procedurally generated
town is stationary and reports crimes to Elder Moor's jurisdiction**, including
guards in Millbrook, Thornfield and Dalhurst. TownGenerator also threads a
seeded RNG (`:827`) where TownSpawner does not, so hand-authored towns re-roll
their population every boot while procedural ones are deterministic — the
opposite of what one would expect.

Two ways to get a guard at all: `GuardNPC.spawn_guard` (real AI — patrols,
arrests, fights back) and `CivilianNPC.spawn_guard_civilian` (`:1668`) plus its
three siblings, which produce a civilian wearing a guard sprite that **flees**
when struck (`civilian_npc.gd:543`) where a real guard fights
(`guard_npc.gd:823`). Same visual, opposite behaviour, chosen by whichever spawn
call a level author copied. CLAUDE.md pitfall #10 documents the two classes
fighting over the name `spawn_dwarf_guard` — that collision is the tell.

Enemies are the healthy counter-example: `EnemyBase.spawn_billboard_enemy` and
its two siblings are the only construction path, with no direct `.new()`
anywhere and 40 caller files. **Caveat:** three independent *policy* owners sit
above it — `enemy_spawner.gd`, `wave_spawner.gd`, `encounter_manager.gd` — none
of which knows the others' counts, so CLAUDE.md's "Max active enemies per zone:
20" is unenforceable by construction.

**Prescription: REWRITE**, scoped. One `spawn_civilian(parent, pos, config)`
with the 60 factories reduced to thin named presets over it; one guard factory;
one town-population routine both builders call. Effort M/L. Gate: `check_groups`
and `check_living_world` already exercise spawned NPCs; add an assertion that a
guard spawned by either builder carries a non-empty `region_id` matching its
town.

### 22. Pause and mouse capture — nine owners, no depth counter

`BasePopupUI._enter_menu_state` (`base_popup_ui.gd:169-181`) is the canonical
pair and the only one that also notifies `GameManager.enter_menu()`. Eight
others set `get_tree().paused` and `Input.set_mouse_mode` independently:
`pause_menu.gd:282-292`, `game_menu.gd:2108-2135`,
`humanoid_dialogue.gd:161/334`, `intro_dialogue_ui.gd:247/259`,
`fast_travel_ui.gd:244/268/284`, `wait_ui.gd:364/374`, `hud.gd:1481/1521/1618`,
and mouse-only in `conversation_ui.gd:690/722` and `dialogue_box.gd:355/378`.

Every exit path unconditionally writes `paused = false` and
`MOUSE_MODE_CAPTURED`. **There is no depth counter.** `pause_menu.gd:471` opens
`OptionsMenu`, which is a `BasePopupUI`; closing it unpauses the game and
recaptures the mouse **with the pause menu still on screen**. Six of the nine
paths never call `GameManager.enter_menu()`, so anything reading GameManager's
menu state sees the game as unpaused during them.

**Prescription: REWRITE.** One `UIManager` owning a modal stack with a depth
count; `paused` and mouse mode are functions of stack depth, written in one
place. Effort M. Gate: `check_popups.tscn` already instantiates all 18 popups —
extend it to open two nested and assert `get_tree().paused` is still true after
closing the inner one.

### Popup migration status, re-measured

`docs/audits/popup_migration.md` claims 8 migrated and 10 held. Measured today:
**9 migrated** (the doc omits `options_menu.gd`) and **12 still rolling their
own** — `conversation_ui`, `dialogue_box`, `humanoid_dialogue`,
`intro_dialogue_ui`, `fast_travel_ui`, `wait_ui`, `pause_menu`, `game_menu`,
`dice_roll_ui`, `companion_status_ui`, `companion_command_ui`, `world_map`.

**The doc is stale in a load-bearing way:** it discusses `npc_dialogue_ui.gd`
at length, with reasoning about its `TakeoverManager.end_dialogue()` call.
**That file does not exist** — no `.gd` or `.tscn` in the repo mentions it, and
`tools/check_popups.gd`, the gate the doc points at, does not list it. The
doc's own gate already disagrees with the doc. Fix the doc as part of finding 22.

**No confirmation mechanism exists at all.** There is no `ConfirmationDialog`,
no shared confirm popup. `base_popup_ui.gd:19` documents a `COMPACT` tier *for*
"confirmations" and nothing uses it for one. `pause_menu.gd:418` deletes a save,
`:398` overwrites one, and `:377` quits — none with a prompt between the button
and the act. Not a duplicate-system finding; recorded here because the lens
found it.

### 19/20. Loaders and validators

**Quests are walked by five loaders.** The runtime one
(`quest_manager.gd:615-649`) is recursive, skips `_`-prefixed staging, and
honours `"disabled": true`. Of the four tool walkers, `validate_content.gd` is
recursive and skips staging but **does not honour `disabled`** — so a disabled
quest is validated as shipping content the engine never loads. The town editor
(`town_editor_dock.gd:866-894`) is **non-recursive by its own admission**, so
every quest under `bounties/`, `chains/`, `guild/**`, `kazan_dun/` and `temple/`
is invisible when assigning quests to a town's NPCs — the majority of the
corpus. The flat-path `get_quest_data` fossil is genuinely gone from the code,
but its ghost survives in `tools/fixtures/broken_paths_baseline.txt:180` and in
`data/quests/temple/chronos/IMPLEMENTATION_GUIDE.md:31`, which still documents
the flat pattern as the way to load.

**Items are loaded from hardcoded id lists.**
`inventory_manager.gd:73-300` iterates hand-maintained `Array[String]`s; the
validator (`validate_content.gd:224-230`) and the authoring dock walk the
directories instead — and the dock keys by *filename*, not by the `id` field, a
third derivation with no gate keeping it in step. **Eleven `.tres` exist on disk
that the game cannot load**: `dwarven_grave_ale`, `hold_friend_token`,
`kazan_dun_deep_key`, `keepers_badge`, `merchant_goods`, `package`,
`stolen_goods`, `tharins_letter`, `tharins_trade_message`, `ember_blade`,
`venomous_dagger`. Six are named by shipped quests. `_expect_item` passes them
because the file is on disk; `InventoryManager.add_item` will not resolve them
at runtime. **The validator is green on items the game cannot hand the player.**

**Schedule rules are asserted twice**, in `validate_content.gd` and
`check_living_world.gd`, over five overlapping rules. Two constants are
hand-copied rather than read from the owner: `SCHEDULE_ACTIONS`
(`validate_content.gd:713`) duplicates `NPCScheduler.ACTIONS`
(`npc_scheduler.gd:33`), and `SCHEDULE_DAY_FIRST/LAST` (`:717-718`) duplicates
`DAY_FIRST_HOUR/DAY_LAST_HOUR` (`:29-30`). A sixth scheduler action would make
the validator reject valid data.

Worse, **the two disagree by 44 records about who is a quest NPC.**
`validate_content` derives the set by scanning quests for `giver_npc_id`,
`turn_in_target` and `talk` targets; `check_living_world` reads the
`"quest_giver": true` boolean on the schedule record. 79 scheduled NPCs are
named by quests; 36 records carry the flag. 44 are checked by one and not the
other — including `harbor_master_dalhurst`, `millbrook_healer`,
`thornfield_innkeeper`, `guard_captain_millbrook` — and one
(`acolyte_morthane_dalhurst`) only by the other. They also disagree about what
"unreachable" means: one fails on `station.interior`, the other calls
`NPCScheduler.is_interactable()` and separately fails on `station == "home"`, a
condition the first does not test.

`validate_content.gd:795-803` carries a written note explaining why the
"every scheduled npc_id spawns somewhere" rule lives only in
`check_living_world`. **That is the pattern the other five rows should follow:**
each rule in exactly one probe, with a note where the other one would have
looked. Effort M.

### Save-field duplicates, in brief

- **Discovered locations (finding 5).** `SaveManager.discovered_locations`
  (`:42`, saved at `:568`) and `PlayerGPS.discovered_locations` (saved at
  `:1090`) are two save fields for one concept. Every real caller uses PlayerGPS;
  `SaveManager.discover_location()` and `is_location_discovered()` have **zero
  callers** outside SaveManager. Delete.
- **Play time, deaths, rests (finding 10).** `SaveManager.total_play_time`
  counts wall clock including menus; `StatsTracker["play_time_seconds"]`
  (`:218-221`) skips paused frames. The save-slot list reads the first, the
  journal reads the second, and they disagree by exactly the menu time.
  `StatsTracker["deaths"]` and `["times_rested"]` have **no incrementer
  anywhere** — yet the journal displays them (`journal_panel.gd:1026`). The
  player's death counter is permanently 0 while the real number lives in
  `SaveManager.death_count` and is displayed nowhere.
- **Dungeon seeds.** `world.dungeon_seeds` in the slot file *and*
  `user://saves/dungeon_seeds.cache`, which is **global, not per-slot**, loaded
  in `_ready()` before any slot, and merged with `if not has(zone_id)`. Playing
  slot 1 then loading slot 3 hands slot 3 slot 1's dungeon layouts.
  `reset_world_state()` deletes the cache globally, so starting a new game
  destroys the seeds of every existing save. Effort S; the cache should be
  per-slot or gone.
- **`get_save_info()` does not migrate** (`:315-338`) while `load_game()` does
  (`:279-289`). A pre-format-1 save lists as "Unknown / level 1 / Unknown
  location" with an empty `current_scene` while loading perfectly — and
  `_do_quick_load` (`:136-150`) takes the scene path from the *unmigrated*
  parse and hands it to `SceneManager` after a *migrated* load. The two parses
  of one file can disagree about where the player is. `get_save_info` also skips
  the `is_valid()` check, so a corrupt save is listed as loadable.
- **Three autosave guard sets** (finding 16). `_do_autosave` (`:168-192`) checks
  `get_tree().paused`; `autosave_on_exit` (`:196-219`) does not but checks
  `get_tree()` exists; `_do_quick_save` (`:125-134`) checks neither. Hand-copied
  three ways.
- **`QuestSaveData`'s fields do not mean their names.** `save_manager.gd:604-616`
  hard-writes `completed = {}` and `failed = {}` ("not used in new format"), and
  repurposes `variables` as a two-key envelope for `tracked_quest_id` and
  `bounty_cooldowns`. Bounty state therefore has two homes in one save file:
  cooldowns inside `quests.variables`, the bounties themselves in `errand_data`.

### 14. `npc_names.json` — a data file that generates nothing

`data/npc_names.json` (200 names, with a full generative schema: name lists,
surname prefixes and suffixes, occupational surnames, title prefixes) has
**exactly one reader in the repo**, and it is not gameplay:
`tools/validate_content.gd:1073-1074` feeds it to the grounding-law token set so
those names are not flagged as invented proper nouns.

The real generator is `WorldLexicon.get_random_name()`
(`scripts/data/world_lexicon.gd:416`) and `get_unique_name_for_zone()` (`:520`),
consumed by `CivilianNPC._assign_unique_name` (`:1258-1269`) — the path every
ambient NPC goes down, and which also derives `npc_id` from the first name.
`TownSpawner`, `TownGenerator`, `CitizenDresser` and `CellStreamer` touch names
either through `CivilianNPC` or not at all.

The two lists have drifted: about a quarter overlap on given names (30 of ~120
male, 21 of ~100 female) and near-zero elsewhere. The JSON's `dwarf_names` block
is Tolkien/Norse — `Balin`, `Bifur`, `Bofur`, `Bombur`, `Azog`, `Bolg`, `Dain`
— never drawn from, and **grounded as legitimate world tokens by the validator
purely because the file exists.** Under the grounding law that is a hole: the
lint is being told these are real names of things in the world, and nothing in
the world uses them.

**Prescription: CONSOLIDATE-NOW.** Delete `data/npc_names.json` and drop its
line from `validate_content.gd`. If any of its names are wanted, move them into
`WorldLexicon` where they will actually be drawn. Effort S. Gate: the grounding
self-test (`_selftest_grounding()`) already fails if the lint stops flagging an
invented place; removing a source of free tokens can only tighten it.

---

## Checked and found clean

Recorded so the next audit does not re-walk them.

- **Game time.** `GameManager` is the sole owner of `game_time`, `current_day`
  and `current_time_of_day`; `day_changed` and `time_of_day_changed` have one
  emitter each. `WeatherManager` and `NPCScheduler` consume, they do not
  duplicate.
- **Enemy construction.** `EnemyBase`'s three static factories are the only
  path; no direct `.new()` anywhere across 40 caller files. (The three *policy*
  owners above them are noted in finding 25.)
- **Fog of war.** `PlayerGPS.discovered_cells` is the single store.
  `MapFogOfWar` and `PaintedWorldMap` are genuinely deleted, and grep confirms
  neither name survives.
- **Dialogue resource classes.** `DialogueData`, `DialogueNode`,
  `DialogueChoice`, `DialogueCondition`, `DialogueAction` and `DialogueLoader`
  have one definition each and are shared by both front-ends. The duplication is
  entirely in the *executors*, not the data model — which is what makes the
  substrate merge tractable.
- **The 45 dialogue trees.** All are referenced, most through `data/companions/`
  `.tres` files rather than from script. No orphans.
- **`DialogueManager` save state.** It has none, by design, since format 8 — it
  is a pure executor over FlagManager, and says so in a comment
  (`dialogue_manager.gd:1130-1134`). This is the one place in this audit where a
  previous consolidation clearly worked, and it is why the dialogue substrate
  merge costs no save migration.

---

## Two general observations

**The recurring shape is not "someone wrote it twice".** It is *one owner is
correct and complete; a second, older or narrower owner is still wired to live
consumers, and nothing tells anyone.* Weather, discovered locations, death
counts, music keys, the item catalogue, the disposition scales and fifteen
dialogue action types are all that shape. The reason it survives is that a
`match` with no `_:` branch, a `has_method` guard on a method that does not
exist, and a fallback that quietly serves the wrong thing all look exactly like
working code.

**Every gate this project has was written after a bug, and each one closed a
class.** The gap this audit found is that the gates are *per-owner*: there is a
`check_conversation_tiers` but no `check_dialogue_engine`; a
`check_serialization` per registered class but nothing asserting two save fields
do not describe one fact; a `check_autoload_api` that resolves members but not
whether two members mean the same thing. **The gate shape this project is
missing is the cross-owner agreement assertion** — "these two executors handle
the same set", "these two probes do not both own this rule", "this field has one
writer". Step 0 of the dialogue plan is the first of those. It should not be the
last.
