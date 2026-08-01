# Wave B dispositions — content that needs Caleb

Everything in this file is a phantom reference the validator still reports **on
purpose**. Wave B fixed only what existing data already determined (an NPC with
a written dialogue tree and a zone the quests name; an id that could be repointed
at a character who already exists). Everything below needs a decision no file in
the repo can supply — a name, a personality, stats, or a piece of world story —
so it is recorded here rather than invented.

Columns: **id** · **refs** (how many quest references break) · **what exists
already** · **proposed fix** · **why it needs Caleb**.

## 1. Generic role NPCs — the town needs the role, nobody has written the person

These are ids like `dalhurst_merchant`: the quest chain wants "the merchant in
Dalhurst" but never names or characterises them. Spawning one means inventing a
person (name, sprite, personality, what else they know), and each becomes a
permanent resident of a hub town.

| id | refs | what exists already | proposed fix | why it needs Caleb |
|---|---|---|---|---|
| `dalhurst_merchant` | 7 | 4 quest chains (missing courier, rescue daughter, stolen ledger) all point at one unnamed Dalhurst merchant | One named merchant in the Dalhurst market who owns all four chains | Name + personality; he is the emotional centre of a kidnapping chain |
| `millbrook_civilian` | 6 | Three chains use one id for a widow, a witness and a mother | Either one named villager or three separate people | Are these one person or three? Three different griefs share one id |
| `elder_moor_civilian` | 6 | "old woman" (family heirloom) and "woodsman's family" (rescue) share the id | Same question as Millbrook | One person or two; names |
| `millbrook_merchant` | 3 | market_theft chain | Named Millbrook stallholder | Name/personality |
| `millbrook_priest` | 3 | rescue_sacrifice_victim chain | A priest for Millbrook — which of the Three Gods? | Millbrook's shrine is not in the pantheon docs |
| `millbrook_healer` | 2 | medicine_delivery bounty | Named healer | Name; overlaps `millbrook_priest` if the shrine heals |
| `millbrook_shepherd` | 3 | gaela_bonus_shepherd_quest | Named shepherd on the pasture | Name/personality |
| `millbrook_farmer` | 2 | gaela_01 / gaela_03 | Named farmer | Name/personality |
| `millbrook_innkeeper` | 1 | mage_05 witness | Millbrook has no inn NPC | Does Millbrook (hamlet) even have an inn? |
| `head_fisherman_millbrook` | 1 | fish_fraud (Hector's accusers) | Named head fisherman | Name; he is the counterweight to Hector, now spawned |
| `guard_captain_millbrook` | 1 | morthane_06 murder investigation | Named guard captain | Name; Millbrook currently has no guard at all |
| `dalhurst_scholar` | 3 | cursed_tome chain, "Dalhurst's library" | Scholar in the Athenaeum or a town library | Is the library the Athenaeum, or a separate Dalhurst building? |
| `dalhurst_innkeeper` | 1 | missing_courier | Dalhurst has an `innkeeper_dalhurst` NPC id already spawned | Confirm they are the same person — then this is a one-line repoint |
| `dalhurst_witness` | 1 | keepers_test | Generic "someone who saw something" | Who; probably folds into an existing civilian |
| `old_fisherman_dalhurst` | 1 | ghost_ship_rumors | Named old salt on the docks | Name; Larton already has "Old Salt Willem" — same man moved, or a new one? |
| `widow_dalhurst` | 1 | morthane_restless_soul | The ghost's widow | Name; ties to the ghost's story |
| `elder_moor_guard` | 3 | bandit_justice chain; Elder Moor has exactly one watchman (`guard_elder_moor_1`) | Repoint the chain to the watchman, or give him a name and quests | The watchman is a GuardNPC, not a QuestGiver — this is a small refactor, and the quest calls him "the guard captain" (a rank Elder Moor may not have) |
| `thornfield_wizard` | 3 | rescue_wizard_apprentice chain | Named wizard in Thornfield | Name; Dalhurst already has two wizards (Master Aldric, Master Helvant) — is this a third? |
| `thornfield_merchant` | 2 | missing_courier turn-in | Thornfield has `thornfield_trader` spawned | Likely a one-line repoint — confirm they are the same trader |
| `thornfield_innkeeper` | 1 | wizard_stolen_pages | Named innkeeper | Name |
| `thornfield_healer` | 1 | gaela_08 | Named healer | Name |
| `thornfield_farmer` | 1 | guild_contract_elite survivors | Named farmer | Name |
| `logging_foreman` / `logging_foreman_elder_moor` | 2 | Elder Moor already has **Foreman Garvek** running the logging camp | Repoint both to `foreman_garvek` | The Gaela grove quests make the foreman the antagonist of a sacred-grove dispute — is Garvek that man, or a Dalhurst crew boss? |
| `mine_foreman_duncaster` | 3 | miners_in_peril; Duncaster level exists with `duncaster_foreman` spawned | Probably a repoint to `duncaster_foreman` | Confirm same man |
| `trade_master_larton` | 6 | starving_south / supply_line_crisis / aberdeen_relief; Larton has a mayor and several NPCs | A "Trade Master" office in Larton | Rank does not exist in the world yet; the quests make him the southern relief authority |
| `imperial_magistrate` | 1 | starving_south | Imperial authority figure | Empire's civil hierarchy is undefined in the bible |
| `caravan_survivor` | 1 | willow_dale_investigation (optional) | Survivor at the ruins | Name; and whether anyone survives is a story call |
| `guild_witness` | 1 | adventurers_11 | Rank-and-file guild member | Name |
| `guild_members` | 1 | thieves_13 "recruit specialists" | A recruitment roster, not one NPC | This objective wants a *mechanic* (hire specialists), not a person |
| `iron_company_veteran` | 1 | mercenary_09 | Iron Company soldier in Dalhurst | Name |
| `inside_contact` | 1 | thieves_10 | Guild plant inside the magistrate's office | Name; ties to `magistrate` fiction |
| `informant_crossroads` | 1 | mage_09 | Informant at Crossroads | Name |

## 2. Named characters, but the naming/lore is Caleb's

The quest text names them, but they are story-adjacent: they carry lore that
touches the bible's `[OPEN]` questions, or they are antagonists whose stats and
allegiance are a design decision.

| id | refs | what exists already | proposed fix | why it needs Caleb |
|---|---|---|---|---|
| `king_aldric` | 3 | `_future/the_imprisoned_king.json`, zone "chamber_of_immortality" | Spawn the missing king | The bible has this deliberately `[OPEN]`: does this game reach the king at all? The name "Aldric" is a Wyrm *proposal*, not his ruling |
| `secret_society_contact` | 7 | 3 `_future` Falkenhaften quests | Spawn in the capital | Act II content; the society is unnamed and touches the claimant plot |
| `capital_informant` | 1 | capital_intrigue | Falkenhaften informant | Same Act II gate |
| `elven_elder_witness` / `elven_guide` | 2 | the_false_queen / the_kings_secret | Elves who know the elixir path | Bible `[OPEN]`: where the elven lands sit; what the king did for the elves |
| `khan_toghrul` | 1 | tenger_diplomacy | Tegnar warband leader | Bible `[OPEN]`: are the Tegnar an invasion arc or frontier flavour? A named khan sets that |
| `village_elder_east_hollow` | 4 | tenger_diplomacy; **East Hollow has no scene** | Place East Hollow on the map, then the elder | A settlement decision, not an NPC decision |
| `garrison_commander` | 2 | `_future/tenger_scouts`, zone "southern_outpost" (**no scene**) | Same as above | Southern outpost does not exist yet |
| `whaelers_abyss_mayor` | 1 | `_future/missing_surveyors` | Mayor of Whalers Abyss | Name; the town has no civic figure |
| `noble_hakon` | 2 | noble_soulstone_request | Dalhurst noble | Name/house; soulstone economy is lore-touching |
| `noble_client` | 1 | mercenary_10 | Noble hiring the Iron Company | Which house; the noble war has no named parties |
| `guild_mastermind` | 4 | thieves_guild_mastermind (Ashford gala heist) | Could be Lady Nightshade, now spawned | Is the "mastermind" Nightshade herself or a separate character? Merging them is a story call |
| `mage_aldric_dalhurst` | 3 | mage_04/mage_08 call him "Senior Mage Aldric"; Dalhurst already has **Master Aldric** (`wizard_dalhurst`) | Repoint to `wizard_dalhurst` | Same man or two Aldrics? A one-line fix once ruled |
| `high_chronist_thornfield` | 4 | chronos_03, temple_prophecy_chronos; "Temple of Time in Thornfield" | Spawn the High Chronist | Thornfield has no temple built — a building decision first |
| `aldric_the_merchant` | 1 | mercenary_04 caravan | Merchant at Crossroads | A *third* Aldric; needs the same ruling as above |
| `merchant_elara` | 1 | morthane_08, dying merchant at Crossroads | Spawn a dying merchant | "Elara" is also the Priestess of Gaela's name in other quests — collision |
| `merchant_vrell` | 1 | morthane_06, the murderer | Spawn in Millbrook | Murder-mystery casting; who did it is a writing call |
| `restless_ghost` | 1 | morthane_restless_soul | A ghost NPC | Ghost NPC class + the ghost's story |
| `necromancer_valdris` / `necromancer_aeris` | 2 | morthane_necromancer / morthane_04 | Named necromancer bosses | Two different necromancers in the same line — same villain or two? Enemy stats needed |
| `false_prophet_millbrook` / `false_seer_thornfield` | 2 | chronos_04 / chronos_false_prophet | Charlatan NPCs | Same character in two quests? And is the prophecy real (Chronos plot) |
| `guild_traitor` | 2 | adventurers_11 **and** thieves_09 use one id for two different traitors | Two distinct NPCs with distinct ids | Casting + a quest-data fix; the shared id is itself a bug |
| `iron_company_traitor` | 1 | mercenary_09 | Named traitor | Casting |
| `iron_blades_leader` | 1 | adventurers_09 | Rival company leader | Name; rival company is new lore |
| `black_wolf_captain` | 1 | mercenary_08 | Rival company captain | Name |
| `enemy_commander` | 1 | mercenary_10 | Opposing commander | Name/house |
| `bridge_troll` | 1 | guild_contract_troll | A talking troll at the Crossroads bridge | Is the troll a negotiable NPC or only an enemy? Design call |
| `tomas_informant` | 1 | thieves_guild_informant (also used as a kill target) | Named informant | He is both a talk target and an enemy id — which he is depends on the branch |
| `garrett_sailor` | 1 | thieves_04, "Garrett at the Crossroads tavern" | Named debtor | A second Garrett (Whalers Abyss has one, now spawned) — same man? |
| `sailor_brennan` | 1 | sailors_debt | Named sailor | Elder Moor already has "Old Sage Brennan" — name collision |
| `kidnapped_merchant` | 1 | mercenary_06 | Hostage | See hostages below |

## 3. Hostages — one mechanic, six missing bodies

`hostage_merchant_daughter`, `hostage_missing_child`, `hostage_sacrifice_victim`,
`hostage_soldier`, `hostage_wizard_apprentice`, `hostage_woodsman`
(1 ref each, plus `kidnapped_merchant`).

`scripts/npcs/hostage_npc.gd` already exists. What is missing is placement: each
rescue quest's second leg happens in a camp or temple whose scene is not named in
the quest data, so nothing determines *which* room the hostage sits in. **Proposed
fix:** one hostage marker per rescue site, spawned by the level script from the
marker (the standard pattern). **Why Caleb:** picking the rooms is level design,
and the victims' names/reactions are writing.

## 4. Already whitelisted — no action needed

`bounty_board` (15 refs), `guild_contract_board` (2), `temporal_echo_trigger` (1)
are world interactables, not people. `tools/validate_content.gd` now carries an
`INTERACTABLE_IDS` list (and an empty, documented `LORE_ONLY_IDS` list for
deliberate narrative placeholders), so these no longer report as errors.

## 5. Flagged decision made during Wave B

Lady Nightshade existed twice over: as the magic-shop merchant in her Curiosities
and, in `data/dialogue/lady_nightshade.json`, as the Thieves Guild guildmaster the
quests call `guildmaster_nightshade`. She is now spawned once, as the guildmaster
behind her own counter, and the shop is staffed by a "Curiosities Clerk". If you
would rather she simply run the shop *and* the guild from one node,
`QuestGiver.has_shop` exists (untested — no other NPC in the game uses it).

## 6. Items

See `## Items` at the bottom of this file after step 11.
