## faction_manager.gd - Manages faction relationships and player reputation
## Autoload singleton implementing Daggerfall-style faction cascading
extends Node

## Signals
signal reputation_changed(faction_id: String, old_rep: int, new_rep: int)
signal faction_status_changed(faction_id: String, old_status: int, new_status: int)
signal joined_faction(faction_id: String, rank_name: String)
signal left_faction(faction_id: String)
signal rank_changed(faction_id: String, old_rank: String, new_rank: String)

## All loaded faction data (faction_id -> FactionData)
var factions: Dictionary = {}

## Player reputation per faction (faction_id -> reputation int)
var player_reputations: Dictionary = {}

## Faction memberships (faction_id -> {rank: String, joined_time: float})
var faction_memberships: Dictionary = {}

## Cascade multipliers for reputation changes
const ALLY_CASCADE_MULT: float = 0.25      # Allies get 25% of rep change
const ENEMY_CASCADE_MULT: float = -0.5     # Enemies get -50% of rep change (opposite)
const PARENT_CASCADE_MULT: float = 0.5     # Parent faction gets 50% of rep change
const CHILD_CASCADE_MULT: float = 0.25     # Child factions get 25% of parent change

## Reputation bounds
const MIN_REPUTATION: int = -100
const MAX_REPUTATION: int = 100

## Path to faction data files
const FACTIONS_PATH: String = "res://data/factions/"

func _ready() -> void:
	_load_all_factions()
	_initialize_player_reputations()

## Load all faction data files from the factions directory
func _load_all_factions() -> void:
	var dir := DirAccess.open(FACTIONS_PATH)
	if not dir:
		push_warning("[FactionManager] Could not open factions directory: %s" % FACTIONS_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := FACTIONS_PATH + file_name
			var faction: FactionData = load(path) as FactionData
			if faction and not faction.id.is_empty():
				factions[faction.id] = faction
				print("[FactionManager] Loaded faction: %s" % faction.id)
		file_name = dir.get_next()

	dir.list_dir_end()
	print("[FactionManager] Loaded %d factions" % factions.size())

## Initialize player reputations from faction defaults or player data
func _initialize_player_reputations() -> void:
	# Start with default reputations from faction data
	for faction_id: String in factions:
		var faction: FactionData = factions[faction_id]
		if not player_reputations.has(faction_id):
			player_reputations[faction_id] = faction.default_reputation

	# Override with player data if available
	if GameManager.player_data:
		for faction_id: String in GameManager.player_data.faction_reputations:
			player_reputations[faction_id] = GameManager.player_data.faction_reputations[faction_id]

		for faction_id: String in GameManager.player_data.faction_memberships:
			faction_memberships[faction_id] = GameManager.player_data.faction_memberships[faction_id]

## Get a faction by ID
func get_faction(faction_id: String) -> FactionData:
	return factions.get(faction_id, null)

## Get player's reputation with a faction
func get_reputation(faction_id: String) -> int:
	return player_reputations.get(faction_id, 0)

## Get reputation status for a faction
func get_reputation_status(faction_id: String) -> FactionData.ReputationStatus:
	var rep: int = get_reputation(faction_id)
	return FactionData.get_reputation_status(rep)

## Get status name for a faction
func get_status_name(faction_id: String) -> String:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	return FactionData.get_status_name(status)

## Get relationship between two factions
## Returns: "allied", "enemy", "neutral", or "self"
func get_relationship(faction_a: String, faction_b: String) -> String:
	if faction_a == faction_b:
		return "self"

	var faction: FactionData = get_faction(faction_a)
	if not faction:
		return "neutral"

	if faction_b in faction.allies:
		return "allied"
	elif faction_b in faction.enemies:
		return "enemy"
	else:
		return "neutral"

## Modify player reputation with a faction (with cascading)
func modify_reputation(faction_id: String, amount: int, reason: String = "", cascade: bool = true) -> void:
	if not factions.has(faction_id):
		push_warning("[FactionManager] Unknown faction: %s" % faction_id)
		return

	# Apply main reputation change
	_apply_reputation_change(faction_id, amount, reason)

	# Apply cascading effects
	if cascade:
		_cascade_reputation(faction_id, amount)

	# Sync with player data
	_sync_to_player_data()

## Apply a reputation change to a single faction (no cascade)
func _apply_reputation_change(faction_id: String, amount: int, reason: String = "") -> void:
	var old_rep: int = player_reputations.get(faction_id, 0)
	var old_status: int = FactionData.get_reputation_status(old_rep)

	var new_rep: int = clampi(old_rep + amount, MIN_REPUTATION, MAX_REPUTATION)
	player_reputations[faction_id] = new_rep

	if new_rep != old_rep:
		reputation_changed.emit(faction_id, old_rep, new_rep)

		var direction: String = "increased" if amount > 0 else "decreased"
		if not reason.is_empty():
			print("[Faction] %s reputation %s by %d (%s): %d -> %d" % [faction_id, direction, abs(amount), reason, old_rep, new_rep])
		else:
			print("[Faction] %s reputation %s by %d: %d -> %d" % [faction_id, direction, abs(amount), old_rep, new_rep])

		# Check for status change
		var new_status: int = FactionData.get_reputation_status(new_rep)
		if new_status != old_status:
			faction_status_changed.emit(faction_id, old_status, new_status)

		# Check for rank change if member
		_check_rank_change(faction_id, old_rep, new_rep)

## Cascade reputation changes to related factions (Daggerfall-style)
func _cascade_reputation(source_faction_id: String, amount: int) -> void:
	var faction: FactionData = factions.get(source_faction_id)
	if not faction:
		return

	# Cascade to allies (same direction, reduced)
	for ally_id: String in faction.allies:
		if factions.has(ally_id):
			var ally_amount: int = int(amount * ALLY_CASCADE_MULT)
			if ally_amount != 0:
				_apply_reputation_change(ally_id, ally_amount, "allied with %s" % faction.display_name)

	# Cascade to enemies (opposite direction)
	for enemy_id: String in faction.enemies:
		if factions.has(enemy_id):
			var enemy_amount: int = int(amount * ENEMY_CASCADE_MULT)
			if enemy_amount != 0:
				_apply_reputation_change(enemy_id, enemy_amount, "enemy of %s" % faction.display_name)

	# Cascade to parent faction
	if not faction.parent_faction.is_empty() and factions.has(faction.parent_faction):
		var parent_amount: int = int(amount * PARENT_CASCADE_MULT)
		if parent_amount != 0:
			_apply_reputation_change(faction.parent_faction, parent_amount, "parent of %s" % faction.display_name)

	# Cascade to child factions (factions with this as parent)
	for faction_id: String in factions:
		var other: FactionData = factions[faction_id]
		if other.parent_faction == source_faction_id:
			var child_amount: int = int(amount * CHILD_CASCADE_MULT)
			if child_amount != 0:
				_apply_reputation_change(faction_id, child_amount, "child of %s" % faction.display_name)

## Check if player's rank changed due to reputation
func _check_rank_change(faction_id: String, old_rep: int, new_rep: int) -> void:
	if not faction_memberships.has(faction_id):
		return

	var faction: FactionData = factions.get(faction_id)
	if not faction:
		return

	var old_rank: String = faction.get_rank_name(old_rep)
	var new_rank: String = faction.get_rank_name(new_rep)

	if old_rank != new_rank:
		faction_memberships[faction_id]["rank"] = new_rank
		rank_changed.emit(faction_id, old_rank, new_rank)
		print("[Faction] Rank changed in %s: %s -> %s" % [faction_id, old_rank, new_rank])

## Join a faction
func join_faction(faction_id: String) -> bool:
	var faction: FactionData = factions.get(faction_id)
	if not faction:
		push_warning("[FactionManager] Cannot join unknown faction: %s" % faction_id)
		return false

	if not faction.joinable:
		print("[Faction] %s is not joinable" % faction_id)
		return false

	var rep: int = get_reputation(faction_id)
	if rep < faction.join_threshold:
		print("[Faction] Insufficient reputation to join %s (need %d, have %d)" % [faction_id, faction.join_threshold, rep])
		return false

	if faction_memberships.has(faction_id):
		print("[Faction] Already a member of %s" % faction_id)
		return false

	var rank_name: String = faction.get_rank_name(rep)
	faction_memberships[faction_id] = {
		"rank": rank_name,
		"joined_time": Time.get_unix_time_from_system()
	}

	joined_faction.emit(faction_id, rank_name)
	print("[Faction] Joined %s as %s" % [faction.display_name, rank_name])

	_sync_to_player_data()
	return true

## Leave a faction
func leave_faction(faction_id: String) -> bool:
	if not faction_memberships.has(faction_id):
		print("[Faction] Not a member of %s" % faction_id)
		return false

	faction_memberships.erase(faction_id)
	left_faction.emit(faction_id)

	# Leaving costs reputation
	modify_reputation(faction_id, -20, "left faction", false)

	_sync_to_player_data()
	return true

## Check if player is a member of a faction
func is_member(faction_id: String) -> bool:
	return faction_memberships.has(faction_id)

## Get player's rank in a faction
func get_rank(faction_id: String) -> String:
	if not faction_memberships.has(faction_id):
		return ""
	return faction_memberships[faction_id].get("rank", "")

## Get all factions the player is a member of
func get_joined_factions() -> Array[String]:
	var result: Array[String] = []
	for faction_id: String in faction_memberships:
		result.append(faction_id)
	return result

## Get all visible factions (non-hidden or discovered)
func get_visible_factions() -> Array[FactionData]:
	var result: Array[FactionData] = []
	for faction_id: String in factions:
		var faction: FactionData = factions[faction_id]
		if not faction.is_hidden or faction_memberships.has(faction_id):
			result.append(faction)
	return result

## Check if player has minimum reputation with a faction
func has_min_reputation(faction_id: String, min_rep: int) -> bool:
	return get_reputation(faction_id) >= min_rep

## Check if player has a specific rank or higher
func has_rank(faction_id: String, rank_name: String) -> bool:
	if not faction_memberships.has(faction_id):
		return false

	var faction: FactionData = factions.get(faction_id)
	if not faction:
		return false

	var current_rank: String = faction_memberships[faction_id].get("rank", "")

	# Find rank indices
	var current_index: int = -1
	var required_index: int = -1

	for i: int in range(faction.ranks.size()):
		var rank: Dictionary = faction.ranks[i]
		if rank.get("name") == current_rank:
			current_index = i
		if rank.get("name") == rank_name:
			required_index = i

	return current_index >= required_index and required_index >= 0

## Sync reputation and memberships to player data
func _sync_to_player_data() -> void:
	if GameManager.player_data:
		GameManager.player_data.faction_reputations = player_reputations.duplicate()
		GameManager.player_data.faction_memberships = faction_memberships.duplicate(true)

## Reset all faction data (for new game)
func reset() -> void:
	player_reputations.clear()
	faction_memberships.clear()
	_initialize_player_reputations()

## Save faction state to dictionary
func to_dict() -> Dictionary:
	return {
		"reputations": player_reputations.duplicate(),
		"memberships": faction_memberships.duplicate(true)
	}

## Load faction state from dictionary
func from_dict(data: Dictionary) -> void:
	player_reputations = data.get("reputations", {})
	faction_memberships = data.get("memberships", {})

	# Ensure all factions have a reputation entry
	for faction_id: String in factions:
		if not player_reputations.has(faction_id):
			var faction: FactionData = factions[faction_id]
			player_reputations[faction_id] = faction.default_reputation

	_sync_to_player_data()
