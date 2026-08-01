extends Node
## Three-tier conversation check.
##
## Usage: godot --headless --path . res://tools/check_conversation_tiers.tscn
##
## The three-tier system (unique NPC -> archetype -> generic) fails silently when
## it fails at all: a tier that registers nothing just falls through to generic,
## and a generic answer still looks like a conversation. It only reads as
## "every NPC in this town says the same thing", which is exactly the complaint
## the alpha came back with and exactly the thing no crash report will ever show.
##
## So this asserts the tiers are actually populated and actually preferred.

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	print("")
	print("Responses registered by tier:")
	print("  tier 1 (unique NPC): %d" % ConversationSystem._tier1_registered)
	print("  tier 2 (archetype):  %d" % ConversationSystem._tier2_registered)
	print("  tier 3 (generic):    %d" % ConversationSystem._tier3_registered)

	_check_tier2_populated()
	_check_speaker_scoped_pools_are_gated()
	_check_unique_tier_wins()
	_check_unique_pool_directory_is_read()
	_check_memory_survives_a_save()
	_check_repeats_are_avoided()

	print("")
	if _failures.is_empty():
		print("Conversation tier check: OK")
	else:
		print("Conversation tier check: %d FAILED" % _failures.size())
		for line: String in _failures:
			print("  - " + line)

	get_tree().quit(0 if _failures.is_empty() else 1)


## Tier 2 must hold content from more than one pool file. When only career_topics
## reached it, twenty-seven lines carried the entire archetype dimension.
func _check_tier2_populated() -> void:
	if ConversationSystem._tier2_registered < 60:
		_failures.append("tier 2 holds only %d responses; the speaker-scoped pools are not routing" % ConversationSystem._tier2_registered)

	var archetypes_served: int = ConversationSystem.archetype_pools.size()
	if archetypes_served < 6:
		_failures.append("only %d archetypes have their own responses" % archetypes_served)


## A priest's line about his own faith must not be reachable from the generic pool,
## where any farmer could draw it.
func _check_speaker_scoped_pools_are_gated() -> void:
	for topic_type: Variant in ConversationSystem.response_pools:
		var candidates: Array = ConversationSystem.response_pools[topic_type]
		for response: Variant in candidates:
			if not response is ConversationResponse:
				continue
			var resp: ConversationResponse = response
			if resp.response_id.begins_with("personal_priest_"):
				_failures.append("'%s' is still in the generic pool" % resp.response_id)
				return


## The whole point of tier 1: when a named NPC has his own words for a topic, he
## uses them instead of his trade's stock answer.
func _check_unique_tier_wins() -> void:
	const TEST_NPC_ID := "_tier_check_npc"
	const TEST_RESPONSE_ID := "_tier_check_unique"

	var unique := ConversationResponse.new()
	unique.response_id = TEST_RESPONSE_ID
	unique.text = "Only I say this."
	unique.topic_type = ConversationTopic.TopicType.PERSONAL
	ConversationSystem.register_unique_response(TEST_NPC_ID, ConversationTopic.TopicType.PERSONAL, unique)

	if not ConversationSystem.unique_responses.has(TEST_NPC_ID):
		_failures.append("register_unique_response() did not populate unique_responses")
		return

	var npc := Node.new()
	npc.name = TEST_NPC_ID
	add_child(npc)

	var profile := NPCKnowledgeProfile.priest()
	ConversationSystem.start_conversation(npc, profile)
	var chosen: ConversationResponse = ConversationSystem.select_response(ConversationTopic.TopicType.PERSONAL)
	ConversationSystem.end_conversation()

	if chosen == null or chosen.response_id != TEST_RESPONSE_ID:
		var got: String = "null" if chosen == null else chosen.response_id
		_failures.append("tier 1 did not win over tier 2/3 (got '%s')" % got)

	ConversationSystem.unique_responses.erase(TEST_NPC_ID)
	npc.queue_free()


## Anti-repeat is only as persistent as the save file. Every field the filter
## reads has to survive the round trip through SaveData, or NPCs start repeating
## themselves the moment the player reloads.
func _check_memory_survives_a_save() -> void:
	var kept_memory: Dictionary = ConversationSystem.npc_memory.duplicate()
	var kept_counts: Dictionary = ConversationSystem.npc_memory_heard_count.duplicate()
	var kept_topics: Array[String] = ConversationSystem.player_known_topics.duplicate()

	ConversationSystem.npc_memory = {"_save_check_npc:_save_check_line": "said once"}
	ConversationSystem.npc_memory_heard_count = {"_save_check_npc:_save_check_line": 4}
	ConversationSystem.player_known_topics = ["_save_check_topic"]

	var save_block := SaveData.ConversationSaveData.new()
	var live: Dictionary = ConversationSystem.to_dict()
	save_block.npc_memory = live.get("npc_memory", {})
	save_block.npc_memory_heard_count = live.get("npc_memory_heard_count", {})
	save_block.conversation_flags = live.get("conversation_flags", {})
	save_block.player_known_topics = live.get("player_known_topics", [])

	# Through the on-disk shape and back, the way a real save/load goes
	var reloaded := SaveData.ConversationSaveData.new()
	reloaded.from_dict(save_block.to_dict())

	ConversationSystem.npc_memory = {}
	ConversationSystem.npc_memory_heard_count = {}
	ConversationSystem.player_known_topics = []
	ConversationSystem.from_dict({
		"npc_memory": reloaded.npc_memory,
		"npc_memory_heard_count": reloaded.npc_memory_heard_count,
		"conversation_flags": reloaded.conversation_flags,
		"player_known_topics": reloaded.player_known_topics,
	})

	if not ConversationSystem.npc_memory.has("_save_check_npc:_save_check_line"):
		_failures.append("npc_memory did not survive the save round trip")
	if ConversationSystem.npc_memory_heard_count.get("_save_check_npc:_save_check_line", 0) != 4:
		_failures.append("npc_memory_heard_count did not survive the save round trip")
	if "_save_check_topic" not in ConversationSystem.player_known_topics:
		_failures.append("player_known_topics did not survive the save round trip")

	ConversationSystem.npc_memory = kept_memory
	ConversationSystem.npc_memory_heard_count = kept_counts
	ConversationSystem.player_known_topics = kept_topics


## The point of all of it: ask the same NPC the same thing twice and get two
## different answers, including across a reload.
func _check_repeats_are_avoided() -> void:
	const TEST_NPC_ID := "_repeat_check_npc"

	var kept_memory: Dictionary = ConversationSystem.npc_memory.duplicate()
	var kept_counts: Dictionary = ConversationSystem.npc_memory_heard_count.duplicate()

	var npc := Node.new()
	npc.name = TEST_NPC_ID
	add_child(npc)

	ConversationSystem.start_conversation(npc, NPCKnowledgeProfile.guard())
	var first: ConversationResponse = ConversationSystem.select_response(ConversationTopic.TopicType.PERSONAL)
	ConversationSystem.end_conversation()

	if first == null:
		_failures.append("no PERSONAL response at all for a guard")
	else:
		# Pretend a whole past session happened and he already said that line
		ConversationSystem.npc_memory[TEST_NPC_ID + ":" + first.response_id] = first.text
		ConversationSystem.npc_memory_heard_count[TEST_NPC_ID + ":" + first.response_id] = 1

		ConversationSystem.start_conversation(npc, NPCKnowledgeProfile.guard())
		var second: ConversationResponse = ConversationSystem.select_response(ConversationTopic.TopicType.PERSONAL)
		ConversationSystem.end_conversation()

		if second != null and second.response_id == first.response_id:
			_failures.append("NPC repeated '%s' though npc_memory says he already said it" % first.response_id)

	npc.queue_free()
	ConversationSystem.npc_memory = kept_memory
	ConversationSystem.npc_memory_heard_count = kept_counts


## Per-NPC pools are meant to be droppable into a folder, not listed in code.
func _check_unique_pool_directory_is_read() -> void:
	var files: Array[String] = ConversationSystem._list_unique_pool_files("res://data/conversation_pools/")
	print("  unique/ pool files found: %d" % files.size())
	if not DirAccess.dir_exists_absolute("res://data/conversation_pools/unique/"):
		_failures.append("data/conversation_pools/unique/ does not exist; per-NPC pools have nowhere to go")
