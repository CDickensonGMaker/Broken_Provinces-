## morality_manager.gd - Tracks player's moral alignment and reputation
## Autoload singleton for managing the morality system
extends Node

## Signals
signal morality_changed(old_score: int, new_score: int)
signal tier_changed(old_tier: MoralityTier, new_tier: MoralityTier)

## Morality tier enum
enum MoralityTier {
	VILE,       # -100 to -60
	WICKED,     # -59 to -20
	NEUTRAL,    # -19 to +19
	HONORABLE,  # +20 to +59
	PARAGON     # +60 to +100
}

## Score bounds
const MIN_SCORE: int = -100
const MAX_SCORE: int = 100

## Tier thresholds
const TIER_VILE_MAX: int = -60
const TIER_WICKED_MAX: int = -20
const TIER_NEUTRAL_MAX: int = 19
const TIER_HONORABLE_MAX: int = 59

## Decay settings - morality drifts toward 0 over time
const DECAY_AMOUNT: int = 1          # Points to decay per interval
const DECAY_INTERVAL_HOURS: float = 168.0  # In-game hours (1 week = 168 hours)

## Current morality score (-100 to +100)
var morality_score: int = 0

## Time tracking for decay
var hours_since_last_decay: float = 0.0

## Morality action presets for common actions
const ACTION_MURDER_INNOCENT: int = -25
const ACTION_MURDER_CRIMINAL: int = -5
const ACTION_THEFT: int = -10
const ACTION_ASSAULT_INNOCENT: int = -15
const ACTION_HELP_NEEDY: int = 5
const ACTION_DONATE_LARGE: int = 10
const ACTION_DONATE_SMALL: int = 3
const ACTION_COMPLETE_GOOD_QUEST: int = 8
const ACTION_COMPLETE_EVIL_QUEST: int = -8
const ACTION_SPARE_ENEMY: int = 5
const ACTION_BETRAY_TRUST: int = -15
const ACTION_KEEP_PROMISE: int = 5
const ACTION_BREAK_PROMISE: int = -10
const ACTION_INTIMIDATION: int = -3
const ACTION_PERSUASION_GOOD: int = 2

func _ready() -> void:
	# Load morality from player data if available
	if GameManager.player_data:
		morality_score = GameManager.player_data.morality_score

## Get the current morality tier based on score
func get_morality_tier() -> MoralityTier:
	if morality_score <= TIER_VILE_MAX:
		return MoralityTier.VILE
	elif morality_score <= TIER_WICKED_MAX:
		return MoralityTier.WICKED
	elif morality_score <= TIER_NEUTRAL_MAX:
		return MoralityTier.NEUTRAL
	elif morality_score <= TIER_HONORABLE_MAX:
		return MoralityTier.HONORABLE
	else:
		return MoralityTier.PARAGON

## Get display name for a morality tier
func get_tier_name(tier: int = -1) -> String:
	var resolved_tier: MoralityTier
	if tier == -1:
		resolved_tier = get_morality_tier()
	else:
		resolved_tier = tier as MoralityTier

	match resolved_tier:
		MoralityTier.VILE:
			return "Vile"
		MoralityTier.WICKED:
			return "Wicked"
		MoralityTier.NEUTRAL:
			return "Neutral"
		MoralityTier.HONORABLE:
			return "Honorable"
		MoralityTier.PARAGON:
			return "Paragon"
		_:
			return "Unknown"

## Get color for morality tier (for UI display)
func get_tier_color(tier: int = -1) -> Color:
	var resolved_tier: MoralityTier
	if tier == -1:
		resolved_tier = get_morality_tier()
	else:
		resolved_tier = tier as MoralityTier

	match resolved_tier:
		MoralityTier.VILE:
			return Color(0.5, 0.0, 0.0)  # Dark red
		MoralityTier.WICKED:
			return Color(0.8, 0.2, 0.2)  # Red
		MoralityTier.NEUTRAL:
			return Color(0.7, 0.7, 0.7)  # Gray
		MoralityTier.HONORABLE:
			return Color(0.2, 0.6, 0.8)  # Light blue
		MoralityTier.PARAGON:
			return Color(1.0, 0.85, 0.0)  # Gold
		_:
			return Color.WHITE

## Modify morality score by an amount
## Positive values increase morality (good deeds)
## Negative values decrease morality (evil deeds)
func modify_morality(amount: int, reason: String = "") -> void:
	var old_score: int = morality_score
	var old_tier: MoralityTier = get_morality_tier()

	morality_score = clampi(morality_score + amount, MIN_SCORE, MAX_SCORE)

	# Sync with player data
	if GameManager.player_data:
		GameManager.player_data.morality_score = morality_score

	if morality_score != old_score:
		morality_changed.emit(old_score, morality_score)

		# Check for tier change
		var new_tier: MoralityTier = get_morality_tier()
		if new_tier != old_tier:
			tier_changed.emit(old_tier, new_tier)

## Process morality decay over time (called by game time system)
func process_time_passed(hours: float) -> void:
	hours_since_last_decay += hours

	# Check if enough time has passed for decay
	while hours_since_last_decay >= DECAY_INTERVAL_HOURS:
		hours_since_last_decay -= DECAY_INTERVAL_HOURS
		_apply_decay()

## Apply decay toward neutral (0)
func _apply_decay() -> void:
	if morality_score == 0:
		return

	var decay_direction: int = -1 if morality_score > 0 else 1
	modify_morality(decay_direction * DECAY_AMOUNT, "natural decay")

## Record a specific moral action using preset values
func record_action(action_type: String) -> void:
	match action_type:
		"murder_innocent":
			modify_morality(ACTION_MURDER_INNOCENT, "murdered innocent")
		"murder_criminal":
			modify_morality(ACTION_MURDER_CRIMINAL, "killed criminal")
		"theft":
			modify_morality(ACTION_THEFT, "committed theft")
		"assault_innocent":
			modify_morality(ACTION_ASSAULT_INNOCENT, "assaulted innocent")
		"help_needy":
			modify_morality(ACTION_HELP_NEEDY, "helped someone in need")
		"donate_large":
			modify_morality(ACTION_DONATE_LARGE, "made generous donation")
		"donate_small":
			modify_morality(ACTION_DONATE_SMALL, "made small donation")
		"complete_good_quest":
			modify_morality(ACTION_COMPLETE_GOOD_QUEST, "completed virtuous quest")
		"complete_evil_quest":
			modify_morality(ACTION_COMPLETE_EVIL_QUEST, "completed dark quest")
		"spare_enemy":
			modify_morality(ACTION_SPARE_ENEMY, "showed mercy")
		"betray_trust":
			modify_morality(ACTION_BETRAY_TRUST, "betrayed trust")
		"keep_promise":
			modify_morality(ACTION_KEEP_PROMISE, "kept promise")
		"break_promise":
			modify_morality(ACTION_BREAK_PROMISE, "broke promise")
		"intimidation":
			modify_morality(ACTION_INTIMIDATION, "used intimidation")
		"persuasion_good":
			modify_morality(ACTION_PERSUASION_GOOD, "persuaded for good")
		_:
			push_warning("[Morality] Unknown action type: %s" % action_type)

## Check if player meets a morality requirement
func meets_requirement(min_score: int = MIN_SCORE, max_score: int = MAX_SCORE) -> bool:
	return morality_score >= min_score and morality_score <= max_score

## Check if player is in a specific tier
func is_tier(tier: MoralityTier) -> bool:
	return get_morality_tier() == tier

## Check if player is good (Honorable or Paragon)
func is_good() -> bool:
	return morality_score >= 20

## Check if player is evil (Wicked or Vile)
func is_evil() -> bool:
	return morality_score <= -20

## Check if player is neutral
func is_neutral() -> bool:
	return morality_score > -20 and morality_score < 20

## Get a description of the player's moral standing
func get_description() -> String:
	match get_morality_tier():
		MoralityTier.VILE:
			return "You are feared as a monster. Your cruelty is legendary."
		MoralityTier.WICKED:
			return "You have a dark reputation. People distrust your motives."
		MoralityTier.NEUTRAL:
			return "You walk the line between good and evil."
		MoralityTier.HONORABLE:
			return "You are known as a person of principle and honor."
		MoralityTier.PARAGON:
			return "You are celebrated as a beacon of virtue and righteousness."
		_:
			return "Your moral standing is unknown."

## Get morality as a normalized value (0.0 to 1.0 for UI sliders)
func get_normalized_score() -> float:
	return (morality_score + 100.0) / 200.0

## Reset morality to neutral (for new game)
func reset() -> void:
	morality_score = 0
	hours_since_last_decay = 0.0
	if GameManager.player_data:
		GameManager.player_data.morality_score = 0

## Save morality state to dictionary
func to_dict() -> Dictionary:
	return {
		"morality_score": morality_score,
		"hours_since_last_decay": hours_since_last_decay
	}

## Load morality state from dictionary
func from_dict(data: Dictionary) -> void:
	var old_score: int = morality_score
	var old_tier: MoralityTier = get_morality_tier()

	morality_score = data.get("morality_score", 0)
	hours_since_last_decay = data.get("hours_since_last_decay", 0.0)

	# Sync with player data
	if GameManager.player_data:
		GameManager.player_data.morality_score = morality_score

	# Emit signals if state changed
	if morality_score != old_score:
		morality_changed.emit(old_score, morality_score)

	var new_tier: MoralityTier = get_morality_tier()
	if new_tier != old_tier:
		tier_changed.emit(old_tier, new_tier)


# =============================================================================
# GAMEPLAY HOOKS - How morality affects game mechanics
# =============================================================================

## Get disposition modifier for NPC interactions based on morality
## Returns a bonus/penalty applied to base NPC disposition
## npc_alignment: "good", "evil", "neutral", or empty for no preference
func get_disposition_modifier(npc_alignment: String = "") -> int:
	var tier: MoralityTier = get_morality_tier()

	match npc_alignment.to_lower():
		"good":
			# Good-aligned NPCs like paragons, hate vile players
			match tier:
				MoralityTier.PARAGON:
					return 20
				MoralityTier.HONORABLE:
					return 10
				MoralityTier.WICKED:
					return -15
				MoralityTier.VILE:
					return -30
		"evil":
			# Evil-aligned NPCs like wicked players, hate paragons
			match tier:
				MoralityTier.VILE:
					return 15
				MoralityTier.WICKED:
					return 10
				MoralityTier.HONORABLE:
					return -10
				MoralityTier.PARAGON:
					return -20
		"neutral", "":
			# Neutral NPCs slightly prefer neutrality
			if is_neutral():
				return 5
			elif tier == MoralityTier.PARAGON or tier == MoralityTier.VILE:
				return -5

	return 0


## Get shop price modifier based on morality
## Returns a multiplier (1.0 = normal, 1.2 = 20% more expensive, 0.9 = 10% cheaper)
func get_price_modifier() -> float:
	var tier: MoralityTier = get_morality_tier()

	match tier:
		MoralityTier.PARAGON:
			return 0.9   # 10% discount - merchants trust you
		MoralityTier.HONORABLE:
			return 0.95  # 5% discount
		MoralityTier.WICKED:
			return 1.1   # 10% markup - merchants wary
		MoralityTier.VILE:
			return 1.25  # 25% markup - merchants fear/hate you

	return 1.0  # Neutral = normal prices


## Check if morality allows an action (for dialogue gating)
## action_type: "good_only", "evil_only", "neutral_only", "not_evil", "not_good"
func allows_action(action_type: String) -> bool:
	match action_type.to_lower():
		"good_only":
			return is_good()
		"evil_only":
			return is_evil()
		"neutral_only":
			return is_neutral()
		"not_evil":
			return not is_evil()
		"not_good":
			return not is_good()
		"paragon":
			return is_tier(MoralityTier.PARAGON)
		"vile":
			return is_tier(MoralityTier.VILE)

	return true  # Unknown action type allows by default


## Get persuasion skill bonus/penalty based on morality and NPC alignment
func get_persuasion_modifier(npc_alignment: String = "") -> int:
	var tier: MoralityTier = get_morality_tier()

	# Extreme alignments can help with same-aligned NPCs
	if npc_alignment.to_lower() == "good" and tier == MoralityTier.PARAGON:
		return 3  # +3 to persuasion with good NPCs as a paragon
	if npc_alignment.to_lower() == "evil" and tier == MoralityTier.VILE:
		return 3  # +3 to persuasion with evil NPCs as vile

	# But hurt with opposite alignment
	if npc_alignment.to_lower() == "good" and is_evil():
		return -2
	if npc_alignment.to_lower() == "evil" and is_good():
		return -2

	return 0


## Get intimidation skill modifier based on morality
## Evil characters are more intimidating, good characters less so
func get_intimidation_modifier() -> int:
	var tier: MoralityTier = get_morality_tier()

	match tier:
		MoralityTier.VILE:
			return 4   # +4 intimidation - terrifying reputation
		MoralityTier.WICKED:
			return 2   # +2 intimidation
		MoralityTier.PARAGON:
			return -2  # -2 intimidation - too noble to be scary

	return 0
