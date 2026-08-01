## world_state.gd - Durable facts about the world, and what they change about it.
##
## FlagManager holds the player's paperwork: which deity he swore to, which
## guild rank he holds, which dialogue lines he already tripped. WorldState
## holds facts about the *world* that outlive any one quest - the bandit camp
## is cleared, Kazan-Dun fell, the mountain pass is open - so a quest offered
## later can notice the work is already done and settle itself on the spot.
##
## Every flag set here is mirrored into FlagManager when it is a plain boolean,
## so existing dialogue conditions and quest flag prerequisites can read world
## facts without learning a second vocabulary. The mirror is one-way: writing
## a flag on FlagManager does NOT make it a world fact.
extends Node

## A world fact changed. old_value is null the first time a flag is written.
signal flag_changed(flag: String, old_value: Variant, new_value: Variant)

## A world modification was recorded or withdrawn (terrain, settlement state).
signal world_modification_changed(mod_id: String, data: Dictionary)

# =============================================================================
# KNOWN FLAGS
# =============================================================================
# Flags are free-form strings; these constants exist so the engine and the
# content agree on spelling for the ones systems read directly.

const FLAG_BANDIT_CAMP_CLEARED := "bandit_camp_cleared"
const FLAG_BANDIT_CAMP_JOINED := "bandit_camp_joined"
const FLAG_BANDIT_BOSS := "player_is_bandit_boss"
const FLAG_KAZAN_DUN_HELPED := "kazan_dun_helped"
const FLAG_KAZAN_DUN_FALLEN := "kazan_dun_fallen"
const FLAG_DWARF_KING_RECOVERED := "dwarf_king_body_recovered"
const FLAG_MOUNTAIN_PASS_OPEN := "mountain_pass_open"

## Documented world facts, for tooling and for the codex of what content may
## rely on. Content is free to invent more; these are the ones with meaning
## already wired somewhere in the engine.
const KNOWN_FLAGS: Array[String] = [
	FLAG_BANDIT_CAMP_CLEARED,
	FLAG_BANDIT_CAMP_JOINED,
	FLAG_BANDIT_BOSS,
	FLAG_KAZAN_DUN_HELPED,
	FLAG_KAZAN_DUN_FALLEN,
	FLAG_DWARF_KING_RECOVERED,
	FLAG_MOUNTAIN_PASS_OPEN,
]

# =============================================================================
# STATE
# =============================================================================

## World facts. Values may be bool, int, float or String.
var flags: Dictionary = {}

## Standing changes to the world itself: terrain edits, razed settlements,
## opened passes. mod_id -> Dictionary payload owned by whoever applies it.
var world_modifications: Dictionary = {}


# =============================================================================
# FLAGS
# =============================================================================

## Record a world fact. Passing a bool also mirrors it onto FlagManager.
func set_flag(flag: String, value: Variant = true) -> void:
	if flag.is_empty():
		return

	var old_value: Variant = flags.get(flag, null)
	if old_value == value:
		return

	flags[flag] = value
	_mirror_to_flag_manager(flag, value)
	flag_changed.emit(flag, old_value, value)


## Read a world fact.
func get_flag(flag: String, default_value: Variant = false) -> Variant:
	return flags.get(flag, default_value)


## True when the fact is recorded and truthy. This is the question most
## callers actually mean: "did this happen?"
func has_flag(flag: String) -> bool:
	if not flags.has(flag):
		return false
	var value: Variant = flags[flag]
	if value is bool:
		return value
	if value is int:
		return (value as int) != 0
	if value is float:
		return not is_zero_approx(value as float)
	if value is String:
		return not (value as String).is_empty()
	return value != null


## Forget a world fact entirely.
func clear_flag(flag: String) -> void:
	if not flags.has(flag):
		return
	var old_value: Variant = flags[flag]
	flags.erase(flag)
	_mirror_to_flag_manager(flag, false)
	flag_changed.emit(flag, old_value, null)


## Every recorded fact, copied.
func get_all_flags() -> Dictionary:
	return flags.duplicate()


## Mirror boolean facts onto FlagManager so dialogue and quest prerequisites
## can read them with the vocabulary they already use.
func _mirror_to_flag_manager(flag: String, value: Variant) -> void:
	var flag_mgr: Node = get_node_or_null("/root/FlagManager")
	if flag_mgr == null:
		return
	if value is bool:
		if value:
			flag_mgr.set_flag(flag, true)
		else:
			flag_mgr.clear_flag(flag)


# =============================================================================
# WORLD MODIFICATIONS
# =============================================================================

## Record a standing change to the world. The payload belongs to the system
## that applies it - WorldState only guarantees it survives a save.
func set_world_modification(mod_id: String, data: Dictionary) -> void:
	if mod_id.is_empty():
		return
	world_modifications[mod_id] = data.duplicate(true)
	world_modification_changed.emit(mod_id, world_modifications[mod_id])


## Read one standing change. Empty dictionary when there is none.
func get_world_modification(mod_id: String) -> Dictionary:
	return (world_modifications.get(mod_id, {}) as Dictionary).duplicate(true)


## True when a standing change has been recorded under this id.
func has_world_modification(mod_id: String) -> bool:
	return world_modifications.has(mod_id)


## Withdraw a standing change.
func clear_world_modification(mod_id: String) -> void:
	if not world_modifications.has(mod_id):
		return
	world_modifications.erase(mod_id)
	world_modification_changed.emit(mod_id, {})


## Every standing change, copied.
func get_world_modifications() -> Dictionary:
	return world_modifications.duplicate(true)


# =============================================================================
# CONDITIONS
# =============================================================================

## Evaluate a world condition written in quest JSON.
##
## Shapes, all optional and combinable:
##   {"flag": "bandit_camp_cleared"}                  fact is truthy
##   {"flag": "bandit_camp_state", "equals": "razed"}  fact equals a value
##   {"flag": "bodies_burned", "at_least": 3}          numeric fact >= value
##   {"world_modification": "mountain_pass"}           modification recorded
##   {"all": [cond, cond]}                             every one holds
##   {"any": [cond, cond]}                             at least one holds
##   {"not": cond}                                     the inverse
##
## An empty condition is false: "no condition" must never pre-complete an
## objective by accident.
func evaluate_condition(condition: Dictionary) -> bool:
	if condition.is_empty():
		return false

	if condition.has("not"):
		var inner: Variant = condition["not"]
		if inner is Dictionary:
			return not evaluate_condition(inner as Dictionary)
		return false

	if condition.has("all"):
		var all_list: Variant = condition["all"]
		if not (all_list is Array):
			return false
		for entry: Variant in (all_list as Array):
			if not (entry is Dictionary) or not evaluate_condition(entry as Dictionary):
				return false
		return true

	if condition.has("any"):
		var any_list: Variant = condition["any"]
		if not (any_list is Array):
			return false
		for entry: Variant in (any_list as Array):
			if entry is Dictionary and evaluate_condition(entry as Dictionary):
				return true
		return false

	if condition.has("world_modification"):
		return has_world_modification(str(condition["world_modification"]))

	if condition.has("flag"):
		var flag: String = str(condition["flag"])
		if condition.has("equals"):
			return flags.has(flag) and flags[flag] == condition["equals"]
		if condition.has("at_least"):
			if not flags.has(flag):
				return false
			var value: Variant = flags[flag]
			if not (value is int or value is float):
				return false
			return float(value) >= float(condition["at_least"])
		return has_flag(flag)

	return false


# =============================================================================
# SAVE / LOAD
# =============================================================================

## Serialize for saving.
func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(),
		"world_modifications": world_modifications.duplicate(true)
	}


## Deserialize from a save. Restored flags are mirrored onto FlagManager again
## so the two never disagree after a load.
func from_dict(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate()
	world_modifications = (data.get("world_modifications", {}) as Dictionary).duplicate(true)

	for flag: String in flags:
		_mirror_to_flag_manager(flag, flags[flag])


## Reset for a new game.
func reset_for_new_game() -> void:
	flags.clear()
	world_modifications.clear()
