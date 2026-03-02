## intro_dialogue_builder.gd - Builds dynamic intro dialogue based on player race/career
## Creates a DialogueData resource from modular text segments in intro_text.json
class_name IntroDialogueBuilder
extends RefCounted

const INTRO_TEXT_PATH := "res://data/dialogue/intro_text.json"

## Cached intro text data
static var _intro_data: Dictionary = {}
static var _data_loaded: bool = false


## Load intro text data from JSON (cached after first load)
static func _load_intro_data() -> bool:
	if _data_loaded:
		return true

	if not FileAccess.file_exists(INTRO_TEXT_PATH):
		push_error("[IntroDialogueBuilder] Intro text file not found: %s" % INTRO_TEXT_PATH)
		return false

	var file := FileAccess.open(INTRO_TEXT_PATH, FileAccess.READ)
	if not file:
		push_error("[IntroDialogueBuilder] Failed to open intro text file")
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("[IntroDialogueBuilder] Failed to parse intro JSON: %s" % json.get_error_message())
		return false

	_intro_data = json.data
	_data_loaded = true
	return true


## Build intro dialogue for the given race and career
## Returns a DialogueData resource ready to be passed to DialogueManager, or null on error
static func build_intro_dialogue(race: Enums.Race, career: Enums.Career) -> Variant:
	if not _load_intro_data():
		return null

	# Get text components
	var opening: String = _intro_data.get("opening", "")
	var race_insert: String = _get_race_insert(race)
	var career_insert: String = _get_career_insert(career)
	var core_message: String = _intro_data.get("core_message", "")
	var lore_hint: String = _get_random_lore_hint()
	var closing: String = _intro_data.get("closing", "")

	# Build full dialogue text with paragraph breaks
	var full_text := ""

	# Opening paragraph
	if not opening.is_empty():
		full_text += opening

	# Race and career inserts (combined into one paragraph)
	var background := ""
	if not race_insert.is_empty():
		background += race_insert
	if not career_insert.is_empty():
		if not background.is_empty():
			background += " "
		background += career_insert

	if not background.is_empty():
		full_text += "\n\n" + background

	# Core message (task/Tharin info)
	if not core_message.is_empty():
		full_text += "\n\n" + core_message

	# Optional lore hint
	if not lore_hint.is_empty():
		full_text += "\n\n" + lore_hint

	# Closing
	if not closing.is_empty():
		full_text += "\n\n" + closing

	# Create DialogueData with a single node
	var dialogue := DialogueData.new()
	dialogue.id = "intro_dialogue"
	dialogue.display_name = "Narrator"
	dialogue.description = "New game intro text"
	dialogue.start_node_id = "intro"

	# Create the intro node
	var intro_node := DialogueNode.new()
	intro_node.id = "intro"
	intro_node.speaker_name = ""  # No speaker name for narrator text
	intro_node.text = full_text
	intro_node.is_end_node = true  # Single node, ends when dismissed

	dialogue.nodes.append(intro_node)

	return dialogue


## Get race-specific insert text
static func _get_race_insert(race: Enums.Race) -> String:
	var race_inserts: Dictionary = _intro_data.get("race_inserts", {})

	var race_key: String
	match race:
		Enums.Race.HUMAN:
			race_key = "HUMAN"
		Enums.Race.ELF:
			race_key = "ELF"
		Enums.Race.HALFLING:
			race_key = "HALFLING"
		Enums.Race.DWARF:
			race_key = "DWARF"
		_:
			race_key = "HUMAN"

	return race_inserts.get(race_key, "")


## Get career-specific insert text
static func _get_career_insert(career: Enums.Career) -> String:
	var career_inserts: Dictionary = _intro_data.get("career_inserts", {})

	var career_key: String
	match career:
		Enums.Career.APPRENTICE:
			career_key = "APPRENTICE"
		Enums.Career.FARMER:
			career_key = "FARMER"
		Enums.Career.GRAVE_DIGGER:
			career_key = "GRAVE_DIGGER"
		Enums.Career.SCOUT:
			career_key = "SCOUT"
		Enums.Career.SOLDIER:
			career_key = "SOLDIER"
		Enums.Career.MERCHANT:
			career_key = "MERCHANT"
		Enums.Career.PRIEST:
			career_key = "PRIEST"
		Enums.Career.THIEF:
			career_key = "THIEF"
		Enums.Career.NOBLE:
			career_key = "NOBLE"
		Enums.Career.CULTIST:
			career_key = "CULTIST"
		Enums.Career.ALCHEMIST:
			career_key = "ALCHEMIST"
		Enums.Career.BEGGAR:
			career_key = "BEGGAR"
		_:
			career_key = "FARMER"

	return career_inserts.get(career_key, "")


## Get a random lore hint from the available options
static func _get_random_lore_hint() -> String:
	var lore_hints_raw: Array = _intro_data.get("lore_hints", [])

	if lore_hints_raw.is_empty():
		return ""

	var index: int = randi() % lore_hints_raw.size()
	var hint: Variant = lore_hints_raw[index]
	return str(hint) if hint != null else ""
