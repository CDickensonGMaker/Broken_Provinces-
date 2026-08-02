extends Node
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	await get_tree().process_frame
	for id: String in ["aberdeens_blessing", "missing_miner"]:
		if QuestManager.quest_database.has(id):
			var q: Object = QuestManager.quest_database[id]
			print("LIVE DB %-22s giver=%s" % [id, q.giver_npc_id])
	print("quests loaded: %d" % QuestManager.quest_database.size())
	get_tree().quit(0)
