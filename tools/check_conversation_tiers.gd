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


## Per-NPC pools are meant to be droppable into a folder, not listed in code.
func _check_unique_pool_directory_is_read() -> void:
	var files: Array[String] = ConversationSystem._list_unique_pool_files("res://data/conversation_pools/")
	print("  unique/ pool files found: %d" % files.size())
	if not DirAccess.dir_exists_absolute("res://data/conversation_pools/unique/"):
		_failures.append("data/conversation_pools/unique/ does not exist; per-NPC pools have nowhere to go")
