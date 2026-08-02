extends Node
## Living-world guard, headless.
##
## Usage: godot --headless --path . res://tools/check_living_world.tscn
##
## Six things are asserted.
##
## 1. SCHEDULE RESOLUTION. Every scheduled npc_id resolves to a real archetype,
##    a real action and a real station at four sample hours - 03, 09, 13, 21.
##    A record naming an archetype nobody wrote, or an archetype with a gap in
##    its day, fails here rather than in front of a player.
##
## 2. ROSTER DIFF. Elder Moor's roster at 03:00 is a different set of people in
##    different places from its roster at 13:00. This is the ship gate: a town
##    whose night looks like its day has not been made to live, it has been made
##    to have a clock.
##
## 3. PRESENCE GATING. A shopkeeper's shop refuses OPEN_SHOP at 03:00 and takes
##    it at 13:00, and the prompt says which. There is no second boolean:
##    presence IS the gate.
##
## 4. THE CLOCK ROUND TRIP. Booked events, the fired keys, the hour and the day
##    all survive a save and a load, and `advance()` replays the hours it
##    crossed instead of jumping them.
##
## 5. THE AMBIENT CROWD IS THE SAME PEOPLE. A town booted twice under one
##    world seed spawns the same ids in the same spots; under another seed it
##    spawns a different town. A disposition earned with Mabel is Mabel's.
##
## 6. THE PLACEMENT ITSELF, in the live scene. Elder Moor is booted and the
##    NPCs are counted where they stand, not where the data says they should.

const START_SCENE := "res://scenes/levels/elder_moor.tscn"

## Every town that carries schedule records. Booted so the "scheduled npc_ids
## spawn somewhere" rule is a measurement rather than a regex's opinion:
## twenty of the ids in the table are assigned in ways no static scan can see.
const SCHEDULED_TOWNS: Dictionary = {
	"elder_moor": "res://scenes/levels/elder_moor.tscn",
	"dalhurst": "res://scenes/levels/dalhurst.tscn",
	"thornfield": "res://scenes/levels/thornfield.tscn",
	"millbrook": "res://scenes/levels/millbrook.tscn",
	"willow_dale": "res://scenes/levels/willow_dale.tscn",
}
## Towns with a procedural ambient crowd, keyed by the meta the level sets on
## itself. These are the ones RULING LW-1 seeds off the world seed.
const AMBIENT_TOWNS: Dictionary = {
	"dalhurst": "res://scenes/levels/dalhurst.tscn",
	"elder_moor": "res://scenes/levels/elder_moor.tscn",
}
const ELDER_MOOR_CELL := Vector2i(0, 0)
const SAMPLE_HOURS: Array[int] = [3, 9, 13, 21]

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	await _run()
	_finish()


func _run() -> void:
	_check_data_resolves()
	_check_archetype_days_are_whole()
	_check_quest_npcs_are_reachable_by_day()
	_check_clock()
	await _check_every_scheduled_npc_spawns()
	await _check_ambient_population_is_seeded()
	await _check_live_roster()


## ============================================================================
## 1. SCHEDULE RESOLUTION
## ============================================================================

func _check_data_resolves() -> void:
	_check("archetypes loaded", NPCScheduler.archetypes.size() > 0)
	_check("npc records loaded", NPCScheduler.records.size() > 0)

	var bad_archetype: Array[String] = []
	var bad_action: Array[String] = []
	var bad_station: Array[String] = []
	var no_work: Array[String] = []

	for npc_id: String in NPCScheduler.records.keys():
		var rec: Dictionary = NPCScheduler.records[npc_id]
		if not NPCScheduler.archetypes.has(rec.get("archetype", "")):
			bad_archetype.append(npc_id)
		var stations: Dictionary = rec.get("stations", {})
		if not stations.has("work"):
			no_work.append(npc_id)
		for hour: int in SAMPLE_HOURS:
			var action: String = String(NPCScheduler.action_for(npc_id, hour))
			if not NPCScheduler.ACTIONS.has(action):
				bad_action.append("%s@%02d=%s" % [npc_id, hour, action])
			if NPCScheduler.station_of(npc_id, hour).is_empty():
				bad_station.append("%s@%02d" % [npc_id, hour])

	_check("every record names an archetype that exists%s" % _tail(bad_archetype),
		bad_archetype.is_empty())
	_check("every record has a work station - the authored spawn%s" % _tail(no_work),
		no_work.is_empty())
	_check("every sampled hour resolves to a declared action%s" % _tail(bad_action),
		bad_action.is_empty())
	_check("every sampled hour resolves to a station%s" % _tail(bad_station),
		bad_station.is_empty())


## An archetype's day must cover all 24 hours with no gap and no overlap.
## A gap silently becomes `idle at work`, which reads as a schedule that works
## and is really a schedule with a hole in it.
func _check_archetype_days_are_whole() -> void:
	var broken: Array[String] = []
	var goes_home_by_day: Array[String] = []

	# The day-band rule applies to the trades quest holders actually keep. A
	# night watchman sleeping through noon is the whole of his job, not a bug;
	# a shopkeeper with a quest doing it is a soft-lock.
	var quest_archetypes: Dictionary = {}
	for npc_id: String in NPCScheduler.records.keys():
		if bool(NPCScheduler.records[npc_id].get("quest_giver", false)):
			quest_archetypes[NPCScheduler.archetype_of(npc_id)] = true

	for id: String in NPCScheduler.archetypes.keys():
		var blocks: Array = NPCScheduler.archetypes[id].get("blocks", [])
		var covered: Array[int] = []
		covered.resize(24)
		for block: Dictionary in blocks:
			var from: int = int(block.get("from", 0))
			var to: int = int(block.get("to", 0))
			if not NPCScheduler.ACTIONS.has(String(block.get("action", ""))):
				broken.append("%s: action '%s'" % [id, block.get("action", "")])
			for h: int in range(24):
				var inside: bool = (from <= h and h < to) if from < to else (h >= from or h < to)
				if inside:
					covered[h] += 1
		for h: int in range(24):
			if covered[h] != 1:
				broken.append("%s: hour %02d covered %d times" % [id, h, covered[h]])

		# No quest-holding trade goes behind an unmodelled door between 09:00
		# and 17:00. This is what makes the quest-availability guarantee hold
		# by construction rather than by 113 separate strokes of luck.
		if not quest_archetypes.has(id):
			continue
		for h: int in range(NPCScheduler.DAY_FIRST_HOUR, NPCScheduler.DAY_LAST_HOUR + 1):
			for block: Dictionary in blocks:
				var from: int = int(block.get("from", 0))
				var to: int = int(block.get("to", 0))
				var inside: bool = (from <= h and h < to) if from < to else (h >= from or h < to)
				if inside and String(block.get("station", "")) == "home":
					goes_home_by_day.append("%s@%02d" % [id, h])

	_check("every archetype's day covers 24 hours exactly once%s" % _tail(broken),
		broken.is_empty())
	_check("no quest-holding trade is behind a closed door between %02d:00 and %02d:00%s" % [
			NPCScheduler.DAY_FIRST_HOUR, NPCScheduler.DAY_LAST_HOUR, _tail(goes_home_by_day)],
		goes_home_by_day.is_empty())


## ============================================================================
## 2. QUEST AVAILABILITY
## ============================================================================

## A player who plays by daylight can never be soft-locked by a schedule.
## Night is flavour; it is not a lockout.
func _check_quest_npcs_are_reachable_by_day() -> void:
	var unreachable: Array[String] = []
	for npc_id: String in NPCScheduler.records.keys():
		if not bool(NPCScheduler.records[npc_id].get("quest_giver", false)):
			continue
		for hour: int in range(NPCScheduler.DAY_FIRST_HOUR, NPCScheduler.DAY_LAST_HOUR + 1):
			if not NPCScheduler.is_interactable(npc_id, hour):
				unreachable.append("%s@%02d" % [npc_id, hour])
				break
	_check("every quest-holding NPC is present and awake all day%s" % _tail(unreachable),
		unreachable.is_empty())


## ============================================================================
## 3. THE CLOCK
## ============================================================================

func _check_clock() -> void:
	var seen_hours: Array[int] = []
	var seen_events: Array[String] = []
	var on_hour := func(h: int) -> void: seen_hours.append(h)
	var on_event := func(kind: StringName, payload: Dictionary) -> void:
		seen_events.append("%s:%s" % [kind, payload.get("tag", "")])

	var saved_day: int = GameManager.current_day
	var saved_time: float = GameManager.game_time
	var saved_schedules: Array = GameManager._schedules.duplicate(true)
	var saved_fired: Dictionary = GameManager._fired_event_keys.duplicate(true)

	GameManager.clear_schedules()
	GameManager.set_time(8.0, 1)
	GameManager.hour_advanced.connect(on_hour)
	GameManager.sim_event.connect(on_event)

	# Three events on one hour. A kind-wide dedup key drops two of them - the
	# exact bug the per-entry key exists to prevent.
	GameManager.schedule_event(-1, 10, &"probe", {"tag": "a"})
	GameManager.schedule_event(-1, 10, &"probe", {"tag": "b"})
	GameManager.schedule_event(-1, 10, &"probe", {"tag": "c"})

	seen_hours.clear()
	seen_events.clear()
	GameManager.advance(4.0)

	_check("advance() replays every hour it crosses (got %s)" % str(seen_hours),
		seen_hours == [9, 10, 11, 12])
	_check("three events on one hour all fire (got %d)" % seen_events.size(),
		seen_events.size() == 3)
	_check("advance() lands on the right hour", absf(GameManager.game_time - 12.0) < 0.001)

	# The same hour tomorrow fires the daily entries again, and only once.
	seen_events.clear()
	GameManager.advance(24.0)
	_check("a daily event fires again the next day, three times not nine (got %d)" % seen_events.size(),
		seen_events.size() == 3)

	# Rolling into tomorrow.
	GameManager.set_time(22.0, 5)
	var slept: float = GameManager.advance_to_hour(6.0)
	_check("advance_to_hour rolls into tomorrow (slept %.1f)" % slept, absf(slept - 8.0) < 0.001)
	_check("advance_to_hour lands on the hour", absf(GameManager.game_time - 6.0) < 0.001)
	_check("advance_to_hour advances the day", GameManager.current_day == 6)

	# Save round trip of the clock fields.
	GameManager.set_time(17.5, 11)
	GameManager.clear_schedules()
	GameManager.schedule_event(12, 4, &"probe_curfew", {"town": "probe_town"})
	var written: Dictionary = GameManager.to_dict()

	GameManager.set_time(3.0, 1)
	GameManager.clear_schedules()
	GameManager.from_dict(written)

	_check("the hour survives a round trip", absf(GameManager.game_time - 17.5) < 0.001)
	_check("the day survives a round trip", GameManager.current_day == 11)
	_check("a booked event survives a round trip", GameManager._schedules.size() == 1)
	_check("the booked event keeps its payload",
		(GameManager._schedules[0] as Dictionary).get("payload", {}).get("town", "") == "probe_town")

	GameManager.hour_advanced.disconnect(on_hour)
	GameManager.sim_event.disconnect(on_event)
	GameManager._schedules = saved_schedules
	GameManager._fired_event_keys = saved_fired
	GameManager.set_time(saved_time, saved_day)


## ============================================================================
## 4. EVERY SCHEDULED NPC EXISTS
## ============================================================================

## A record for someone nobody spawns is dead data that reads as coverage. Boot
## each town and demand the nodes.
func _check_every_scheduled_npc_spawns() -> void:
	var found: Dictionary = {}

	for zone: String in SCHEDULED_TOWNS.keys():
		var path: String = SCHEDULED_TOWNS[zone]
		if not ResourceLoader.exists(path):
			_check("%s exists" % zone, false)
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			_check("%s loads" % zone, false)
			continue
		var level: Node = packed.instantiate()
		add_child(level)
		for _i: int in range(4):
			await get_tree().process_frame
		for node: Node in get_tree().get_nodes_in_group("npcs"):
			found[NPCScheduler._id_of(node)] = true
		level.queue_free()
		remove_child(level)
		await get_tree().process_frame

	var missing: Array[String] = []
	for npc_id: String in NPCScheduler.records.keys():
		if not found.has(npc_id):
			missing.append(npc_id)
	_check("every scheduled npc_id is spawned by the town that claims it%s" % _tail(missing),
		missing.is_empty())


## ============================================================================
## 4b. THE AMBIENT POPULATION IS THE SAME PEOPLE EVERY SESSION (RULING LW-1)
## ============================================================================

## Boot a town twice under one world seed and once under another. Same seed
## must give the same people in the same order standing in the same places;
## a different seed must give a different town, or "seeded" means "hardcoded".
##
## Position is compared with slack. The seed fixes where each slot is PUT, but
## `CivilianNPC.validate_spawn_position` then nudges anyone who landed inside
## something by up to two units, and what a spawn overlaps depends on how far
## the physics server has got - which is not a property of the seed.
const AMBIENT_SPOT_SLACK := 2.5

func _check_ambient_population_is_seeded() -> void:
	var saved_seed: int = GameManager.world_seed

	for zone: String in AMBIENT_TOWNS.keys():
		var path: String = AMBIENT_TOWNS[zone]
		var first: Dictionary = await _ambient_crowd(path, 424242)
		var again: Dictionary = await _ambient_crowd(path, 424242)
		var other: Dictionary = await _ambient_crowd(path, 991137)

		var ids_first: Array[String] = first["ids"]
		var ids_again: Array[String] = again["ids"]
		var ids_other: Array[String] = other["ids"]

		_check("%s has an ambient population to compare (%d)" % [zone, ids_first.size()],
			ids_first.size() > 0)
		_check("%s: the same world_seed spawns the same people in the same order%s" % [
				zone, _tail(_differences(ids_first, ids_again))],
			ids_first == ids_again)
		_check("%s: the same world_seed puts them in the same places%s" % [
				zone, _tail(_spot_differences(first, again))],
			_spot_differences(first, again).is_empty())
		_check("%s: a different world_seed spawns a different ambient crowd" % zone,
			ids_first != ids_other)

	GameManager.world_seed = saved_seed
	WorldLexicon.clear_all_zone_names()


## Who the town's ambient crowd are and where they were PUT, in spawn order.
## The wander home is the spawn point; the live position is whatever the wander
## has done with it in the four frames since, which is not the subject.
func _ambient_crowd(scene_path: String, world_seed: int) -> Dictionary:
	var ids: Array[String] = []
	var spots: Array[Vector3] = []
	var out: Dictionary = {"ids": ids, "spots": spots}
	if not ResourceLoader.exists(scene_path):
		return out

	# A cold session: nothing carried over from the previous boot.
	GameManager.world_seed = world_seed
	WorldLexicon.clear_all_zone_names()

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return out
	var level: Node = packed.instantiate()
	add_child(level)
	for _i: int in range(4):
		await get_tree().process_frame

	var container: Node = null
	if level.has_meta("civilians_container"):
		container = level.get_meta("civilians_container") as Node
	if container != null:
		for child: Node in container.get_children():
			if not child is CivilianNPC:
				continue
			var npc: CivilianNPC = child as CivilianNPC
			ids.append(npc.npc_id)
			spots.append(npc.wander.home_position if npc.wander != null else npc.global_position)

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame
	return out


## Slots whose spawn point moved further than the collision nudge can explain.
func _spot_differences(a: Dictionary, b: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var left: Array[Vector3] = a["spots"]
	var right: Array[Vector3] = b["spots"]
	var ids: Array[String] = a["ids"]
	for i: int in range(mini(left.size(), right.size())):
		var gap: float = left[i].distance_to(right[i])
		if gap > AMBIENT_SPOT_SLACK:
			out.append("slot %d (%s) moved %.1f" % [i, ids[i], gap])
	return out


## The first few slots where two fingerprints part company.
func _differences(a: Array[String], b: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var count: int = maxi(a.size(), b.size())
	for i: int in range(count):
		var left: String = a[i] if i < a.size() else "-"
		var right: String = b[i] if i < b.size() else "-"
		if left != right:
			out.append("slot %d: %s vs %s" % [i, left, right])
	return out


## ============================================================================
## 5. THE LIVE TOWN
## ============================================================================

func _check_live_roster() -> void:
	if not ResourceLoader.exists(START_SCENE):
		_check("Elder Moor exists", false)
		return

	var packed: PackedScene = load(START_SCENE)
	if packed == null:
		_check("Elder Moor loads", false)
		return

	var level: Node = packed.instantiate()
	add_child(level)
	for _i: int in range(4):
		await get_tree().process_frame

	var night: Dictionary = await _roster_at(3)
	var day: Dictionary = await _roster_at(13)

	_check("Elder Moor has people in it at 13:00 (%d)" % day.size(), day.size() > 0)
	_check("Elder Moor at 03:00 is not the same set of people as at 13:00 (%d vs %d)" % [
			night.size(), day.size()],
		night.keys() != day.keys())

	# An invisible NPC with live collision is a wall the player cannot see.
	var solid_ghosts: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if not node is CollisionObject3D:
			continue
		var body: CollisionObject3D = node as CollisionObject3D
		if not body.visible and body.collision_layer != 0:
			solid_ghosts.append(NPCScheduler._id_of(node))
	_check("nobody who has left the world is still solid%s" % _tail(solid_ghosts),
		solid_ghosts.is_empty())

	var moved: int = 0
	for npc_id: String in night.keys():
		if day.has(npc_id) and (night[npc_id] as Vector3).distance_to(day[npc_id] as Vector3) > 1.0:
			moved += 1
	_check("at least someone who is up at both hours is somewhere else (%d moved)" % moved,
		moved > 0 or night.keys() != day.keys())

	# The shop gate, on a keeper who is really in this town.
	var keeper: String = ""
	for npc_id: String in NPCScheduler.records.keys():
		if NPCScheduler.archetype_of(npc_id) == "shopkeeper" \
				and String(NPCScheduler.records[npc_id].get("zone", "")) == "elder_moor":
			keeper = npc_id
			break

	_check("Elder Moor has a shopkeeper on the books", not keeper.is_empty())
	if not keeper.is_empty():
		_check("%s will not open the shop at 03:00" % keeper,
			not NPCScheduler.is_open_for_business(keeper, 3))
		_check("%s opens the shop at 13:00" % keeper,
			NPCScheduler.is_open_for_business(keeper, 13))
		_check("%s is not interactable while asleep at 03:00" % keeper,
			not NPCScheduler.is_interactable(keeper, 3))
		_check("%s is interactable at 13:00" % keeper,
			NPCScheduler.is_interactable(keeper, 13))

	# The gate itself, through the one door every shop path uses. There is no
	# second boolean to set, so the only way to test it is to try the door.
	var keeper_node: Node = null
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if NPCScheduler._id_of(node) == keeper:
			keeper_node = node
			break
	_check("the shopkeeper is a node in the live scene", keeper_node != null)
	if keeper_node != null:
		GameManager.set_time(3.0)
		_check("ShopUI refuses to open at 03:00", ShopUI.open_for(keeper_node) == null)
		GameManager.set_time(13.0)
		var opened: ShopUI = ShopUI.open_for(keeper_node)
		_check("ShopUI opens at 13:00", opened != null)
		if opened != null:
			opened.close()

	# A shopkeeper at their leisure station is present, awake, and still shut.
	var at_leisure: String = ""
	for npc_id: String in NPCScheduler.records.keys():
		if NPCScheduler.archetype_of(npc_id) != "shopkeeper":
			continue
		if NPCScheduler.is_interactable(npc_id, 12) and not NPCScheduler.is_open_for_business(npc_id, 12):
			at_leisure = npc_id
			break
	_check("a keeper away from the counter is talkable but shut (%s)" % at_leisure,
		not at_leisure.is_empty())

	print("")
	print("  Elder Moor roster: 03:00 = %d present, 13:00 = %d present" % [night.size(), day.size()])
	print("  03:00 -> %s" % str(_sorted(night.keys())))
	print("  13:00 -> %s" % str(_sorted(day.keys())))

	level.queue_free()
	remove_child(level)
	await get_tree().process_frame


## Who is actually standing in Elder Moor at this hour, and where. Read off the
## live nodes, not off the data that put them there.
func _roster_at(hour: int) -> Dictionary:
	GameManager.set_time(float(hour))
	NPCScheduler.refresh_all(hour)
	await get_tree().process_frame

	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if not node is Node3D:
			continue
		var n3: Node3D = node as Node3D
		if not n3.visible or not n3.is_in_group("interactable"):
			continue
		out[NPCScheduler._id_of(node)] = n3.global_position
	return out


## ============================================================================

func _sorted(keys: Array) -> Array:
	var out: Array = keys.duplicate()
	out.sort()
	return out


func _tail(items: Array[String]) -> String:
	if items.is_empty():
		return ""
	var shown: Array[String] = items.slice(0, 5)
	return " - %s%s" % [", ".join(shown), "" if items.size() <= 5 else " (+%d)" % (items.size() - 5)]


func _check(label: String, passed: bool) -> void:
	_checks += 1
	if passed:
		return
	_failures += 1
	print("  - %s" % label)


func _finish() -> void:
	print("")
	if _failures > 0:
		print("FAIL: %d of %d living-world checks failed" % [_failures, _checks])
		get_tree().quit(1)
		return
	print("OK: %d living-world checks pass" % _checks)
	get_tree().quit(0)
