extends Node
## Faction loop check: quest -> reputation -> cascade -> gate -> rank -> flag.
##
## Usage: godot --headless --path . res://tools/check_faction_loop.tscn
##
## Runs as a scene, not with --script: FactionManager, QuestManager,
## GuildRankManager, FlagManager and DialogueManager are all autoloads, and the
## point of this check is that they talk to each other.
##
## Every previous audit of the faction system read the code and declared the
## chain wired. This one runs it. Each link is exercised through the real API a
## player's actions would reach, and asserts the state the NEXT link needs:
##
##   L1  a quest's `faction_reputation` reward actually lands on FactionManager
##   L2  the change cascades to allies, enemies, parent and children, and every
##       id named in a cascade list resolves to a faction that exists
##   L3  a dialogue REPUTATION condition reads the reputation the quest wrote
##   L4  GuildRankManager counts the quest, because the reward named a guild
##   L5  reputation + quest count together promote the player
##   L6  the promotion writes the rank flag dialogue gates on
##   L7  the ongoing-effects ticker moves reputation on a day change
##   L8  the eight factions authored 8/1 load, and nothing they point at is dead
##   L9  the bandit chair is reachable and hostility follows it
##   L10 deep devotion to one temple closes the other two, and shallow service
##       to all three stays open
##
## L10 is the devotion lockout. The rule is not invented here: each priest says
## it out loud ("deep devotion can only be given to one" -
## priest_chronos_dalhurst.json, node devotee_inquiry), refuses a rival's
## devotee in his own voice (node already_other_devotee), and
## design/gdd/quest-system.md documents `forbidden_flags` using these exact
## flags as its example. This check is what makes the speech true.

var _failures: Array[String] = []
var _checks: int = 0

## The eight factions the dispositions pass authored on 8/1. Their cascade
## lists are the most likely place for a dead id to hide, because they were
## written against a faction roster that was still growing.
const NEW_FACTIONS: Array[String] = [
	"merchant_guild", "common_folk", "nobility", "hunters_guild",
	"scholars_guild", "shadowed_hand_cult", "aberdeen", "larton",
]

const DEITIES: Array[String] = ["chronos", "gaela", "morthane"]

## Cascade ids that name no faction and have no determinate target, with the
## reason each is still written down. A dead id is silent - `_cascade_reputation`
## skips it and nothing warns - so the relationship a writer authored simply
## does not exist. These four are recorded rather than repaired because picking
## a target for them is Caleb's call, not a mechanical fix; the evidence for
## each is in docs/audits/faction_exclusivity_audit.md.
##
## The point of the list is that it is closed: a NEW dead id fails this check.
## An entry that stops being needed also fails, as a stale excuse.
const KNOWN_DEAD_CASCADE_IDS: Dictionary = {
	# `undead` used to sit here as "enemy category, not a political faction".
	# It is a faction now (data/factions/undead.tres): the six lists that named
	# it resolve, and player reputation with it starts at 0 and is moved by
	# nothing yet, which is content and not a defect.
	#
	# Both are listed as allies of human_empire - parts of itself. Repointing
	# either at human_empire would make that faction list itself.
	"the_crown": "names a part of human_empire; no separate faction is intended",
	"imperial_army": "names a part of human_empire; no separate faction is intended",
	# the_keepers.enemies. No character or faction by this name exists anywhere
	# in the repository.
	"the_witch": "names nothing in the repository",
}

## Each temple's chain, split at the devotion choice. Quests 1-4 are open
## service - the priests offer them to anyone. Quest 5 onward is the bond.
const TEMPLE_CHAINS: Dictionary = {
	"chronos": {
		"flag": "chronos_devotee",
		"open": ["chronos_01_first_vision", "chronos_04_false_prophet"],
		"bond": ["chronos_05_devotion_choice", "chronos_06_temporal_echo",
			"chronos_10_eternal_vigil", "chronos_repeatable_visions"],
	},
	"gaela": {
		"flag": "gaela_devotee",
		"open": ["gaela_01_first_offering", "gaela_04_sacred_grove"],
		"bond": ["gaela_05_devotion_choice", "gaela_06_blight_source",
			"gaela_10_lifebringer", "gaela_repeatable_tending"],
	},
	"morthane": {
		"flag": "morthane_devotee",
		"open": ["morthane_01_last_rites", "morthane_04_necromancer_trail"],
		"bond": ["morthane_05_devotion_choice", "morthane_06_death_speaker",
			"morthane_10_deathwalker", "morthane_repeatable_cleansing"],
	},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _settle()

	# Each check resets first, but a quest completed in the previous one can
	# still have deferred work in flight - `next_quest` chaining lands a frame
	# later, and it lands on top of the reset. So the frame is drained between
	# checks, not just at the start.
	_check_reward_lands()
	await _settle()
	_check_cascade()
	await _settle()
	_check_no_dead_cascade_ids()
	await _settle()
	_check_dialogue_reads_reputation()
	await _settle()
	_check_guild_quest_count_and_promotion()
	await _settle()
	_check_rank_flag_gates_dialogue()
	await _settle()
	_check_ticker_moves_reputation()
	await _settle()
	_check_new_factions_are_reachable()
	await _settle()
	_check_bandit_chair()
	await _settle()
	_check_devotion_lockout()
	await _settle()
	_check_devotion_decline_ends_chain()

	print("")
	print("Checks run: %d" % _checks)
	if _failures.is_empty():
		print("Faction loop check: PASS")
		get_tree().quit(0)
		return

	print("Faction loop check: FAIL (%d)" % _failures.size())
	for failure: String in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)


## Drain deferred work so it cannot land on the next check's clean slate.
func _settle() -> void:
	for _i: int in 3:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _reset() -> void:
	FactionManager.reset()
	FlagManager.flags.clear()
	GuildRankManager.reset_for_new_game()
	QuestManager.reset_for_new_game()
	WorldState.reset_for_new_game()


## Complete a quest the way finishing it would, so its reward block runs.
##
## Walks the quest's prerequisites first. A player reaches quest three by doing
## quests one and two, and start_quest refuses in that order - so a probe that
## calls it cold measures nothing except its own impatience.
func _finish(quest_id: String, depth: int = 0) -> bool:
	if QuestManager.is_quest_completed(quest_id):
		return true
	if depth > 12:
		return false

	var template: QuestManager.Quest = QuestManager.quest_database.get(quest_id)
	if template == null:
		return false

	for prereq: String in template.prerequisites:
		if not _finish(prereq, depth + 1):
			return false

	if not QuestManager.start_quest(quest_id):
		return false
	QuestManager.complete_quest(quest_id)
	return QuestManager.is_quest_completed(quest_id)


# =============================================================================
# L1 - the reward lands
# =============================================================================

func _check_reward_lands() -> void:
	_reset()

	# gaela_03_protect_harvest pays church_of_gaela 20, church_of_three 15 and
	# millbrook 25. Millbrook is the interesting one: a town, not a church, so
	# it proves the reward block is read whole rather than for churches only.
	var before: int = FactionManager.get_reputation("millbrook")
	_expect(_finish("gaela_03_protect_harvest"), "gaela_03_protect_harvest could not be started and completed")

	var after: int = FactionManager.get_reputation("millbrook")
	_expect(
		after > before,
		"a quest's faction_reputation reward did not reach FactionManager: millbrook %d -> %d" % [before, after]
	)
	_expect(
		FactionManager.get_reputation("church_of_gaela") > 0,
		"church_of_gaela did not move on a Gaela quest, got %d" % FactionManager.get_reputation("church_of_gaela")
	)


# =============================================================================
# L2 - it cascades
# =============================================================================

func _check_cascade() -> void:
	_reset()

	# Measured as a delta, because factions start at their own
	# `default_reputation` and the thieves start the player at -30.
	var thieves_before: int = FactionManager.get_reputation("thieves_guild")
	var empire_before: int = FactionManager.get_reputation("human_empire")

	FactionManager.modify_reputation("thieves_guild", 40, "probe")

	_expect(
		FactionManager.get_reputation("thieves_guild") == thieves_before + 40,
		"the direct reputation change did not apply: %d -> %d" % [
			thieves_before, FactionManager.get_reputation("thieves_guild")
		]
	)

	# human_empire is on the thieves' enemies list, so pleasing the guild must
	# cost the player with the empire.
	var empire_after: int = FactionManager.get_reputation("human_empire")
	_expect(
		empire_after < empire_before,
		"enemy cascade did not fire: human_empire %d -> %d after the player pleased the thieves" % [
			empire_before, empire_after
		]
	)

	_reset()

	# church_of_chronos is a child of church_of_three: pleasing the child must
	# lift the parent.
	FactionManager.modify_reputation("church_of_chronos", 40, "probe")
	_expect(
		FactionManager.get_reputation("church_of_three") > 0,
		"parent cascade did not fire: church_of_three is %d" % FactionManager.get_reputation("church_of_three")
	)


## Every id in an allies/enemies/neutrals/parent list must name a faction that
## exists. A dead id is silent - the cascade loop simply skips it - so the
## relationship a writer authored is absent and nothing ever says so.
func _check_no_dead_cascade_ids() -> void:
	var seen_dead: Dictionary = {}

	for faction_id: String in FactionManager.factions:
		var faction: FactionData = FactionManager.factions[faction_id]
		var lists: Dictionary = {
			"allies": faction.allies,
			"enemies": faction.enemies,
			"neutrals": faction.neutrals,
		}
		for list_name: String in lists:
			for other_id: String in lists[list_name]:
				_expect(
					FactionManager.factions.has(other_id) or KNOWN_DEAD_CASCADE_IDS.has(other_id),
					"%s.%s names '%s', which is not a faction" % [faction_id, list_name, other_id]
				)
				_expect(
					other_id != faction_id,
					"%s lists itself in %s" % [faction_id, list_name]
				)
				seen_dead[other_id] = true
		if not faction.parent_faction.is_empty():
			_expect(
				FactionManager.factions.has(faction.parent_faction),
				"%s.parent_faction names '%s', which is not a faction" % [faction_id, faction.parent_faction]
			)

	# A recorded excuse that nothing needs any more is itself a defect.
	for dead_id: String in KNOWN_DEAD_CASCADE_IDS:
		_expect(
			seen_dead.has(dead_id),
			"KNOWN_DEAD_CASCADE_IDS still excuses '%s', which no faction names any more - delete the entry"
				% dead_id
		)


# =============================================================================
# L3 - dialogue reads what the quest wrote
# =============================================================================

func _check_dialogue_reads_reputation() -> void:
	_reset()

	var condition := DialogueCondition.new()
	condition.type = DialogueData.ConditionType.REPUTATION
	condition.param_string = "church_of_gaela"
	condition.param_int = 15

	_expect(
		not DialogueManager.evaluate_condition(condition),
		"a reputation gate stood open before the player had earned anything (church_of_gaela=%d)"
			% FactionManager.get_reputation("church_of_gaela")
	)

	_expect(_finish("gaela_03_protect_harvest"), "gaela_03_protect_harvest could not be completed for the gate test")

	_expect(
		DialogueManager.evaluate_condition(condition),
		"a reputation gate stayed shut after the quest that should open it: church_of_gaela is %d, gate wants 15"
			% FactionManager.get_reputation("church_of_gaela")
	)


# =============================================================================
# L4 + L5 - the guild counts the quest, and promotes
# =============================================================================

func _check_guild_quest_count_and_promotion() -> void:
	_reset()

	_expect(
		GuildRankManager.get_guild_quest_count("adventurers_guild") == 0,
		"the guild quest count did not start at zero"
	)

	# The Guild's own quests pay adventurers_guild reputation, which is the
	# only thing that tells GuildRankManager a guild quest was done.
	FactionManager.modify_reputation("adventurers_guild", 30, "probe: joining")
	var joined: bool = FactionManager.join_faction("adventurers_guild")
	_expect(joined, "the player could not join the Adventurer's Guild at reputation 30")

	var counted: int = 0
	for quest_id: String in ["adventurers_01_proving_ground", "adventurers_02_pest_control", "adventurers_03_escort_duty"]:
		if _finish(quest_id):
			counted += 1

	_expect(counted > 0, "no Adventurer's Guild quest could be completed, so the counting link is untested")

	var count: int = GuildRankManager.get_guild_quest_count("adventurers_guild")
	_expect(
		count >= counted,
		"GuildRankManager counted %d guild quests after %d completed with adventurers_guild in their rewards" % [count, counted]
	)

	# Journeyman wants reputation 25 and 3 quests. Give it both and it must
	# promote off its own signal path, not because this check said so.
	GuildRankManager.add_guild_quest_completion("adventurers_guild", 3)
	FactionManager.modify_reputation("adventurers_guild", 30, "probe: earning the rank")
	GuildRankManager.check_rank_promotion("adventurers_guild")

	_expect(
		GuildRankManager.get_guild_rank_level("adventurers_guild") >= 1,
		"the player met both Journeyman requirements and was not promoted (rep %d, quests %d, level %d)" % [
			FactionManager.get_reputation("adventurers_guild"),
			GuildRankManager.get_guild_quest_count("adventurers_guild"),
			GuildRankManager.get_guild_rank_level("adventurers_guild"),
		]
	)


# =============================================================================
# L6 - the promotion writes the flag dialogue gates on
# =============================================================================

func _check_rank_flag_gates_dialogue() -> void:
	# Continues from the promotion above deliberately: this is the same run of
	# state a player would be carrying.
	var rank_flag: String = FlagManager.get_guild_rank_flag("adventurers_guild")
	_expect(
		not rank_flag.is_empty(),
		"the player was promoted and no adventurers_guild rank flag was written"
	)

	if rank_flag.is_empty():
		return

	var condition := DialogueCondition.new()
	condition.type = DialogueData.ConditionType.FLAG_SET
	condition.param_string = rank_flag

	_expect(
		DialogueManager.evaluate_condition(condition),
		"the rank flag '%s' was written but a dialogue FLAG_SET gate could not read it" % rank_flag
	)

	_expect(
		QuestManager.is_quest_available("__nonexistent_quest__") == false,
		"is_quest_available answered true for a quest that does not exist"
	)


# =============================================================================
# L7 - the daily ticker moves reputation
# =============================================================================

func _check_ticker_moves_reputation() -> void:
	_reset()

	FactionManager.add_daily_penalty("merchant_guild", "unpaid_debt", -5, "Unpaid debt")
	var before: int = FactionManager.get_reputation("merchant_guild")
	FactionManager.process_ongoing_effects(2)
	var after: int = FactionManager.get_reputation("merchant_guild")

	_expect(
		after < before,
		"a standing debt did not cost reputation on a day change: merchant_guild %d -> %d" % [before, after]
	)


# =============================================================================
# L8 - the eight new factions are real and reachable
# =============================================================================

func _check_new_factions_are_reachable() -> void:
	_reset()

	for faction_id: String in NEW_FACTIONS:
		_expect(
			FactionManager.factions.has(faction_id),
			"faction '%s' does not load" % faction_id
		)
		if not FactionManager.factions.has(faction_id):
			continue

		var faction: FactionData = FactionManager.factions[faction_id]
		_expect(not faction.ranks.is_empty(), "faction '%s' has no ranks, so standing means nothing" % faction_id)

		# Reputation must be able to reach the top rank. A ladder whose top
		# rung sits above MAX_REPUTATION is a rank nobody can hold.
		var top: int = 0
		for rank: Dictionary in faction.ranks:
			top = maxi(top, int(rank.get("min_reputation", 0)))
		_expect(
			top <= FactionManager.MAX_REPUTATION,
			"faction '%s' has a top rank at %d, above the reputation ceiling of %d" % [
				faction_id, top, FactionManager.MAX_REPUTATION
			]
		)

		# And something must actually be able to move it.
		FactionManager.modify_reputation(faction_id, 10, "probe")
		_expect(
			FactionManager.get_reputation(faction_id) != faction.default_reputation,
			"faction '%s' did not move when a reward paid it" % faction_id
		)
		_reset()


# =============================================================================
# L9 - the bandit chair
# =============================================================================

func _check_bandit_chair() -> void:
	_reset()

	_expect(FactionManager.factions.has("bandits"), "the bandits faction does not load")

	var took_it: bool = FactionManager.force_join_faction("bandits", "Chief")
	_expect(took_it, "force_join_faction could not seat the player as Chief of the bandits")
	_expect(FactionManager.is_member("bandits"), "the player took the chair and is not a member")
	_expect(
		FactionManager.get_rank("bandits") == "Chief",
		"the player took the chair and holds rank '%s'" % FactionManager.get_rank("bandits")
	)

	# Being the chief must be visible to the people who would hunt him.
	FactionManager.add_hostility("town_guard", 60, "probe: the chair")
	_expect(
		FactionManager.is_hunting_player("town_guard"),
		"the town guard is not hunting a bandit chief at hostility %d" % FactionManager.get_hostility("town_guard")
	)
	_expect(
		WorldState.has_flag("town_guard_hunting_player"),
		"crossing the hunting line did not write the world fact other zones read"
	)


# =============================================================================
# L10 - the devotion lockout
# =============================================================================

## Shallow service to all three temples stays open; deep devotion to one closes
## the other two. Both halves are asserted, because a lockout that also shuts
## the introductory quests would contradict what the priests say.
func _check_devotion_lockout() -> void:
	for deity: String in DEITIES:
		_reset()

		var chain: Dictionary = TEMPLE_CHAINS[deity]
		FlagManager.set_flag(chain["flag"])

		for other: String in DEITIES:
			if other == deity:
				continue
			var other_chain: Dictionary = TEMPLE_CHAINS[other]

			# The other temple's open service must stay available.
			for quest_id: String in other_chain["open"]:
				var template: QuestManager.Quest = QuestManager.quest_database.get(quest_id)
				_expect(template != null, "quest '%s' does not load" % quest_id)
				if template == null:
					continue
				_expect(
					not FlagManager.has_flag(chain["flag"]) or template.forbidden_flags.is_empty()
						or not (chain["flag"] as String) in template.forbidden_flags,
					"a devotee of %s is refused '%s', but the priests offer open service to anyone" % [deity, quest_id]
				)

			# The other temple's bond must be closed.
			for quest_id: String in other_chain["bond"]:
				var template: QuestManager.Quest = QuestManager.quest_database.get(quest_id)
				_expect(template != null, "quest '%s' does not load" % quest_id)
				if template == null:
					continue
				_expect(
					(chain["flag"] as String) in template.forbidden_flags,
					"'%s' does not forbid %s, so a devotee of %s can take a second god's bond" % [
						quest_id, chain["flag"], deity
					]
				)
				_expect(
					not QuestManager.is_quest_available(quest_id),
					"'%s' is offered to a devotee of %s - the lockout the priest describes does not fire" % [quest_id, deity]
				)

	_reset()


## Declining is the other half of the same choice. The priests say the path
## closes; the chain must actually stop rather than run on the strength of
## having finished the quest where the player said no.
func _check_devotion_decline_ends_chain() -> void:
	for deity: String in DEITIES:
		_reset()

		var chain: Dictionary = TEMPLE_CHAINS[deity]
		var bond: Array = chain["bond"]

		for quest_id: String in bond:
			if quest_id.ends_with("_05_devotion_choice"):
				continue
			var template: QuestManager.Quest = QuestManager.quest_database.get(quest_id)
			if template == null:
				continue
			_expect(
				(chain["flag"] as String) in template.flag_prerequisites,
				"'%s' does not require %s, so declining devotion still unlocks it" % [quest_id, chain["flag"]]
			)

	_reset()
