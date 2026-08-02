# Broken Provinces: The Empty Throne — Code Architecture Tree
*2026-08-02. Paste-ready system map for outside architecture review. Godot 4.7, GDScript strict-typed, ~145k lines, solo dev + AI agents. PS1-style open-world RPG (Elder Scrolls exploration, Daggerfall/Skyrim combat, FNV-style faction dialogue). Migrating NPC/enemy visuals from 2D billboards to PSX 3D models (dual-support via one interface).*

## The shape
- **46 autoload singletons** (listed below) communicating mostly via signals; strict typing throughout; data-driven content (quests = JSON, enemies/items = .tres resources).
- **World model:** a grid of 100-unit cells (`WorldGrid` = static truth for terrain/biome/locations), streamed as a 3×3 ring around the player (`CellStreamer`) with floating-origin shifts. Hand-built town scenes sit at fixed cells; wilderness cells are generated per-cell (noise terrain + biome vegetation, seeded/deterministic).
- **Simulation:** game clock lives IN `GameManager` (hour signals + a schedule book); `NPCScheduler` gives every NPC a daily schedule (home/work/leisure stations); NPC position off-screen is a pure function of (schedule, hour) — no off-screen ticking. Presence gates shops/dialogue (a closed shop = the keeper isn't standing there).
- **Verification culture:** 19 headless "check scenes" (quest engine round-trip, serialization diff, navmesh polygons, broken res:// paths, audio events, living-world census...) + a content validator (every id in quests/dialogue must resolve to a real entity — "grounding lint") wired as a pre-commit gate. 0 errors is the enforced baseline.

## Autoloads by domain (46)
**core/** — GameManager (game state + CLOCK: time, day, hour_advanced, schedule_event, advance()) · WorldGrid (static world truth: cells, biomes, locations) · SceneManager · SaveManager (save v9, field-diff regression-guarded) · FlagManager (boolean flags: dialogue/quest vocabulary) · WorldState (durable world facts + world_modifications; mirrors booleans ONE-WAY into FlagManager) · AudioManager (3 tables + variants + substitutes resolver) · DiceManager (TTRPG checks) · LootTables · ActorRegistry (npc_id → sprite/model config) · StatsTracker · GameSystems · PostProcess · UIManager (one canvas above HUD; popup chrome) · Log
**world/streaming/** — CellStreamer (3×3 ring, floating origin) · PlayerGPS (position/discovery truth) · CaveManager · WorldForgeImporter (editor-authored world map overlay)
**world/** — WeatherManager
**systems/combat/** — CombatManager (THE damage path: melee+spells routed, armour applies once, crits/XP/damage numbers)
**systems/quests/** — QuestManager (OR-objective groups, world_condition pre-completion, choice_consequences, timers) · JournalManager · CodexManager
**systems/dialogue/** — DialogueManager (authored choice-TREES per NPC; conditions/actions incl. quest/flag ops) · ConversationSystem (topic-based pools: 3 tiers — unique/archetype/generic + REACTION pools gated on player state; npc_memory anti-repeat)  ⚠ two systems, one concept — see tensions
**systems/factions/** — FactionManager (−100..100, cascading relations both ways, ongoing-effects ticker: daily income/penalties) · GuildRankManager (rep+quest-count ranks → flags) · MoralityManager · TakeoverManager
**systems/economy/** — InventoryManager (items + gold authority) · CraftingManager · EnchantmentManager · SpellCreator · SoulstoneEconomy (exactly 100 soulstones world-wide)
**systems/crime/** — CrimeManager (witnessed crimes, bounties, jail) · BountyManager (procedural bounty quests)
**systems/travel/** — BoatTravelManager · FastTravelManager
**systems/events/** — EncounterManager · TournamentManager (arena) · DuelManager · EscortManager* · RestManager (routes time-skips through GameManager.advance)
**characters/ai/** — NPCScheduler (schedules, station_of(), npcs_in_cell(), presence) · FollowerManager · CompanionManager · EscortManager

## Non-autoload key layers
- `characters/visuals/` — **CharacterVisual** interface: BillboardVisual (wraps legacy Sprite3D billboards) | RiggedVisual (PSX GLB + runtime dresser: face-atlas UV offset, garb texture page by archetype, dye tint by seed — EverQuest-style one-mesh-many-skins). Per-character flip via one data field.
- `world/terrain/` — EnhancedTerrain (per-cell noise generator: domain warp, ridged multifractal, biome relief presets, town-edge blend falloff) + TerrainConfig (single height authority) + zoning classifier + BiomePalette.
- `characters/enemies/enemy_base.gd` (3.1k lines — one base for 64 enemy .tres, 10-state AI) and `characters/npcs/` (CivilianNPC 1.9k lines, QuestGiver) — the two biggest classes after hud.gd (4k).
- `generation/` — towns/dungeons/rooms/wilderness generators; SimpleDungeons addon for dungeons.
- Editor plugins: World Forge (world map painting), Town Editor (NPC placement + schedule authoring + day scrub), Dungeon Editor, Quest Authoring panel (schema-aware form with live id lint), World Overview.

## Data flows (the load-bearing ones)
quest JSON → QuestManager → rewards → FactionManager rep → cascades → dialogue REPUTATION gates + GuildRankManager promotion → rank flags → gated dialogue/services
GameManager.hour_advanced → NPCScheduler roster-diff on loaded cells → spawn/despawn/place NPCs → presence gates OPEN_SHOP + conversations
WorldState facts (kazan_dun_fallen, player_is_bandit_boss...) → mirrored flags → reaction pools + quest world_condition pre-completion
CellStreamer cell load → wilderness generation (terrain+vegetation, seeded) OR scene instancing → NPC roster spawn → navmesh

## KNOWN TENSIONS (what we want outside opinions on)
1. **Two dialogue systems** own "NPC speech": DialogueManager (authored trees, ~50 JSON files, quest-critical actions) vs ConversationSystem (topic pools + reactions + memory). Both have conditions, actions, and per-NPC state. Consolidation cost/benefit is the biggest open architecture call.
2. **Flag stores:** FlagManager (dialogue vocabulary) + WorldState (world facts, one-way mirror in) + ConversationSystem's private flag dict + computed flags — has_flag() reads 4 layers. Wants ONE end-state ownership story.
3. **Quest gating vocabulary ×5:** prerequisites (quest ids), flag_prerequisites, forbidden_flags, world_condition (WorldState), rank_required. Domain-separated but sprawling.
4. **46 autoloads** — many tiny (DiceManager, RestManager); init-order coupling risk; is consolidation into domain facades worth it in Godot?
5. **Save serialization** is hand-copied per system (guarded by a reflection diff check, but still N hand-written to_dict/from_dict pairs).
6. **god classes:** hud.gd (post-split ~2.1k), enemy_base.gd (3.1k, 64 inheritors), wilderness_room.gd (3.3k), conversation_system.gd (2.5k+).
7. Billboard→3D migration is mid-flight by design (dual-support): every NPC/enemy eventually flips to RiggedVisual; billboards live under sprites/legacy/.

## Constraints for any proposal
Godot 4.7 GDScript (no C#); solo dev + AI agents execute; save-compat matters (append/migrate, never break v9 saves); the 19-gate suite must stay green through any refactor; strict one-concept-one-authority law just adopted (rewrite beats tack-on; consolidate what works).
