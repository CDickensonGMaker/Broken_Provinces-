## companion_data.gd - Resource class defining combat companion NPCs
## Used by CompanionNPC and CompanionManager for companion configuration
class_name CompanionData
extends Resource

## AI behavior preferences for combat
enum AIBehavior {
	BALANCED,    ## Mix of offense and defense, follows player lead
	AGGRESSIVE,  ## Prioritizes attacking, engages enemies proactively
	DEFENSIVE,   ## Stays close to player, protects rather than attacks
	SUPPORT,     ## Focuses on healing/buffing (future), stays back
}

## Combat style preference
enum CombatStyle {
	MELEE,       ## Close combat with weapons
	RANGED,      ## Bow/crossbow attacks from distance
	MAGIC,       ## Spell casting (uses mana)
	HYBRID,      ## Can switch between melee and ranged
}

## Unlock condition types
enum UnlockType {
	NONE,                ## Available from start (debug/testing)
	QUEST_COMPLETE,      ## Requires completing a specific quest
	FACTION_REPUTATION,  ## Requires faction rep threshold
	ITEM_POSSESSION,     ## Requires having a specific item
	DIALOGUE_FLAG,       ## Requires a dialogue flag to be set
	LEVEL_REQUIREMENT,   ## Requires player level
}

## Unique identifier for this companion
@export var id: String = ""

## Display name
@export var display_name: String = "Companion"

## Character class/archetype (for UI and lore)
@export var character_class: String = "Warrior"

## Description for UI
@export_multiline var description: String = ""

## ============================================================================
## STATS
## ============================================================================

@export_group("Stats")

## Base health
@export var max_health: int = 100

## Base damage output
@export var base_damage: int = 15

## Armor value (damage reduction)
@export var armor: int = 10

## Movement speed multiplier
@export var speed_multiplier: float = 1.0

## Attack cooldown in seconds
@export var attack_cooldown: float = 1.5

## Detection range for enemies
@export var combat_range: float = 12.0

## Preferred attack range (melee vs ranged)
@export var attack_range: float = 2.0

## ============================================================================
## COMBAT CONFIGURATION
## ============================================================================

@export_group("Combat")

## Combat behavior preference
@export var ai_behavior: AIBehavior = AIBehavior.BALANCED

## Combat style
@export var combat_style: CombatStyle = CombatStyle.MELEE

## Whether companion is essential (can't permanently die)
@export var is_essential: bool = true

## Time to recover from knockout (seconds, 0 = recover after combat)
@export var knockout_duration: float = 0.0

## Preferred weapon types (for loot filtering / equipment)
@export var preferred_weapons: Array[String] = ["sword", "axe"]

## ============================================================================
## ABILITIES
## ============================================================================

@export_group("Abilities")

## List of ability IDs this companion can use
@export var abilities: Array[String] = []

## Chance to use ability vs basic attack (0.0 - 1.0)
@export var ability_use_chance: float = 0.2

## Projectile data for ranged companions
@export var ranged_projectile_path: String = ""

## ============================================================================
## VISUAL CONFIGURATION
## ============================================================================

@export_group("Visual")

## Sprite sheet path
@export var sprite_path: String = ""

## Sprite sheet configuration
@export var sprite_h_frames: int = 5
@export var sprite_v_frames: int = 1
@export var sprite_pixel_size: float = 0.0256

## Skin/color tint
@export var tint_color: Color = Color.WHITE

## ============================================================================
## UNLOCK CONDITIONS
## ============================================================================

@export_group("Unlock")

## How this companion is unlocked
@export var unlock_type: UnlockType = UnlockType.QUEST_COMPLETE

## Unlock parameter (quest_id, faction_id, item_id, flag_name, or level)
@export var unlock_param: String = ""

## Unlock threshold value (for reputation/level requirements)
@export var unlock_threshold: int = 0

## ============================================================================
## DIALOGUE
## ============================================================================

@export_group("Dialogue")

## Dialogue data resource path for scripted dialogue
@export var dialogue_path: String = ""

## Knowledge profile resource path for topic conversations
@export var knowledge_profile_path: String = ""

## Voice lines for combat barks
@export var combat_bark_lines: Array[String] = [
	"For glory!",
	"Take that!",
	"I've got your back!",
]

## Voice lines when knocked out
@export var knockout_lines: Array[String] = [
	"I... can't...",
	"Ugh...",
]

## Voice lines when recovered
@export var recovery_lines: Array[String] = [
	"I'm back!",
	"Not done yet!",
]


## ============================================================================
## METHODS
## ============================================================================

## Check if companion can be unlocked by player
func can_unlock() -> bool:
	# Safety check: autoloads may not be ready during resource loading
	var quest_mgr: Node = Engine.get_singleton("QuestManager") if Engine.has_singleton("QuestManager") else null
	var faction_mgr: Node = Engine.get_singleton("FactionManager") if Engine.has_singleton("FactionManager") else null
	var inventory_mgr: Node = Engine.get_singleton("InventoryManager") if Engine.has_singleton("InventoryManager") else null
	var flag_mgr: Node = Engine.get_singleton("FlagManager") if Engine.has_singleton("FlagManager") else null
	var game_mgr: Node = Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else null

	# Also check for global autoloads via tree if singletons not registered
	if not quest_mgr:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			quest_mgr = tree.root.get_node_or_null("QuestManager")
			faction_mgr = tree.root.get_node_or_null("FactionManager")
			inventory_mgr = tree.root.get_node_or_null("InventoryManager")
			flag_mgr = tree.root.get_node_or_null("FlagManager")
			game_mgr = tree.root.get_node_or_null("GameManager")

	match unlock_type:
		UnlockType.NONE:
			return true

		UnlockType.QUEST_COMPLETE:
			if quest_mgr and quest_mgr.has_method("is_quest_completed"):
				return quest_mgr.is_quest_completed(unlock_param)
			return false

		UnlockType.FACTION_REPUTATION:
			if faction_mgr and faction_mgr.has_method("get_reputation"):
				var rep: int = faction_mgr.get_reputation(unlock_param)
				return rep >= unlock_threshold
			return false

		UnlockType.ITEM_POSSESSION:
			if inventory_mgr and inventory_mgr.has_method("has_item"):
				return inventory_mgr.has_item(unlock_param)
			return false

		UnlockType.DIALOGUE_FLAG:
			if flag_mgr and flag_mgr.has_method("has_flag"):
				return flag_mgr.has_flag(unlock_param)
			return false

		UnlockType.LEVEL_REQUIREMENT:
			if game_mgr and "player_data" in game_mgr and game_mgr.player_data:
				return game_mgr.player_data.level >= unlock_threshold
			return false

	return false


## Get unlock description text for UI
func get_unlock_description() -> String:
	# Safety check: autoloads may not be ready during resource loading
	var quest_mgr: Node = null
	var inventory_mgr: Node = null

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		quest_mgr = tree.root.get_node_or_null("QuestManager")
		inventory_mgr = tree.root.get_node_or_null("InventoryManager")

	match unlock_type:
		UnlockType.NONE:
			return "Available"

		UnlockType.QUEST_COMPLETE:
			var quest_name: String = unlock_param
			if quest_mgr and quest_mgr.has_method("get_quest_data"):
				var quest_data: Dictionary = quest_mgr.get_quest_data(unlock_param)
				if quest_data.has("title"):
					quest_name = quest_data.title
			return "Complete quest: %s" % quest_name

		UnlockType.FACTION_REPUTATION:
			return "Reach %d reputation with %s" % [unlock_threshold, unlock_param]

		UnlockType.ITEM_POSSESSION:
			var item_name: String = unlock_param
			if inventory_mgr and inventory_mgr.has_method("get_item_name"):
				item_name = inventory_mgr.get_item_name(unlock_param)
			return "Obtain: %s" % item_name

		UnlockType.DIALOGUE_FLAG:
			return "Special condition"

		UnlockType.LEVEL_REQUIREMENT:
			return "Reach level %d" % unlock_threshold

	return "Unknown"


## Serialize to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"character_class": character_class,
		"description": description,
		"max_health": max_health,
		"base_damage": base_damage,
		"armor": armor,
		"speed_multiplier": speed_multiplier,
		"attack_cooldown": attack_cooldown,
		"combat_range": combat_range,
		"attack_range": attack_range,
		"ai_behavior": ai_behavior,
		"combat_style": combat_style,
		"is_essential": is_essential,
		"knockout_duration": knockout_duration,
		"preferred_weapons": preferred_weapons,
		"abilities": abilities,
		"ability_use_chance": ability_use_chance,
		"ranged_projectile_path": ranged_projectile_path,
		"sprite_path": sprite_path,
		"sprite_h_frames": sprite_h_frames,
		"sprite_v_frames": sprite_v_frames,
		"sprite_pixel_size": sprite_pixel_size,
		"tint_color": {
			"r": tint_color.r,
			"g": tint_color.g,
			"b": tint_color.b,
			"a": tint_color.a
		},
		"unlock_type": unlock_type,
		"unlock_param": unlock_param,
		"unlock_threshold": unlock_threshold,
		"dialogue_path": dialogue_path,
		"knowledge_profile_path": knowledge_profile_path,
		"combat_bark_lines": combat_bark_lines,
		"knockout_lines": knockout_lines,
		"recovery_lines": recovery_lines,
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> CompanionData:
	var companion := CompanionData.new()
	companion.id = data.get("id", "")
	companion.display_name = data.get("display_name", "Companion")
	companion.character_class = data.get("character_class", "Warrior")
	companion.description = data.get("description", "")
	companion.max_health = data.get("max_health", 100)
	companion.base_damage = data.get("base_damage", 15)
	companion.armor = data.get("armor", 10)
	companion.speed_multiplier = data.get("speed_multiplier", 1.0)
	companion.attack_cooldown = data.get("attack_cooldown", 1.5)
	companion.combat_range = data.get("combat_range", 12.0)
	companion.attack_range = data.get("attack_range", 2.0)
	companion.ai_behavior = data.get("ai_behavior", AIBehavior.BALANCED)
	companion.combat_style = data.get("combat_style", CombatStyle.MELEE)
	companion.is_essential = data.get("is_essential", true)
	companion.knockout_duration = data.get("knockout_duration", 0.0)
	companion.preferred_weapons = data.get("preferred_weapons", ["sword", "axe"])
	companion.abilities = data.get("abilities", [])
	companion.ability_use_chance = data.get("ability_use_chance", 0.2)
	companion.ranged_projectile_path = data.get("ranged_projectile_path", "")
	companion.sprite_path = data.get("sprite_path", "")
	companion.sprite_h_frames = data.get("sprite_h_frames", 5)
	companion.sprite_v_frames = data.get("sprite_v_frames", 1)
	companion.sprite_pixel_size = data.get("sprite_pixel_size", 0.0256)

	var tint_data: Dictionary = data.get("tint_color", {})
	if not tint_data.is_empty():
		companion.tint_color = Color(
			tint_data.get("r", 1.0),
			tint_data.get("g", 1.0),
			tint_data.get("b", 1.0),
			tint_data.get("a", 1.0)
		)

	companion.unlock_type = data.get("unlock_type", UnlockType.QUEST_COMPLETE)
	companion.unlock_param = data.get("unlock_param", "")
	companion.unlock_threshold = data.get("unlock_threshold", 0)
	companion.dialogue_path = data.get("dialogue_path", "")
	companion.knowledge_profile_path = data.get("knowledge_profile_path", "")
	companion.combat_bark_lines = data.get("combat_bark_lines", [])
	companion.knockout_lines = data.get("knockout_lines", [])
	companion.recovery_lines = data.get("recovery_lines", [])

	return companion
