## audio_manager.gd - Handles all audio playback with PS1-style compression feel
extends Node

## Audio buses
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const AMBIENT_BUS := "Ambient"

## Standardized audio event names
## Use these constants when playing sounds to ensure consistency
const EVENTS := {
	# Player events
	"player_hit": "res://assets/audio/sfx/player_hit.wav",
	"player_attack": "res://assets/audio/sfx/player_attack.wav",

	# Melee weapon hit sounds (sword clanks)
	"melee_hit_1": "res://assets/audio/sfx/weapons/sword_clank_1.wav",
	"melee_hit_2": "res://assets/audio/sfx/weapons/sword_clank_2.wav",
	"melee_hit_3": "res://assets/audio/sfx/weapons/sword_clank_3.wav",

	# UI accept/click sound
	"ui_accept": "res://assets/audio/sfx/ui/Accepting_Click_Noise.wav",
	"player_death": "res://assets/audio/sfx/player_death.wav",
	"player_block": "res://assets/audio/sfx/player_block.wav",
	"player_parry": "res://assets/audio/sfx/player_parry.wav",
	"player_stagger": "res://assets/audio/sfx/player_stagger.wav",
	"player_heal": "res://assets/audio/sfx/player_heal.wav",
	"player_level_up": "res://assets/audio/sfx/player_level_up.wav",

	# Enemy events
	"enemy_hit": "res://assets/audio/sfx/enemy_hit.wav",
	"enemy_death": "res://assets/audio/sfx/enemy_death.wav",
	"enemy_attack": "res://assets/audio/sfx/enemy_attack.wav",
	"enemy_alert": "res://assets/audio/sfx/enemy_alert.wav",
	"enemy_aggro": "res://assets/audio/sfx/enemy_aggro.wav",
	"enemy_stagger": "res://assets/audio/sfx/enemy_stagger.wav",
	"enemy_spawn": "res://assets/audio/sfx/enemy_spawn.wav",

	# Monster-specific sounds (wolves, beasts)
	"monster_growl_low": "res://assets/audio/sfx/monsters/low_growl.wav",
	"monster_growl_mid": "res://assets/audio/sfx/monsters/mid_growl.wav",
	# Goblin sounds
	"goblin_screech": "res://assets/audio/sfx/monsters/goblin_screech.wav",
	# Cultist sounds
	"cultist_chant_1": "res://assets/audio/sfx/monsters/cultist_1.wav",
	"cultist_chant_2": "res://assets/audio/sfx/monsters/cultist_2.wav",
	# Undead/skeleton sounds
	"undead_groan_1": "res://assets/audio/sfx/monsters/undead_1.wav",
	"undead_groan_2": "res://assets/audio/sfx/monsters/undead_2.wav",

	# Weapon fire (real files on disk)
	"bow_fire": "res://assets/audio/sfx/weapons/bow_and_arrow_quick.wav",
	"musket_fire": "res://assets/audio/sfx/weapons/musket_bang.wav",
	"spell_chant": "res://assets/audio/sfx/weapons/magical_chanting_cast.wav",

	# Projectile events
	"projectile_fire": "res://assets/audio/sfx/projectile_fire.wav",
	"projectile_hit": "res://assets/audio/sfx/projectile_hit.wav",
	"projectile_miss": "res://assets/audio/sfx/projectile_miss.wav",
	"projectile_explode": "res://assets/audio/sfx/projectile_explode.wav",

	# Item events
	"item_pickup": "res://assets/audio/sfx/item_pickup.wav",
	"item_drop": "res://assets/audio/sfx/item_drop.wav",
	"item_use": "res://assets/audio/sfx/item_use.wav",
	"item_equip": "res://assets/audio/sfx/item_equip.wav",
	"item_unequip": "res://assets/audio/sfx/item_unequip.wav",
	"item_break": "res://assets/audio/sfx/item_break.wav",
	"gold_pickup": "res://assets/audio/sfx/gold_pickup.wav",

	# Menu/UI events
	"menu_open": "res://assets/audio/sfx/menu_open.wav",
	"menu_close": "res://assets/audio/sfx/menu_close.wav",
	"menu_select": "res://assets/audio/sfx/menu_select.wav",
	"menu_confirm": "res://assets/audio/sfx/menu_confirm.wav",
	"menu_cancel": "res://assets/audio/sfx/menu_cancel.wav",
	"menu_error": "res://assets/audio/sfx/menu_error.wav",
	"menu_hover": "res://assets/audio/sfx/menu_hover.wav",

	# Combat events
	"critical_hit": "res://assets/audio/sfx/critical_hit.wav",
	"miss": "res://assets/audio/sfx/miss.wav",
	"block": "res://assets/audio/sfx/block.wav",
	"parry": "res://assets/audio/sfx/parry.wav",

	# Spell events
	"spell_cast": "res://assets/audio/sfx/spell_cast.wav",
	"spell_fail": "res://assets/audio/sfx/spell_fail.wav",
	"spell_impact": "res://assets/audio/sfx/spell_impact.wav",

	# Environment/World events
	"door_open": "res://assets/audio/sfx/door_open.wav",
	"door_close": "res://assets/audio/sfx/door_close.wav",
	"door_locked": "res://assets/audio/sfx/door_locked.wav",
	"door_unlock": "res://assets/audio/sfx/door_unlock.wav",
	"chest_open": "res://assets/audio/sfx/chest_open.wav",
	"lever_pull": "res://assets/audio/sfx/lever_pull.wav",
	"secret_found": "res://assets/audio/sfx/secret_found.wav",
	"trap_trigger": "res://assets/audio/sfx/trap_trigger.wav",
	"torch_extinguish": "res://assets/audio/sfx/torch_extinguish.wav",

	# Footstep events (by terrain)
	"footstep_stone": "res://assets/audio/sfx/footstep_stone.wav",
	"footstep_wood": "res://assets/audio/sfx/footstep_wood.wav",
	"footstep_grass": "res://assets/audio/sfx/footstep_grass.wav",
	"footstep_water": "res://assets/audio/sfx/footstep_water.wav",
	"footstep_metal": "res://assets/audio/sfx/footstep_metal.wav",
	"footstep_dirt": "res://assets/audio/sfx/footstep_dirt.wav",
	"footstep_generic": "res://assets/audio/sfx/walking and movement/footstep_1.wav",
	"footstep_loop": "res://assets/audio/sfx/walking and movement/footstep_1_walking_loop_long.wav",

	# Status effect events
	"effect_poison": "res://assets/audio/sfx/effect_poison.wav",
	"effect_burn": "res://assets/audio/sfx/effect_burn.wav",
	"effect_freeze": "res://assets/audio/sfx/effect_freeze.wav",
	"effect_stun": "res://assets/audio/sfx/effect_stun.wav",
	"effect_bleed": "res://assets/audio/sfx/effect_bleed.wav",
	"effect_cure": "res://assets/audio/sfx/effect_cure.wav",

	# Notification events
	"quest_start": "res://assets/audio/sfx/quest_start.wav",
	"quest_complete": "res://assets/audio/sfx/quest_complete.wav",
	"quest_fail": "res://assets/audio/sfx/quest_fail.wav",
	"objective_complete": "res://assets/audio/sfx/objective_complete.wav",
	"save_game": "res://assets/audio/sfx/save_game.wav",
	"load_game": "res://assets/audio/sfx/load_game.wav",

	# NPC response sounds (conversation barks)
	"npc_male_hmm": "res://assets/audio/sfx/npc/npc_male_response_hmm.wav",
	"npc_male_yeah": "res://assets/audio/sfx/npc/npc_male_response_02 low yeeeh.wav",
	"npc_female_eyh": "res://assets/audio/sfx/npc/npc_female_response_01_eyyh.wav",
	"npc_female_response": "res://assets/audio/sfx/npc/npc_female_response_02_3s.wav",

	# Foraging sounds
	"wood_chop_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_01.wav",
	"wood_chop_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_02.wav",
	"wood_chop_3": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_03.wav",
	"wood_chop_heavy": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/wood_chop_heavy_01.wav",
	"bush_pick_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/bush_pick_01.wav",
	"bush_pick_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/bush_pick_02.wav",
	"bush_forage": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/foraging/bush_pick_forage_01.wav",

	# Blacksmith/Crafting sounds
	"anvil_hit_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_01.wav",
	"anvil_hit_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_02.wav",
	"anvil_hit_3": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_03.wav",
	"anvil_hit_4": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_hit_04.wav",
	"metal_strike_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_hot_metal_strike_01.wav",
	"metal_strike_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_hot_metal_strike_02.wav",
	"metal_strike_3": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_hot_metal_strike_03.wav",
	"anvil_heavy_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_heavy_01.wav",
	"anvil_heavy_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_anvil_heavy_02.wav",
	"tongs_handle_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_tongs_handle_01.wav",
	"tongs_handle_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/crafting/blacksmith_tongs_handle_03.wav",

	# Enchanting sounds
	"enchant_charge": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_charge_01.wav",
	"enchant_release": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_cast_release_02.wav",
	"enchant_success_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_success_01.wav",
	"enchant_success_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_success_02.wav",
	"enchant_fail_1": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_fail_01.wav",
	"enchant_fail_2": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_fail_02.wav",
	"enchant_dark": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/enchanting/enchant_dark_01.wav",

	# Alchemy/Potion sounds
	"alchemy_clink": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/potion making/alchemy_glass_clink_01.wav",
	"alchemy_success": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/potion making/alchemy_potion_success_01.wav",

	# Cooking sounds
	"cooking_sizzle": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/cooking/cooking_crafting_pan_sizzle.wav",
	"cooking_chop": "res://assets/audio/sfx/foraging and crafting and potion and enchanting/cooking/cooking_crafting_chop_prep.wav",
}

## Event names call sites use that are spelled differently from EVENTS.
## Resolved before anything else, so an old spelling still finds its sound.
const EVENT_ALIASES := {
	"enemy_roar": "enemy_aggro",
	"magic_attack": "spell_cast",
	"gold_drop": "gold_pickup",
	"npc_death": "enemy_death",
	"guard_death": "enemy_death",
	"secret_revealed": "secret_found",
	"chest_revealed": "secret_found",
	"ambush_alert": "enemy_alert",
	"portal_open": "spell_impact",
	"kraken_rumble": "monster_growl_low",
	"hit": "enemy_hit",
	"death": "enemy_death",
}

## Synthesised placeholders for events that resolved to nothing at all.
##
## Every path here is under assets/audio/generated/ and was written by
## tools/gen_audio.py - procedural synthesis, PS1-era on purpose. They are
## PLACEHOLDER-CLASS: each has a row in docs/audits/art_replacement_manifest.md
## saying so, and Caleb may replace any of them.
##
## **Resolution order puts them BELOW the event's own asset**, so the day a
## real recording lands at `EVENTS[name]` the placeholder steps aside on its
## own and nothing here has to be edited. The wiring survives replacement
## because the event name never moves.
##
## A list is a variant list: one is picked at random per play. Anything that
## fires often gets 2-5, because the same file twice in a row is the second
## loudest tell that a sound was generated.
const EVENT_VARIANTS := {
	# Swings, misses and the arrows that go past
	"player_attack": [
		"res://assets/audio/generated/sfx/combat/player_attack_1.wav",
		"res://assets/audio/generated/sfx/combat/player_attack_2.wav",
		"res://assets/audio/generated/sfx/combat/player_attack_3.wav",
	],
	"enemy_attack": [
		"res://assets/audio/generated/sfx/combat/enemy_attack_1.wav",
		"res://assets/audio/generated/sfx/combat/enemy_attack_2.wav",
		"res://assets/audio/generated/sfx/combat/enemy_attack_3.wav",
	],
	"miss": [
		"res://assets/audio/generated/sfx/combat/miss_1.wav",
		"res://assets/audio/generated/sfx/combat/miss_2.wav",
	],
	"projectile_miss": [
		"res://assets/audio/generated/sfx/combat/projectile_miss_1.wav",
		"res://assets/audio/generated/sfx/combat/projectile_miss_2.wav",
	],
	"enemy_spawn": ["res://assets/audio/generated/sfx/combat/enemy_spawn.wav"],

	# Stylised combat vocalisations - pitched tones and breath, not attempted
	# realism. Realism half-done reads worse than a stylisation done on purpose.
	"player_stagger": [
		"res://assets/audio/generated/sfx/voice/player_hurt_1.wav",
		"res://assets/audio/generated/sfx/voice/player_hurt_2.wav",
		"res://assets/audio/generated/sfx/voice/player_hurt_3.wav",
	],
	"enemy_stagger": [
		"res://assets/audio/generated/sfx/voice/enemy_hurt_1.wav",
		"res://assets/audio/generated/sfx/voice/enemy_hurt_2.wav",
		"res://assets/audio/generated/sfx/voice/enemy_hurt_3.wav",
	],
	"player_death": ["res://assets/audio/generated/sfx/voice/player_death.wav"],
	"enemy_death": [
		"res://assets/audio/generated/sfx/voice/enemy_death_1.wav",
		"res://assets/audio/generated/sfx/voice/enemy_death_2.wav",
		"res://assets/audio/generated/sfx/voice/enemy_death_3.wav",
		"res://assets/audio/generated/sfx/voice/death_exhale_1.wav",
		"res://assets/audio/generated/sfx/voice/death_exhale_2.wav",
	],

	# Good news
	"player_heal": ["res://assets/audio/generated/sfx/ui/player_heal.wav"],
	"player_level_up": ["res://assets/audio/generated/sfx/ui/player_level_up.wav"],
	"quest_fail": ["res://assets/audio/generated/sfx/ui/quest_fail.wav"],

	# Handling things
	"item_drop": [
		"res://assets/audio/generated/sfx/items/item_drop_1.wav",
		"res://assets/audio/generated/sfx/items/item_drop_2.wav",
	],
	"item_equip": ["res://assets/audio/generated/sfx/items/item_equip.wav"],
	"item_unequip": ["res://assets/audio/generated/sfx/items/item_unequip.wav"],
	"item_break": ["res://assets/audio/generated/sfx/items/item_break.wav"],

	# Magic
	"spell_fail": ["res://assets/audio/generated/sfx/magic/spell_fail.wav"],
	"spell_impact": [
		"res://assets/audio/generated/sfx/magic/spell_impact_1.wav",
		"res://assets/audio/generated/sfx/magic/spell_impact_2.wav",
	],

	# Doors, locks, levers, traps
	"door_open": [
		"res://assets/audio/generated/sfx/world/door_open_1.wav",
		"res://assets/audio/generated/sfx/world/door_open_2.wav",
	],
	"door_close": [
		"res://assets/audio/generated/sfx/world/door_close_1.wav",
		"res://assets/audio/generated/sfx/world/door_close_2.wav",
	],
	"door_locked": ["res://assets/audio/generated/sfx/world/door_locked.wav"],
	"door_unlock": ["res://assets/audio/generated/sfx/world/door_unlock.wav"],
	"lever_pull": ["res://assets/audio/generated/sfx/world/lever_pull.wav"],
	"secret_found": ["res://assets/audio/generated/sfx/world/secret_found.wav"],
	"trap_trigger": ["res://assets/audio/generated/sfx/world/trap_trigger.wav"],
	"torch_extinguish": ["res://assets/audio/generated/sfx/world/torch_extinguish.wav"],

	# The six conditions - the only feedback that a condition landed at all
	"effect_poison": ["res://assets/audio/generated/sfx/effects/effect_poison.wav"],
	"effect_burn": ["res://assets/audio/generated/sfx/effects/effect_burn.wav"],
	"effect_freeze": ["res://assets/audio/generated/sfx/effects/effect_freeze.wav"],
	"effect_stun": ["res://assets/audio/generated/sfx/effects/effect_stun.wav"],
	"effect_bleed": ["res://assets/audio/generated/sfx/effects/effect_bleed.wav"],
	"effect_cure": ["res://assets/audio/generated/sfx/effects/effect_cure.wav"],

	# Footsteps per surface. These had an honest stand-in - the one real
	# footstep, on every surface - and now have shaped ones per material.
	# The real file is untouched and still answers `footstep_generic`.
	"footstep_stone": [
		"res://assets/audio/generated/sfx/footsteps/footstep_stone_1.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_stone_2.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_stone_3.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_stone_4.wav",
	],
	"footstep_wood": [
		"res://assets/audio/generated/sfx/footsteps/footstep_wood_1.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_wood_2.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_wood_3.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_wood_4.wav",
	],
	"footstep_grass": [
		"res://assets/audio/generated/sfx/footsteps/footstep_grass_1.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_grass_2.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_grass_3.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_grass_4.wav",
	],
	"footstep_water": [
		"res://assets/audio/generated/sfx/footsteps/footstep_water_1.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_water_2.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_water_3.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_water_4.wav",
	],
	"footstep_metal": [
		"res://assets/audio/generated/sfx/footsteps/footstep_metal_1.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_metal_2.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_metal_3.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_metal_4.wav",
	],
	"footstep_dirt": [
		"res://assets/audio/generated/sfx/footsteps/footstep_dirt_1.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_dirt_2.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_dirt_3.wav",
		"res://assets/audio/generated/sfx/footsteps/footstep_dirt_4.wav",
	],
}

## Stand-ins for events whose own asset does not exist yet.
## Value is an event name, or an array of event names to pick between.
## EVERY entry here is also a row in docs/audits/art_replacement_manifest.md -
## these are the sounds the game asks for and does not have, playing something
## near enough that the moment is not silent.
const EVENT_SUBSTITUTES := {
	# Impacts: the sword clanks
	"player_hit": ["melee_hit_1", "melee_hit_2", "melee_hit_3"],
	"enemy_hit": ["melee_hit_1", "melee_hit_2", "melee_hit_3"],
	"projectile_hit": ["melee_hit_1", "melee_hit_2"],
	"critical_hit": "melee_hit_3",
	"block": "melee_hit_2",
	"parry": "melee_hit_2",
	"player_block": "melee_hit_2",
	"player_parry": "melee_hit_2",

	# Creatures
	"enemy_alert": "monster_growl_mid",
	"enemy_aggro": "monster_growl_low",

	# Ranged
	"projectile_fire": "bow_fire",
	"projectile_explode": "musket_fire",

	# Magic
	"spell_cast": "spell_chant",

	# UI, journal and save: the one click we own
	"menu_select": "ui_accept",
	"menu_confirm": "ui_accept",
	"menu_open": "ui_accept",
	"menu_close": "ui_accept",
	"menu_cancel": "ui_accept",
	"menu_hover": "ui_accept",
	"menu_error": "ui_accept",
	"quest_start": "ui_accept",
	"quest_complete": "ui_accept",
	"objective_complete": "ui_accept",
	"save_game": "ui_accept",
	"load_game": "ui_accept",

	# Handling things
	"item_pickup": "bush_pick_1",
	"item_use": "bush_pick_2",
	"gold_pickup": "alchemy_clink",
	"chest_open": "tongs_handle_1",
}

## Events with no asset and no honest stand-in. They stay silent, warn once,
## and are listed in docs/audits/art_replacement_manifest.md.
## tools/check_audio_events.tscn fails if an entry here is not in that file,
## or if an event is missing from disk and named in neither table.
##
## **It is empty.** The 32 events that stood here on 8/2 - every swing, death,
## door, lock, condition and level-up in the game - now resolve to synthesised
## placeholders in EVENT_VARIANTS. Nothing this game names is silent.
const MISSING_SFX: Array[String] = []

# =============================================================================
# DIALOGUE VOICE BLIPS
# =============================================================================
#
# PS1/Banjo-Kazooie gibberish, not speech: a short pitched grain with a formant
# on it, one per few revealed characters, quiet enough to sit under the reading
# rather than in front of it. Nobody is voicing this game and nobody should
# pretend to - a syllable-shaped tone reads as "a person is talking" where a
# half-done recording reads as broken.
#
# Four pitch classes. Synthesised, PLACEHOLDER-CLASS, manifest rows in
# docs/audits/art_replacement_manifest.md.

const VOICE_BLIP_ROOT := "res://assets/audio/generated/voice/"

const VOICE_BLIPS := {
	"low": [
		VOICE_BLIP_ROOT + "blip_low_1.wav", VOICE_BLIP_ROOT + "blip_low_2.wav",
		VOICE_BLIP_ROOT + "blip_low_3.wav", VOICE_BLIP_ROOT + "blip_low_4.wav",
		VOICE_BLIP_ROOT + "blip_low_5.wav", VOICE_BLIP_ROOT + "blip_low_6.wav",
	],
	"mid": [
		VOICE_BLIP_ROOT + "blip_mid_1.wav", VOICE_BLIP_ROOT + "blip_mid_2.wav",
		VOICE_BLIP_ROOT + "blip_mid_3.wav", VOICE_BLIP_ROOT + "blip_mid_4.wav",
		VOICE_BLIP_ROOT + "blip_mid_5.wav", VOICE_BLIP_ROOT + "blip_mid_6.wav",
	],
	"high": [
		VOICE_BLIP_ROOT + "blip_high_1.wav", VOICE_BLIP_ROOT + "blip_high_2.wav",
		VOICE_BLIP_ROOT + "blip_high_3.wav", VOICE_BLIP_ROOT + "blip_high_4.wav",
		VOICE_BLIP_ROOT + "blip_high_5.wav", VOICE_BLIP_ROOT + "blip_high_6.wav",
	],
	"solemn": [
		VOICE_BLIP_ROOT + "blip_solemn_1.wav", VOICE_BLIP_ROOT + "blip_solemn_2.wav",
		VOICE_BLIP_ROOT + "blip_solemn_3.wav", VOICE_BLIP_ROOT + "blip_solemn_4.wav",
		VOICE_BLIP_ROOT + "blip_solemn_5.wav", VOICE_BLIP_ROOT + "blip_solemn_6.wav",
	],
}

## NPCKnowledgeProfile.Archetype -> blip class. Keyed by the enum's integer so
## this table does not have to preload the profile script.
## GENERIC_VILLAGER=0 FARMER=1 GUARD=2 MERCHANT=3 INNKEEPER=4 BLACKSMITH=5
## SCHOLAR=6 PRIEST=7 HUNTER=8 MINER=9 NOBLE=10 BEGGAR=11 THIEF=12 BARD=13
const ARCHETYPE_BLIP_CLASS := {
	0: "mid",      # generic villager
	1: "mid",      # farmer
	2: "low",      # guard - deep
	3: "mid",      # merchant
	4: "mid",      # innkeeper
	5: "low",      # blacksmith - deep
	6: "solemn",   # scholar
	7: "solemn",   # priest - distinct, slower, with a room around it
	8: "mid",      # hunter
	9: "low",      # miner - deep
	10: "high",    # noble - lighter, clipped
	11: "low",     # beggar
	12: "high",    # thief
	13: "high",    # bard - the highest voice in the game until children exist
}

## Reveal this many characters between blips. A blip per character is a
## machine gun; a blip per word is a metronome. Six is roughly syllabic.
const BLIP_EVERY_CHARS: int = 6

## Quiet on purpose. This sits under the reading.
const BLIP_VOLUME_DB: float = -16.0


## Play one dialogue syllable for a speaker of this archetype.
## `archetype` is an `NPCKnowledgeProfile.Archetype`; -1 or anything unmapped
## takes the mid voice, so an NPC with no profile still sounds like a person.
func play_dialogue_blip(archetype: int = -1) -> void:
	var blip_class: String = ARCHETYPE_BLIP_CLASS.get(archetype, "mid")
	var choices: Array = VOICE_BLIPS.get(blip_class, [])
	if choices.is_empty():
		return
	play_sfx(str(choices[randi() % choices.size()]), BLIP_VOLUME_DB, 0.08)


## Background music tracks
const MUSIC := {
	"menu": "res://assets/audio/background music/game_menu_intro_3min_medieval_trumpets_war_drums.wav",
	"village": "res://assets/audio/background music/general_game_music_village_120s_ps1_retro.wav",
	"wilderness": "res://assets/audio/background music/general_game_music_wilderness_120s_ps1_retro.wav",
	"dungeon": "res://assets/audio/background music/general_game_music_dungeon_lofi_120s_ps1_retro.wav",
	"ruins": "res://assets/audio/background music/ruins_game_music_dungeon_lofi_120s_v2_ps1_retro.wav",
}

## Ambient sound loops by zone type
const AMBIANCE := {
	"town": "res://assets/audio/Ambiance/towns/town_murmur_medieval_mix_60s_ps1_retro.wav",
	"port_city": "res://assets/audio/Ambiance/cities/port_city_1.wav",
	"ruins": "res://assets/audio/Ambiance/ruins/ruins_creepy_ambience.wav",
	"combat_arena_1": "res://assets/audio/Ambiance/combat arena/kling_20260303_Text_to_Audio_90s_retro__1451_1.wav",
	"combat_arena_2": "res://assets/audio/Ambiance/combat arena/kling_20260303_Text_to_Audio_90s_retro__1451_3.wav",
}

## Music players
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

## Dedicated crafting player (stops previous sound on new play, no overlap)
var crafting_player: AudioStreamPlayer

## SFX pool for overlapping sounds
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_size: int = 16

## Volume settings (0-1 linear, stored as dB internally)
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var ambient_volume: float = 0.5

## Current playing tracks
var current_music: String = ""
var current_ambient: String = ""

## Music fade
var fade_duration: float = 1.0
var is_fading: bool = false

## Sound cache
var sound_cache: Dictionary = {}

## Names already warned about, so a missing sound says so once, not every frame
var _warned_missing: Dictionary = {}

## Global creature sound limit to prevent audio stacking
const MAX_CONCURRENT_CREATURE_SOUNDS: int = 4
var _active_creature_sounds: int = 0

## Per-sound-file instance tracking to prevent duplicate sound overlap
## Key: sound file path (String), Value: count of active instances (int)
const MAX_SAME_SOUND_INSTANCES: int = 2
var _active_sound_instances: Dictionary = {}

## Stagger delay range for enemy sounds (seconds)
const STAGGER_DELAY_MIN: float = 0.1
const STAGGER_DELAY_MAX: float = 0.3

## How far music and ambience drop while the game is paused
const PAUSE_DUCK_DB: float = -8.0

func _ready() -> void:
	_setup_audio_buses()
	_create_players()
	_connect_feedback_signals()
	_create_biome_ambience()


## Sounds that belong to events the game already announces. These signals were
## emitted into the void - `item_used` had no listener at all, and pause and
## resume changed nothing anyone could hear.
func _connect_feedback_signals() -> void:
	InventoryManager.item_used.connect(_on_item_used)
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)


func _on_item_used(_item_id: String) -> void:
	play_sfx("item_use", 0.0, 0.1)


func _on_game_paused() -> void:
	music_player.volume_db = _linear_to_db(music_volume) + PAUSE_DUCK_DB
	ambient_player.volume_db = _linear_to_db(ambient_volume) + PAUSE_DUCK_DB


func _on_game_resumed() -> void:
	music_player.volume_db = _linear_to_db(music_volume)
	ambient_player.volume_db = _linear_to_db(ambient_volume)


# =============================================================================
# BIOME AMBIENCE
# =============================================================================
#
# The outdoors used to be silent. `AmbientSoundscape` had the layer and
# crossfade machinery and was instantiated by nothing; there were no biome
# beds for it to play, so nobody noticed. There are beds now.
#
# This is the whole driver: one instance, owned here, told which biome the
# player's cell is and whether it is night. It stands down the moment a scene
# claims the ambient player for itself - a town murmur and a forest bed at
# once is worse than either alone.
#
# The class is preloaded rather than named, because an autoload runs before
# non-autoload class names are guaranteed resolvable.


const AmbientSoundscapeScript := preload("res://scripts/audio/ambient_soundscape.gd")

var biome_ambience: Node = null

## True while no scene has claimed `ambient_player`. Zone ambience wins.
var _biome_ambience_allowed: bool = true


func _create_biome_ambience() -> void:
	biome_ambience = AmbientSoundscapeScript.new()
	biome_ambience.name = "BiomeAmbience"
	biome_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(biome_ambience)

	PlayerGPS.cell_changed.connect(_on_gps_cell_changed)
	SceneManager.scene_load_started.connect(_on_scene_load_started)
	_sync_biome_to_player_cell()


## A new scene owns nothing until it says so. Clearing `current_ambient` here
## is also what stops a town murmur following the player out into the woods -
## levels call `play_ambient()` on entry and nothing has ever called
## `stop_ambient()` on the way out.
func _on_scene_load_started(_scene_path: String) -> void:
	ambient_player.stop()
	current_ambient = ""
	_biome_ambience_allowed = true
	_sync_biome_to_player_cell()


func _on_gps_cell_changed(_old_cell: Vector2i, _new_cell: Vector2i) -> void:
	_sync_biome_to_player_cell()


## Point the bed at the player's cell, then apply the gate. The order matters:
## `set_biome` raises the layer targets, so the mute has to come after it or a
## cell change would restart the forest under a town.
func _sync_biome_to_player_cell() -> void:
	if not is_instance_valid(biome_ambience):
		return
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(PlayerGPS.current_cell)
	if cell:
		biome_ambience.set_biome_from_world_biome(cell.biome)
	if _biome_ambience_allowed:
		biome_ambience.resume()
	else:
		biome_ambience.stop_all()


## Interiors, dungeons and caves: one call, and the bed becomes the cave bed.
func set_biome_ambience_interior(interior: bool) -> void:
	if not is_instance_valid(biome_ambience):
		return
	biome_ambience.set_interior(interior)
	if interior and _biome_ambience_allowed:
		biome_ambience.resume()
	elif not interior:
		_sync_biome_to_player_cell()

func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	# In a real project, you'd set these up in project settings
	pass

func _create_players() -> void:
	# Music player - keeps playing during pause (dialogue, menus)
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	# Ambient player - keeps playing during pause
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = AMBIENT_BUS
	ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ambient_player)

	# Crafting player - dedicated player for crafting sounds (stops previous on new play)
	crafting_player = AudioStreamPlayer.new()
	crafting_player.bus = SFX_BUS
	crafting_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(crafting_player)

	# SFX pool
	for i in range(sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_pool.append(player)

## Play a sound effect
func play_sfx(sound_path: String, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	var stream := _load_sound(sound_path)
	if not stream:
		return

	var player := _get_free_sfx_player()
	if not player:
		return

	player.stream = stream
	player.volume_db = volume_db + _linear_to_db(sfx_volume)

	# Add pitch variance for variety
	if pitch_variance > 0:
		player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	else:
		player.pitch_scale = 1.0

	player.play()

## Play a 3D positioned sound
func play_sfx_3d(sound_path: String, position: Vector3, volume_db: float = 0.0) -> void:
	var stream := _load_sound(sound_path)
	if not stream:
		return

	# Create a temporary 3D player
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db + _linear_to_db(sfx_volume)
	player.bus = SFX_BUS

	# PS1-style: simple distance attenuation
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 5.0
	player.max_distance = 50.0

	get_tree().current_scene.add_child(player)
	player.global_position = position
	player.play()

	# Auto-cleanup
	player.finished.connect(player.queue_free)


## Play an enemy sound from their data arrays (attack_sounds, hurt_sounds, death_sounds)
## Returns true if a sound was played (or scheduled to play with stagger)
## stagger_delay: if true, adds a random delay (0.1-0.3s) before playing to prevent echo
func play_enemy_sound(sound_array: Array, position: Vector3, volume_db: float = 0.0, stagger_delay: bool = false) -> bool:
	if sound_array.is_empty():
		return false

	# Check global creature sound limit
	if _active_creature_sounds >= MAX_CONCURRENT_CREATURE_SOUNDS:
		return false

	# Pick a random sound from the array, with fallback if too many instances
	var sound_path: String = _pick_available_sound(sound_array)
	if sound_path.is_empty():
		return false

	# If stagger delay requested, queue the sound to play after a random delay
	if stagger_delay:
		var delay: float = randf_range(STAGGER_DELAY_MIN, STAGGER_DELAY_MAX)
		get_tree().create_timer(delay).timeout.connect(
			_play_enemy_sound_internal.bind(sound_path, position, volume_db)
		)
		return true

	# Play immediately
	return _play_enemy_sound_internal(sound_path, position, volume_db)


## Pick an available sound from the array, avoiding sounds with too many instances
## Returns empty string if no sound is available
func _pick_available_sound(sound_array: Array) -> String:
	if sound_array.is_empty():
		return ""

	# Shuffle order to randomize which sound we try first
	var shuffled: Array = sound_array.duplicate()
	shuffled.shuffle()

	for sound_path: Variant in shuffled:
		if sound_path is String and not sound_path.is_empty():
			var current_count: int = _active_sound_instances.get(sound_path, 0)
			if current_count < MAX_SAME_SOUND_INSTANCES:
				return sound_path

	# All sounds at limit - return empty to skip playing
	return ""


## Internal function to actually play the enemy sound
func _play_enemy_sound_internal(sound_path: String, position: Vector3, volume_db: float) -> bool:
	# Re-check limits (may have changed during stagger delay)
	if _active_creature_sounds >= MAX_CONCURRENT_CREATURE_SOUNDS:
		return false

	var current_count: int = _active_sound_instances.get(sound_path, 0)
	if current_count >= MAX_SAME_SOUND_INSTANCES:
		return false

	var stream := _load_sound(sound_path)
	if not stream:
		return false

	# Create a temporary 3D player with tracking
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db + _linear_to_db(sfx_volume)
	player.bus = SFX_BUS

	# PS1-style: simple distance attenuation
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 5.0
	player.max_distance = 50.0

	get_tree().current_scene.add_child(player)
	player.global_position = position

	# Increment counters and connect to finished signal
	_active_creature_sounds += 1
	_active_sound_instances[sound_path] = current_count + 1
	player.finished.connect(_on_creature_sound_finished.bind(player, sound_path))

	player.play()
	return true


## Callback when a creature sound finishes playing
func _on_creature_sound_finished(player: AudioStreamPlayer3D, sound_path: String = "") -> void:
	_active_creature_sounds = maxi(0, _active_creature_sounds - 1)

	# Decrement per-sound instance count
	if not sound_path.is_empty() and _active_sound_instances.has(sound_path):
		var count: int = _active_sound_instances[sound_path]
		if count <= 1:
			_active_sound_instances.erase(sound_path)
		else:
			_active_sound_instances[sound_path] = count - 1

	if is_instance_valid(player):
		player.queue_free()


## Play music with optional crossfade
func play_music(music_path: String, crossfade: bool = true) -> void:
	if music_path == current_music:
		return

	var stream := _load_sound(music_path)
	if not stream:
		return

	if crossfade and music_player.playing:
		_crossfade_music(stream)
	else:
		music_player.stream = stream
		music_player.volume_db = _linear_to_db(music_volume)
		music_player.play()

	current_music = music_path

## Stop music with fade
func stop_music(fade: bool = true) -> void:
	if not music_player.playing:
		return

	if fade:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

	current_music = ""


## Called when music finishes - restart to loop
func _on_music_finished() -> void:
	if current_music != "" and music_player:
		music_player.play()


## Play music for a specific zone type
## zone_type can be: "village", "wilderness", "dungeon", "ruins"
func play_zone_music(zone_type: String, crossfade: bool = true) -> void:
	if MUSIC.has(zone_type):
		play_music(MUSIC[zone_type], crossfade)
	else:
		# Default to wilderness for unknown zone types
		play_music(MUSIC["wilderness"], crossfade)


## Play ambient for a specific zone type
## zone_type can be: "town", "port_city", "ruins", "combat_arena"
func play_zone_ambiance(zone_type: String) -> void:
	if zone_type == "combat_arena":
		# Random arena ambient
		var arena_sounds: Array[String] = [AMBIANCE["combat_arena_1"], AMBIANCE["combat_arena_2"]]
		play_ambient(arena_sounds[randi() % arena_sounds.size()])
	elif AMBIANCE.has(zone_type):
		play_ambient(AMBIANCE[zone_type])
	else:
		# Default to town for unknown zone types
		play_ambient(AMBIANCE["town"])


## Play random NPC conversation bark sound
func play_npc_bark(is_female: bool = false, position: Vector3 = Vector3.ZERO, volume_db: float = -3.0) -> void:
	var sounds: Array[String] = []
	if is_female:
		sounds = [EVENTS["npc_female_eyh"], EVENTS["npc_female_response"]]
	else:
		sounds = [EVENTS["npc_male_hmm"], EVENTS["npc_male_yeah"]]

	var sound: String = sounds[randi() % sounds.size()]
	if position != Vector3.ZERO:
		play_sfx_3d(sound, position, volume_db)
	else:
		play_sfx(sound, volume_db)


## Play random foraging sound
## resource_type: "wood", "plant", or "bush"
func play_foraging_sound(resource_type: String = "plant", position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = ""
	match resource_type:
		"wood":
			var wood_sounds: Array[String] = [EVENTS["wood_chop_1"], EVENTS["wood_chop_2"], EVENTS["wood_chop_3"]]
			sound = wood_sounds[randi() % wood_sounds.size()]
		"heavy_wood":
			sound = EVENTS["wood_chop_heavy"]
		_:  # plant, bush, herb
			var bush_sounds: Array[String] = [EVENTS["bush_pick_1"], EVENTS["bush_pick_2"], EVENTS["bush_forage"]]
			sound = bush_sounds[randi() % bush_sounds.size()]

	if position != Vector3.ZERO:
		play_sfx_3d(sound, position)
	else:
		play_sfx(sound)


## Play a crafting-type sound on the dedicated crafting player
## Stops any previous crafting sound to prevent overlap
## Max duration is 1 second
var _crafting_sound_id: int = 0  # Track which sound we're playing

func _play_crafting_type_sound(sound_path: String) -> void:
	if not crafting_player:
		return
	var stream := _load_sound(sound_path)
	if not stream:
		return
	# Stop any currently playing crafting sound
	crafting_player.stop()
	crafting_player.stream = stream
	crafting_player.volume_db = _linear_to_db(sfx_volume)
	crafting_player.play()

	# Increment ID so old timers know to ignore
	_crafting_sound_id += 1
	var my_sound_id: int = _crafting_sound_id

	# Auto-stop after 1 second to keep sounds short
	get_tree().create_timer(1.0).timeout.connect(func():
		# Only stop if this is still the current sound
		if is_instance_valid(crafting_player) and _crafting_sound_id == my_sound_id and crafting_player.playing:
			crafting_player.stop()
	)


## Play random crafting/blacksmith sound (stops previous, max 1 second)
func play_crafting_sound(_position: Vector3 = Vector3.ZERO) -> void:
	var sounds: Array[String] = [
		EVENTS["anvil_hit_1"], EVENTS["anvil_hit_2"], EVENTS["anvil_hit_3"], EVENTS["anvil_hit_4"],
		EVENTS["metal_strike_1"], EVENTS["metal_strike_2"], EVENTS["metal_strike_3"],
		EVENTS["anvil_heavy_1"], EVENTS["anvil_heavy_2"],
	]
	var sound: String = sounds[randi() % sounds.size()]
	_play_crafting_type_sound(sound)


## Play enchanting sound (stops previous, max 1 second)
## success: true for successful enchant, false for failure
func play_enchant_sound(success: bool, _position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = ""
	if success:
		var success_sounds: Array[String] = [EVENTS["enchant_success_1"], EVENTS["enchant_success_2"]]
		sound = success_sounds[randi() % success_sounds.size()]
	else:
		var fail_sounds: Array[String] = [EVENTS["enchant_fail_1"], EVENTS["enchant_fail_2"]]
		sound = fail_sounds[randi() % fail_sounds.size()]
	_play_crafting_type_sound(sound)


## Play enchanting charge-up sound (stops previous, max 1 second)
func play_enchant_charge(_position: Vector3 = Vector3.ZERO) -> void:
	_play_crafting_type_sound(EVENTS["enchant_charge"])


## Play alchemy sound (stops previous, max 1 second)
func play_alchemy_sound(success: bool = true, _position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = EVENTS["alchemy_success"] if success else EVENTS["alchemy_clink"]
	_play_crafting_type_sound(sound)


## Play cooking sound (stops previous, max 1 second)
## sizzle: true for sizzle/cooking sound, false for chopping/prep sound
func play_cooking_sound(sizzle: bool = true, _position: Vector3 = Vector3.ZERO) -> void:
	var sound: String = EVENTS["cooking_sizzle"] if sizzle else EVENTS["cooking_chop"]
	_play_crafting_type_sound(sound)


## Play ambient loop
func play_ambient(ambient_path: String) -> void:
	if ambient_path == current_ambient:
		return

	var stream := _load_sound(ambient_path)
	if not stream:
		return

	ambient_player.stream = stream
	ambient_player.volume_db = _linear_to_db(ambient_volume)
	ambient_player.play()
	current_ambient = ambient_path

	# A zone that names its own ambience owns the ambience. The biome bed
	# stands down rather than layering a forest under a town murmur.
	_biome_ambience_allowed = false
	if is_instance_valid(biome_ambience):
		biome_ambience.stop_all()

## Stop ambient
func stop_ambient() -> void:
	ambient_player.stop()
	current_ambient = ""
	_biome_ambience_allowed = true
	if is_instance_valid(biome_ambience):
		biome_ambience.resume()

## Set master volume (0-1)
func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), _linear_to_db(master_volume))

## Set music volume (0-1)
func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	music_player.volume_db = _linear_to_db(music_volume)

## Set SFX volume (0-1)
func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)

## Set ambient volume (0-1)
func set_ambient_volume(value: float) -> void:
	ambient_volume = clamp(value, 0.0, 1.0)
	ambient_player.volume_db = _linear_to_db(ambient_volume)

## Common sound effect shortcuts.
## These name events, not files - the file each one ends up at is
## resolve_event_path()'s business, and only it knows what is on disk.
func play_hit_sound(is_critical: bool = false) -> void:
	if is_critical:
		play_sfx("critical_hit", 3.0, 0.1)
	else:
		play_sfx("enemy_hit", 0.0, 0.15)

func play_miss_sound() -> void:
	play_sfx("miss", -3.0, 0.1)

func play_block_sound() -> void:
	play_sfx("block", 0.0, 0.1)

func play_death_sound() -> void:
	play_sfx("enemy_death", 0.0, 0.0)

func play_footstep() -> void:
	play_sfx("footstep_generic", -6.0, 0.15)

## Play a footstep for a named surface - "stone", "wood", "grass", "water",
## "metal", "dirt". An unknown surface falls back to the generic step; the
## absence of a surface match must never mean silence.
func play_footstep_surface(surface: String, volume_db: float = -6.0) -> void:
	var event_name: String = "footstep_%s" % surface
	if not EVENTS.has(event_name):
		event_name = "footstep_generic"
	play_sfx(event_name, volume_db, 0.15)

func play_ui_select() -> void:
	play_sfx("menu_select", -3.0, 0.0)

func play_ui_confirm() -> void:
	# Use the accepting click noise for UI confirmations
	play_sfx("ui_accept", -3.0, 0.0)

func play_ui_cancel() -> void:
	play_sfx("menu_cancel", -3.0, 0.0)

## Play a random melee weapon hit sound (sword clanks)
func play_melee_hit_sound() -> void:
	play_sfx("melee_hit_%d" % randi_range(1, 3), 0.0, 0.1)

## Play a random melee weapon hit sound at a 3D position
func play_melee_hit_sound_3d(position: Vector3) -> void:
	play_sfx_3d("melee_hit_%d" % randi_range(1, 3), position, 0.0)

## Play a sound named from data - the PLAY_SOUND dialogue action's param_string.
## Accepts a res:// path, an EVENTS key, or one of the named UI wrappers.
func play_ui_sound(sound_name: String) -> void:
	if sound_name.is_empty():
		return

	if sound_name.begins_with("res://"):
		play_sfx(sound_name)
		return

	match sound_name:
		"select", "menu_select", "ui_select":
			play_ui_select()
			return
		"confirm", "accept", "menu_confirm", "ui_accept":
			play_ui_confirm()
			return
		"cancel", "menu_cancel":
			play_ui_cancel()
			return
		"open", "menu_open":
			play_ui_open()
			return
		"close", "menu_close":
			play_ui_close()
			return

	if not play_event(sound_name):
		push_warning("AudioManager: play_ui_sound could not resolve '%s'" % sound_name)


func play_ui_open() -> void:
	play_sfx("menu_open", -3.0, 0.0)

func play_ui_close() -> void:
	play_sfx("menu_close", -3.0, 0.0)

func play_item_pickup() -> void:
	play_sfx("item_pickup", 0.0, 0.1)

func play_gold_pickup() -> void:
	play_sfx("gold_pickup", 0.0, 0.05)

func play_spell_cast(spell_school: Enums.SpellSchool) -> void:
	# Play magical chanting sound for all spell casts
	play_sfx("spell_chant", -3.0, 0.05)
	# School-specific layers have no assets yet - see the art manifest. The
	# chant above is what a cast sounds like until they land.

## Resolve an event name to a file on disk.
##
## Order: alias -> the event's own asset -> a synthesised variant -> a declared
## substitute -> nothing. Returns "" when the sound genuinely does not exist,
## and warns once so a silent event is visible in a log without drowning it.
##
## The event's own asset comes first on purpose: dropping a real recording at
## `EVENTS[name]` retires its placeholder without anyone editing a table.
func resolve_event_path(event_name: String) -> String:
	var name: String = EVENT_ALIASES.get(event_name, event_name)

	var own_path: String = EVENTS.get(name, "")
	if not own_path.is_empty() and ResourceLoader.exists(own_path):
		return own_path

	if EVENT_VARIANTS.has(name):
		var variants: Array = (EVENT_VARIANTS[name] as Array).duplicate()
		variants.shuffle()
		for variant: Variant in variants:
			var variant_path: String = str(variant)
			if ResourceLoader.exists(variant_path):
				return variant_path

	if EVENT_SUBSTITUTES.has(name):
		var sub: Variant = EVENT_SUBSTITUTES[name]
		var candidates: Array = (sub as Array).duplicate() if sub is Array else [sub]
		candidates.shuffle()
		for candidate: Variant in candidates:
			var sub_path: String = EVENTS.get(str(candidate), "")
			if not sub_path.is_empty() and ResourceLoader.exists(sub_path):
				return sub_path

	_warn_once(name, own_path)
	return ""


## Warn about a sound the game asks for and does not have - once per name.
func _warn_once(event_name: String, intended_path: String) -> void:
	if _warned_missing.has(event_name):
		return
	_warned_missing[event_name] = true
	if EVENTS.has(event_name):
		push_warning("AudioManager: no asset for event '%s' (wants %s) - see docs/audits/art_replacement_manifest.md" % [event_name, intended_path])
	else:
		push_warning("AudioManager: unknown sound '%s' - not an EVENTS key, an alias, or a res:// path" % event_name)


## Helper: Load and cache sound.
## Accepts a res:// path or an event name - gameplay code has always spoken
## the event vocabulary from CLAUDE.md, and until now nothing understood it.
## The cache is keyed on the RESOLVED path, never on the name that asked for
## it. Keying on the name froze the first random pick forever, so a variant
## list - and every shuffled substitute already in the tables - would have
## played exactly one file for the life of the process.
func _load_sound(path: String) -> AudioStream:
	var resolved: String = path
	if not path.begins_with("res://"):
		resolved = resolve_event_path(path)
		if resolved.is_empty():
			return null

	if sound_cache.has(resolved):
		return sound_cache[resolved]

	if not ResourceLoader.exists(resolved):
		# A hardcoded res:// path that is not on disk is a code bug, not a
		# missing asset request - it can never be substituted for.
		if not _warned_missing.has(resolved):
			_warned_missing[resolved] = true
			push_error("AudioManager: sound file not found: " + resolved)
		return null

	var stream: AudioStream = load(resolved)
	sound_cache[resolved] = stream
	return stream

## Helper: Get available SFX player from pool
func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	# All busy, use oldest (first in pool)
	return sfx_pool[0]

## Helper: Crossfade music
func _crossfade_music(new_stream: AudioStream) -> void:
	# Create temporary player for old music
	var old_player := AudioStreamPlayer.new()
	old_player.stream = music_player.stream
	old_player.volume_db = music_player.volume_db
	old_player.bus = MUSIC_BUS
	add_child(old_player)
	old_player.play(music_player.get_playback_position())

	# Fade out old
	var tween := create_tween()
	tween.tween_property(old_player, "volume_db", -80.0, fade_duration)
	tween.tween_callback(old_player.queue_free)

	# Start new music at low volume and fade in
	music_player.stream = new_stream
	music_player.volume_db = -80.0
	music_player.play()

	var tween2 := create_tween()
	tween2.tween_property(music_player, "volume_db", _linear_to_db(music_volume), fade_duration)

## Helper: Convert linear volume to dB
func _linear_to_db(value: float) -> float:
	if value <= 0:
		return -80.0
	return 20.0 * log(value) / log(10.0)

## Serialize settings
func get_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume
	}

## Load settings
func load_settings(data: Dictionary) -> void:
	set_master_volume(data.get("master_volume", 1.0))
	set_music_volume(data.get("music_volume", 0.7))
	set_sfx_volume(data.get("sfx_volume", 1.0))
	set_ambient_volume(data.get("ambient_volume", 0.5))

## Play a sound by event name from EVENTS dictionary
## Returns false if event not found
func play_event(event_name: String, volume_db: float = 0.0, pitch_variance: float = 0.1) -> bool:
	var path: String = resolve_event_path(event_name)
	if path.is_empty():
		return false

	play_sfx(path, volume_db, pitch_variance)
	return true

## Play a sound by event name at a 3D position
## Returns false if event not found
func play_event_3d(event_name: String, position: Vector3, volume_db: float = 0.0) -> bool:
	var path: String = resolve_event_path(event_name)
	if path.is_empty():
		return false

	play_sfx_3d(path, position, volume_db)
	return true

## Check if an event exists
func has_event(event_name: String) -> bool:
	return EVENTS.has(event_name)

## Get the file path for an event (for custom handling).
## This is what will actually play - substitutes included.
func get_event_path(event_name: String) -> String:
	return resolve_event_path(event_name)
