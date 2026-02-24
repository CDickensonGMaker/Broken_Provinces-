## faction_data.gd - Resource class for faction definitions
## Defines a faction with its relationships, ranks, and alignment
class_name FactionData
extends Resource

## Unique faction identifier (e.g., "human_empire", "dwarves_birth")
@export var id: String = ""

## Display name for the faction
@export var display_name: String = ""

## Description of the faction
@export_multiline var description: String = ""

## Parent faction ID (for sub-factions, e.g., "dwarves" for "dwarves_birth")
## Actions affecting sub-factions cascade partially to parent
@export var parent_faction: String = ""

## Allied faction IDs - reputation gains/losses partially cascade
@export var allies: Array[String] = []

## Enemy faction IDs - opposite reputation changes cascade
@export var enemies: Array[String] = []

## Neutral faction IDs - no cascade
@export var neutrals: Array[String] = []

## Faction alignment (-100 to 100, like morality)
## Used for comparing alignment with player morality
@export_range(-100, 100) var alignment: int = 0

## Faction ranks from lowest to highest
## Each rank is a dictionary with: {name, min_reputation, benefits}
@export var ranks: Array[Dictionary] = []

## Default reputation when player first encounters this faction
@export_range(-100, 100) var default_reputation: int = 0

## Whether the player can join this faction
@export var joinable: bool = true

## Minimum reputation required to join
@export_range(-100, 100) var join_threshold: int = 20

## Whether this faction is hidden (secret organization)
@export var is_hidden: bool = false

## Icon for UI display (optional)
@export var icon: Texture2D

## Color for UI display
@export var faction_color: Color = Color.WHITE

## Reputation thresholds for relationship status
const REP_HATED: int = -80
const REP_HOSTILE: int = -50
const REP_UNFRIENDLY: int = -20
const REP_NEUTRAL: int = 20
const REP_FRIENDLY: int = 50
const REP_HONORED: int = 80

## Reputation status enum
enum ReputationStatus {
	HATED,      # -100 to -80
	HOSTILE,    # -79 to -50
	UNFRIENDLY, # -49 to -20
	NEUTRAL,    # -19 to 20
	FRIENDLY,   # 21 to 50
	HONORED,    # 51 to 80
	EXALTED     # 81 to 100
}

## Get reputation status from a reputation value
static func get_reputation_status(reputation: int) -> ReputationStatus:
	if reputation <= REP_HATED:
		return ReputationStatus.HATED
	elif reputation <= REP_HOSTILE:
		return ReputationStatus.HOSTILE
	elif reputation <= REP_UNFRIENDLY:
		return ReputationStatus.UNFRIENDLY
	elif reputation <= REP_NEUTRAL:
		return ReputationStatus.NEUTRAL
	elif reputation <= REP_FRIENDLY:
		return ReputationStatus.FRIENDLY
	elif reputation <= REP_HONORED:
		return ReputationStatus.HONORED
	else:
		return ReputationStatus.EXALTED

## Get display name for a reputation status
static func get_status_name(status: ReputationStatus) -> String:
	match status:
		ReputationStatus.HATED:
			return "Hated"
		ReputationStatus.HOSTILE:
			return "Hostile"
		ReputationStatus.UNFRIENDLY:
			return "Unfriendly"
		ReputationStatus.NEUTRAL:
			return "Neutral"
		ReputationStatus.FRIENDLY:
			return "Friendly"
		ReputationStatus.HONORED:
			return "Honored"
		ReputationStatus.EXALTED:
			return "Exalted"
		_:
			return "Unknown"

## Get color for a reputation status
static func get_status_color(status: ReputationStatus) -> Color:
	match status:
		ReputationStatus.HATED:
			return Color(0.5, 0.0, 0.0)  # Dark red
		ReputationStatus.HOSTILE:
			return Color(0.8, 0.2, 0.2)  # Red
		ReputationStatus.UNFRIENDLY:
			return Color(0.9, 0.5, 0.2)  # Orange
		ReputationStatus.NEUTRAL:
			return Color(0.7, 0.7, 0.7)  # Gray
		ReputationStatus.FRIENDLY:
			return Color(0.2, 0.7, 0.2)  # Green
		ReputationStatus.HONORED:
			return Color(0.2, 0.6, 0.9)  # Blue
		ReputationStatus.EXALTED:
			return Color(1.0, 0.85, 0.0)  # Gold
		_:
			return Color.WHITE

## Get the player's rank in this faction based on reputation
func get_rank_for_reputation(reputation: int) -> Dictionary:
	var best_rank: Dictionary = {}

	for rank: Dictionary in ranks:
		var min_rep: int = rank.get("min_reputation", 0)
		if reputation >= min_rep:
			if best_rank.is_empty() or min_rep > best_rank.get("min_reputation", 0):
				best_rank = rank

	return best_rank

## Get the rank name for a reputation value
func get_rank_name(reputation: int) -> String:
	var rank: Dictionary = get_rank_for_reputation(reputation)
	if rank.is_empty():
		return "Outsider"
	return rank.get("name", "Member")

## Check if reputation meets the join threshold
func can_join_with_reputation(reputation: int) -> bool:
	return joinable and reputation >= join_threshold

## Create a basic faction with standard ranks
static func create_standard_faction(
	faction_id: String,
	faction_name: String,
	faction_desc: String = "",
	faction_alignment: int = 0
) -> FactionData:
	var faction := FactionData.new()
	faction.id = faction_id
	faction.display_name = faction_name
	faction.description = faction_desc
	faction.alignment = faction_alignment

	# Standard rank progression
	faction.ranks = [
		{"name": "Initiate", "min_reputation": 0, "benefits": []},
		{"name": "Member", "min_reputation": 20, "benefits": ["basic_services"]},
		{"name": "Trusted", "min_reputation": 40, "benefits": ["basic_services", "discounts"]},
		{"name": "Veteran", "min_reputation": 60, "benefits": ["basic_services", "discounts", "special_quests"]},
		{"name": "Champion", "min_reputation": 80, "benefits": ["basic_services", "discounts", "special_quests", "leadership"]}
	]

	return faction
