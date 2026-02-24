## dialogue_loader.gd - Utility for loading dialogue trees from JSON files
## Converts JSON data to DialogueData resources at runtime
class_name DialogueLoader
extends RefCounted

## Load a dialogue tree from a JSON file
## Returns a DialogueData resource or null on failure
static func load_from_json(json_path: String) -> DialogueData:
	if not FileAccess.file_exists(json_path):
		push_error("[DialogueLoader] File not found: " + json_path)
		return null

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("[DialogueLoader] Could not open file: " + json_path)
		return null

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("[DialogueLoader] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null

	var data: Dictionary = json.data
	return _build_dialogue_data(data)


## Build a DialogueData resource from parsed JSON dictionary
static func _build_dialogue_data(data: Dictionary) -> DialogueData:
	var dialogue := DialogueData.new()

	dialogue.id = data.get("id", "")
	dialogue.display_name = data.get("display_name", dialogue.id)
	dialogue.description = data.get("description", "")
	dialogue.start_node_id = data.get("start_node", "start")

	# Build nodes
	var nodes_data: Array = data.get("nodes", [])
	for node_dict: Dictionary in nodes_data:
		var node := _build_dialogue_node(node_dict)
		if node:
			dialogue.nodes.append(node)

	return dialogue


## Build a DialogueNode from JSON dictionary
static func _build_dialogue_node(data: Dictionary) -> DialogueNode:
	var node := DialogueNode.new()

	node.id = data.get("id", "")
	node.speaker_name = data.get("speaker", "")
	node.text = data.get("text", "")
	node.is_end_node = data.get("is_end", false)
	node.auto_continue_to = data.get("auto_continue", "")
	node.portrait_id = data.get("portrait", "")

	# Build choices
	var choices_data: Array = data.get("choices", [])
	for choice_dict: Dictionary in choices_data:
		var choice := _build_dialogue_choice(choice_dict)
		if choice:
			node.choices.append(choice)

	return node


## Build a DialogueChoice from JSON dictionary
static func _build_dialogue_choice(data: Dictionary) -> DialogueChoice:
	var choice := DialogueChoice.new()

	choice.text = data.get("text", "")
	choice.next_node_id = data.get("next", "")
	choice.show_when_unavailable = data.get("show_when_unavailable", false)
	choice.unavailable_reason = data.get("unavailable_reason", "")

	# Build conditions
	var conditions_data: Array = data.get("conditions", [])
	for cond_dict: Dictionary in conditions_data:
		var condition := _build_dialogue_condition(cond_dict)
		if condition:
			choice.conditions.append(condition)

	# Build actions
	var actions_data: Array = data.get("actions", [])
	for action_dict: Dictionary in actions_data:
		var action := _build_dialogue_action(action_dict)
		if action:
			choice.actions.append(action)

	return choice


## Build a DialogueCondition from JSON dictionary
static func _build_dialogue_condition(data: Dictionary) -> DialogueCondition:
	var condition := DialogueCondition.new()

	var type_str: String = data.get("type", "none")
	condition.type = _parse_condition_type(type_str)
	condition.param_string = data.get("param", "")
	condition.param_int = data.get("value", 0)
	condition.param_float = data.get("threshold", 0.0)
	condition.invert = data.get("invert", false)

	return condition


## Build a DialogueAction from JSON dictionary
static func _build_dialogue_action(data: Dictionary) -> DialogueAction:
	var action := DialogueAction.new()

	var type_str: String = data.get("type", "none")
	action.type = _parse_action_type(type_str)
	action.param_string = data.get("param", "")
	action.param_int = data.get("value", 0)
	action.param_float = data.get("dc", 0.0)
	action.success_node_id = data.get("success_node", "")
	action.failure_node_id = data.get("failure_node", "")

	return action


## Parse condition type from string
static func _parse_condition_type(type_str: String) -> DialogueData.ConditionType:
	match type_str.to_lower():
		"none": return DialogueData.ConditionType.NONE
		"quest_state": return DialogueData.ConditionType.QUEST_STATE
		"quest_complete": return DialogueData.ConditionType.QUEST_COMPLETE
		"has_item": return DialogueData.ConditionType.HAS_ITEM
		"has_gold": return DialogueData.ConditionType.HAS_GOLD
		"flag_set": return DialogueData.ConditionType.FLAG_SET
		"flag_not_set": return DialogueData.ConditionType.FLAG_NOT_SET
		"stat_check": return DialogueData.ConditionType.STAT_CHECK
		"skill_check": return DialogueData.ConditionType.SKILL_CHECK
		"time_of_day": return DialogueData.ConditionType.TIME_OF_DAY
		"reputation": return DialogueData.ConditionType.REPUTATION
		"random": return DialogueData.ConditionType.RANDOM_CHANCE
		_: return DialogueData.ConditionType.NONE


## Parse action type from string
static func _parse_action_type(type_str: String) -> DialogueData.ActionType:
	match type_str.to_lower():
		"none": return DialogueData.ActionType.NONE
		"give_item": return DialogueData.ActionType.GIVE_ITEM
		"take_item": return DialogueData.ActionType.TAKE_ITEM
		"give_gold": return DialogueData.ActionType.GIVE_GOLD
		"take_gold": return DialogueData.ActionType.TAKE_GOLD
		"start_quest": return DialogueData.ActionType.START_QUEST
		"complete_quest": return DialogueData.ActionType.COMPLETE_QUEST
		"advance_quest": return DialogueData.ActionType.ADVANCE_QUEST
		"set_flag": return DialogueData.ActionType.SET_FLAG
		"clear_flag": return DialogueData.ActionType.CLEAR_FLAG
		"skill_check": return DialogueData.ActionType.SKILL_CHECK
		"modify_reputation": return DialogueData.ActionType.MODIFY_REPUTATION
		"give_xp": return DialogueData.ActionType.GIVE_XP
		"heal": return DialogueData.ActionType.HEAL_PLAYER
		"teleport": return DialogueData.ActionType.TELEPORT
		"open_shop": return DialogueData.ActionType.OPEN_SHOP
		"play_sound": return DialogueData.ActionType.PLAY_SOUND
		"set_npc_state": return DialogueData.ActionType.SET_NPC_STATE
		_: return DialogueData.ActionType.NONE


## Convenience method to load and cache dialogue from JSON
## Uses preloaded dialogues to avoid repeated file reads
static var _dialogue_cache: Dictionary = {}

static func get_dialogue(json_path: String) -> DialogueData:
	if _dialogue_cache.has(json_path):
		return _dialogue_cache[json_path]

	var dialogue := load_from_json(json_path)
	if dialogue:
		_dialogue_cache[json_path] = dialogue

	return dialogue


## Clear the dialogue cache
static func clear_cache() -> void:
	_dialogue_cache.clear()
