extends Node
## Serialization field guard, headless.
##
## Usage: godot --headless --path . res://tools/check_serialization.tscn
##
## check_quest_engine.tscn was the only reflection-based field guard in the
## repo and it covered two classes. Batch 2 found four more instances of the
## same bug in four unguarded ones - total_ip_earned, the crime return
## location, the quest timers, the follower's state - all by hand, all after
## they had shipped. This is that guard generalised.
##
## Three things are asserted for every registered class.
##
## 1. COVERAGE. Every field declared in the class's own script either appears
##    in what its serialiser writes, or is named in TRANSIENT with a written
##    reason. "Deliberately not saved" has to be written down, not assumed.
##
## 2. CLASS ROUND TRIP. Every covered field is dirtied from
##    tools/fixtures/serialization_reference.json, serialised, wiped, and
##    deserialised. A key that to_dict writes and from_dict never reads fails
##    here.
##
## 3. PIPELINE ROUND TRIP. The same values go through the real
##    SaveManager.save_game() / load_game() pair, on disk, as JSON. This is the
##    layer that actually broke: CrimeManager, FastTravelManager,
##    TournamentManager, CaveManager and QuestManager all had a correct
##    to_dict that SaveManager either never called or read three keys out of.
##    A guard that only tested the class would have passed on every one of
##    them.
##
## The fixture must carry a value for every non-transient field. A field with
## no value there fails, which is the reminder to write one - the guard can
## only protect fields it knows about.

const FIXTURE_PATH := "res://tools/fixtures/serialization_reference.json"
const TEST_SLOT := 5

## Registered classes.
##
## script       - the file whose own `var` declarations define the field list.
##                Inherited state belongs to the base class's own entry, or to
##                `extra` below when the serialiser really does carry it.
## object       - autoload name, or "" when `build` names a factory instead.
## serialize    - method returning the save dictionary.
## deserialize  - method taking one back.
## alias        - field name -> the key it is written under, where they differ.
## whole        - a field that IS the whole dictionary rather than one key.
## extra        - inherited fields the serialiser carries, checked anyway.
## transient    - field -> why it is deliberately not saved.
## pipeline     - false for classes SaveManager does not own directly.
const REGISTRY: Array[Dictionary] = [
	{
		"name": "GameManager",
		"script": "res://scripts/autoload/game_manager.gd",
		"object": "GameManager",
		"serialize": "to_dict", "deserialize": "from_dict",
		"alias": {
			"_schedules": "schedules",
			"_fired_event_keys": "fired_event_keys",
		},
		"transient": {
			"player_data": "CharacterData, saved and restored by the player block",
			"time_scale": "tuning, authored on the script",
			"current_time_of_day": "derived from game_time every time the clock settles",
			"current_weather": "mirrors WeatherManager, which owns the weather and saves it",
			"is_paused": "a runtime flag; a loaded game starts unpaused",
			"is_in_menu": "a runtime flag; a loaded game starts out of menus",
			"is_in_dialogue": "a runtime flag; a loaded game starts out of dialogue",
			"is_in_combat": "a runtime flag; a loaded game starts out of combat",
			"damage_multiplier": "difficulty tuning, authored on the script",
			"enemy_hp_multiplier": "difficulty tuning, authored on the script",
			"debug_mode": "a developer toggle, never persisted",
			"dev_speed_multiplier": "a developer toggle, never persisted",
			"world_seed": "saved and restored by the world block",
			"_last_absolute_hour": "re-derived from game_time and current_day the moment the clock settles after a load",
		},
	},
	{
		"name": "CrimeManager",
		"script": "res://scripts/autoload/crime_manager.gd",
		"object": "CrimeManager",
		"serialize": "to_dict", "deserialize": "from_dict",
	},
	{
		"name": "FactionManager",
		"script": "res://scripts/autoload/faction_manager.gd",
		"object": "FactionManager",
		"serialize": "to_dict", "deserialize": "from_dict",
		"alias": {
			"player_reputations": "reputations",
			"faction_memberships": "memberships",
			"faction_hostility": "hostility",
		},
		"transient": {
			"factions": "the faction definitions, reloaded from data/factions/*.tres every boot",
		},
	},
	{
		"name": "WorldState",
		"script": "res://scripts/autoload/world_state.gd",
		"object": "WorldState",
		"serialize": "to_dict", "deserialize": "from_dict",
	},
	{
		"name": "FlagManager",
		"script": "res://scripts/autoload/flag_manager.gd",
		"object": "FlagManager",
		"serialize": "to_dict", "deserialize": "from_dict",
	},
	{
		"name": "ConversationSystem",
		"script": "res://scripts/autoload/conversation_system.gd",
		"object": "ConversationSystem",
		"serialize": "to_dict", "deserialize": "from_dict",
		"transient": {
			"is_active": "whether a conversation is open right now",
			"current_context": "the open conversation's context object",
			"current_npc": "a live node reference, freed by the scene change a load performs",
			"conversation_ui": "a live node reference",
			"response_pools": "reloaded from data/conversations on every boot",
			"archetype_pools": "reloaded from data/conversations on every boot",
			"unique_responses": "reloaded from data/conversations on every boot",
			"quest_turnin_responses": "reloaded from data/conversations on every boot",
			"greeting_pool": "reloaded from data/conversations on every boot",
			"farewell_pool": "reloaded from data/conversations on every boot",
			"_tier1_registered": "a load-time count, for the boot report",
			"_tier2_registered": "a load-time count, for the boot report",
			"_tier3_registered": "a load-time count, for the boot report",
			"context_variables": "set per conversation from the NPC being spoken to",
			"is_scripted_mode": "state of the open conversation only",
			"scripted_lines": "state of the open conversation only",
			"scripted_current_index": "state of the open conversation only",
			"scripted_callback": "a Callable into the open scene",
			"scripted_last_choice_index": "state of the open conversation only",
		},
	},
	{
		"name": "WeatherManager",
		"script": "res://scripts/autoload/weather_manager.gd",
		"object": "WeatherManager",
		"serialize": "get_save_data", "deserialize": "load_save_data",
		"alias": {
			"_target_weather": "target_weather",
			"_time_until_change": "time_until_change",
			"_transitioning": "transitioning",
			"_transition_progress": "transition_progress",
		},
		"transient": {
			"_is_outdoor": "derived from the zone the player is standing in",
			"_weather_effects": "a live node reference",
			"min_weather_duration": "tuning, authored on the script",
			"max_weather_duration": "tuning, authored on the script",
			"transition_duration": "tuning, authored on the script",
		},
	},
	{
		"name": "SoulstoneEconomy",
		"script": "res://scripts/autoload/soulstone_economy.gd",
		"object": "SoulstoneEconomy",
		"serialize": "get_save_data", "deserialize": "load_save_data",
	},
	{
		"name": "GuildRankManager",
		"script": "res://scripts/autoload/guild_rank_manager.gd",
		"object": "GuildRankManager",
		"serialize": "to_dict", "deserialize": "from_dict",
		"alias": {
			"guild_quest_counts": "quest_counts",
			"guild_rank_levels": "rank_levels",
		},
	},
	{
		"name": "MoralityManager",
		"script": "res://scripts/autoload/morality_manager.gd",
		"object": "MoralityManager",
		"serialize": "to_dict", "deserialize": "from_dict",
	},
	{
		"name": "CodexManager",
		"script": "res://scripts/autoload/codex_manager.gd",
		"object": "CodexManager",
		"serialize": "to_dict", "deserialize": "from_dict",
		"transient": {
			"all_recipes": "the recipe catalogue, rebuilt from data on every boot",
			"all_lore": "the lore catalogue, rebuilt from data on every boot",
		},
	},
	{
		"name": "JournalManager",
		"script": "res://scripts/autoload/journal_manager.gd",
		"object": "JournalManager",
		"serialize": "to_dict", "deserialize": "from_dict",
	},
	{
		"name": "StatsTracker",
		"script": "res://scripts/autoload/stats_tracker.gd",
		"object": "StatsTracker",
		"serialize": "to_dict", "deserialize": "from_dict",
		"whole": "stats",
		# from_dict only copies keys that are already in `stats`, so the field
		# has to be reset to its default key set rather than emptied.
		"blank_method": "reset",
	},
	{
		"name": "FastTravelManager",
		"script": "res://scripts/autoload/fast_travel_manager.gd",
		"object": "FastTravelManager",
		"serialize": "to_dict", "deserialize": "from_dict",
	},
	{
		"name": "TournamentManager",
		"script": "res://scripts/autoload/tournament_manager.gd",
		"object": "TournamentManager",
		"serialize": "get_save_data", "deserialize": "load_save_data",
		"transient": {
			"_enemy_base_script": "a preloaded GDScript, resolved on first use",
			"current_wave_enemies": "live node references, freed by the scene change a load performs",
		},
		# load_save_data deliberately ends an interrupted tournament, so the
		# three fields that describe one cannot round-trip by design.
		"skip_round_trip": ["is_tournament_active", "current_wave", "is_equipment_locked"],
	},
	{
		"name": "CaveManager",
		"script": "res://scripts/autoload/cave_manager.gd",
		"object": "CaveManager",
		"serialize": "get_save_data", "deserialize": "load_save_data",
		"transient": {
			"active_cave_id": "set when a cave scene registers itself",
			"cave_root": "a live node reference",
			"area_data": "rebuilt from the cave model's CaveArea_* markers on registration",
			"current_area_id": "recomputed from the player's position",
			"_area_enemies": "live node references",
			"_active_enemy_count": "recounted as enemies spawn",
			"_nav_markers": "live node references",
			"_area_check_timer": "a frame timer",
		},
	},
	{
		"name": "CharacterData",
		"script": "res://scripts/data/character_data.gd",
		"object": "",
		"build": "character_data",
		"serialize": "_collect_player_data", "deserialize": "_apply_player_data",
		"transient": {
			"morality_score": "MoralityManager owns the player's morality and saves it",
			"faction_reputations": "FactionManager owns reputation and saves it",
			"faction_memberships": "FactionManager owns membership and saves it",
			"dot_tick_timers": "sub-second damage-over-time tick timers",
		},
	},
	{
		"name": "FollowerNPC",
		"script": "res://scripts/npcs/follower_npc.gd",
		"object": "",
		"build": "follower",
		"serialize": "get_save_data", "deserialize": "load_save_data",
		"pipeline": false,
		"alias": {"current_state": "state"},
		"extra": ["current_health", "max_health"],
		"transient": {
			"follow_distance": "tuning, set from the follower definition on spawn",
			"combat_range": "tuning, set from the follower definition on spawn",
			"leash_range": "tuning, set from the follower definition on spawn",
			"attack_cooldown_time": "tuning, set from the follower definition on spawn",
			"_idle_line_timer": "a frame timer",
			"_next_idle_line_time": "a frame timer",
			"_player": "a live node reference, re-found after a load",
			"_current_target": "a live node reference; combat does not resume across a load",
			"_navigation_agent": "a child node, rebuilt on spawn",
			"_attack_cooldown": "a frame timer",
			"_is_attacking": "mid-swing state",
			"_has_spoken_combat_line": "resets with the fight",
			"_leash_check_timer": "a frame timer",
			"_unconscious_timer": "restarted on load - see load_save_data",
		},
	},
]

var _failures: Array[String] = []
var _checks: int = 0
var _fixture: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	_fixture = _load_fixture()
	if _fixture.is_empty():
		_fail("fixture would not load: %s" % FIXTURE_PATH)
		_finish()
		return

	GameManager.reset_for_new_game()
	GameManager.create_new_character("Serial", Enums.Race.HUMAN, Enums.Career.SOLDIER)

	for entry: Dictionary in REGISTRY:
		_check_coverage(entry)
		_check_class_round_trip(entry)

	_check_pipeline_round_trip()
	_check_version_agreement()
	_finish()


func _finish() -> void:
	print("")
	print("Checks run: %d" % _checks)
	if _failures.is_empty():
		print("Serialization check: PASS")
		get_tree().quit(0)
		return
	print("Serialization check: FAIL (%d)" % _failures.size())
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
# 1. COVERAGE
# =============================================================================

func _check_coverage(entry: Dictionary) -> void:
	var name: String = entry["name"]
	var obj: Object = _resolve(entry)
	if obj == null:
		_fail("%s: could not resolve the object to check" % name)
		return

	var written: Dictionary = _serialize(entry, obj)
	var transient: Dictionary = entry.get("transient", {})
	var alias: Dictionary = entry.get("alias", {})
	var whole: String = entry.get("whole", "")
	var fixture_fields: Dictionary = _fixture.get(name, {})

	for field: String in _declared_fields(entry):
		if field.begins_with("_README"):
			continue
		if transient.has(field):
			_expect(
				not String(transient[field]).is_empty(),
				"%s.%s is declared transient with no reason" % [name, field]
			)
			continue

		if field != whole:
			var key: String = alias.get(field, field)
			_expect(
				written.has(key),
				"%s.%s is neither written by %s (as '%s') nor declared transient with a reason" % [
					name, field, entry["serialize"], key
				]
			)

		_expect(
			fixture_fields.has(field),
			"%s.%s has no value in %s - the guard cannot prove it survives" % [
				name, field, FIXTURE_PATH
			]
		)


# =============================================================================
# 2. CLASS ROUND TRIP
# =============================================================================

func _check_class_round_trip(entry: Dictionary) -> void:
	var name: String = entry["name"]
	var fields: Dictionary = _fixture.get(name, {})
	if fields.is_empty():
		return

	var obj: Object = _resolve(entry)
	if obj == null:
		return

	var skip: Array = entry.get("skip_round_trip", [])
	var applied: Dictionary = _dirty(obj, fields, skip)

	var wire: Variant = JSON.parse_string(JSON.stringify(_serialize(entry, obj)))
	if not (wire is Dictionary):
		_fail("%s: %s did not survive JSON" % [name, entry["serialize"]])
		return

	# A second, clean object proves from_dict really reads the key rather than
	# leaving whatever happened to be in the field already.
	var fresh: Object = _resolve(entry, true)
	if fresh == null:
		return
	_blank_fields(entry, fresh, applied)
	_deserialize(entry, fresh, wire as Dictionary)

	var whole: String = entry.get("whole", "")
	for field: String in applied:
		_expect(
			_returned(applied[field], fresh.get(field), field == whole),
			"%s.%s did not survive %s -> %s (set %s, got %s)" % [
				name, field, entry["serialize"], entry["deserialize"],
				var_to_str(applied[field]), var_to_str(fresh.get(field))
			]
		)


# =============================================================================
# 3. PIPELINE ROUND TRIP
# =============================================================================

## The real thing: SaveManager.save_game() to disk, wipe, load_game() back.
func _check_pipeline_round_trip() -> void:
	var applied: Dictionary = {}  # entry name -> {field: value}

	for entry: Dictionary in REGISTRY:
		if not entry.get("pipeline", true):
			continue
		var obj: Object = _resolve(entry)
		if obj == null:
			continue
		applied[entry["name"]] = _dirty(
			obj, _fixture.get(entry["name"], {}), entry.get("skip_round_trip", [])
		)

	var saved: bool = SaveManager.save_game(TEST_SLOT)
	_expect(saved, "the pipeline check could not write a save")
	if not saved:
		return

	# Wipe every field, so anything that comes back came back off the disk.
	for entry: Dictionary in REGISTRY:
		if not applied.has(entry["name"]):
			continue
		_blank_fields(entry, _resolve(entry), applied[entry["name"]])

	var loaded: bool = SaveManager.load_game(TEST_SLOT)
	_expect(loaded, "the pipeline check could not read the save back")
	if not loaded:
		return

	for entry: Dictionary in REGISTRY:
		if not applied.has(entry["name"]):
			continue
		var obj: Object = _resolve(entry)
		var values: Dictionary = applied[entry["name"]]
		var whole_field: String = entry.get("whole", "")
		for field: String in values:
			_expect(
				_returned(values[field], obj.get(field), field == whole_field),
				"%s.%s was dropped by SaveManager save/load (set %s, got %s)" % [
					entry["name"], field, var_to_str(values[field]), var_to_str(obj.get(field))
				]
			)

	SaveManager.delete_save(TEST_SLOT)


## SaveManager used to keep its own copy of the format version and it drifted
## three versions from SaveData's, which left a live migration block that could
## never run. One number, one place.
func _check_version_agreement() -> void:
	_expect(
		SaveManager.SAVE_VERSION == SaveData.SAVE_VERSION,
		"SaveManager.SAVE_VERSION (%d) and SaveData.SAVE_VERSION (%d) disagree" % [
			SaveManager.SAVE_VERSION, SaveData.SAVE_VERSION
		]
	)

	# The instance is fixed; this closes the class. load_game() only migrates
	# `if version < SAVE_VERSION`, so a migration block whose target sits above
	# SAVE_VERSION can never run, and one that stops short of it leaves the
	# newest saves half-migrated. The ladder must end exactly at the constant.
	var source: String = _read_text("res://scripts/autoload/save_manager.gd")
	var re := RegEx.new()
	re.compile("migrated\\[\"version\"\\]\\s*=\\s*(\\d+)")
	var targets: Array[int] = []
	for m: RegExMatch in re.search_all(source):
		targets.append(int(m.get_string(1)))

	_expect(not targets.is_empty(), "no migration blocks found in save_manager.gd - has _migrate_save_data moved?")
	if targets.is_empty():
		return

	var highest: int = targets.max()
	_expect(
		highest == SaveManager.SAVE_VERSION,
		"the migration ladder ends at version %d but SAVE_VERSION is %d - %s" % [
			highest, SaveManager.SAVE_VERSION,
			"blocks above the constant can never run" if highest > SaveManager.SAVE_VERSION
				else "the newest format has no migration into it"
		]
	)

	# And no rung may be missing, or a save two versions old stalls.
	for step: int in range(1, SaveManager.SAVE_VERSION + 1):
		_expect(targets.has(step), "no migration block produces save version %d - the ladder has a missing rung" % step)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


# =============================================================================
# PLUMBING
# =============================================================================

## Fields declared by the class's own script, in file order.
func _declared_fields(entry: Dictionary) -> Array[String]:
	var fields: Array[String] = []
	var file := FileAccess.open(entry["script"], FileAccess.READ)
	if file == null:
		_fail("%s: could not read %s" % [entry["name"], entry["script"]])
		return fields

	var pattern := RegEx.new()
	pattern.compile("^(?:@export[a-z_]*(?:\\([^)]*\\))?\\s+)?var\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for line: String in file.get_as_text().split("\n"):
		var found: RegExMatch = pattern.search(line)
		if found != null:
			fields.append(found.get_string(1))
	file.close()

	for extra: Variant in entry.get("extra", []):
		fields.append(String(extra))
	return fields


func _resolve(entry: Dictionary, fresh: bool = false) -> Object:
	var autoload_name: String = entry.get("object", "")
	if not autoload_name.is_empty():
		# Autoloads are singletons; there is no second instance to build, so the
		# "fresh" object is the same one. Wiping the fields before deserialising
		# gives the same proof.
		return get_node_or_null("/root/%s" % autoload_name)

	match String(entry.get("build", "")):
		"character_data":
			if fresh:
				GameManager.player_data = CharacterData.new()
			return GameManager.player_data
		"follower":
			var follower := FollowerNPC.new()
			add_child(follower)
			return follower
		_:
			return null


func _serialize(entry: Dictionary, obj: Object) -> Dictionary:
	# CharacterData has no serialiser of its own - SaveManager copies it field
	# by field by hand, which is exactly how total_ip_earned went missing. The
	# hand-copy is therefore what gets guarded.
	if String(entry.get("build", "")) == "character_data":
		var player_save = SaveData.PlayerSaveData.new()
		SaveManager._collect_player_data(player_save)
		return player_save.to_dict()

	var out: Variant = obj.call(entry["serialize"])
	return out as Dictionary if out is Dictionary else {}


func _deserialize(entry: Dictionary, obj: Object, data: Dictionary) -> void:
	if String(entry.get("build", "")) == "character_data":
		var player_save = SaveData.PlayerSaveData.new()
		player_save.from_dict(data)
		SaveManager._apply_player_data(player_save)
		return
	obj.call(entry["deserialize"], data)


func _load_fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


## JSON has no Vector3, so the fixture spells one as {"__vec3": [x, y, z]}.
func _decode(value: Variant) -> Variant:
	if value is Dictionary and (value as Dictionary).has("__vec3"):
		var parts: Array = (value as Dictionary)["__vec3"]
		return Vector3(parts[0], parts[1], parts[2])
	if value is Dictionary and (value as Dictionary).has("__vec2i"):
		var pair: Array = (value as Dictionary)["__vec2i"]
		return Vector2i(int(pair[0]), int(pair[1]))
	return value


## Write the fixture values onto an object, and report what was written.
func _dirty(obj: Object, fields: Dictionary, skip: Array) -> Dictionary:
	var applied: Dictionary = {}
	for field: String in fields:
		if field.begins_with("_README") or field in skip:
			continue
		var value: Variant = _coerce(fields[field], obj.get(field))
		obj.set(field, value)
		applied[field] = value
	return applied


## Empty the fields, so anything that comes back came back from the save.
func _blank_fields(entry: Dictionary, obj: Object, applied: Dictionary) -> void:
	if obj == null:
		return
	var blank_method: String = entry.get("blank_method", "")
	if not blank_method.is_empty() and obj.has_method(blank_method):
		obj.call(blank_method)
		return
	for field: String in applied:
		obj.set(field, _blank(applied[field]))


## A fixture value in the field's own type. Typed arrays keep their element
## type by being rebuilt from a duplicate of what is already in the field -
## assigning a plain Array into an Array[String] is an error, not a test.
func _coerce(value: Variant, template: Variant) -> Variant:
	if value is Array and template is Array:
		var out: Array = (template as Array).duplicate()
		out.clear()
		for element: Variant in (value as Array):
			out.append(_decode(element))
		return out
	return _decode(value)


## A value of the same type that is obviously not the fixture value.
func _blank(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY: return {}
		TYPE_ARRAY:
			var empty: Array = (value as Array).duplicate()
			empty.clear()
			return empty
		TYPE_STRING: return ""
		TYPE_INT: return 0
		TYPE_FLOAT: return 0.0
		TYPE_BOOL: return not bool(value)
		TYPE_VECTOR3: return Vector3.ZERO
		_: return null


## Did the value come back?
##
## Dictionaries are compared by containment: every entry that was written must
## come back, and the manager is allowed to have seeded its own defaults
## alongside. Several of them legitimately do - FactionManager knows every
## faction in data/, GuildRankManager knows every guild, CodexManager knows
## every category - and FlagManager picks up entries mirrored onto it by
## WorldState and the rank system. Containment still catches the thing this
## guard is for: a dropped field has no entry at all, and a dropped entry
## inside a carried field is missing by name.
func _returned(expected: Variant, actual: Variant, _whole: bool) -> bool:
	if expected is Dictionary and actual is Dictionary:
		for key: Variant in (expected as Dictionary):
			if not (actual as Dictionary).has(key):
				return false
			if not _same((expected as Dictionary)[key], (actual as Dictionary)[key]):
				return false
		return true
	return _same(expected, actual)


## Equality that tolerates the wire format. JSON has one number type, so an int
## that comes back as a float travelled correctly and is not a dropped field.
func _same(a: Variant, b: Variant) -> bool:
	if a is float or a is int:
		return (b is float or b is int) and is_equal_approx(float(a), float(b))
	if a is Dictionary or a is Array:
		if var_to_str(a) == var_to_str(b):
			return true
		return var_to_str(_normalise(a)) == var_to_str(_normalise(b))
	return a == b


func _normalise(value: Variant) -> Variant:
	var wire: Variant = JSON.parse_string(JSON.stringify(value))
	return wire if wire != null else value
