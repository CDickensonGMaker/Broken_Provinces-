## npc_data.gd - Resource class for named NPC definitions
## Defines a unique NPC with their traits, dialogue, and quest hooks
class_name NPCData
extends Resource

## Unique NPC identifier (e.g., "tharin_ironbeard")
@export var npc_id: String = ""

## Display name for the NPC
@export var display_name: String = ""

## NPC's race (for disposition calculations)
@export_enum("Human", "Dwarf", "Elf", "Goblin", "Orc") var race: String = "Human"

## NPC archetype for default behavior
@export_enum("quest_giver", "merchant", "guard", "civilian", "priest", "noble") var archetype: String = "civilian"

## Location where this NPC can be found
@export var location: String = ""

## Zone ID for the location
@export var zone_id: String = ""

## Primary faction affiliation
@export var faction_id: String = ""

## Secondary faction affiliations
@export var secondary_factions: Array[String] = []

## Base disposition toward player (50 = neutral)
@export_range(0, 100) var base_disposition: int = 50

## Moral alignment (-100 to 100)
@export_range(-100, 100) var alignment: int = 0

## Description shown when examining NPC
@export_multiline var description: String = ""

## Path to portrait image (if any)
@export var portrait_path: String = ""

## Path to sprite sheet
@export var sprite_path: String = ""

## Sprite sheet configuration
@export var sprite_h_frames: int = 4
@export var sprite_v_frames: int = 1

## Available dialogue topics for this NPC
@export var dialogue_topics: Array[String] = ["local_news", "rumors"]

## Whether this NPC has unique scripted dialogue (DialogueData)
@export var has_unique_dialogue: bool = false

## Path to DialogueData resource for scripted conversations
@export var dialogue_data_path: String = ""

## Path to NPCKnowledgeProfile for topic-based conversations
@export var knowledge_profile_path: String = ""

## Shop type if merchant
@export_enum("none", "general", "weapons", "armor", "alchemy", "magic", "curiosities") var shop_type: String = "none"

## Special flags for quest/story logic
@export var flags: Dictionary = {}

## Whether NPC wanders or stays in place
@export var can_wander: bool = true

## Wander radius if can_wander is true
@export var wander_radius: float = 5.0

## Schedule (future feature) - times when NPC is available
@export var schedule: Dictionary = {}

## Get the full set of faction IDs this NPC belongs to
func get_all_factions() -> Array[String]:
	var factions: Array[String] = []
	if not faction_id.is_empty():
		factions.append(faction_id)
	factions.append_array(secondary_factions)
	return factions

## Check if NPC is a secret member of a faction
func is_secret_member(faction: String) -> bool:
	return flags.get("secret_" + faction, false)

## Get the knowledge profile resource
func get_knowledge_profile() -> NPCKnowledgeProfile:
	if knowledge_profile_path.is_empty():
		return null
	if ResourceLoader.exists(knowledge_profile_path):
		return load(knowledge_profile_path) as NPCKnowledgeProfile
	return null

## Get the dialogue data resource
func get_dialogue_data() -> DialogueData:
	if dialogue_data_path.is_empty():
		return null
	if ResourceLoader.exists(dialogue_data_path):
		return load(dialogue_data_path) as DialogueData
	return null
