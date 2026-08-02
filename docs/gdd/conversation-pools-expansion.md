# Conversation Pool Expansion — 100 Pools for Deep NPCs
**Date:** 2026-07-08 | **Status:** APPROVED DESIGN (authoring begins when tier architecture lands — CatacombsOfGore-sv2)
**Goal:** Modern-Daggerfall NPC depth. Every conversation should feel like it belongs to THAT person in THAT place at THAT moment.

## How pools now combine (post-architecture-fix)
Selection order: **unique (per-NPC) → archetype (profession) → generic (fallback)**, filtered by disposition, knowledge tags, personality affinity, region, and persistent heard-memory. An NPC's effective voice = archetype pool + region pool + any personality/situational pools that match + generic fallback. A Millbrook fisherman at night who dislikes you draws from: `arch_fisherman` + `region_millbrook` + `situ_night` + `disp_wary` + generic.

**Authoring rules (every pool):**
- 8-15 responses per pool (smaller for niche situational pools is fine)
- Match existing JSON schema (`data/dialogue/pools/local_news.json` reference): response_id unique per pool, topic_type, personality_affinity, min/max_disposition, required_knowledge, weight
- **Only reference REAL places** — WorldGrid locations + the Act I unique-locations list (docs/gdd/act1-unique-locations.md). Below-the-line places only as distant rumor, never directions.
- Grim, morally grey, LOTR-flecked tone (see Desktop notes / world bible). Common folk speak plainly; educated NPCs speak longer.
- Seed hooks: at least 1 response per archetype pool should hint at a real quest, location, or system (teaches the game while flavoring it).

---

## The 100 Pools

### A. Archetype pools (30) — profession voices
| # | pool_id | Voice sketch |
|---|---------|-------------|
| 1 | arch_farmer | weather-worn, suspicious of towns, harvest-god pious |
| 2 | arch_logger | Elder Moor's backbone; axe pride, forest superstitions |
| 3 | arch_miner | dark-tunnel fatalism, dwarf respect, Kazan-Dun rumors |
| 4 | arch_fisherman | river/lake lore, patience philosophy, water omens |
| 5 | arch_sailor | Dalhurst harbor, distant ports, ghost-pirate dread |
| 6 | arch_dockworker | cargo gossip, harbor-master grumbles, smuggling winks |
| 7 | arch_hunter | wolf trouble, tracking talk, respect for the wild |
| 8 | arch_trapper | solitary, strange things seen at forest edges |
| 9 | arch_shepherd | Millbrook hills, lost lambs, bandit fear |
| 10 | arch_merchant_general | prices, trade routes, caravan risks |
| 11 | arch_blacksmith | steel pride, repair advice, guard contracts |
| 12 | arch_alchemist | ingredient chatter, cryptic warnings, burn scars |
| 13 | arch_innkeeper | traveler stories, room gossip, diplomatic neutrality |
| 14 | arch_barmaid | overheard everything, sharp wit, local hearts |
| 15 | arch_cook | food opinions, supply complaints, comfort wisdom |
| 16 | arch_priest_chronos | measured, time-metaphors, quietly jealous of Morthane's flock |
| 17 | arch_priest_gaela | serene, growth-metaphors, beloved by farmers |
| 18 | arch_priest_morthane | morbid-kind, cycle-of-life comfort, defensive about mistrust |
| 19 | arch_guard_militia | local boys, undertrained, honest fears |
| 20 | arch_guard_professional | Dalhurst-grade, procedure-minded, seen real fights |
| 21 | arch_noble | decaying-empire hauteur, Falkenhaften nostalgia |
| 22 | arch_beggar | street truth, overheard secrets for coin, grim humor |
| 23 | arch_thief | coded speech, fence hints, guild winks (career-gated) |
| 24 | arch_fence | appraising eye, no-questions-asked etiquette |
| 25 | arch_mercenary | contract talk, war stories, Iron Company pride |
| 26 | arch_mage | Arcane Circle gossip, condescension, soulstone curiosity |
| 27 | arch_scholar | history lectures, Empire-decline analysis, book hunger |
| 28 | arch_healer | plague fears, herb-lore, gallows-humor triage |
| 29 | arch_bard | song fragments, exaggerated news, crowd-reading |
| 30 | arch_gravedigger | Morthane-adjacent, who-died-lately, dry as bone |

### B. Region pools (5) — local color, real places only
| # | pool_id | Content anchor |
|---|---------|---------------|
| 31 | region_elder_moor | logging camp life, Tharin's camp, standing stones, sunken crypts dread, bandit extortion fatigue |
| 32 | region_dalhurst | harbor politics, Harbor Master, backwoods jokes about Elder Moor, Rusty Anchor, cemetery |
| 33 | region_thornfield | frontier mood, rock collapse, old watchtower, Ashford Estate whispers |
| 34 | region_millbrook | the mill (curse!), river trade dying, something-wrong-here unease (bandit takeover foreshadow) |
| 35 | region_crossroads_travelers | road news between towns, ambush warnings, merchant caravan chatter |

### C. Deep topic pools (20) — the world's living conversations
| # | pool_id | Topic |
|---|---------|-------|
| 36 | topic_missing_king | rumors, theories, who benefits; council vs temple tension |
| 37 | topic_empire_decline | slow-rot mood; taxes unpaid, roads unrepaired |
| 38 | topic_tegner_horde | southern dread, refugee tales, veteran memories |
| 39 | topic_rock_collapse | the severed pass, who's to blame, when will it open |
| 40 | topic_ghost_pirates | Larton whispers reaching Dalhurst docks (Act II bait, LORE_ONLY) |
| 41 | topic_kazan_dun_trouble | dwarf-hold rumors, goblin whispers (LORE_ONLY directions) |
| 42 | topic_three_gods | folk theology, god-jealousy gossip, blessing talk |
| 43 | topic_standing_stones | Elder Moor monoliths — shrugs by day, unease by night |
| 44 | topic_sunken_crypts | lose-your-head warnings, treasure temptation |
| 45 | topic_bandit_trouble | extortion stories, camp locations hinted, leader names |
| 46 | topic_mill_curse | Millbrook's mill — sabotage vs curse debate |
| 47 | topic_harvest_season | Gaela festivals, crop worries, seasonal work |
| 48 | topic_war_stories | Border Wars veterans, the graveyard in the east (LORE_ONLY) |
| 49 | topic_local_legends | Seratheal folklore: white stag, weeping well, king-under-the-hill |
| 50 | topic_guild_fighters | Iron Company gossip, contract talk, Steele's reputation |
| 51 | topic_guild_mages | Arcane Circle entrance exam, Velkyr's Tower, Elara |
| 52 | topic_guild_thieves | careful hints, Lady Nightshade name-drops, fence network |
| 53 | topic_arena_talk | Bloodsand tournament, Gormund, fighter fame |
| 54 | topic_soulstones | what are they, who buys them, temple disapproval |
| 55 | topic_undead_fears | risen dead sightings, Morthane blame, crypt warnings |

### D. Disposition pools (4) — how they treat YOU
| # | pool_id | Range |
|---|---------|-------|
| 56 | disp_hostile | 0-20: curt, insulting, go-away |
| 57 | disp_wary | 21-40: guarded, short answers, watching your hands |
| 58 | disp_warm | 61-80: open, helpful, extra details |
| 59 | disp_devoted | 81-100: confiding, secrets, gifts of information |

### E. Race pools (4)
| # | pool_id | Voice |
|---|---------|-------|
| 60 | race_dwarf | clan pride, stone metaphors, Kazan-Dun homesickness |
| 61 | race_halfling | hearth comfort, food talk, underestimated-and-fine-with-it |
| 62 | race_elf_visitor | rare in Act I; distant, curious about short lives |
| 63 | race_human_about_others | how commoners talk ABOUT dwarves/halflings/elves/Tegner |

### F. Personality pools (8) — assigned per-NPC at spawn
| # | pool_id |
|---|---------|
| 64 | pers_gruff | 65 | pers_cheerful | 66 | pers_gossipy | 67 | pers_paranoid |
| 68 | pers_pious | 69 | pers_drunk | 70 | pers_greedy | 71 | pers_melancholy |

### G. Situational pools (8) — condition-gated
| # | pool_id | Gate |
|---|---------|------|
| 72 | situ_night | TIME_OF_DAY | 73 | situ_dawn | TIME_OF_DAY |
| 74 | situ_market_day | day-of-week flag | 75 | situ_weapon_drawn | player state |
| 76 | situ_player_famous | reputation high | 77 | situ_player_infamous | crime bounty |
| 78 | situ_player_injured | player HP low | 79 | situ_after_combat | recent combat flag |

### H. Career-response pools (6) — expand existing career content per player background
| # | pool_id |
|---|---------|
| 80 | career_warrior | 81 | career_thief | 82 | career_mage |
| 83 | career_hunter | 84 | career_scholar | 85 | career_laborer |

### I. Relationship-stage pools (3) — uses persistent npc_memory depth
| # | pool_id | Gate |
|---|---------|------|
| 86 | rel_first_meeting | zero memory entries |
| 87 | rel_acquaintance | 3+ prior responses heard |
| 88 | rel_old_friend | 10+ heard AND disposition 60+ |

### J. Faction-attitude pools (6)
| # | pool_id |
|---|---------|
| 89 | fact_pro_temple | 90 | fact_pro_council | 91 | fact_guild_recognized (player is guildmate) |
| 92 | fact_anti_guild | 93 | fact_bandit_sympathizer | 94 | fact_veteran_empire |

### K. Named-NPC unique pools (6 starter sets, template for ~30)
| # | pool_id | NPC |
|---|---------|-----|
| 95 | uniq_tharin_ironbeard | boss-dwarf warmth, surveyor worry, Keepers evasion |
| 96 | uniq_grimwald | merchant pragmatism, stock stories |
| 97 | uniq_aldric_vane | curiosities double-meanings, Keepers contact subtext |
| 98 | uniq_gormund | pit-master bombast, fighter appraisal |
| 99 | uniq_lady_nightshade | silk-over-steel, guild recruitment probes |
| 100 | uniq_martha | barmaid warmth, follower-hire hints |

---

## Assignment matrix (who gets what)
Every generated NPC at spawn receives: 1 archetype + 1 region + 1-2 personality + all matching situational/disposition/relationship/race gates. Named NPCs additionally get their unique pool with top selection priority.

## Authoring waves (agent batches)
- Wave 1 (foundation): A1-A30 archetypes + B31-35 regions (35 pools, ~420 responses)
- Wave 2 (world talk): C36-55 topics + D/E (29 pools, ~300 responses)
- Wave 3 (texture): F/G/H/I/J (31 pools, ~280 responses)
- Wave 4 (stars): K unique pools for all ~30 named quest givers
Each wave: write → validate schema (parse test) → spot-check tone against this doc.
