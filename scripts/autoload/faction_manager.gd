## faction_manager.gd - Manages faction relationships and player reputation
## Autoload singleton implementing Daggerfall-style faction cascading
extends Node

## Signals
signal reputation_changed(faction_id: String, old_rep: int, new_rep: int)
signal faction_status_changed(faction_id: String, old_status: int, new_status: int)
signal joined_faction(faction_id: String, rank_name: String)
signal left_faction(faction_id: String)
signal rank_changed(faction_id: String, old_rank: String, new_rank: String)
signal daily_penalty_added(faction_id: String, reason: String, amount: int)
signal daily_penalty_cleared(faction_id: String, reason: String)
signal ongoing_effect_added(effect_id: String, config: Dictionary)
signal ongoing_effect_cleared(effect_id: String)
signal ongoing_effect_applied(effect_id: String, effect_type: String, amount: int)
signal hostility_changed(faction_id: String, old_value: int, new_value: int)

## All loaded faction data (faction_id -> FactionData)
var factions: Dictionary = {}

## Player reputation per faction (faction_id -> reputation int)
var player_reputations: Dictionary = {}

## Faction memberships (faction_id -> {rank: String, joined_time: float})
var faction_memberships: Dictionary = {}

## Last crime day per faction (faction_id -> in-game day number)
## Used for time decay of negative reputation
var last_crime_day: Dictionary = {}

## Last reputation decay day per faction (faction_id -> in-game day number)
## Tracks when decay was last applied to prevent double-counting
var last_decay_day: Dictionary = {}

## Ongoing effects - everything the world does to the player once a day because
## of a standing arrangement. Debts bleed reputation, a camp under the player's
## thumb pays him, and a town that knows what he has become gets angrier.
##
## Format: { effect_id: {type, faction, amount, reason_display, source} }
##   type:           "reputation" | "gold" | "hostility"
##   faction:        which faction it concerns (unused by "gold")
##   amount:         applied every day; sign is meaningful for all three types
##   reason_display: human-readable, for notifications and UI
##   source:         optional tag so one arrangement's effects clear together
var ongoing_effects: Dictionary = {}

## Standing hostility per faction (faction_id -> 0..100). Reputation is what a
## faction thinks of the player; hostility is how hard it is currently looking
## for him. A bandit chief can be respected by his crew and hunted by every
## guard on the road at the same time.
var faction_hostility: Dictionary = {}

## Prefix under which the old daily-penalty API stores its effects, so the
## penalty calls that already exist keep working unchanged.
const PENALTY_EFFECT_PREFIX := "penalty:"

## Hostility at which a faction is actively hunting the player. Crossing it
## raises the world fact "<faction_id>_hunting_player".
const HOSTILITY_HUNTING_THRESHOLD: int = 50

## Hostility bounds
const MIN_HOSTILITY: int = 0
const MAX_HOSTILITY: int = 100

## Days required without crimes before reputation starts decaying toward 0
const CRIME_COOLDOWN_DAYS: int = 7

## Reputation decay amount per week (applied to negative rep only)
const REPUTATION_DECAY_PER_WEEK: int = 1

## Cascade multipliers for reputation changes
const ALLY_CASCADE_MULT: float = 0.25      # Allies get 25% of rep change
const ENEMY_CASCADE_MULT: float = -0.5     # Enemies get -50% of rep change (opposite)
const PARENT_CASCADE_MULT: float = 0.5     # Parent faction gets 50% of rep change
const CHILD_CASCADE_MULT: float = 0.25     # Child factions get 25% of parent change

## Every relationship in the game was written from one side only. The merchants
## call the thieves enemies; the thieves have never heard of the merchants. So
## helping the merchants cost the player with the thieves, and robbing for the
## thieves cost him nothing at all with the merchants - true across most pairs,
## because `_cascade_reputation` reads the *source's* lists and nobody else's.
##
## Ruled: the reverse edge exists, at half strength. A grudge one side keeps
## and the other has not noticed is still a grudge, but it does not weigh the
## same from both ends. The reverse is derived rather than written into the
## `.tres` files, so an edge authored tomorrow gets its reciprocal for free and
## a hand-written mirror can never drift out of step with the edge it mirrors.
##
## An authored edge in BOTH directions is unaffected - it already cascades at
## full strength each way, and the derived pass skips it.
const RECIPROCAL_CASCADE_SCALE: float = 0.5

## Reputation bounds
const MIN_REPUTATION: int = -100
const MAX_REPUTATION: int = 100

## Path to faction data files
const FACTIONS_PATH: String = "res://data/factions/"

func _ready() -> void:
	_load_all_factions()
	_initialize_player_reputations()

	# Connect to day change for reputation decay processing
	if GameManager:
		GameManager.day_changed.connect(_on_day_changed)

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
		file_name = dir.get_next()

	dir.list_dir_end()

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

## Handle day change - process reputation decay and ongoing effects
func _on_day_changed(new_day: int) -> void:
	process_reputation_decay(new_day)
	process_ongoing_effects(new_day)


## Process time decay for negative reputation
## Negative reputation slowly decays toward 0 if no crimes committed in the past week
## Rate: +1 reputation per week (called daily, checks if 7 days have passed since last decay)
func process_reputation_decay(current_day: int) -> void:
	for faction_id: String in player_reputations:
		var rep: int = player_reputations[faction_id]

		# Only apply decay to NEGATIVE reputation
		if rep >= 0:
			continue

		# Check if player has committed a crime against this faction recently
		var last_crime: int = last_crime_day.get(faction_id, 0)
		var days_since_crime: int = current_day - last_crime

		# Only decay if enough time has passed since last crime
		if days_since_crime < CRIME_COOLDOWN_DAYS:
			continue

		# Check when we last applied decay for this faction
		var last_decay: int = last_decay_day.get(faction_id, 0)
		var days_since_decay: int = current_day - last_decay

		# Apply decay if 7+ days have passed since last decay (or never decayed)
		if days_since_decay >= CRIME_COOLDOWN_DAYS:
			var new_rep: int = mini(rep + REPUTATION_DECAY_PER_WEEK, 0)
			if new_rep != rep:
				_apply_reputation_change(faction_id, REPUTATION_DECAY_PER_WEEK, "time decay")
				last_decay_day[faction_id] = current_day


## Record that a crime was committed against a faction (updates last crime timestamp)
## Called automatically when reputation decreases due to criminal activity
## Also resets the decay timer so player must wait another full week for decay
func record_crime_against_faction(faction_id: String) -> void:
	last_crime_day[faction_id] = GameManager.current_day
	# Reset decay timer - committing a new crime means they need to wait another week
	last_decay_day[faction_id] = GameManager.current_day


# =============================================================================
# ONGOING EFFECTS
# =============================================================================
# One ticker for everything a standing arrangement does to the player each day.
# It began as accumulating reputation penalties for unpaid debts; it now also
# pays - a camp the player runs sends him his share - and makes the people who
# know what he did look harder for him.

## Register a standing daily effect.
## effect_id: unique; registering the same id again replaces the old effect
## config:    {type, faction, amount, reason_display, source} - see ongoing_effects
## Returns false if the effect is malformed and was not registered.
func add_ongoing_effect(effect_id: String, config: Dictionary) -> bool:
	if effect_id.is_empty():
		push_warning("[FactionManager] Ongoing effect needs an id")
		return false

	var effect_type: String = str(config.get("type", ""))
	if not effect_type in ["reputation", "gold", "hostility"]:
		push_warning("[FactionManager] Unknown ongoing effect type: '%s'" % effect_type)
		return false

	var faction_id: String = str(config.get("faction", ""))
	if effect_type != "gold":
		if faction_id.is_empty() or not factions.has(faction_id):
			push_warning("[FactionManager] Ongoing effect '%s' names no known faction: '%s'" % [effect_id, faction_id])
			return false

	var effect: Dictionary = {
		"type": effect_type,
		"faction": faction_id,
		"amount": int(config.get("amount", 0)),
		"reason_display": str(config.get("reason_display", effect_id)),
		"source": str(config.get("source", ""))
	}

	ongoing_effects[effect_id] = effect
	ongoing_effect_added.emit(effect_id, effect.duplicate())
	return true


## Stop a standing effect. Returns true if there was one to stop.
func clear_ongoing_effect(effect_id: String) -> bool:
	if not ongoing_effects.has(effect_id):
		return false
	ongoing_effects.erase(effect_id)
	ongoing_effect_cleared.emit(effect_id)
	return true


## Stop every effect that came from the same arrangement. When the player is
## thrown out of the camp he was running, the share, the guard heat and the
## debts to the men he shorted all end together.
## Returns how many were cleared.
func clear_ongoing_effects_from_source(source: String) -> int:
	if source.is_empty():
		return 0

	var doomed: Array[String] = []
	for effect_id: String in ongoing_effects:
		if str((ongoing_effects[effect_id] as Dictionary).get("source", "")) == source:
			doomed.append(effect_id)

	for effect_id: String in doomed:
		clear_ongoing_effect(effect_id)

	return doomed.size()


## Is this effect running?
func has_ongoing_effect(effect_id: String) -> bool:
	return ongoing_effects.has(effect_id)


## One effect's configuration, copied. Empty when there is none.
func get_ongoing_effect(effect_id: String) -> Dictionary:
	return (ongoing_effects.get(effect_id, {}) as Dictionary).duplicate()


## Every running effect, copied.
func get_ongoing_effects() -> Dictionary:
	return ongoing_effects.duplicate(true)


## What the player's standing arrangements pay (or cost) him per day.
func get_daily_income() -> int:
	var total: int = 0
	for effect_id: String in ongoing_effects:
		var effect: Dictionary = ongoing_effects[effect_id]
		if str(effect.get("type", "")) == "gold":
			total += int(effect.get("amount", 0))
	return total


## Apply one day of every standing effect. Called on day change; exposed so a
## check or a debug command can advance a day without waiting for one.
func process_ongoing_effects(_current_day: int = 0) -> void:
	# Reputation effects are summed per faction first, so a man carrying three
	# debts to the same town takes one reputation hit, not three.
	var reputation_totals: Dictionary = {}
	var gold_total: int = 0

	for effect_id: String in ongoing_effects:
		var effect: Dictionary = ongoing_effects[effect_id]
		var amount: int = int(effect.get("amount", 0))
		if amount == 0:
			continue

		var effect_type: String = str(effect.get("type", ""))
		var faction_id: String = str(effect.get("faction", ""))

		match effect_type:
			"reputation":
				reputation_totals[faction_id] = int(reputation_totals.get(faction_id, 0)) + amount
			"gold":
				gold_total += amount
			"hostility":
				add_hostility(faction_id, amount, str(effect.get("reason_display", "")))

		ongoing_effect_applied.emit(effect_id, effect_type, amount)

	for faction_id: String in reputation_totals:
		var total: int = reputation_totals[faction_id]
		if total != 0:
			_apply_reputation_change(faction_id, total, "ongoing effects")

	if gold_total != 0:
		_pay_ongoing_gold(gold_total)


## Hand over (or take) the day's coin from standing arrangements.
func _pay_ongoing_gold(amount: int) -> void:
	var inventory: Node = get_node_or_null("/root/InventoryManager")
	if inventory == null:
		return

	if amount > 0:
		inventory.add_gold(amount)
	else:
		inventory.remove_gold(-amount)


# =============================================================================
# HOSTILITY
# =============================================================================

## How hard a faction is currently looking for the player (0..100).
func get_hostility(faction_id: String) -> int:
	return int(faction_hostility.get(faction_id, 0))


## Raise or lower how hard a faction is looking for the player.
func add_hostility(faction_id: String, amount: int, _reason: String = "") -> void:
	if amount == 0:
		return
	set_hostility(faction_id, get_hostility(faction_id) + amount)


## Set hostility outright.
func set_hostility(faction_id: String, value: int) -> void:
	if faction_id.is_empty():
		return

	var old_value: int = get_hostility(faction_id)
	var new_value: int = clampi(value, MIN_HOSTILITY, MAX_HOSTILITY)
	if new_value == old_value:
		return

	faction_hostility[faction_id] = new_value
	hostility_changed.emit(faction_id, old_value, new_value)

	# Crossing the line either way is a fact about the world, not about a
	# quest, so guards and rumours in other zones can read it.
	var world_state: Node = get_node_or_null("/root/WorldState")
	if world_state == null:
		return

	var was_hunting: bool = old_value >= HOSTILITY_HUNTING_THRESHOLD
	var is_hunting: bool = new_value >= HOSTILITY_HUNTING_THRESHOLD
	if was_hunting != is_hunting:
		world_state.set_flag("%s_hunting_player" % faction_id, is_hunting)


## Is this faction actively hunting the player?
func is_hunting_player(faction_id: String) -> bool:
	return get_hostility(faction_id) >= HOSTILITY_HUNTING_THRESHOLD


# =============================================================================
# DAILY PENALTIES (the original ticker, now a view onto ongoing effects)
# =============================================================================

## Effect id under which a faction's named penalty is stored.
func _penalty_effect_id(faction_id: String, penalty_id: String) -> String:
	return "%s%s:%s" % [PENALTY_EFFECT_PREFIX, faction_id, penalty_id]


## Add a daily reputation penalty to a faction
## penalty_id: Unique identifier for this penalty (allows clearing specific penalties)
## faction_id: The faction receiving the penalty
## amount: Reputation loss per day (should be negative)
## reason_display: Human-readable reason for UI/notifications
func add_daily_penalty(faction_id: String, penalty_id: String, amount: int, reason_display: String = "") -> void:
	var added: bool = add_ongoing_effect(_penalty_effect_id(faction_id, penalty_id), {
		"type": "reputation",
		"faction": faction_id,
		"amount": amount,
		"reason_display": reason_display if not reason_display.is_empty() else penalty_id,
		"source": "daily_penalty"
	})
	if added:
		daily_penalty_added.emit(faction_id, penalty_id, amount)


## Clear a specific daily penalty from a faction
## Returns true if the penalty was found and cleared
func clear_daily_penalty(faction_id: String, penalty_id: String) -> bool:
	if not clear_ongoing_effect(_penalty_effect_id(faction_id, penalty_id)):
		return false
	daily_penalty_cleared.emit(faction_id, penalty_id)
	return true


## Clear all daily penalties for a faction
func clear_all_penalties_for_faction(faction_id: String) -> void:
	for penalty_id: String in get_faction_penalties(faction_id):
		clear_daily_penalty(faction_id, penalty_id)


## Get all active penalties for a faction
## Returns: Dictionary { penalty_id: {amount: int, reason_display: String} }
func get_faction_penalties(faction_id: String) -> Dictionary:
	var prefix: String = "%s%s:" % [PENALTY_EFFECT_PREFIX, faction_id]
	var penalties: Dictionary = {}

	for effect_id: String in ongoing_effects:
		if not effect_id.begins_with(prefix):
			continue
		var effect: Dictionary = ongoing_effects[effect_id]
		penalties[effect_id.substr(prefix.length())] = {
			"amount": int(effect.get("amount", 0)),
			"reason_display": str(effect.get("reason_display", ""))
		}

	return penalties


## Get total daily penalty amount for a faction
func get_total_daily_penalty(faction_id: String) -> int:
	var penalties: Dictionary = get_faction_penalties(faction_id)
	var total: int = 0
	for penalty_id: String in penalties:
		total += int((penalties[penalty_id] as Dictionary).get("amount", 0))
	return total


## Check if a faction has a specific penalty
func has_penalty(faction_id: String, penalty_id: String) -> bool:
	return has_ongoing_effect(_penalty_effect_id(faction_id, penalty_id))


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
## is_crime: If true, records this as a crime for time decay tracking (resets the cooldown)
func modify_reputation(faction_id: String, amount: int, reason: String = "", cascade: bool = true, is_crime: bool = false) -> void:
	if not factions.has(faction_id):
		push_warning("[FactionManager] Unknown faction: %s" % faction_id)
		return

	# Record crime if this is a criminal act (negative reputation from crime)
	# This resets the time decay cooldown for this faction
	if is_crime and amount < 0:
		record_crime_against_faction(faction_id)

	# Apply main reputation change
	_apply_reputation_change(faction_id, amount, reason)

	# Apply cascading effects
	if cascade:
		_cascade_reputation(faction_id, amount)

	# Sync with player data
	_sync_to_player_data()

## Apply a reputation change to a single faction (no cascade)
func _apply_reputation_change(faction_id: String, amount: int, _reason: String = "") -> void:
	var old_rep: int = player_reputations.get(faction_id, 0)
	var old_status: int = FactionData.get_reputation_status(old_rep)

	var new_rep: int = clampi(old_rep + amount, MIN_REPUTATION, MAX_REPUTATION)
	player_reputations[faction_id] = new_rep

	if new_rep != old_rep:
		reputation_changed.emit(faction_id, old_rep, new_rep)

		# Check for status change
		var new_status: int = FactionData.get_reputation_status(new_rep)
		if new_status != old_status:
			faction_status_changed.emit(faction_id, old_status, new_status)

			# Unlock secret faction lore when reaching HONORED status
			if new_status >= FactionData.ReputationStatus.HONORED and old_status < FactionData.ReputationStatus.HONORED:
				_unlock_secret_faction_lore(faction_id)

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

	_cascade_reciprocal(source_faction_id, faction, amount)


## The other half of every one-way relationship, at RECIPROCAL_CASCADE_SCALE.
##
## Walks the factions that name the source and that the source does not name
## back, and cascades to each at half the multiplier the authored direction
## would use. `neutrals` is deliberately not mirrored: a neutral is the absence
## of a relationship and cascades nothing in either direction, and a faction the
## source lists as neutral is not one that quietly cares.
func _cascade_reciprocal(source_faction_id: String, faction: FactionData, amount: int) -> void:
	for other_id: String in factions:
		if other_id == source_faction_id:
			continue

		var other: FactionData = factions[other_id]

		# Neutrality on the source's side is a statement, not a silence: if the
		# source has looked at this faction and called it neutral, the reverse
		# edge is not derived over the top of that ruling.
		if other_id in faction.allies or other_id in faction.enemies or other_id in faction.neutrals:
			continue

		var mult: float = 0.0
		if source_faction_id in other.allies:
			mult = ALLY_CASCADE_MULT
		elif source_faction_id in other.enemies:
			mult = ENEMY_CASCADE_MULT
		else:
			continue

		var reciprocal_amount: int = int(amount * mult * RECIPROCAL_CASCADE_SCALE)
		if reciprocal_amount == 0:
			continue

		_apply_reputation_change(
			other_id, reciprocal_amount, "%s counts %s a %s" % [
				other.display_name, faction.display_name,
				"friend" if mult > 0.0 else "rival"
			]
		)

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

## Join a faction
func join_faction(faction_id: String) -> bool:
	var faction: FactionData = factions.get(faction_id)
	if not faction:
		push_warning("[FactionManager] Cannot join unknown faction: %s" % faction_id)
		return false

	if not faction.joinable:
		return false

	var rep: int = get_reputation(faction_id)
	if rep < faction.join_threshold:
		return false

	if faction_memberships.has(faction_id):
		return false

	var rank_name: String = faction.get_rank_name(rep)
	faction_memberships[faction_id] = {
		"rank": rank_name,
		"joined_time": Time.get_unix_time_from_system()
	}

	joined_faction.emit(faction_id, rank_name)

	# Unlock faction-specific lore in the Codex when joining
	if CodexManager:
		# Try to discover faction lore entry (e.g., "thieves_guild" -> discovers "thieves_guild" lore)
		CodexManager.discover_lore(faction_id)
		# Also try with common prefixes
		CodexManager.discover_lore("faction_" + faction_id)

	_sync_to_player_data()
	return true

## Join a faction regardless of what it thinks of the player, at a named rank.
##
## join_faction() is the front door: earn the reputation, ask to be let in.
## This is the other way in - the player who kills a camp's chief and stands
## over the body is their chief now, and nobody is going to check his standing
## first. Reputation is raised to the rank's floor so the promotion sticks and
## does not immediately demote him again.
##
## rank_name empty means "whatever rank his reputation already earns".
## Returns false only if the faction or the rank does not exist.
func force_join_faction(faction_id: String, rank_name: String = "") -> bool:
	var faction: FactionData = factions.get(faction_id)
	if not faction:
		push_warning("[FactionManager] Cannot join unknown faction: %s" % faction_id)
		return false

	var resolved_rank: String = rank_name
	if not rank_name.is_empty():
		var floor_rep: int = -101
		for rank: Dictionary in faction.ranks:
			if str(rank.get("name", "")) == rank_name:
				floor_rep = int(rank.get("min_reputation", 0))
				break

		if floor_rep < -100:
			push_warning("[FactionManager] Faction '%s' has no rank '%s'" % [faction_id, rank_name])
			return false

		if get_reputation(faction_id) < floor_rep:
			modify_reputation(faction_id, floor_rep - get_reputation(faction_id), "took the rank of %s" % rank_name)
	else:
		resolved_rank = faction.get_rank_name(get_reputation(faction_id))

	var was_member: bool = faction_memberships.has(faction_id)
	var old_rank: String = get_rank(faction_id)

	faction_memberships[faction_id] = {
		"rank": resolved_rank,
		"joined_time": faction_memberships.get(faction_id, {}).get("joined_time", Time.get_unix_time_from_system())
	}

	if was_member:
		if old_rank != resolved_rank:
			rank_changed.emit(faction_id, old_rank, resolved_rank)
	else:
		joined_faction.emit(faction_id, resolved_rank)
		if CodexManager:
			CodexManager.discover_lore(faction_id)
			CodexManager.discover_lore("faction_" + faction_id)

	_sync_to_player_data()
	return true


## Leave a faction
func leave_faction(faction_id: String) -> bool:
	if not faction_memberships.has(faction_id):
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
	# The mirror has to go first. `_initialize_player_reputations()` overrides
	# every default with whatever `GameManager.player_data` holds, and
	# `_sync_to_player_data()` has been writing this manager's state into that
	# dictionary all along - so clearing only the local copy cleared nothing.
	# Both callers are new-game paths, which means a second character could
	# start out already Honored with somebody the first one had pleased.
	if GameManager.player_data:
		GameManager.player_data.faction_reputations.clear()
		GameManager.player_data.faction_memberships.clear()

	player_reputations.clear()
	faction_memberships.clear()
	last_crime_day.clear()
	last_decay_day.clear()
	ongoing_effects.clear()
	faction_hostility.clear()
	_initialize_player_reputations()

## Copy a dictionary of whole numbers back into ints after a JSON round trip.
func _as_int_dict(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (source is Dictionary):
		return result
	for key: Variant in (source as Dictionary):
		var value: Variant = (source as Dictionary)[key]
		if value is int or value is float:
			result[key] = int(value)
		else:
			result[key] = value
	return result


## Save faction state to dictionary
func to_dict() -> Dictionary:
	return {
		"reputations": player_reputations.duplicate(),
		"memberships": faction_memberships.duplicate(true),
		"last_crime_day": last_crime_day.duplicate(),
		"last_decay_day": last_decay_day.duplicate(),
		"ongoing_effects": ongoing_effects.duplicate(true),
		"hostility": faction_hostility.duplicate()
	}

## Load faction state from dictionary
func from_dict(data: Dictionary) -> void:
	# JSON has no integers, so everything numeric comes back as a float. These
	# are whole numbers - reputation, hostility, day counts - and code that
	# reads them expects ints, so they are put back the way they went in.
	player_reputations = _as_int_dict(data.get("reputations", {}))
	faction_memberships = data.get("memberships", {})
	last_crime_day = _as_int_dict(data.get("last_crime_day", {}))
	last_decay_day = _as_int_dict(data.get("last_decay_day", {}))
	faction_hostility = _as_int_dict(data.get("hostility", {}))

	ongoing_effects = {}
	var saved_effects: Dictionary = data.get("ongoing_effects", {})
	for effect_id: String in saved_effects:
		var effect: Dictionary = (saved_effects[effect_id] as Dictionary).duplicate()
		effect["amount"] = int(effect.get("amount", 0))
		ongoing_effects[effect_id] = effect

	# Saves written before the ticker was generalized carry penalties in the
	# old per-faction shape. Fold them in rather than dropping the player's
	# debts on the floor.
	var legacy_penalties: Dictionary = data.get("daily_penalties", {})
	for faction_id: String in legacy_penalties:
		var per_faction: Dictionary = legacy_penalties[faction_id]
		for penalty_id: String in per_faction:
			var penalty: Dictionary = per_faction[penalty_id]
			ongoing_effects[_penalty_effect_id(faction_id, penalty_id)] = {
				"type": "reputation",
				"faction": faction_id,
				"amount": int(penalty.get("amount", 0)),
				"reason_display": str(penalty.get("reason_display", penalty_id)),
				"source": "daily_penalty"
			}

	# Ensure all factions have a reputation entry
	for faction_id: String in factions:
		if not player_reputations.has(faction_id):
			var faction: FactionData = factions[faction_id]
			player_reputations[faction_id] = faction.default_reputation

	_sync_to_player_data()


## Secret lore IDs for each faction - unlocked at HONORED reputation
## These reveal deep secrets about the faction's true nature
const SECRET_FACTION_LORE: Dictionary = {
	"keepers": ["keeper_secrets"],              # Truth about the witch-king
	"thieves_guild": ["thieves_guild_secrets"], # Guild operations and history
	"church_of_three": ["church_secrets"],      # Ancient truths about the Three Gods
	"mages_guild": ["mages_guild_secrets"],     # Hidden magical knowledge
	"fighters_guild": ["fighters_guild_secrets"], # Guild's darker history
	"merchant_guild": ["merchants_guild_secrets"], # Trade secrets and conspiracies
}


## Unlock secret lore entries for a faction when reaching HONORED status
func _unlock_secret_faction_lore(faction_id: String) -> void:
	if not CodexManager:
		return

	# Get secret lore IDs for this faction
	var secret_lore_ids: Array = SECRET_FACTION_LORE.get(faction_id, [])

	for lore_id in secret_lore_ids:
		if CodexManager.discover_lore(lore_id):
			# Show notification that secret lore was unlocked
			var hud: Node = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Secret knowledge unlocked!")


## Town faction IDs mapped to their location IDs
const TOWN_FACTIONS: Dictionary = {
	"elder_moor": "elder_moor",
	"dalhurst": "dalhurst",
	"thornfield": "thornfield",
	"millbrook": "millbrook"
}


## Get the town faction ID for the current player location
## Returns: The town faction ID, or "" if not in a town
func get_town_faction() -> String:
	if not PlayerGPS:
		return ""

	var location_id: String = PlayerGPS.current_location_id
	if location_id.is_empty():
		return ""

	# Check if this location has an associated town faction
	if TOWN_FACTIONS.has(location_id):
		return TOWN_FACTIONS[location_id]

	return ""


## Get town faction for a specific location ID
func get_town_faction_for_location(location_id: String) -> String:
	if TOWN_FACTIONS.has(location_id):
		return TOWN_FACTIONS[location_id]
	return ""


## Check if the player is HOSTILE or worse with a faction
func is_hostile_with(faction_id: String) -> bool:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	return status == FactionData.ReputationStatus.HOSTILE or status == FactionData.ReputationStatus.HATED


## Check if the player is HATED by a faction
func is_hated_by(faction_id: String) -> bool:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	return status == FactionData.ReputationStatus.HATED


## Check if the player is FRIENDLY or better with a faction
func is_friendly_with(faction_id: String) -> bool:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	return status == FactionData.ReputationStatus.FRIENDLY or \
		   status == FactionData.ReputationStatus.HONORED or \
		   status == FactionData.ReputationStatus.EXALTED


## Check if the player is HONORED or better with a faction
func is_honored_by(faction_id: String) -> bool:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	return status == FactionData.ReputationStatus.HONORED or \
		   status == FactionData.ReputationStatus.EXALTED


## Check if the player is EXALTED with a faction
func is_exalted_with(faction_id: String) -> bool:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	return status == FactionData.ReputationStatus.EXALTED


## Get discount percentage based on reputation status
## Returns: Percentage discount (0.0 to 0.4) or negative for markup
func get_reputation_price_modifier(faction_id: String) -> float:
	var status: FactionData.ReputationStatus = get_reputation_status(faction_id)
	match status:
		FactionData.ReputationStatus.HATED:
			return 1.0  # Double prices (merchants refuse anyway)
		FactionData.ReputationStatus.HOSTILE:
			return 0.75  # +75% markup (merchants refuse anyway)
		FactionData.ReputationStatus.UNFRIENDLY:
			return 0.5  # +50% markup
		FactionData.ReputationStatus.NEUTRAL:
			return 0.0  # Normal prices
		FactionData.ReputationStatus.FRIENDLY:
			return -0.1  # 10% discount
		FactionData.ReputationStatus.HONORED:
			return -0.25  # 25% discount
		FactionData.ReputationStatus.EXALTED:
			return -0.4  # 40% discount
		_:
			return 0.0


# =============================================================================
# SUB-FACTION SUPPORT
# =============================================================================

## Church sub-faction IDs
const CHURCH_CHRONOS := "church_of_chronos"
const CHURCH_GAELA := "church_of_gaela"
const CHURCH_MORTHANE := "church_of_morthane"

## All church sub-factions
const CHURCH_SUB_FACTIONS: Array[String] = [
	CHURCH_CHRONOS,
	CHURCH_GAELA,
	CHURCH_MORTHANE
]

## Map deity name to church sub-faction ID
const DEITY_TO_FACTION: Dictionary = {
	"chronos": CHURCH_CHRONOS,
	"gaela": CHURCH_GAELA,
	"morthane": CHURCH_MORTHANE
}


## Get all sub-factions of a parent faction
func get_sub_factions(parent_faction_id: String) -> Array[String]:
	var sub_factions: Array[String] = []
	for faction_id: String in factions:
		var faction: FactionData = factions[faction_id]
		if faction.parent_faction == parent_faction_id:
			sub_factions.append(faction_id)
	return sub_factions


## Check if a faction is a sub-faction of another
func is_sub_faction_of(faction_id: String, parent_id: String) -> bool:
	var faction: FactionData = factions.get(faction_id)
	if not faction:
		return false
	return faction.parent_faction == parent_id


## Get the parent faction ID for a sub-faction
func get_parent_faction(faction_id: String) -> String:
	var faction: FactionData = factions.get(faction_id)
	if not faction:
		return ""
	return faction.parent_faction


## Get the church sub-faction for a deity
## deity: "chronos", "gaela", or "morthane"
func get_church_for_deity(deity: String) -> String:
	return DEITY_TO_FACTION.get(deity.to_lower(), "")


## Get the deity name for a church sub-faction
func get_deity_for_church(faction_id: String) -> String:
	for deity: String in DEITY_TO_FACTION:
		if DEITY_TO_FACTION[deity] == faction_id:
			return deity
	return ""


## Check if a faction is a church sub-faction
func is_church_sub_faction(faction_id: String) -> bool:
	return faction_id in CHURCH_SUB_FACTIONS


## Get player's reputation with a specific church (by deity name)
## deity: "chronos", "gaela", or "morthane"
func get_church_reputation(deity: String) -> int:
	var faction_id: String = get_church_for_deity(deity)
	if faction_id.is_empty():
		return 0
	return get_reputation(faction_id)


## Modify reputation with a specific church (by deity name)
## deity: "chronos", "gaela", or "morthane"
func modify_church_reputation(deity: String, amount: int, reason: String = "") -> void:
	var faction_id: String = get_church_for_deity(deity)
	if faction_id.is_empty():
		push_warning("[FactionManager] Unknown deity: %s" % deity)
		return
	modify_reputation(faction_id, amount, reason)


## Get the highest reputation church sub-faction for the player
## Returns the faction_id of the church with highest reputation, or "" if none
func get_favored_church() -> String:
	var best_faction: String = ""
	var best_rep: int = -101

	for faction_id: String in CHURCH_SUB_FACTIONS:
		var rep: int = get_reputation(faction_id)
		if rep > best_rep:
			best_rep = rep
			best_faction = faction_id

	return best_faction


## Get the deity name for the player's favored church
func get_favored_deity() -> String:
	var church: String = get_favored_church()
	if church.is_empty():
		return ""
	return get_deity_for_church(church)


## Check if player is friendly or better with a specific church
func is_friendly_with_church(deity: String) -> bool:
	var faction_id: String = get_church_for_deity(deity)
	if faction_id.is_empty():
		return false
	return is_friendly_with(faction_id)


## Check if player is honored or better with a specific church
func is_honored_by_church(deity: String) -> bool:
	var faction_id: String = get_church_for_deity(deity)
	if faction_id.is_empty():
		return false
	return is_honored_by(faction_id)
