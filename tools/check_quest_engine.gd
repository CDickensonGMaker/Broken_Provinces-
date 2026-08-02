extends Node
## Quest engine check: field survival, OR groups, world-state pre-completion.
##
## Usage: godot --headless --path . res://tools/check_quest_engine.tscn
##
## It runs as a *scene*, not with --script: QuestManager, FlagManager and
## WorldState are autoloads, and a --script run starts an engine with none of
## them.
##
## Three things are proved here.
##
## 1. THE FIELD REGRESSION GUARD. start_quest() builds the active quest by
##    copying the template field by field, by hand. Every field added to the
##    JSON since has had to be added to that copy by hand too, and twice now
##    one was not: choice_consequences vanished until 6452717 fixed it, and
##    dungeon_spawn vanished from objectives without anyone noticing. The guard
##    does not carry a list of fields to check - it reads the property list off
##    QuestManager.Quest and QuestManager.Objective, so a field added to the
##    class and forgotten in the copy fails this check the day it is written.
##    tools/fixtures/quest_field_reference.json carries a value for every
##    documented field; a new field with no value there fails too, which is the
##    reminder to document it.
##
##    The same diff runs again after a save/load round trip, because a field
##    can survive being started and still be dropped by to_dict/from_dict.
##
## 2. OR GROUPS. Objectives sharing a `group` id are alternatives. Settling one
##    settles the group, and the quest stops waiting on the rest.
##
## 3. WORLD-STATE PRE-COMPLETION. An objective whose world_condition already
##    holds when the quest is offered completes on the spot - the "you already
##    did this" moment.
##
## 4. QUESTMANAGER'S OWN MEMBER STATE. The field guard above covers Quest and
##    Objective, and that is exactly the gap that let _timed_objectives reach a
##    milestone build unsaved: to_dict wrote it and SaveManager threw it away,
##    while _paused_timers was never written at all. So the same reflection now
##    runs over QuestManager's own script variables - each must appear in
##    to_dict, survive from_dict, or be named in TRANSIENT_MEMBERS with a
##    reason.

const FIXTURE_PATH := "res://tools/fixtures/quest_field_reference.json"

## QuestManager members that are deliberately not saved, and why.
const TRANSIENT_MEMBERS: Dictionary = {
	"quest_database": "rebuilt from data/quests/**.json on every boot",
	"objective_locations": "a compass position cache, recomputed after a load",
	"_quest_spawns": "live node references; every one is freed by the scene change a load performs",
}

## Member name -> the key to_dict writes it under, where they differ.
const MEMBER_KEY_ALIASES: Dictionary = {
	"quests": "quests",
	"_timed_objectives": "timed_objectives",
	"_paused_timers": "paused_timers",
}

## Quest fields that are deliberately not carried from template to active quest.
const QUEST_RUNTIME_FIELDS: Array[String] = [
	"state",             # the template is never ACTIVE
	"completion_state",  # outcome, decided later
	"objectives",        # compared field by field of their own
]

## Objective fields that are progress, not authored data.
const OBJECTIVE_RUNTIME_FIELDS: Array[String] = [
	"current_count",
	"is_completed",
	"completion_method",
	"is_settled",
]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	_check_field_survival()
	_check_or_groups()
	_check_world_pre_completion()
	_check_world_state_round_trip()
	_check_manager_member_survival()

	print("")
	print("Checks run: %d" % _checks)
	if _failures.is_empty():
		print("Quest engine check: PASS")
		get_tree().quit(0)
		return

	print("Quest engine check: FAIL (%d)" % _failures.size())
	for failure: String in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)


func _fail(message: String) -> void:
	_failures.append(message)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


# =============================================================================
# 1. FIELD SURVIVAL
# =============================================================================

func _check_field_survival() -> void:
	var fixture: Dictionary = _load_fixture()
	if fixture.is_empty():
		_fail("fixture would not load: %s" % FIXTURE_PATH)
		return

	var quest_id: String = fixture.get("id", "")
	var template: Object = QuestManager._parse_quest(fixture)
	QuestManager.quest_database[quest_id] = template

	# Every field in the class must have a value in the fixture, or the guard
	# is only checking the fields somebody remembered to write down.
	_check_fixture_covers_class(fixture, template)

	# The template's gates: a completed prerequisite quest and a raised flag.
	_satisfy_prerequisites(template)

	var started: bool = QuestManager.start_quest(quest_id)
	_expect(started, "the reference quest would not start - its prerequisites are not being met")
	if not started:
		return

	var active: Object = QuestManager.quests[quest_id]
	_diff_quest(template, active, "after start_quest")

	# And again across a save.
	var saved: Dictionary = QuestManager.to_dict()
	QuestManager.from_dict(saved)
	_expect(QuestManager.quests.has(quest_id), "the reference quest did not survive a save/load round trip")
	if QuestManager.quests.has(quest_id):
		_diff_quest(template, QuestManager.quests[quest_id], "after save/load")

	QuestManager.quests.erase(quest_id)


func _load_fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## Make sure the fixture actually exercises every authored field on the class.
func _check_fixture_covers_class(fixture: Dictionary, template: Object) -> void:
	for field: String in _authored_fields(template, QUEST_RUNTIME_FIELDS):
		if field in ["id", "title", "description"]:
			continue
		_expect(
			fixture.has(field) or _fixture_alias(fixture, field),
			"quest field '%s' has no value in %s - the guard cannot prove it survives" % [field, FIXTURE_PATH]
		)

	var objectives: Array = fixture.get("objectives", [])
	var objective_keys: Dictionary = {}
	for entry: Variant in objectives:
		if entry is Dictionary:
			for key: String in (entry as Dictionary):
				objective_keys[key] = true

	if template.objectives.is_empty():
		_fail("the reference quest parsed with no objectives")
		return

	for field: String in _authored_fields(template.objectives[0], OBJECTIVE_RUNTIME_FIELDS):
		if field in ["id", "description"]:
			continue
		_expect(
			objective_keys.has(field),
			"objective field '%s' has no value in %s - the guard cannot prove it survives" % [field, FIXTURE_PATH]
		)


## A couple of quest fields are spelled differently in JSON than on the class.
func _fixture_alias(fixture: Dictionary, field: String) -> bool:
	match field:
		"quest_source":
			return fixture.has("quest_source")
		"objective_groups":
			return fixture.has("objective_groups")
		_:
			return false


## Script-declared properties on an object, minus the runtime ones.
func _authored_fields(obj: Object, skip: Array[String]) -> Array[String]:
	var fields: Array[String] = []
	for property: Dictionary in obj.get_property_list():
		var usage: int = property.get("usage", 0)
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name: String = property.get("name", "")
		if name.is_empty() or name.begins_with("_") or name in skip:
			continue
		fields.append(name)
	return fields


func _satisfy_prerequisites(template: Object) -> void:
	for prereq_id: String in template.prerequisites:
		var stub: Object = QuestManager.Quest.new()
		stub.id = prereq_id
		stub.title = prereq_id
		stub.state = Enums.QuestState.COMPLETED
		QuestManager.quests[prereq_id] = stub

	for flag: String in template.flag_prerequisites:
		FlagManager.set_flag(flag, true)

	for flag: String in template.forbidden_flags:
		FlagManager.clear_flag(flag)


func _diff_quest(template: Object, active: Object, stage: String) -> void:
	for field: String in _authored_fields(template, QUEST_RUNTIME_FIELDS):
		var expected: Variant = template.get(field)
		var actual: Variant = active.get(field)
		_expect(
			_same(expected, actual),
			"quest field '%s' was dropped %s (template %s, quest %s)" % [
				field, stage, var_to_str(expected), var_to_str(actual)
			]
		)

	_expect(
		template.objectives.size() == active.objectives.size(),
		"objective count changed %s (%d -> %d)" % [stage, template.objectives.size(), active.objectives.size()]
	)

	var count: int = mini(template.objectives.size(), active.objectives.size())
	for i: int in range(count):
		var t_obj: Object = template.objectives[i]
		var a_obj: Object = active.objectives[i]
		for field: String in _authored_fields(t_obj, OBJECTIVE_RUNTIME_FIELDS):
			var expected: Variant = t_obj.get(field)
			var actual: Variant = a_obj.get(field)
			_expect(
				_same(expected, actual),
				"objective '%s' field '%s' was dropped %s (template %s, quest %s)" % [
					t_obj.id, field, stage, var_to_str(expected), var_to_str(actual)
				]
			)


## Value equality that survives nesting. var_to_str is stable for the plain
## data these fields hold, and unlike == it never quietly compares references.
func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary or a is Array:
		return var_to_str(a) == var_to_str(b)
	return a == b


# =============================================================================
# 2. OR GROUPS
# =============================================================================

func _check_or_groups() -> void:
	var quest_id := "_or_group_check"
	QuestManager.quest_database[quest_id] = QuestManager._parse_quest({
		"id": quest_id,
		"title": "Deal with the camp",
		"turn_in_type": "auto_complete",
		"objective_groups": {"settle": {"required": 1}},
		"objectives": [
			{"id": "kill", "type": "kill", "target": "_or_bandit_leader", "group": "settle"},
			{"id": "bribe", "type": "interact", "target": "_or_bribe", "group": "settle"},
			{"id": "intimidate", "type": "interact", "target": "_or_intimidate", "group": "settle"},
		]
	})

	_expect(QuestManager.start_quest(quest_id), "the OR-group quest would not start")
	if not QuestManager.quests.has(quest_id):
		return

	var quest: Object = QuestManager.quests[quest_id]
	_expect(not QuestManager.are_objectives_complete(quest_id), "an OR group counted as settled before anything was done")

	# Take one road: intimidate him.
	QuestManager.on_interact("_or_intimidate")

	var settled_ids: Array[String] = []
	var completed_ids: Array[String] = []
	for obj: Object in quest.objectives:
		if obj.is_settled:
			settled_ids.append(obj.id)
		if obj.is_completed:
			completed_ids.append(obj.id)

	_expect(completed_ids == ["intimidate"], "the road the player took should be the only completed one, got %s" % str(completed_ids))
	_expect(settled_ids.size() == 2, "the two roads not taken should be settled, got %s" % str(settled_ids))
	_expect(
		quest.state == Enums.QuestState.COMPLETED,
		"settling the group should have completed an auto-complete quest, state is %d" % quest.state
	)

	# Settled state has to survive a save, or a reload re-opens the roads the
	# player already closed.
	var saved: Dictionary = QuestManager.to_dict()
	QuestManager.from_dict(saved)
	var reloaded: Object = QuestManager.quests.get(quest_id)
	if reloaded == null:
		_fail("the OR-group quest did not survive a save/load round trip")
		return

	var reloaded_settled: int = 0
	for obj: Object in reloaded.objectives:
		if obj.is_settled:
			reloaded_settled += 1
	_expect(reloaded_settled == 2, "settled objectives did not survive a save, %d of 2 came back" % reloaded_settled)

	QuestManager.quests.erase(quest_id)


# =============================================================================
# 3. WORLD-STATE PRE-COMPLETION
# =============================================================================

func _check_world_pre_completion() -> void:
	var quest_id := "_pre_completion_check"
	QuestManager.quest_database[quest_id] = QuestManager._parse_quest({
		"id": quest_id,
		"title": "Clear the camp",
		"turn_in_type": "auto_complete",
		"objectives": [
			{
				"id": "clear_camp",
				"type": "kill",
				"target": "_pre_bandit",
				"required_count": 6,
				"world_condition": {"flag": "_pre_camp_cleared"}
			}
		]
	})

	# Offered cold, the work is still the player's to do.
	_expect(QuestManager.start_quest(quest_id), "the pre-completion quest would not start")
	var quest: Object = QuestManager.quests.get(quest_id)
	if quest == null:
		return
	_expect(not quest.objectives[0].is_completed, "an objective pre-completed with no world fact to justify it")
	QuestManager.quests.erase(quest_id)

	# Now the world says he already did it.
	WorldState.set_flag("_pre_camp_cleared", true)
	_expect(QuestManager.start_quest(quest_id), "the pre-completion quest would not start a second time")
	quest = QuestManager.quests.get(quest_id)
	if quest == null:
		return

	_expect(quest.objectives[0].is_completed, "the world said the camp was cleared and the objective did not settle")
	_expect(
		quest.objectives[0].completion_method == "already_done",
		"a pre-completed objective should record how it settled, got '%s'" % quest.objectives[0].completion_method
	)
	_expect(
		quest.state == Enums.QuestState.COMPLETED,
		"a quest whose every objective was already done should complete on offer, state is %d" % quest.state
	)

	# The mirror: world facts must be readable as ordinary flags, because that
	# is the vocabulary dialogue and quest prerequisites already speak.
	_expect(FlagManager.has_flag("_pre_camp_cleared"), "a world fact did not reach FlagManager")

	WorldState.clear_flag("_pre_camp_cleared")
	QuestManager.quests.erase(quest_id)


# =============================================================================
# 4. WORLDSTATE ROUND TRIP
# =============================================================================

func _check_world_state_round_trip() -> void:
	WorldState.reset_for_new_game()
	WorldState.set_flag(WorldState.FLAG_BANDIT_CAMP_CLEARED, true)
	WorldState.set_flag("kazan_dun_state", "besieged")
	WorldState.set_flag("bodies_recovered", 3)
	WorldState.set_world_modification("mountain_pass", {"cells": [[3, -4], [3, -5]], "passable": true})

	var before: Dictionary = WorldState.to_dict()
	var wire: String = JSON.stringify(before)
	var after_parse: Variant = JSON.parse_string(wire)
	if not (after_parse is Dictionary):
		_fail("WorldState did not survive JSON at all")
		return

	WorldState.reset_for_new_game()
	WorldState.from_dict(after_parse as Dictionary)

	_expect(WorldState.has_flag(WorldState.FLAG_BANDIT_CAMP_CLEARED), "a bool world fact did not survive the round trip")
	_expect(WorldState.get_flag("kazan_dun_state", "") == "besieged", "a String world fact did not survive the round trip")
	_expect(
		WorldState.evaluate_condition({"flag": "bodies_recovered", "at_least": 3}),
		"a numeric world fact did not survive the round trip"
	)
	_expect(
		WorldState.has_world_modification("mountain_pass"),
		"a world modification did not survive the round trip"
	)

	# Conditions have to hold their shape too.
	_expect(WorldState.evaluate_condition({"flag": "kazan_dun_state", "equals": "besieged"}), "equals condition failed")
	_expect(not WorldState.evaluate_condition({"flag": "kazan_dun_state", "equals": "fallen"}), "equals condition matched the wrong value")
	_expect(WorldState.evaluate_condition({"not": {"flag": "nothing_happened_here"}}), "not condition failed")
	_expect(
		WorldState.evaluate_condition({"all": [
			{"flag": WorldState.FLAG_BANDIT_CAMP_CLEARED},
			{"flag": "bodies_recovered", "at_least": 1}
		]}),
		"all condition failed"
	)
	_expect(
		WorldState.evaluate_condition({"any": [{"flag": "never_set"}, {"flag": WorldState.FLAG_BANDIT_CAMP_CLEARED}]}),
		"any condition failed"
	)
	_expect(not WorldState.evaluate_condition({}), "an empty condition must never pre-complete anything")

	WorldState.reset_for_new_game()


# =============================================================================
# 5. QUESTMANAGER MEMBER STATE
# =============================================================================

func _check_manager_member_survival() -> void:
	# tracked_quest_id is only kept if the quest it names is really active -
	# from_dict re-points it otherwise - so give it a real one to hold.
	var quest_id := "_member_check_quest"
	QuestManager.quest_database[quest_id] = QuestManager._parse_quest({
		"id": quest_id,
		"title": "Member check",
		"objectives": [{"id": "_obj", "type": "kill", "target": "_member_check_target"}]
	})
	QuestManager.start_quest(quest_id)

	# Numbers are written as floats by JSON, so dirty them as floats: an int
	# that comes back as a float is the wire format, not a dropped field.
	var dirty: Dictionary = {
		"tracked_quest_id": quest_id,
		"bounty_cooldowns": {"_member_check_bounty": 4.0},
		"_timed_objectives": {"_member_check_quest:_obj": 42.0},
		"_paused_timers": {"_member_check_quest:_paused": 17.0},
	}
	for member: String in dirty:
		QuestManager.set(member, dirty[member])

	var wire: Dictionary = QuestManager.to_dict()

	for member: String in _manager_members():
		if TRANSIENT_MEMBERS.has(member):
			continue
		var key: String = MEMBER_KEY_ALIASES.get(member, member)
		_expect(
			wire.has(key),
			"QuestManager.%s is neither written by to_dict (as '%s') nor declared in TRANSIENT_MEMBERS" % [member, key]
		)

	# And it has to come back, not just go out.
	var round_tripped: Variant = JSON.parse_string(JSON.stringify(wire))
	if not (round_tripped is Dictionary):
		_fail("QuestManager.to_dict() did not survive JSON")
		return

	for member: String in dirty:
		QuestManager.set(member, {} if dirty[member] is Dictionary else "")
	QuestManager.from_dict(round_tripped as Dictionary)
	_expect(QuestManager.quests.has(quest_id), "the member-check quest did not survive the round trip")

	for member: String in dirty:
		_expect(
			_same(dirty[member], QuestManager.get(member)),
			"QuestManager.%s was dropped by the save round trip (set %s, got %s)" % [
				member, var_to_str(dirty[member]), var_to_str(QuestManager.get(member))
			]
		)

	QuestManager.reset_for_new_game()
	QuestManager.quest_database.erase(quest_id)


## Script-declared members on the QuestManager singleton.
func _manager_members() -> Array[String]:
	var members: Array[String] = []
	for property: Dictionary in QuestManager.get_property_list():
		var usage: int = property.get("usage", 0)
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var name: String = property.get("name", "")
		if name.is_empty():
			continue
		members.append(name)
	return members
