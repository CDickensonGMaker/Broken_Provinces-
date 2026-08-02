extends Node
## SCRATCH. Reproduces the batch-3 headline: shipped quests whose objectives no
## handler can settle. Deleted once check_quest_engine carries the permanent
## coverage assertion.

const AFFECTED: Array[String] = [
	"noble_soulstone_request",
	"mage_05_rogue_mage",
	"mage_13_council_seat",
	"mage_repeatable_research",
	"thieves_09_informant",
	"thieves_10_government_job",
	"thieves_11_impossible_vault",
	"thieves_12_guild_traitor",
	"thieves_13_right_hand",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	var stuck_total: int = 0
	for quest_id: String in AFFECTED:
		if not QuestManager.quest_database.has(quest_id):
			print("%-30s MISSING FROM DATABASE" % quest_id)
			continue

		var template: Object = QuestManager.quest_database[quest_id]
		_satisfy_gates(template)
		QuestManager.quests.erase(quest_id)
		if not QuestManager.start_quest(quest_id):
			print("%-30s WOULD NOT START" % quest_id)
			continue

		var quest: Object = QuestManager.quests[quest_id]
		# Twice: several "talk" objectives are gated on all prior objectives
		# being complete, so one pass settles them in the wrong order.
		_drive_everything(quest)
		_drive_everything(quest)

		var stuck: Array[String] = []
		for obj: Object in quest.objectives:
			if not obj.is_satisfied():
				stuck.append("%s(%s)" % [obj.id, obj.type])
		stuck_total += stuck.size()
		print("%-30s %s" % [
			quest_id,
			"COMPLETABLE" if stuck.is_empty() else "STUCK: " + ", ".join(stuck)
		])

	print("")
	print("Objectives no handler can settle: %d" % stuck_total)
	get_tree().quit(0)


func _satisfy_gates(template: Object) -> void:
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


## Fires every driver the engine owns at every objective, the most generous
## reading possible. Anything still unsatisfied afterwards has no handler.
func _drive_everything(quest: Object) -> void:
	for obj: Object in quest.objectives:
		var target: String = obj.target
		if obj.type == "has_item":
			InventoryManager.add_item(target, obj.required_count)
			QuestManager.refresh_has_item_objectives(quest)
		QuestManager.on_enemy_killed(target)
		QuestManager.on_item_collected(target, 99)
		QuestManager.on_npc_talked(target)
		QuestManager.on_location_reached(target)
		QuestManager.on_location_explored(target)
		for i: int in range(maxi(1, obj.required_count)):
			QuestManager.on_interact(target)
		QuestManager.on_puzzle_solved(target)
		QuestManager.on_follower_recruited(target)
		QuestManager.on_soulstone_delivered(target, quest.turn_in_target)
		QuestManager.on_escort_arrived(target, obj.target_zone)
		QuestManager.update_progress("craft", target, 99)
		QuestManager.update_progress("duel_win", target, 99)
	for choice_id: String in quest.choice_consequences:
		QuestManager.apply_choice_consequence(quest.id, choice_id)
		break
