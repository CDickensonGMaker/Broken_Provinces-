extends Node
## Faction ongoing-effects check: the ticker, hostility, and joining a crew.
##
## Usage: godot --headless --path . res://tools/check_ongoing_effects.tscn
##
## Runs as a scene, not with --script: FactionManager, InventoryManager and
## WorldState are autoloads.
##
## What it proves:
##
## 1. The ticker still does what the daily-penalty system did - the old API is
##    now a view onto the general one, and unpaid debts must still bleed
##    reputation exactly as before, including summing several debts to the same
##    faction into one hit.
## 2. It also pays. A camp under the player's thumb sends him his share every
##    day, and a negative arrangement takes coin instead.
## 3. It raises hostility, and crossing the hunting line writes a world fact
##    other zones can read.
## 4. A crew can be joined the front way (earn it) and the other way (kill the
##    chief and take his chair), and the bandit faction exists to join.
## 5. All of it survives a save: serialize, deserialize, identical.

var _failures: Array[String] = []
var _checks: int = 0

const TEST_FACTION := "bandits"
const DEBT_FACTION := "thieves_guild"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame

	_check_bandit_faction_exists()
	_check_penalty_compatibility()
	_check_income()
	_check_hostility()
	_check_join_mechanics()
	_check_round_trip()

	print("")
	print("Checks run: %d" % _checks)
	if _failures.is_empty():
		print("Ongoing effects check: PASS")
		get_tree().quit(0)
		return

	print("Ongoing effects check: FAIL (%d)" % _failures.size())
	for failure: String in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _reset() -> void:
	FactionManager.reset()
	WorldState.reset_for_new_game()


# =============================================================================

func _check_bandit_faction_exists() -> void:
	var bandits: FactionData = FactionManager.get_faction(TEST_FACTION)
	_expect(bandits != null, "there is no bandits faction - every bandit enemy points at one")
	if bandits == null:
		return

	_expect(bandits.joinable, "the bandits must be joinable; joining them is the point")
	_expect(bandits.ranks.size() >= 2, "the bandits need a ladder to climb, found %d ranks" % bandits.ranks.size())

	var top_rank: String = str((bandits.ranks[bandits.ranks.size() - 1] as Dictionary).get("name", ""))
	_expect(not top_rank.is_empty(), "the bandits' top rank has no name")


# =============================================================================

func _check_penalty_compatibility() -> void:
	_reset()

	var before: int = FactionManager.get_reputation(DEBT_FACTION)
	FactionManager.add_daily_penalty(DEBT_FACTION, "unpaid_debt", -5, "Unpaid debt")
	FactionManager.add_daily_penalty(DEBT_FACTION, "broke_a_deal", -3, "Broke a deal")

	_expect(FactionManager.has_penalty(DEBT_FACTION, "unpaid_debt"), "a daily penalty did not register")
	_expect(
		FactionManager.get_total_daily_penalty(DEBT_FACTION) == -8,
		"two penalties should total -8, got %d" % FactionManager.get_total_daily_penalty(DEBT_FACTION)
	)
	_expect(
		FactionManager.get_faction_penalties(DEBT_FACTION).size() == 2,
		"both penalties should be listed for the faction"
	)

	FactionManager.process_ongoing_effects(1)
	_expect(
		FactionManager.get_reputation(DEBT_FACTION) == before - 8,
		"a day of two debts should cost 8 reputation, went %d -> %d" % [before, FactionManager.get_reputation(DEBT_FACTION)]
	)

	_expect(FactionManager.clear_daily_penalty(DEBT_FACTION, "unpaid_debt"), "clearing a penalty reported nothing to clear")
	_expect(not FactionManager.has_penalty(DEBT_FACTION, "unpaid_debt"), "a cleared penalty is still registered")

	FactionManager.clear_all_penalties_for_faction(DEBT_FACTION)
	_expect(
		FactionManager.get_faction_penalties(DEBT_FACTION).is_empty(),
		"clearing a faction's penalties left some behind"
	)

	var after_clear: int = FactionManager.get_reputation(DEBT_FACTION)
	FactionManager.process_ongoing_effects(2)
	_expect(
		FactionManager.get_reputation(DEBT_FACTION) == after_clear,
		"a cleared debt still charged the player"
	)


# =============================================================================

func _check_income() -> void:
	_reset()

	var starting_gold: int = InventoryManager.gold
	_expect(
		FactionManager.add_ongoing_effect("millbrook_extortion", {
			"type": "gold",
			"amount": 25,
			"reason_display": "The camp's share",
			"source": "bandit_boss"
		}),
		"an extortion income effect would not register"
	)
	_expect(FactionManager.get_daily_income() == 25, "daily income should be 25, got %d" % FactionManager.get_daily_income())

	FactionManager.process_ongoing_effects(1)
	_expect(
		InventoryManager.gold == starting_gold + 25,
		"a day of extortion should have paid 25, gold went %d -> %d" % [starting_gold, InventoryManager.gold]
	)

	# The same arrangement can cost as well as pay.
	FactionManager.add_ongoing_effect("crew_upkeep", {
		"type": "gold",
		"amount": -10,
		"reason_display": "Feeding the crew",
		"source": "bandit_boss"
	})
	_expect(FactionManager.get_daily_income() == 15, "income net of upkeep should be 15, got %d" % FactionManager.get_daily_income())

	var before_second_day: int = InventoryManager.gold
	FactionManager.process_ongoing_effects(2)
	_expect(
		InventoryManager.gold == before_second_day + 15,
		"a day of pay and upkeep should net 15, gold went %d -> %d" % [before_second_day, InventoryManager.gold]
	)

	# Losing the camp ends every part of the arrangement at once.
	var cleared: int = FactionManager.clear_ongoing_effects_from_source("bandit_boss")
	_expect(cleared == 2, "losing the camp should have ended both effects, ended %d" % cleared)
	_expect(FactionManager.get_daily_income() == 0, "income continued after the arrangement ended")

	# A malformed effect must be refused rather than half-registered.
	_expect(not FactionManager.add_ongoing_effect("nonsense", {"type": "favour", "amount": 1}), "an unknown effect type was accepted")
	_expect(
		not FactionManager.add_ongoing_effect("no_such_faction", {"type": "reputation", "faction": "_nobody", "amount": -1}),
		"an effect naming a faction that does not exist was accepted"
	)


# =============================================================================

func _check_hostility() -> void:
	_reset()

	_expect(FactionManager.get_hostility("town_guard") == 0, "hostility should start at nothing")
	_expect(not FactionManager.is_hunting_player("town_guard"), "the guard should not start out hunting the player")

	FactionManager.add_ongoing_effect("guards_know", {
		"type": "hostility",
		"faction": "town_guard",
		"amount": 30,
		"reason_display": "The guard knows who runs the camp",
		"source": "bandit_boss"
	})

	FactionManager.process_ongoing_effects(1)
	_expect(FactionManager.get_hostility("town_guard") == 30, "one day should have raised hostility to 30, got %d" % FactionManager.get_hostility("town_guard"))
	_expect(not FactionManager.is_hunting_player("town_guard"), "30 is below the hunting line and should not count as a hunt")

	FactionManager.process_ongoing_effects(2)
	_expect(FactionManager.get_hostility("town_guard") == 60, "two days should have raised hostility to 60, got %d" % FactionManager.get_hostility("town_guard"))
	_expect(FactionManager.is_hunting_player("town_guard"), "60 is over the line and the guard should be hunting")
	_expect(
		WorldState.has_flag("town_guard_hunting_player"),
		"crossing the hunting line did not become a world fact other zones can read"
	)

	# It has a ceiling, and coming back down withdraws the fact again.
	for day: int in range(3, 10):
		FactionManager.process_ongoing_effects(day)
	_expect(FactionManager.get_hostility("town_guard") == 100, "hostility should cap at 100, got %d" % FactionManager.get_hostility("town_guard"))

	FactionManager.set_hostility("town_guard", 10)
	_expect(
		not WorldState.has_flag("town_guard_hunting_player"),
		"the hunt ended and the world fact did not"
	)


# =============================================================================

func _check_join_mechanics() -> void:
	_reset()

	var bandits: FactionData = FactionManager.get_faction(TEST_FACTION)
	if bandits == null:
		return

	# The front door: a crew that does not know you will not have you.
	_expect(not FactionManager.join_faction(TEST_FACTION), "a stranger was let into the crew")

	FactionManager.modify_reputation(TEST_FACTION, bandits.join_threshold - FactionManager.get_reputation(TEST_FACTION), "check", false)
	_expect(FactionManager.join_faction(TEST_FACTION), "a man who earned it was refused")
	_expect(FactionManager.is_member(TEST_FACTION), "joining did not make him a member")

	# The other door: take the chair.
	var top_rank: String = str((bandits.ranks[bandits.ranks.size() - 1] as Dictionary).get("name", ""))
	_expect(FactionManager.force_join_faction(TEST_FACTION, top_rank), "taking the top rank by force failed")
	_expect(FactionManager.get_rank(TEST_FACTION) == top_rank, "he took the chair and the ledger says '%s'" % FactionManager.get_rank(TEST_FACTION))
	_expect(
		FactionManager.has_rank(TEST_FACTION, top_rank),
		"the rank he holds does not satisfy a check for the rank he holds"
	)

	# The promotion has to stick: reputation must be at or above the rank's
	# floor, or the next reputation tick demotes him again.
	var floor_rep: int = int((bandits.ranks[bandits.ranks.size() - 1] as Dictionary).get("min_reputation", 0))
	_expect(
		FactionManager.get_reputation(TEST_FACTION) >= floor_rep,
		"the chief's standing (%d) is below his own rank's floor (%d)" % [FactionManager.get_reputation(TEST_FACTION), floor_rep]
	)

	# Force-joining a crew that never heard of him works too, from cold.
	_reset()
	_expect(FactionManager.force_join_faction(TEST_FACTION, top_rank), "taking the chair from cold failed")
	_expect(FactionManager.is_member(TEST_FACTION), "taking the chair did not make him a member")

	_expect(not FactionManager.force_join_faction(TEST_FACTION, "Emperor Of Everything"), "a rank that does not exist was granted")
	_expect(not FactionManager.force_join_faction("_no_such_crew", ""), "a faction that does not exist was joined")


# =============================================================================

func _check_round_trip() -> void:
	_reset()

	FactionManager.modify_reputation(TEST_FACTION, 40, "check", false)
	FactionManager.force_join_faction(TEST_FACTION, "Cutthroat")
	FactionManager.add_ongoing_effect("millbrook_extortion", {
		"type": "gold", "amount": 25, "reason_display": "The camp's share", "source": "bandit_boss"
	})
	FactionManager.add_ongoing_effect("guards_know", {
		"type": "hostility", "faction": "town_guard", "amount": 5, "reason_display": "Word travels", "source": "bandit_boss"
	})
	FactionManager.add_daily_penalty(DEBT_FACTION, "unpaid_debt", -5, "Unpaid debt")
	FactionManager.set_hostility("town_guard", 42)

	var before: Dictionary = FactionManager.to_dict()

	# Through JSON, the way a save actually travels.
	var parsed: Variant = JSON.parse_string(JSON.stringify(before))
	if not (parsed is Dictionary):
		_failures.append("faction state did not survive JSON at all")
		return

	FactionManager.reset()
	FactionManager.from_dict(parsed as Dictionary)
	var after: Dictionary = FactionManager.to_dict()

	for key: String in before:
		_expect(
			JSON.stringify(before[key]) == JSON.stringify(after[key]),
			"faction save section '%s' changed across a round trip:\n      before %s\n      after  %s" % [
				key, JSON.stringify(before[key]), JSON.stringify(after[key])
			]
		)

	# And the reloaded state must still tick.
	_expect(FactionManager.get_daily_income() == 25, "income did not survive the reload, got %d" % FactionManager.get_daily_income())
	_expect(FactionManager.get_hostility("town_guard") == 42, "hostility did not survive the reload, got %d" % FactionManager.get_hostility("town_guard"))
	_expect(FactionManager.has_penalty(DEBT_FACTION, "unpaid_debt"), "the debt did not survive the reload")
	_expect(FactionManager.get_rank(TEST_FACTION) == "Cutthroat", "the rank did not survive the reload, got '%s'" % FactionManager.get_rank(TEST_FACTION))

	# A save written before the ticker was generalized still carries its debts.
	FactionManager.reset()
	FactionManager.from_dict({
		"reputations": {},
		"memberships": {},
		"daily_penalties": {DEBT_FACTION: {"old_debt": {"amount": -4, "reason_display": "An old debt"}}}
	})
	_expect(FactionManager.has_penalty(DEBT_FACTION, "old_debt"), "an old save's debts were dropped on load")
	_expect(
		FactionManager.get_total_daily_penalty(DEBT_FACTION) == -4,
		"an old save's debt came back at the wrong size: %d" % FactionManager.get_total_daily_penalty(DEBT_FACTION)
	)

	_reset()
