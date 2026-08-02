## npc_scheduler.gd - Where every named NPC is, at every hour.
##
## NOTE: This is an autoload singleton - do not use class_name.
##
## Two data files and one rule. `data/schedules/archetypes/<name>.json` is a
## trade's day, in blocks of {from, to, action, station}. `data/npc_schedules.json`
## says which trade each npc_id keeps and where their three stations are. The
## rule is that position is a pure function of (schedule, hour) - there is no
## abstract ticker, nothing simulates off-screen, and an NPC waking up far from
## the player is placed for the hour rather than caught up.
##
## The contract, carried over from RECON's site_planner:
##   - a station in a cell that is not loaded is SKIPPED, never relocated;
##   - a station key the archetype asks for and the record does not have falls
##     back to the NPC's authored spawn, with a loud warning;
##   - an hour no block covers is `idle`, never an invented block.
##
## Stations are stored in WORLD coordinates. `world_to_local()` is the only
## place the floating origin is subtracted; do that twice and NPCs walk away
## from the town at a hundred units per cell crossing.
extends Node

const ARCHETYPE_DIR := "res://data/schedules/archetypes"
const RECORDS_PATH := "res://data/npc_schedules.json"

## Hours a player can reasonably expect a town to be open for business. The
## quest-availability rule is written against this band, and so is the
## archetype rule that nobody goes home inside it.
const DAY_FIRST_HOUR := 9
const DAY_LAST_HOUR := 17

## Actions an archetype block may name. Anything else is a data error.
const ACTIONS: Array[String] = ["sleep", "travel", "work", "eat", "socialise", "idle"]

## archetype id -> {"description": String, "blocks": Array[Dictionary]}
var archetypes: Dictionary = {}

## npc_id -> {"archetype", "zone", "stations", ...}
var records: Dictionary = {}

## Runtime records for the ambient population - the townsfolk whose name and
## spot are drawn fresh every boot, so no authored record could name them.
## Their work station is wherever their spawner put them this time.
var _ambient: Dictionary = {}

## (cell, hour) -> Array[String] of npc_ids stationed there. Built once.
var _cell_index: Dictionary = {}

## NPC ids whose despawn is owed but was held because the player is mid-sentence
## with them.
var _deferred_absent: Dictionary = {}

## Nodes we have placed, npc_id -> Node3D, so an hour tick does not have to walk
## the whole scene tree.
var _tracked: Dictionary = {}


func _ready() -> void:
	_load_archetypes()
	_load_records()
	_build_cell_index()

	if not GameManager.hour_advanced.is_connected(_on_hour_advanced):
		GameManager.hour_advanced.connect(_on_hour_advanced)
	if not CellStreamer.cell_loaded.is_connected(_on_cell_loaded):
		CellStreamer.cell_loaded.connect(_on_cell_loaded)
	if not GameManager.is_connected("game_resumed", _on_game_resumed):
		GameManager.game_resumed.connect(_on_game_resumed)


## ============================================================================
## DATA
## ============================================================================

func _load_archetypes() -> void:
	archetypes.clear()
	var dir := DirAccess.open(ARCHETYPE_DIR)
	if not dir:
		push_error("[NPCScheduler] No archetype directory at %s" % ARCHETYPE_DIR)
		return

	for file_name: String in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path: String = ARCHETYPE_DIR + "/" + file_name
		var parsed: Variant = _read_json(path)
		if not parsed is Dictionary:
			push_error("[NPCScheduler] Archetype is not an object: %s" % path)
			continue
		var data: Dictionary = parsed
		var id: String = data.get("id", file_name.get_basename())
		var blocks: Array = data.get("blocks", [])
		if blocks.is_empty():
			push_error("[NPCScheduler] Archetype %s has no blocks" % id)
			continue
		archetypes[id] = {
			"description": String(data.get("description", "")),
			"blocks": blocks,
		}


func _load_records() -> void:
	records.clear()
	var parsed: Variant = _read_json(RECORDS_PATH)
	if not parsed is Dictionary:
		push_error("[NPCScheduler] Could not read %s" % RECORDS_PATH)
		return
	var npcs: Variant = (parsed as Dictionary).get("npcs", {})
	if not npcs is Dictionary:
		push_error("[NPCScheduler] %s has no npcs object" % RECORDS_PATH)
		return

	for npc_id: String in (npcs as Dictionary).keys():
		var rec: Dictionary = (npcs as Dictionary)[npc_id]
		var archetype: String = rec.get("archetype", "")
		if not archetypes.has(archetype):
			push_warning("[NPCScheduler] %s wants archetype '%s', which does not exist - falling back to townsfolk" % [npc_id, archetype])
			rec["archetype"] = "townsfolk"
		records[npc_id] = rec


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[NPCScheduler] %s: %s (line %d)" % [path, json.get_error_message(), json.get_error_line()])
		return null
	return json.data


## Per-hour inverse index: who is stationed in which cell at which hour. Nine
## dictionary lookups an hour beats walking every record.
func _build_cell_index() -> void:
	_cell_index.clear()
	for npc_id: String in records.keys():
		for hour: int in range(24):
			var station: Dictionary = station_of(npc_id, hour)
			if station.is_empty() or station.get("interior", false):
				continue
			var key: String = _index_key(station_cell(station), hour)
			if not _cell_index.has(key):
				_cell_index[key] = [] as Array[String]
			(_cell_index[key] as Array[String]).append(npc_id)


func _index_key(cell: Vector2i, hour: int) -> String:
	return "%d,%d@%d" % [cell.x, cell.y, hour]


## ============================================================================
## QUERIES
## ============================================================================

func has_record(npc_id: String) -> bool:
	return records.has(npc_id) or _ambient.has(npc_id)


func record_for(npc_id: String) -> Dictionary:
	if records.has(npc_id):
		return records[npc_id]
	return _ambient.get(npc_id, {})


func archetype_of(npc_id: String) -> String:
	return String(record_for(npc_id).get("archetype", ""))


## The block covering this hour. An hour no block covers is idle at work - the
## schedule is never invented to fill a gap.
func block_for(npc_id: String, hour: int) -> Dictionary:
	var rec: Dictionary = record_for(npc_id)
	if rec.is_empty():
		return {}
	var archetype: Dictionary = archetypes.get(rec.get("archetype", ""), {})
	if archetype.is_empty():
		return {"action": "idle", "station": "work"}

	var h: int = posmod(hour, 24)
	for block: Dictionary in archetype.get("blocks", []) as Array:
		var from: int = int(block.get("from", 0))
		var to: int = int(block.get("to", 0))
		var covered: bool = (from <= h and h < to) if from < to else (h >= from or h < to)
		if covered:
			return {
				"action": String(block.get("action", "idle")),
				"station": String(block.get("station", "work")),
			}
	return {"action": "idle", "station": "work"}


func action_for(npc_id: String, hour: int) -> StringName:
	var block: Dictionary = block_for(npc_id, hour)
	if block.is_empty():
		return &""
	return StringName(block.get("action", "idle"))


## The station this NPC occupies at this hour, or {} if they have no record.
## A station key the archetype names and the record does not carry falls back to
## `work` - the authored spawn - and says so once.
func station_of(npc_id: String, hour: int) -> Dictionary:
	var rec: Dictionary = record_for(npc_id)
	if rec.is_empty():
		return {}
	var block: Dictionary = block_for(npc_id, hour)
	var wanted: String = block.get("station", "work")
	var stations: Dictionary = rec.get("stations", {})

	if stations.has(wanted):
		return stations[wanted]

	var fallback_key: String = "work"
	if stations.has(fallback_key):
		push_warning("[NPCScheduler] %s has no '%s' station; standing at their authored spawn instead" % [npc_id, wanted])
		return stations[fallback_key]

	push_warning("[NPCScheduler] %s has no stations at all - schedule ignored" % npc_id)
	return {}


func station_cell(station: Dictionary) -> Vector2i:
	var cell: Array = station.get("cell", [0, 0])
	if cell.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(cell[0]), int(cell[1]))


func station_world_pos(station: Dictionary) -> Vector3:
	var p: Array = station.get("pos", [0.0, 0.0, 0.0])
	if p.size() < 3:
		return Vector3.ZERO
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


## Present means: they have a station this hour, it is not behind an unmodelled
## door, and the cell it sits in is one the world has loaded.
func is_present(npc_id: String, hour: int) -> bool:
	var station: Dictionary = station_of(npc_id, hour)
	if station.is_empty():
		return false
	if station.get("interior", false):
		return false
	return true


## Present AND awake. A sleeping NPC is in the world and will not answer.
func is_interactable(npc_id: String, hour: int) -> bool:
	if not is_present(npc_id, hour):
		return false
	return action_for(npc_id, hour) != &"sleep"


## The gate a shop opens behind: the keeper is here, they are working, and they
## are at the counter rather than the tavern.
func is_open_for_business(npc_id: String, hour: int) -> bool:
	if not is_present(npc_id, hour):
		return false
	var block: Dictionary = block_for(npc_id, hour)
	if block.get("action", "") != "work":
		return false
	return block.get("station", "") == "work"


## ============================================================================
## AVAILABILITY - what the rest of the game asks
## ============================================================================

## Called from ShopUI.open_for, and from nowhere else. A keeper the scheduler
## has never heard of keeps whatever hours they always did.
func can_open_shop(keeper: Node) -> bool:
	if not is_instance_valid(keeper):
		return false
	var npc_id: String = _id_of(keeper)
	if not has_record(npc_id):
		return true
	return is_open_for_business(npc_id, current_hour())


## A shut door says so. A locked door that says nothing is the bug the scout
## warns about - the player cannot tell it from a broken one.
func announce_shop_closed(keeper: Node) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	if hud and hud.has_method("show_notification"):
		hud.show_notification(closed_prompt(_id_of(keeper)))


## The line a closed shop shows, in the keeper's own hours.
func closed_prompt(npc_id: String) -> String:
	var hour: int = current_hour()
	if not is_present(npc_id, hour):
		return "Closed - come back in the morning."
	if action_for(npc_id, hour) == &"sleep":
		return "Asleep."
	return "Closed - the keeper is not at the counter."


## Whether this NPC will answer at all right now. An NPC the scheduler has never
## heard of always answers - the schedule adds a reason to refuse, it does not
## take away the default.
func is_awake(npc_id: String) -> bool:
	if not has_record(npc_id):
		return true
	return action_for(npc_id, current_hour()) != &"sleep"


## Say so. A prompt that stops working and explains nothing is the bug.
func announce_asleep(node: Node, display_name: String) -> void:
	if not is_inside_tree():
		return
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("%s is asleep." % display_name)
	# Nothing is talking to them, so nothing may be holding them either.
	if ConversationSystem.current_npc == node:
		ConversationSystem.current_npc = null


## The word an interaction prompt should carry, or "" when there is nothing
## unusual to say. Prompts are the only place presence is ever explained.
func interaction_note(npc_id: String) -> String:
	var hour: int = current_hour()
	if not has_record(npc_id):
		return ""
	if action_for(npc_id, hour) == &"sleep":
		return "Asleep"
	return ""


## Everyone stationed in this cell at this hour. The roster.
func npcs_in_cell(cell: Vector2i, hour: int) -> Array[String]:
	var found: Array[String] = []
	found.assign(_cell_index.get(_index_key(cell, posmod(hour, 24)), [] as Array[String]))
	return found


## THE floating-origin conversion. One place, on purpose.
func world_to_local(world_pos: Vector3) -> Vector3:
	return world_pos - CellStreamer.world_offset


## ============================================================================
## PLACEMENT
## ============================================================================

## Position is a pure function of (schedule, hour). Port of RECON's
## civilian.gd:742-766, the most portable function in that repository: it is
## what stops the world assembling itself on approach instead of having been
## there all along.
##
## Returns true if the NPC is in the world after the call.
func place_for_hour(node: Node3D, npc_id: String, hour: int) -> bool:
	if not is_instance_valid(node):
		return false
	if not has_record(npc_id):
		return true  # not ours to move

	_tracked[npc_id] = node

	var station: Dictionary = station_of(npc_id, hour)
	if station.is_empty():
		return true

	if station.get("interior", false):
		_set_absent(node, npc_id)
		return false

	var cell: Vector2i = station_cell(station)
	if not CellStreamer.loaded_cells.has(cell):
		# Skipped, never relocated. RECON moved absent markers to town centre
		# once and spent a week wondering why the base looked wrong.
		_set_absent(node, npc_id)
		return false

	_set_present(node, npc_id)
	node.global_position = world_to_local(station_world_pos(station))

	var facing: float = float(station.get("facing", 0))
	node.rotation.y = deg_to_rad(facing)

	# ART RULE: billboards get a facing and a sit flag, and nothing is drawn for
	# either until Caleb's art says how.
	var sitting: bool = bool(station.get("sit", false)) and action_for(npc_id, hour) in [&"eat", &"socialise", &"idle"]
	node.set_meta("schedule_sitting", sitting)
	node.set_meta("schedule_action", String(action_for(npc_id, hour)))

	var billboard: Node = node.get_node_or_null("Billboard")
	if billboard and "facing_direction" in billboard:
		billboard.facing_direction = Vector3(sin(deg_to_rad(facing)), 0.0, cos(deg_to_rad(facing)))
	if billboard and billboard.has_method("set_walking"):
		billboard.set_walking(false)

	return true


## Convenience for a node that knows its own id.
func place_node(node: Node3D) -> bool:
	return place_for_hour(node, _id_of(node), current_hour())


func current_hour() -> int:
	return posmod(floori(GameManager.game_time), 24)


func _id_of(node: Node) -> String:
	if "npc_id" in node and not String(node.npc_id).is_empty():
		return String(node.npc_id)
	return String(node.name)


## ============================================================================
## PRESENCE
## ============================================================================

func _set_present(node: Node3D, _npc_id: String) -> void:
	if node.visible and node.is_in_group("interactable"):
		return
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if not node.is_in_group("interactable"):
		node.add_to_group("interactable")
	if not node.is_in_group("npcs"):
		node.add_to_group("npcs")

	# Give the body back the collision layer it was built with, not a guess.
	if node is CollisionObject3D and node.has_meta("schedule_collision_layer"):
		(node as CollisionObject3D).set_deferred("collision_layer",
			int(node.get_meta("schedule_collision_layer")))
	var area: Node = node.get_node_or_null("InteractionArea")
	if area is Area3D:
		(area as Area3D).monitorable = true


## The v1 despawn: the node stays, because freeing an authored quest giver would
## mean rebuilding their quest state on the way back. It leaves the world -
## invisible, unlit, out of every group anything queries.
func _set_absent(node: Node3D, npc_id: String) -> void:
	if GameManager.is_in_dialogue and ConversationSystem.current_npc == node:
		# Never take an NPC out of the world mid-sentence. CLAUDE.md crash class
		# #1 is a freed-object cast out of ConversationSystem.current_npc, and
		# this is the seam that would produce one every night at 21:00.
		_deferred_absent[npc_id] = true
		return

	_deferred_absent.erase(npc_id)
	if ConversationSystem.current_npc == node:
		ConversationSystem.current_npc = null

	if not node.visible and not node.is_in_group("interactable"):
		return
	node.visible = false
	if node.is_in_group("interactable"):
		node.remove_from_group("interactable")
	var area: Node = node.get_node_or_null("InteractionArea")
	if area is Area3D:
		(area as Area3D).monitorable = false

	# An invisible body with live collision is a wall the player walks into and
	# cannot see, and an invisible wanderer keeps walking. Both off, and the
	# layer is remembered rather than guessed at on the way back.
	if node is CollisionObject3D:
		var body: CollisionObject3D = node as CollisionObject3D
		if not body.has_meta("schedule_collision_layer"):
			body.set_meta("schedule_collision_layer", body.collision_layer)
		body.set_deferred("collision_layer", 0)
	node.process_mode = Node.PROCESS_MODE_DISABLED


func _on_game_resumed() -> void:
	if _deferred_absent.is_empty():
		return
	var owed: Array = _deferred_absent.keys()
	_deferred_absent.clear()
	for npc_id: String in owed:
		var node: Node3D = _tracked.get(npc_id, null) as Node3D
		if is_instance_valid(node):
			place_for_hour(node, npc_id, current_hour())


## ============================================================================
## THE SEAM
## ============================================================================

func _on_hour_advanced(hour: int) -> void:
	refresh_all(hour)


func _on_cell_loaded(_coords: Vector2i) -> void:
	# One code path for "existed at load" and "arrived by schedule".
	refresh_all.call_deferred(current_hour())


## Re-place every NPC the scheduler knows about. Cheap: a dictionary lookup and
## a vector assignment each, and the towns hold a hundred and thirteen of them.
func refresh_all(hour: int = -1) -> void:
	var h: int = current_hour() if hour < 0 else posmod(hour, 24)
	if not is_inside_tree():
		return

	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if not node is Node3D:
			continue
		var npc_id: String = _id_of(node)
		if has_record(npc_id):
			place_for_hour(node as Node3D, npc_id, h)

	# NPCs already taken out of the world are no longer in the "npcs" group, so
	# the sweep above cannot bring them back. Walk the tracked set for those.
	for npc_id: String in _tracked.keys():
		var node: Node3D = _tracked[npc_id] as Node3D
		if not is_instance_valid(node):
			_tracked.erase(npc_id)
			continue
		if not node.visible:
			place_for_hour(node, npc_id, h)


## ============================================================================
## THE AMBIENT POPULATION
## ============================================================================

## Townsfolk whose name comes out of a pool and whose spot comes out of randf().
## No authored record can name them, because neither survives a reboot. Their
## spawner names the trade instead and this makes the record on the spot, with
## the position they were actually given as their work station.
func attach_ambient(node: Node3D, archetype: String, leisure_world_pos: Vector3) -> void:
	if not is_instance_valid(node):
		return
	if not archetypes.has(archetype):
		push_warning("[NPCScheduler] attach_ambient: no archetype '%s'" % archetype)
		return

	var npc_id: String = _id_of(node)
	var cell: Vector2i = WorldGrid.world_to_cell(node.global_position + CellStreamer.world_offset)
	var world_pos: Vector3 = node.global_position + CellStreamer.world_offset
	var seed_hash: int = absi(hash(npc_id))
	var angle: float = float(seed_hash % 360)
	var radius: float = 1.5 + float((seed_hash >> 9) % 200) / 100.0

	_ambient[npc_id] = {
		"archetype": archetype,
		"zone": "",
		"ambient": true,
		"stations": {
			"work": {"cell": [cell.x, cell.y], "pos": [world_pos.x, world_pos.y, world_pos.z],
				"facing": float(seed_hash % 8) * 45.0},
			"home": {"cell": [cell.x, cell.y], "pos": [world_pos.x, world_pos.y, world_pos.z],
				"facing": 0.0, "interior": true},
			"leisure": {
				"cell": [cell.x, cell.y],
				"pos": [
					leisure_world_pos.x + cos(deg_to_rad(angle)) * radius,
					leisure_world_pos.y,
					leisure_world_pos.z + sin(deg_to_rad(angle)) * radius,
				],
				"facing": float((seed_hash >> 3) % 8) * 45.0,
				"sit": (seed_hash % 2) == 0,
			},
		},
	}
	place_for_hour(node, npc_id, current_hour())


## Forget an ambient NPC - their cell is unloading and the id will not come back.
func detach_ambient(node: Node3D) -> void:
	var npc_id: String = _id_of(node)
	_ambient.erase(npc_id)
	_tracked.erase(npc_id)
	_deferred_absent.erase(npc_id)
