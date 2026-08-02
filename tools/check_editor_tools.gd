extends Node
## Editor-tool guard, headless.
##
## Usage: godot --headless --path . res://tools/check_editor_tools.tscn
##
## The tools write the world. Nothing has ever checked them, and every finding
## in docs/audits/tool_suite_audit.md was a tool that ran, looked like it had
## worked, and wrote into a contract the game had stopped speaking. Six things
## are asserted.
##
## 1. EVERY ADDON SCRIPT PARSES. In 4.7, from a clean cache. A plugin that fails
##    to compile disables itself with one line in the editor log, and the tool
##    is simply missing next time it is looked for.
##
## 2. NO TOOL WRITES OUTSIDE THE REPOSITORY. A `user://` path in an addon means
##    a file git cannot see, the validator has never read, and no exported build
##    contains. That is exactly how a 4096-cell world map came to exist on one
##    machine and nowhere else.
##
## 3. THE FORGE MAP IS A MAP THE GAME CAN BUILD. Every painted cell inside
##    GRID_MIN..GRID_MAX; every biome override a real WorldGrid.Biome; every POI
##    naming a location LOCATIONS declares.
##
## 4. THE MAP DOES NOT MOVE THE PLACES. This is the 8/2 bug in assertion form:
##    the forge map used to replace the world outright, so Dalhurst was two
##    cells from its own residents and twenty-eight places lost their scene.
##    LOCATIONS wins, and the check proves it on the live grid.
##
## 5. THE TOWN EDITOR'S COORDINATE CONVERSION REPRODUCES THE SHIPPED WORLD.
##    Station positions are absolute world space; element positions are
##    scene-local. Run all 112 shipped records backwards into local space and
##    forwards again through the editor's own arithmetic, and every one must
##    come back byte-identical. If it does not, the editor would write a town
##    whose people stand a few hundred metres outside the cell they claim.
##
## 6. EVERY SCHEDULE RECORD IS ONE NPCScheduler CAN KEEP. A real archetype, a
##    work station, and no station in a cell the world does not have.

const ADDONS_ROOT := "res://addons"
const ARCHETYPE_DIR := "res://data/schedules/archetypes"
const RECORDS_PATH := "res://data/npc_schedules.json"

## Places `LOCATIONS` declares at coordinates the grid does not contain.
##
## Found by this check on the day it was written, and NOT caused by any tool:
## these twelve rows are in `world_grid.gd` itself, outside GRID_MIN..GRID_MAX,
## so `initialize()` builds no cell for them and `get_location_coords()` returns
## `(0, 0)` - which is Elder Moor. Anything that asks where Falkenhaften is gets
## told it is the starting town.
##
## They are recorded rather than moved, because where each of them belongs is a
## design decision and not a merge: either the grid grows south and east to hold
## them, or each row moves inside. The question is filed in
## `docs/audits/wave_b_dispositions.md`.
##
## **The count is a ceiling, not a licence.** Remove a name when it is placed;
## adding one fails this check.
const OUT_OF_BOUNDS_LOCATIONS: Array[String] = [
	"falkenhaften",
	"bandit_camp_tundra_west",
	"bandit_camp_tundra_east",
	"goblin_camp_tundra",
	"ruined_temple_frost",
	"bandit_camp_eastern_road",
	"goblin_camp_eastern_hills",
	"ruined_temple_eastern",
	"bandit_camp_desert",
	"smuggler_cove",
	"pirate_camp_island",
	"ruined_temple_island",
]

## Paths a tool may legitimately name without writing the world there.
const USER_PATH_EXEMPTIONS: Dictionary = {
	"res://addons/world_forge/world_forge_dock.gd":
		"LEGACY_PATH, offered as a one-way import and read nowhere else",
	"res://scripts/core/world_grid.gd":
		"LEGACY_FORGE_MAP_PATH, named so the tool can find it, never loaded from",
}

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_check_addons_parse()
	_check_no_user_paths()
	_check_forge_map()
	_check_places_are_not_moved()
	_check_station_conversion_round_trip()
	_check_schedule_records()
	_finish()


func _ok(what: String) -> void:
	_checks += 1
	print("  ok    %s" % what)


func _fail(what: String) -> void:
	_checks += 1
	_failures += 1
	print("- FAIL: %s" % what)


func _finish() -> void:
	print("")
	if _failures == 0:
		print("check_editor_tools: %d checks, all green." % _checks)
		get_tree().quit(0)
	else:
		print("check_editor_tools: %d checks, %d FAILED." % [_checks, _failures])
		get_tree().quit(1)


## ---------------------------------------------------------------------------
## 1. Every addon script parses
## ---------------------------------------------------------------------------

func _check_addons_parse() -> void:
	print("[1] addon scripts parse in 4.7")
	var scripts: Array[String] = _files_under(ADDONS_ROOT, ".gd")
	if scripts.is_empty():
		_fail("no addon scripts found at all - the scan is broken, not the addons")
		return
	var bad: Array[String] = []
	for path: String in scripts:
		if ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE) == null:
			bad.append(path)
	if bad.is_empty():
		_ok("%d addon scripts compile" % scripts.size())
	else:
		_fail("these addon scripts do not compile: %s" % ", ".join(bad))


## ---------------------------------------------------------------------------
## 2. No tool writes outside the repository
## ---------------------------------------------------------------------------

func _check_no_user_paths() -> void:
	print("[2] no tool writes outside the repository")
	var offenders: Array[String] = []
	for path: String in _files_under(ADDONS_ROOT, ".gd"):
		var text: String = FileAccess.get_file_as_string(path)
		if not text.contains("user://"):
			continue
		if USER_PATH_EXEMPTIONS.has(path):
			continue
		offenders.append(path)

	# An exemption that stops being needed is a stale excuse, and stale excuses
	# are how the last one survived for a year.
	for path: String in USER_PATH_EXEMPTIONS:
		if not FileAccess.file_exists(path):
			_fail("exemption names %s, which does not exist" % path)
			continue
		if not FileAccess.get_file_as_string(path).contains("user://"):
			_fail("exemption for %s is stale - it no longer names a user:// path" % path)

	if offenders.is_empty():
		_ok("no unexplained user:// path in any addon")
	else:
		_fail("these addons write outside the repository: %s" % ", ".join(offenders))


## ---------------------------------------------------------------------------
## 3. The forge map is a map the game can build
## ---------------------------------------------------------------------------

func _check_forge_map() -> void:
	print("[3] the forge map is one the game can build")
	var path: String = WorldGrid.FORGE_MAP_PATH
	if not FileAccess.file_exists(path):
		_ok("no forge map on disk - the land comes from GRID_DATA, which is legal")
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_fail("%s is not parseable JSON" % path)
		return

	var data: Dictionary = parsed
	var grid: Dictionary = data.get("grid", {})
	var width: int = int(grid.get("width", 0))
	var origin_info: Dictionary = data.get("editor_origin", {})
	var origin := Vector2i(int(origin_info.get("x", 0)), int(origin_info.get("y", 0)))
	var layers: Dictionary = data.get("layers", {})
	var terrain: Array = layers.get("terrain", [])
	var biome_override: Array = layers.get("biome_override", [])

	if width <= 0 or terrain.is_empty():
		_fail("%s has no terrain layer" % path)
		return

	var outside: int = 0
	for i: int in range(terrain.size()):
		if terrain[i] == null:
			continue
		var coords := Vector2i(i % width - origin.x, i / width - origin.y)
		if not WorldGrid.is_in_bounds(coords):
			outside += 1
	if outside == 0:
		_ok("every painted cell is inside %s..%s" % [WorldGrid.GRID_MIN, WorldGrid.GRID_MAX])
	else:
		_fail("%d painted cells fall outside the world and will not be built" % outside)

	var biome_names: Array = WorldGrid.Biome.keys()
	var bad_biomes: Array[String] = []
	for i: int in range(biome_override.size()):
		if biome_override[i] == null:
			continue
		var name: String = String(biome_override[i])
		if not biome_names.has(name):
			bad_biomes.append(name)
	if bad_biomes.is_empty():
		_ok("every biome override names a real WorldGrid.Biome")
	else:
		_fail("biome overrides name biomes that do not exist: %s" % ", ".join(bad_biomes))

	var declared: Dictionary = {}
	for loc: Dictionary in WorldGrid.LOCATIONS:
		declared[String(loc.get("id", ""))] = true
	var undeclared: Array[String] = []
	for key: String in data.get("poi_data", {}) as Dictionary:
		var poi: Dictionary = (data["poi_data"] as Dictionary)[key]
		var id: String = String(poi.get("location_id", ""))
		if not id.is_empty() and not declared.has(id):
			undeclared.append(id)
	if undeclared.is_empty():
		_ok("every POI on the map is a place LOCATIONS declares")
	else:
		_fail("the map names places LOCATIONS does not declare, so they have nothing behind them: %s" % ", ".join(undeclared))


## ---------------------------------------------------------------------------
## 4. The map does not move the places
## ---------------------------------------------------------------------------

func _check_places_are_not_moved() -> void:
	print("[4] LOCATIONS decides where places are, not the map")
	var moved: Array[String] = []
	var sceneless: Array[String] = []
	var newly_off_grid: Array[String] = []
	var still_off_grid: Array[String] = []

	for loc: Dictionary in WorldGrid.LOCATIONS:
		var id: String = String(loc.get("id", ""))
		if id.is_empty():
			continue
		var declared := Vector2i(int(loc.get("x", 0)), int(loc.get("y", 0)))

		# A place declared outside the grid has no cell, and asking where it is
		# answers Elder Moor. Known ones are counted; new ones fail.
		if not WorldGrid.is_in_bounds(declared):
			if OUT_OF_BOUNDS_LOCATIONS.has(id):
				still_off_grid.append(id)
			else:
				newly_off_grid.append("%s at %s, outside %s..%s" % [
					id, declared, WorldGrid.GRID_MIN, WorldGrid.GRID_MAX
				])
			continue

		var live: Vector2i = WorldGrid.get_location_coords(id)
		if live != declared:
			moved.append("%s declared at %s, live at %s" % [id, declared, live])

		var cell: WorldGrid.CellInfo = WorldGrid.get_cell(declared)
		if cell == null:
			moved.append("%s has no cell at all" % id)
			continue
		if cell.location_id != id:
			moved.append("%s's own cell says it is '%s'" % [id, cell.location_id])
		var expected_scene: String = String(WorldGrid.LOCATION_SCENES.get(id, ""))
		if not expected_scene.is_empty() and cell.scene_path != expected_scene:
			sceneless.append("%s should stream %s, streams '%s'" % [id, expected_scene.get_file(), cell.scene_path])

	if moved.is_empty():
		_ok("all %d places stand where LOCATIONS puts them" % WorldGrid.LOCATIONS.size())
	else:
		_fail("places have moved: %s" % "; ".join(moved))

	if sceneless.is_empty():
		_ok("every place with a hand-built level still streams it")
	else:
		_fail("hand-built levels lost: %s" % "; ".join(sceneless))

	if newly_off_grid.is_empty():
		_ok("no new place declared outside the grid")
	else:
		_fail("places declared outside the grid, where get_location_coords() answers Elder Moor: %s" % "; ".join(newly_off_grid))

	# The ceiling only ever comes down.
	if still_off_grid.size() > OUT_OF_BOUNDS_LOCATIONS.size():
		_fail("more off-grid places than the recorded %d" % OUT_OF_BOUNDS_LOCATIONS.size())
	else:
		var stale: Array[String] = []
		for id: String in OUT_OF_BOUNDS_LOCATIONS:
			if not still_off_grid.has(id):
				stale.append(id)
		if stale.is_empty():
			_ok("%d places still declared off the grid, all of them recorded (see wave_b_dispositions.md)" % still_off_grid.size())
		else:
			_fail("these names are recorded as off-grid but are not - lower the list: %s" % ", ".join(stale))


## ---------------------------------------------------------------------------
## 5. The Town Editor's coordinate conversion reproduces the shipped world
## ---------------------------------------------------------------------------

## A station's `pos` is absolute world space. The Town Editor holds positions
## scene-local, like every other element, and converts once when it writes:
##
##     world = WorldGrid.cell_to_world(cell) + local
##
## Take every shipped record, invert that, apply it, and demand the original
## back. If the arithmetic is wrong in either direction, the editor writes a
## town whose people stand outside the cell they claim - which is precisely what
## validate_content._check_schedules fails on.
func _check_station_conversion_round_trip() -> void:
	print("[5] the Town Editor's world/local conversion is exact")
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	if not (doc is Dictionary):
		_fail("%s is not parseable" % RECORDS_PATH)
		return

	var records: Dictionary = (doc as Dictionary).get("npcs", {})
	var stations_seen: int = 0
	var wrong: Array[String] = []
	var outside_cell: Array[String] = []

	for npc_id: String in records:
		var record: Dictionary = records[npc_id]
		for key: String in (record.get("stations", {}) as Dictionary):
			var station: Dictionary = (record["stations"] as Dictionary)[key]
			var cell_arr: Array = station.get("cell", [0, 0])
			var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			var pos_arr: Array = station.get("pos", [0.0, 0.0, 0.0])
			var world := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
			var origin: Vector3 = WorldGrid.cell_to_world(cell)

			# Backwards, then forwards, exactly as the editor does it.
			var local: Vector3 = world - Vector3(origin.x, 0.0, origin.z)
			var rebuilt := Vector3(origin.x + local.x, local.y, origin.z + local.z)

			stations_seen += 1
			if rebuilt.distance_to(world) > 0.001:
				wrong.append("%s.%s" % [npc_id, key])

			# The same rule validate_content applies: a station must be inside
			# the cell it claims. A tolerance of one cell either way, because
			# the big towns have scenes wider than one cell.
			if absf(local.x) > WorldGrid.CELL_SIZE or absf(local.z) > WorldGrid.CELL_SIZE:
				outside_cell.append("%s.%s is %.0f, %.0f from the origin of cell %s" % [
					npc_id, key, local.x, local.z, cell
				])

	if stations_seen == 0:
		_fail("no stations found to check - the records file is empty or reshaped")
	elif wrong.is_empty():
		_ok("%d stations survive world -> local -> world unchanged" % stations_seen)
	else:
		_fail("%d stations do not round-trip: %s" % [wrong.size(), ", ".join(wrong)])

	if outside_cell.is_empty():
		_ok("every station stands inside the cell it claims")
	else:
		_fail("stations outside their own cell: %s" % "; ".join(outside_cell))


## ---------------------------------------------------------------------------
## 6. Every record is one NPCScheduler can keep
## ---------------------------------------------------------------------------

func _check_schedule_records() -> void:
	print("[6] every schedule record is one the scheduler can keep")
	var archetypes: Dictionary = {}
	var dir := DirAccess.open(ARCHETYPE_DIR)
	if dir:
		for file_name: String in dir.get_files():
			if file_name.ends_with(".json"):
				archetypes[file_name.get_basename()] = true

	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	if not (doc is Dictionary):
		_fail("%s is not parseable" % RECORDS_PATH)
		return
	var records: Dictionary = (doc as Dictionary).get("npcs", {})

	var bad_archetype: Array[String] = []
	var no_work: Array[String] = []
	var off_grid: Array[String] = []

	for npc_id: String in records:
		var record: Dictionary = records[npc_id]
		if not archetypes.has(String(record.get("archetype", ""))):
			bad_archetype.append("%s wants '%s'" % [npc_id, record.get("archetype", "")])
		var stations: Dictionary = record.get("stations", {})
		if not stations.has("work"):
			no_work.append(npc_id)
		for key: String in stations:
			var cell_arr: Array = (stations[key] as Dictionary).get("cell", [0, 0])
			var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			if not WorldGrid.is_in_bounds(cell):
				off_grid.append("%s.%s at %s" % [npc_id, key, cell])

	if bad_archetype.is_empty():
		_ok("all %d records name an archetype that exists" % records.size())
	else:
		_fail("records name archetypes that do not exist: %s" % ", ".join(bad_archetype))

	if no_work.is_empty():
		_ok("every record has a work station")
	else:
		_fail("records with no work station: %s" % ", ".join(no_work))

	if off_grid.is_empty():
		_ok("every station is in a cell the world has")
	else:
		_fail("stations in cells the world does not have: %s" % ", ".join(off_grid))


## ---------------------------------------------------------------------------

func _files_under(root: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_files_under(full, suffix))
		elif name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
