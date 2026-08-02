extends Node
## Drives every quest in the database from offer to COMPLETED, headlessly.
##
##     godot --headless --path . res://tools/probes/quest_completion_sweep.gd
##
## A probe, not a gate: it reports and never sets a failing exit code, because
## a quest whose objective type has no scripted entry point here is a gap in
## the probe, not a defect in the quest.
##
## Written for the 8/2 terseness pass. That pass rewrote prose in 228 quest
## files and changed exactly one behavioural field - `dwarf_messenger`'s
## `prerequisites` - and this is the instrument that proves the other 227 still
## start, settle and complete.
##
## Prerequisites are seated the way check_quest_engine seats them: a completed
## stub quest per id, the flags raised, the forbidden flags cleared. So this
## measures whether a quest COMPLETES, never whether it is currently OFFERED.

## Objective types this probe knows how to settle through a real public call.
const DRIVABLE: Array[String] = [
	"kill", "collect", "has_item", "talk", "reach", "explore", "interact",
	"craft", "duel_win", "choice", "solve_puzzle", "escort", "deliver_soulstone",
	"recruit_follower", "wave_defense",
]

var completed: int = 0
## Bounties and repeatables are erased from the active table by complete_quest,
## so "is it still there and COMPLETED" is not a test they can pass. The signal
## is the only honest witness.
var _fired: Dictionary = {}
var skipped: Array[String] = []
var stuck: Array[String] = []


func _ready() -> void:
	QuestManager.quest_completed.connect(func(quest_id: String) -> void: _fired[quest_id] = true)
	await get_tree().process_frame
	_run()
	get_tree().quit(0)


func _run() -> void:
	var ids: Array = QuestManager.quest_database.keys()
	ids.sort()
	print("[sweep] %d quests in the database" % ids.size())

	for quest_id: String in ids:
		_drive(quest_id)

	print("")
	print("[sweep] completed:      %d" % completed)
	print("[sweep] not driveable:  %d" % skipped.size())
	print("[sweep] did NOT finish: %d" % stuck.size())
	for line: String in stuck:
		print("    STUCK  %s" % line)
	for line: String in skipped:
		print("    SKIP   %s" % line)

	_report_elder_moor_offers()


## What a brand-new character is offered before he has done anything. The 8/2
## terseness pass paced one remote arc out of this list and nothing else, so
## this is the line to read when somebody asks what changed.
func _report_elder_moor_offers() -> void:
	QuestManager.quests.clear()
	FlagManager.flags.clear()
	var ids: Array = QuestManager.quest_database.keys()
	ids.sort()
	var offered: Array[String] = []
	var gated: Array[String] = []
	for quest_id: String in ids:
		var template: Object = QuestManager.quest_database[quest_id]
		if template.giver_region != "elder_moor":
			continue
		if QuestManager.is_quest_available(quest_id):
			offered.append(quest_id)
		else:
			gated.append(quest_id)
	print("")
	print("[elder_moor] offered from a cold start: %d" % offered.size())
	for quest_id: String in offered:
		print("    OFFER  %s" % quest_id)
	print("[elder_moor] gated: %d" % gated.size())
	for quest_id: String in gated:
		var template: Object = QuestManager.quest_database[quest_id]
		print("    GATED  %-34s by %s %s" % [
			quest_id, str(template.prerequisites), str(template.flag_prerequisites)])


func _drive(quest_id: String) -> void:
	var template: Object = QuestManager.quest_database[quest_id]

	var undriveable: Array[String] = []
	for objective: Object in template.objectives:
		if objective.is_optional:
			continue
		if not DRIVABLE.has(objective.type):
			undriveable.append(objective.type)
	if not undriveable.is_empty():
		skipped.append("%s (objective types: %s)" % [quest_id, ", ".join(undriveable)])
		return

	_seat_prerequisites(template)

	if not QuestManager.start_quest(quest_id):
		stuck.append("%s - start_quest() refused it" % quest_id)
		_clear(quest_id, template)
		return

	var quest: Object = QuestManager.quests.get(quest_id)
	if quest == null:
		stuck.append("%s - started and is not in the active table" % quest_id)
		_clear(quest_id, template)
		return

	for _pass: int in range(4):
		if QuestManager.are_objectives_complete(quest_id):
			break
		for objective: Object in quest.objectives:
			if objective.is_optional or objective.is_satisfied():
				continue
			_settle(quest, objective)

	if QuestManager.are_objectives_complete(quest_id):
		QuestManager.complete_quest(quest_id)

	quest = QuestManager.quests.get(quest_id)
	if _fired.has(quest_id) or (quest != null and quest.state == Enums.QuestState.COMPLETED):
		completed += 1
	else:
		stuck.append("%s - %s" % [quest_id, _unsettled(quest)])

	_clear(quest_id, template)


func _seat_prerequisites(template: Object) -> void:
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
	if template.rank_required >= 0 and not template.faction.is_empty():
		GuildRankManager.guild_rank_levels[template.faction] = template.rank_required


func _settle(quest: Object, objective: Object) -> void:
	match objective.type:
		"kill":
			for _i: int in range(objective.required_count):
				QuestManager.on_enemy_killed(objective.target)
		"collect":
			QuestManager.on_item_collected(objective.target, objective.required_count)
		"has_item":
			InventoryManager.add_item(objective.target, objective.required_count)
			QuestManager.refresh_has_item_objectives(quest)
		"talk":
			for _i: int in range(objective.required_count):
				QuestManager.on_npc_talked(objective.target)
		"reach":
			QuestManager.on_location_reached(objective.target)
		"explore":
			QuestManager.on_location_explored(objective.target)
		"interact":
			for _i: int in range(objective.required_count):
				QuestManager.on_interact(objective.target)
		"solve_puzzle":
			QuestManager.on_puzzle_solved(objective.target)
		"escort":
			QuestManager.on_escort_arrived(objective.target, objective.target)
		"deliver_soulstone":
			QuestManager.on_soulstone_delivered(objective.target, quest.turn_in_target)
		"recruit_follower":
			QuestManager.on_follower_recruited(objective.target)
		"wave_defense":
			QuestManager.on_wave_defense_complete(objective.target)
		_:
			for _i: int in range(objective.required_count):
				QuestManager.update_progress(objective.type, objective.target, 1)


func _unsettled(quest: Object) -> String:
	if quest == null:
		return "vanished from the active table"
	var names: Array[String] = []
	for objective: Object in quest.objectives:
		if not objective.is_optional and not objective.is_satisfied():
			names.append("%s (%s -> %s, %d/%d)" % [
				objective.id, objective.type, objective.target,
				objective.current_count, objective.required_count,
			])
	if names.is_empty():
		return "every objective settled but state is %d" % quest.state
	return ", ".join(names)


func _clear(quest_id: String, template: Object) -> void:
	QuestManager.quests.erase(quest_id)
	QuestManager.bounty_cooldowns.erase(quest_id)
	for prereq_id: String in template.prerequisites:
		QuestManager.quests.erase(prereq_id)
	if not template.faction.is_empty():
		GuildRankManager.guild_rank_levels.erase(template.faction)
