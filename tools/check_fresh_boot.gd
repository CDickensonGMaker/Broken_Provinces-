extends Node
## Fresh-player smoke pass, headless.
##
## Usage: godot --headless --path . res://tools/check_fresh_boot.tscn
##
## Dev saves lie. Every other check in tools/ starts from state some earlier
## step already built; this one starts from nothing and walks the path a person
## who just bought the game walks:
##
##   new character -> Elder Moor loads -> the player is in it -> a quest can be
##   offered and accepted -> save -> change everything -> load -> everything is
##   back.
##
## The load half is the point. A save that writes cleanly and restores nothing
## looks identical to a working one from inside the game, so the check dirties
## gold, inventory, quest state and world flags between the save and the load
## and demands each of them come back.

## Where character creation sends a new character (character_creation.gd:452).
const START_SCENE := "res://scenes/levels/elder_moor.tscn"

## A slot well clear of anything a human would use.
const TEST_SLOT := 7

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	await _run()
	_finish()


func _run() -> void:
	_new_character()
	await _boot_start_scene()
	var quest_id: String = _quest_offer()
	await _save_load_round_trip(quest_id)


## A new character, exactly as the main menu builds one.
##
## The flags and world facts set here stand in for the previous playthrough:
## a guild rank, a deity devotion, a world fact. A new character must not
## inherit any of them, and until 8/1 he inherited all of the FlagManager ones,
## because reset_world_state() cleared eleven systems and not that one.
func _new_character() -> void:
	FlagManager.set_flag(FlagManager.FLAG_THIEVES_MASTER_THIEF, true)
	FlagManager.set_flag(FlagManager.FLAG_GAELA_DEVOTEE, true)
	FlagManager.set_context_variable("merchant_id", "last_run_smith")
	WorldState.set_flag("last_run_fact", true)
	# The rank flags above are only the gate. The ladder itself lives on
	# GuildRankManager, whose reset_for_new_game() had zero callers.
	GuildRankManager.guild_rank_levels["thieves_guild"] = 4
	GuildRankManager.guild_quest_counts["thieves_guild"] = 12
	GuildRankManager.grant_title("Last Run's Hand")

	GameManager.reset_for_new_game()
	InventoryManager.clear_inventory_state()
	QuestManager.reset_for_new_game()
	SaveManager.reset_world_state()
	GameManager.create_new_character("Smoke", Enums.Race.HUMAN, Enums.Career.SOLDIER)

	_check("a new character does not inherit the last run's guild rank",
		not FlagManager.has_flag(FlagManager.FLAG_THIEVES_MASTER_THIEF))
	_check("a new character does not inherit the last run's devotion",
		FlagManager.get_devoted_deity().is_empty())
	_check("a new character does not inherit the last run's flag context",
		FlagManager.get_context_variables().is_empty())
	_check("a new character does not inherit the last run's world facts",
		not WorldState.has_flag("last_run_fact"))
	_check("a new character does not inherit the last run's guild rank level",
		GuildRankManager.get_guild_rank_level("thieves_guild") == -1)
	_check("a new character does not inherit the last run's guild quest count",
		GuildRankManager.get_guild_quest_count("thieves_guild") == 0)
	_check("a new character does not inherit the last run's titles",
		GuildRankManager.get_titles().is_empty())

	_check("character exists", GameManager.player_data != null)
	if GameManager.player_data == null:
		return
	_check("character starts alive", GameManager.player_data.current_hp > 0)
	_check("character starts at level 1", GameManager.player_data.level == 1)
	# The values step 25 confirmed: the purse is the career's, XP starts at zero.
	_check("improvement points start at 0", GameManager.player_data.improvement_points == 0)
	_check("purse starts empty before career grant", InventoryManager.gold == 0)

	# Character creation grants the career purse; a soldier's is the base 10.
	InventoryManager.add_gold(10)


## Elder Moor loads, and the player is actually standing in it.
func _boot_start_scene() -> void:
	if not ResourceLoader.exists(START_SCENE):
		_check("start scene exists", false)
		return

	var packed: PackedScene = load(START_SCENE)
	if packed == null:
		_check("start scene loads", false)
		return
	_check("start scene loads", true)

	var level: Node = packed.instantiate()
	add_child(level)
	# Two frames: _ready runs on the first, deferred spawn work on the second.
	await get_tree().process_frame
	await get_tree().process_frame

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	_check("player is in the start scene", players.size() > 0)

	if players.size() > 0:
		var player: Node3D = players[0] as Node3D
		if player != null:
			# A player at exactly the origin usually means the spawn point was
			# never found and the node was left where it was instanced.
			_check("player is not stranded at the origin",
				player.global_position.length() > 0.01)

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame


## A quest can be offered and accepted from a standing start.
func _quest_offer() -> String:
	var available: Array[String] = QuestManager.get_available_quests()
	_check("a fresh character is offered at least one quest", available.size() > 0)
	if available.is_empty():
		return ""

	var quest_id: String = available[0]
	var started: bool = QuestManager.start_quest(quest_id)
	_check("the offered quest can be accepted (%s)" % quest_id, started)
	if not started:
		return ""

	_check("the accepted quest is active",
		QuestManager.is_quest_active(quest_id))
	return quest_id


## Save, dirty everything, load, and demand it all come back.
func _save_load_round_trip(quest_id: String) -> void:
	InventoryManager.add_gold(137)
	InventoryManager.add_item("bread", 3)
	FlagManager.set_flag("smoke_check_flag", true)
	WorldState.set_flag("smoke_check_fact", true)

	var want_gold: int = InventoryManager.gold
	var want_bread: int = InventoryManager.get_item_count("bread")

	var saved: bool = SaveManager.save_game(TEST_SLOT)
	_check("save writes", saved)
	if not saved:
		return

	# Everything the load must undo.
	InventoryManager.remove_gold(InventoryManager.gold)
	InventoryManager.remove_item("bread", want_bread)
	FlagManager.set_flag("smoke_check_flag", false)
	WorldState.clear_flag("smoke_check_fact")
	if quest_id != "":
		QuestManager.reset_for_new_game()

	_check("the dirty state really is dirty", InventoryManager.gold != want_gold)

	var loaded: bool = SaveManager.load_game(TEST_SLOT)
	_check("load reads", loaded)
	if not loaded:
		return
	await get_tree().process_frame

	_check("gold survives the round trip (%d)" % want_gold,
		InventoryManager.gold == want_gold)
	_check("inventory survives the round trip",
		InventoryManager.get_item_count("bread") == want_bread)
	_check("flags survive the round trip",
		FlagManager.get_flag("smoke_check_flag") == true)
	_check("world facts survive the round trip",
		WorldState.has_flag("smoke_check_fact"))
	if quest_id != "":
		_check("the active quest survives the round trip (%s)" % quest_id,
			QuestManager.is_quest_active(quest_id))

	SaveManager.delete_save(TEST_SLOT)


func _check(what: String, passed: bool) -> void:
	_checks += 1
	if passed:
		print("  ok    %s" % what)
	else:
		_failures += 1
		printerr("  FAIL  %s" % what)


func _finish() -> void:
	print("")
	if _failures > 0:
		print("FAIL: %d of %d fresh-boot checks failed" % [_failures, _checks])
		get_tree().quit(1)
		return
	print("OK: %d fresh-boot checks pass" % _checks)
	get_tree().quit(0)
