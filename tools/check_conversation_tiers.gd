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
	_check_reaction_pools_registered()
	_check_reactions_only_fire_when_their_state_holds()
	_check_reactions_reach_the_player()
	_check_quest_title_resolves_to_a_real_title()
	_check_computed_flags_answer()
	_check_unreadable_conditions_fail_closed()

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


# =============================================================================
# THE REACTIVE LAYER
# =============================================================================
#
# A reaction is a line an NPC says BECAUSE of something the player did. Two ways
# it fails, and both look fine from the outside:
#
#   - it never fires, because its gate reads a store nobody writes to. The NPC
#     just says something generic and the world appears not to have noticed.
#   - it always fires, because its gate was unreadable and fell through to true.
#     The guard is cold to a player who has committed no crime.
#
# Neither throws. So both are asserted here.


## Find a loaded response by id, across every pool it could have landed in.
func _find_response(response_id: String) -> ConversationResponse:
	for response: ConversationResponse in ConversationSystem.greeting_pool:
		if response.response_id == response_id:
			return response
	for archetype: Variant in ConversationSystem.archetype_pools:
		var by_topic: Dictionary = ConversationSystem.archetype_pools[archetype]
		for topic: Variant in by_topic:
			for response: Variant in by_topic[topic]:
				if response is ConversationResponse and response.response_id == response_id:
					return response
	for topic: Variant in ConversationSystem.response_pools:
		for response: Variant in ConversationSystem.response_pools[topic]:
			if response is ConversationResponse and response.response_id == response_id:
				return response
	return null


## The reaction pools have to have actually loaded, into the archetype tier,
## for more than one archetype. A pool file that failed to parse warns once at
## boot and is then indistinguishable from a game with no reactive layer.
func _check_reaction_pools_registered() -> void:
	var reaction_count: int = 0
	var archetypes_reacting: Dictionary = {}
	for archetype: Variant in ConversationSystem.archetype_pools:
		var by_topic: Dictionary = ConversationSystem.archetype_pools[archetype]
		for topic: Variant in by_topic:
			for response: Variant in by_topic[topic]:
				if response is ConversationResponse and (response as ConversationResponse).response_id.begins_with("reaction_"):
					reaction_count += 1
					archetypes_reacting[archetype] = true

	var greeting_reactions: int = 0
	for response: ConversationResponse in ConversationSystem.greeting_pool:
		if response.response_id.begins_with("greet_reaction_"):
			greeting_reactions += 1

	print("  reaction topic lines: %d across %d archetypes" % [reaction_count, archetypes_reacting.size()])
	print("  reaction greetings:   %d" % greeting_reactions)

	if reaction_count < 100:
		_failures.append("only %d reaction lines registered; data/conversation_pools/reactions.json is not loading" % reaction_count)
	if archetypes_reacting.size() < 5:
		_failures.append("only %d archetypes have reactions; priest/guard/merchant/thief/villager is the minimum" % archetypes_reacting.size())
	if greeting_reactions < 20:
		_failures.append("only %d reaction greetings registered; reaction_greetings.json is not routing into greeting_pool" % greeting_reactions)


## The load-bearing assertion. A gated line must be ineligible with its state
## off and eligible with it on - and the state has to be set the way the GAME
## sets it, through WorldState and CrimeManager, not by writing the flag into
## ConversationSystem's own dictionary where the old evaluator could see it.
func _check_reactions_only_fire_when_their_state_holds() -> void:
	var line: ConversationResponse = _find_response("reaction_guard_bandit_boss_1")
	if line == null:
		_failures.append("reaction_guard_bandit_boss_1 did not load at all")
		return
	if line.conditions.is_empty():
		_failures.append("reaction_guard_bandit_boss_1 loaded with NO conditions - it would be said to everyone")
		return

	var was_boss: bool = WorldState.has_flag(WorldState.FLAG_BANDIT_BOSS)

	WorldState.clear_flag(WorldState.FLAG_BANDIT_BOSS)
	if ConversationSystem._check_conditions(line):
		_failures.append("a bandit-boss reaction is eligible with player_is_bandit_boss CLEAR; the gate is not being read")

	WorldState.set_flag(WorldState.FLAG_BANDIT_BOSS, true)
	if not ConversationSystem._check_conditions(line):
		_failures.append("a bandit-boss reaction is NOT eligible with player_is_bandit_boss SET; has_flag() is not reaching WorldState")

	if not was_boss:
		WorldState.clear_flag(WorldState.FLAG_BANDIT_BOSS)


## End to end: with the state set, a guard must actually SAY one of these, and
## with it clear he must never say one. Conditions being right is not the same
## as selection surfacing them - a reaction that always loses the weighted roll
## is a reaction the player never hears.
func _check_reactions_reach_the_player() -> void:
	const SAMPLES: int = 300
	var was_boss: bool = WorldState.has_flag(WorldState.FLAG_BANDIT_BOSS)

	var npc := Node.new()
	npc.name = "_reaction_check_npc"
	add_child(npc)

	WorldState.set_flag(WorldState.FLAG_BANDIT_BOSS, true)
	var reactions_heard: int = 0
	ConversationSystem.start_conversation(npc, NPCKnowledgeProfile.guard())
	for i in range(SAMPLES):
		var picked: ConversationResponse = ConversationSystem.select_response(ConversationTopic.TopicType.LOCAL_NEWS)
		if picked != null and picked.response_id.begins_with("reaction_"):
			reactions_heard += 1
	ConversationSystem.end_conversation()

	if reactions_heard == 0:
		_failures.append("a guard never once reacted to player_is_bandit_boss in %d draws; the reactive layer is invisible in play" % SAMPLES)

	WorldState.clear_flag(WorldState.FLAG_BANDIT_BOSS)
	var leaked: String = ""
	ConversationSystem.start_conversation(npc, NPCKnowledgeProfile.guard())
	for i in range(SAMPLES):
		var picked: ConversationResponse = ConversationSystem.select_response(ConversationTopic.TopicType.LOCAL_NEWS)
		if picked != null and picked.response_id.begins_with("reaction_guard_bandit_boss"):
			leaked = picked.response_id
			break
	ConversationSystem.end_conversation()

	if not leaked.is_empty():
		_failures.append("'%s' was said to a player who is not a bandit boss" % leaked)

	npc.queue_free()
	if was_boss:
		WorldState.set_flag(WorldState.FLAG_BANDIT_BOSS, true)


## {quest_title} must resolve to a title out of quest data. A line that reaches
## the player with the braces still in it is worse than no reaction at all, and
## a line that names a quest by hand becomes a lie the day the quest is renamed.
func _check_quest_title_resolves_to_a_real_title() -> void:
	var context := ConversationContext.new()
	ConversationSystem._populate_reaction_context(context)

	var spoken: String = context.inject_variables("still talking about {quest_title} down at the docks")
	if spoken.contains("{"):
		_failures.append("{quest_title} was not substituted: '%s'" % spoken)

	var completed: Array = QuestManager.get_completed_quests()
	if completed.is_empty():
		# Nothing finished, so nothing to name - but every line that uses the
		# variable is gated on quests_completed:N, so none of them can be said.
		if ConversationSystem.has_flag("quests_completed:1"):
			_failures.append("quests_completed:1 is true with no completed quests")
		return

	var expected: String = str(completed[completed.size() - 1].title)
	if not spoken.contains(expected):
		_failures.append("{quest_title} resolved to something other than the last completed quest's real title")


## The computed-flag vocabulary is the only way a pool line can ask about crime,
## reputation, guild rank or this speaker in particular. If a prefix stops being
## answered it returns -1, falls through to the flag stores, finds nothing, and
## every line gated on it goes quiet - without a warning.
func _check_computed_flags_answer() -> void:
	const TEST_REGION := "_flag_check_region"

	if ConversationSystem._evaluate_computed_flag("crime:wanted") == -1:
		_failures.append("crime:wanted is not answered as a computed flag")
	if ConversationSystem._evaluate_computed_flag("quests_completed:0") != 1:
		_failures.append("quests_completed:0 should always be true")
	if ConversationSystem._evaluate_computed_flag("rep:town_guard:-999") != 1:
		_failures.append("rep:<faction>:<min> is not answered as a computed flag")
	if ConversationSystem._evaluate_computed_flag("not_a_computed_flag") != -1:
		_failures.append("an unknown prefix must fall through to the real flag stores, not answer")

	var kept_bounties: Dictionary = CrimeManager.bounties.duplicate()
	CrimeManager.bounties.clear()
	if ConversationSystem.has_flag("crime:wanted"):
		_failures.append("crime:wanted is true with no bounty anywhere")
	CrimeManager.set_bounty(TEST_REGION, 250)
	if not ConversationSystem.has_flag("crime:wanted"):
		_failures.append("crime:wanted is false with a 250 bounty standing")
	CrimeManager.bounties = kept_bounties

	# Devotee bonds live on FlagManager. has_flag() reaching them is what lets a
	# priest say "Gaela's own" at all.
	var was_devotee: bool = FlagManager.is_devotee_of("gaela")
	FlagManager.set_flag(FlagManager.FLAG_GAELA_DEVOTEE, true)
	if not ConversationSystem.has_flag("devotee:gaela"):
		_failures.append("devotee:gaela is false while the FlagManager bond is set")
	if not ConversationSystem.has_flag(FlagManager.FLAG_GAELA_DEVOTEE):
		_failures.append("ConversationSystem.has_flag() cannot see FlagManager flags")
	if not was_devotee:
		FlagManager.clear_flag(FlagManager.FLAG_GAELA_DEVOTEE)


## A requirement the loader cannot read must fail closed. It used to fall
## through to NONE - "no condition, always available" - which is how sixty-five
## race- and career-gated lines came to be said to everybody.
func _check_unreadable_conditions_fail_closed() -> void:
	var parsed: DialogueCondition = ConversationSystem._parse_condition({
		"condition_type": "no_such_condition_type", "string_value": "x"
	})
	if parsed.type != DialogueData.ConditionType.INVALID:
		_failures.append("an unknown condition_type name did not become INVALID")
	if ConversationSystem._evaluate_condition(parsed):
		_failures.append("an INVALID condition evaluated TRUE; unreadable requirements are standing open")

	var out_of_range: DialogueCondition = ConversationSystem._parse_condition({"condition_type": 9999})
	if out_of_range.type != DialogueData.ConditionType.INVALID:
		_failures.append("an out-of-range numeric condition_type did not become INVALID")

	var by_name: DialogueCondition = ConversationSystem._parse_condition({
		"condition_type": "player_career", "string_value": "thief"
	})
	if by_name.type != DialogueData.ConditionType.PLAYER_CAREER:
		_failures.append("condition_type names are not being parsed; the pools cannot express a requirement")


## Per-NPC pools are meant to be droppable into a folder, not listed in code.
func _check_unique_pool_directory_is_read() -> void:
	var files: Array[String] = ConversationSystem._list_unique_pool_files("res://data/conversation_pools/")
	print("  unique/ pool files found: %d" % files.size())
	if not DirAccess.dir_exists_absolute("res://data/conversation_pools/unique/"):
		_failures.append("data/conversation_pools/unique/ does not exist; per-NPC pools have nowhere to go")
