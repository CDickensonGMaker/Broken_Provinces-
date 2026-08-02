@tool
class_name WorldOverviewDock
extends Control
## World Overview - the whole world, painted from live data, read-only.
##
## Every other tool in this suite edits one thing at a time: one cell, one town,
## one quest. Nothing has ever shown the world as a whole, and so nothing has
## ever answered the question that decides what to build next - **where is the
## content, and where is the world empty?**
##
## It reads, and never writes. Six views over the same twenty-by-forty grid:
##
##   Biome      what the climate model actually decided, cell by cell. The model
##              is latitude, moisture and a mountain mask; this is the only place
##              its output can be looked at rather than reasoned about.
##   Danger     the difficulty gradient outward from Elder Moor.
##   Places     location types, and whether each has a hand-built scene or
##              streams as procedural.
##   Quests     how many quests point at each place. A town with a scene, a
##              population and no quests is a room nobody has been given a
##              reason to enter.
##   People     how many scheduled residents each cell has, at the chosen hour.
##   Scenes     which cells a hand-built level actually covers, since a big town
##              covers more than the one cell it is pinned to.
##
## Because it reads the live registries, it is also an honest map of the gap
## between the world that exists and the world that is furnished.

const CELL_PX := 18

enum View { BIOME, DANGER, PLACES, QUESTS, PEOPLE, SCENES }

const VIEW_NAMES: Array[String] = ["Biome", "Danger", "Places", "Quests", "People", "Scenes"]

## WorldGrid.Biome ordinals -> the colours World Forge paints them.
const BIOME_COLORS: Array[Color] = [
	Color(0.24, 0.42, 0.19),  # FOREST
	Color(0.55, 0.70, 0.38),  # PLAINS
	Color(0.18, 0.29, 0.16),  # SWAMP
	Color(0.52, 0.50, 0.32),  # HILLS
	Color(0.45, 0.44, 0.42),  # ROCKY
	Color(0.30, 0.30, 0.35),  # MOUNTAINS
	Color(0.42, 0.56, 0.52),  # COAST
	Color(0.36, 0.28, 0.40),  # UNDEAD
	Color(0.46, 0.24, 0.22),  # HORDE
	Color(0.83, 0.72, 0.59),  # DESERT
	Color(0.80, 0.86, 0.90),  # WINTER
	Color(0.32, 0.40, 0.28),  # ROCKY_FOREST
	Color(0.52, 0.56, 0.40),  # ROCKY_PLAINS
	Color(0.62, 0.68, 0.74),  # ROCKY_WINTER
	Color(0.68, 0.60, 0.48),  # ROCKY_DESERT
]

var current_view: int = View.PLACES
var hour: int = 13

var canvas: Control
var view_option: OptionButton
var hour_slider: HSlider
var hour_label: Label
var legend: RichTextLabel
var summary: RichTextLabel
var hovered: Vector2i = Vector2i(-999, -999)

# --- what has been read off disk -------------------------------------------
var grid_min: Vector2i = Vector2i(-12, -8)
var grid_max: Vector2i = Vector2i(7, 31)
var cells: Dictionary = {}            # Vector2i -> {biome, terrain, danger, location_id, location_name, location_type, scene_path, wip, region}
var quests_per_location: Dictionary = {}   # location/zone id -> int
var people_per_cell: Dictionary = {}       # Vector2i -> Array[String] of npc ids at `hour`
var scene_cover: Dictionary = {}           # Vector2i -> location_id of the scene covering it
var schedule_records: Dictionary = {}
var archetypes: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_reload()


## ============================================================================
## READING
## ============================================================================

func _reload() -> void:
	_read_world()
	_read_quests()
	_read_people()
	_refresh_summary()
	if canvas:
		canvas.queue_redraw()


## The world, out of WorldGrid's own statics. This runs in the editor, where the
## autoload does not exist, so the script is loaded and initialised by hand -
## which also means the biome column is the real climate model's output and not
## a second implementation of it.
func _read_world() -> void:
	cells.clear()
	scene_cover.clear()

	var wg: Script = load("res://scripts/data/world_grid.gd")
	if wg == null:
		push_error("[WorldOverview] Could not load world_grid.gd")
		return

	wg.force_reload()
	grid_min = wg.GRID_MIN
	grid_max = wg.GRID_MAX

	for y: int in range(grid_min.y, grid_max.y + 1):
		for x: int in range(grid_min.x, grid_max.x + 1):
			var coords := Vector2i(x, y)
			var cell: Variant = wg.get_cell(coords)
			if cell == null:
				continue
			cells[coords] = {
				"biome": int(cell.biome),
				"terrain": int(cell.terrain),
				"danger": int(cell.danger_level),
				"location_id": String(cell.location_id),
				"location_name": String(cell.location_name),
				"location_type": int(cell.location_type),
				"scene_path": String(cell.scene_path),
				"scene_size": cell.scene_size as Vector2,
				"wip": bool(cell.wip),
				"region": String(cell.region_name),
			}

	# Which cells a hand-built level actually covers. A town with a 300x300
	# scene occupies nine cells, and the map has never shown that.
	for coords: Vector2i in cells:
		var info: Dictionary = cells[coords]
		if String(info["scene_path"]).is_empty():
			continue
		var size: Vector2 = info["scene_size"]
		var half_w: int = int(floor((size.x / 100.0) / 2.0))
		var half_d: int = int(floor((size.y / 100.0) / 2.0))
		for dy: int in range(-half_d, half_d + 1):
			for dx: int in range(-half_w, half_w + 1):
				scene_cover[coords + Vector2i(dx, dy)] = info["location_id"]


## How many quests name each place - as giver region, as turn-in zone, or as an
## objective's target zone. A settlement with people and no quests is a room
## nobody has been given a reason to enter, and this is where that shows.
func _read_quests() -> void:
	quests_per_location.clear()
	for path: String in _files_under("res://data/quests", ".json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			continue
		var quest: Dictionary = parsed
		var zones: Dictionary = {}
		for key: String in ["giver_region", "turn_in_zone", "turn_in_region"]:
			var zone: String = String(quest.get(key, ""))
			if not zone.is_empty():
				zones[zone] = true
		for obj: Variant in quest.get("objectives", []) as Array:
			var target_zone: String = String((obj as Dictionary).get("target_zone", ""))
			if not target_zone.is_empty():
				zones[target_zone] = true
		for zone: String in zones:
			quests_per_location[zone] = int(quests_per_location.get(zone, 0)) + 1


func _read_people() -> void:
	schedule_records.clear()
	archetypes.clear()

	var dir := DirAccess.open("res://data/schedules/archetypes")
	if dir:
		for file_name: String in dir.get_files():
			if not file_name.ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("res://data/schedules/archetypes".path_join(file_name)))
			if parsed is Dictionary:
				archetypes[String((parsed as Dictionary).get("id", file_name.get_basename()))] = parsed

	if FileAccess.file_exists("res://data/npc_schedules.json"):
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_schedules.json"))
		if doc is Dictionary:
			schedule_records = (doc as Dictionary).get("npcs", {})

	_recount_people()


## Who is standing in which cell, at this hour. Mirrors NPCScheduler's own rule:
## an absent (interior) station is absent, not relocated.
func _recount_people() -> void:
	people_per_cell.clear()
	for npc_id: String in schedule_records:
		var record: Dictionary = schedule_records[npc_id]
		var archetype: Dictionary = archetypes.get(String(record.get("archetype", "")), {})
		var wanted: String = "work"
		for block: Variant in archetype.get("blocks", []) as Array:
			var b: Dictionary = block
			var from_hour: int = int(b.get("from", 0))
			var to_hour: int = int(b.get("to", 24))
			var inside: bool = (hour >= from_hour and hour < to_hour) if from_hour <= to_hour \
				else (hour >= from_hour or hour < to_hour)
			if inside:
				wanted = String(b.get("station", "work"))
				break

		var stations: Dictionary = record.get("stations", {})
		var station: Dictionary = stations.get(wanted, stations.get("work", {}))
		if station.is_empty() or station.get("interior", false):
			continue
		var cell_arr: Array = station.get("cell", [0, 0])
		var coords := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		if not people_per_cell.has(coords):
			people_per_cell[coords] = [] as Array[String]
		(people_per_cell[coords] as Array).append(npc_id)


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


## ============================================================================
## UI
## ============================================================================

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)

	bar.add_child(_label("View:"))
	view_option = OptionButton.new()
	for name: String in VIEW_NAMES:
		view_option.add_item(name)
	view_option.selected = current_view
	view_option.item_selected.connect(_on_view_changed)
	bar.add_child(view_option)

	bar.add_child(VSeparator.new())
	bar.add_child(_label("Hour:"))
	hour_slider = HSlider.new()
	hour_slider.min_value = 0
	hour_slider.max_value = 23
	hour_slider.step = 1
	hour_slider.value = hour
	hour_slider.custom_minimum_size.x = 140
	hour_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	hour_slider.value_changed.connect(_on_hour_changed)
	bar.add_child(hour_slider)
	hour_label = _label("13:00")
	bar.add_child(hour_label)

	bar.add_child(VSeparator.new())
	var reload_btn := Button.new()
	reload_btn.text = "Reread the world"
	reload_btn.tooltip_text = "Rebuild everything from disk: WorldGrid, data/quests/, data/npc_schedules.json. Press this after saving in any other tool."
	reload_btn.pressed.connect(_reload)
	bar.add_child(reload_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(split)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(scroll)

	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(
		(grid_max.x - grid_min.x + 1) * CELL_PX + 40,
		(grid_max.y - grid_min.y + 1) * CELL_PX + 40
	)
	canvas.mouse_filter = MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_map)
	canvas.gui_input.connect(_on_canvas_input)
	scroll.add_child(canvas)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	split.add_child(side)

	legend = RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.fit_content = true
	legend.custom_minimum_size.y = 200
	side.add_child(legend)

	side.add_child(HSeparator.new())

	summary = RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.size_flags_vertical = SIZE_EXPAND_FILL
	side.add_child(summary)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_view_changed(index: int) -> void:
	current_view = index
	_refresh_summary()
	canvas.queue_redraw()


func _on_hour_changed(value: float) -> void:
	hour = int(value)
	hour_label.text = "%02d:00" % hour
	_recount_people()
	_refresh_summary()
	canvas.queue_redraw()


func _on_canvas_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var pos: Vector2 = (event as InputEventMouseMotion).position - Vector2(20, 20)
	var coords := Vector2i(
		grid_min.x + int(floor(pos.x / CELL_PX)),
		grid_min.y + int(floor(pos.y / CELL_PX))
	)
	if coords != hovered:
		hovered = coords
		_refresh_summary()
		canvas.queue_redraw()


## ============================================================================
## DRAWING
## ============================================================================

func _draw_map() -> void:
	var font: Font = ThemeDB.fallback_font
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.11, 0.11, 0.13))

	for coords: Vector2i in cells:
		var rect := Rect2(
			Vector2((coords.x - grid_min.x) * CELL_PX + 20, (coords.y - grid_min.y) * CELL_PX + 20),
			Vector2(CELL_PX, CELL_PX)
		)
		canvas.draw_rect(rect, _color_for(coords))

		var mark: String = _mark_for(coords)
		if not mark.is_empty():
			canvas.draw_string(font, rect.position + Vector2(3, CELL_PX - 4), mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.05, 0.05))

		var info: Dictionary = cells[coords]
		if not String(info["location_id"]).is_empty():
			canvas.draw_rect(rect, Color(1, 1, 1, 0.55), false, 1.0)

	# Elder Moor
	var origin_rect := Rect2(
		Vector2((0 - grid_min.x) * CELL_PX + 20, (0 - grid_min.y) * CELL_PX + 20),
		Vector2(CELL_PX, CELL_PX)
	)
	canvas.draw_rect(origin_rect, Color(1.0, 0.85, 0.0), false, 2.0)

	if cells.has(hovered):
		var hover_rect := Rect2(
			Vector2((hovered.x - grid_min.x) * CELL_PX + 20, (hovered.y - grid_min.y) * CELL_PX + 20),
			Vector2(CELL_PX, CELL_PX)
		)
		canvas.draw_rect(hover_rect, Color(1, 1, 1, 0.9), false, 2.0)


func _color_for(coords: Vector2i) -> Color:
	var info: Dictionary = cells[coords]
	match current_view:
		View.BIOME:
			var biome: int = int(info["biome"])
			return BIOME_COLORS[biome] if biome >= 0 and biome < BIOME_COLORS.size() else Color.MAGENTA

		View.DANGER:
			var danger: float = clampf(float(info["danger"]) / 10.0, 0.0, 1.0)
			return Color(0.16, 0.16, 0.2).lerp(Color(0.9, 0.2, 0.15), danger)

		View.PLACES:
			var loc_type: int = int(info["location_type"])
			if loc_type == 0:
				return Color(0.16, 0.17, 0.19)
			if bool(info["wip"]):
				return Color(0.55, 0.45, 0.15)
			# Green when a hand-built level streams there, blue when procedural.
			return Color(0.35, 0.72, 0.4) if not String(info["scene_path"]).is_empty() else Color(0.3, 0.45, 0.75)

		View.QUESTS:
			var count: int = int(quests_per_location.get(String(info["location_id"]), 0))
			if String(info["location_id"]).is_empty():
				return Color(0.14, 0.14, 0.16)
			if count == 0:
				return Color(0.42, 0.20, 0.20)
			return Color(0.25, 0.3, 0.25).lerp(Color(0.55, 0.95, 0.5), clampf(float(count) / 8.0, 0.1, 1.0))

		View.PEOPLE:
			var here: Array = people_per_cell.get(coords, [])
			if here.is_empty():
				return Color(0.15, 0.15, 0.17)
			return Color(0.2, 0.25, 0.35).lerp(Color(0.95, 0.85, 0.4), clampf(float(here.size()) / 25.0, 0.15, 1.0))

		View.SCENES:
			if not String(info["scene_path"]).is_empty():
				return Color(0.35, 0.72, 0.4)
			if scene_cover.has(coords):
				return Color(0.22, 0.42, 0.26)
			return Color(0.16, 0.16, 0.18)

	return Color.MAGENTA


func _mark_for(coords: Vector2i) -> String:
	var info: Dictionary = cells[coords]
	match current_view:
		View.QUESTS:
			var count: int = int(quests_per_location.get(String(info["location_id"]), 0))
			if not String(info["location_id"]).is_empty():
				return str(count)
		View.PEOPLE:
			var here: Array = people_per_cell.get(coords, [])
			if not here.is_empty():
				return str(here.size())
		View.DANGER:
			return str(int(info["danger"]))
		_:
			if not String(info["location_id"]).is_empty():
				return String(info["location_name"]).substr(0, 1)
	return ""


## ============================================================================
## THE SIDE PANEL
## ============================================================================

func _refresh_summary() -> void:
	if legend == null:
		return

	var legend_lines: Array[String] = ["[b]%s[/b]" % VIEW_NAMES[current_view], ""]
	match current_view:
		View.BIOME:
			legend_lines.append("What the climate model decided - latitude, moisture and a mountain mask. Paint over one cell of it in World Forge's Biome tab.")
			var counts: Dictionary = {}
			for coords: Vector2i in cells:
				var b: int = int(cells[coords]["biome"])
				counts[b] = int(counts.get(b, 0)) + 1
			var names: Array = _biome_names()
			legend_lines.append("")
			for b: int in counts:
				legend_lines.append("[color=#%s]__[/color]  %s  %d" % [
					BIOME_COLORS[b].to_html(false) if b < BIOME_COLORS.size() else "ffffff",
					names[b] if b < names.size() else str(b), counts[b]
				])
		View.DANGER:
			legend_lines.append("Difficulty outward from Elder Moor. Dark is safe, red is not.")
		View.PLACES:
			legend_lines.append("[color=#59b866]__[/color]  has a hand-built level")
			legend_lines.append("[color=#4d73bf]__[/color]  streams as a procedural town")
			legend_lines.append("[color=#8c7326]__[/color]  WIP - hidden from map and fast travel")
			legend_lines.append("[color=#2a2b30]__[/color]  wilderness")
		View.QUESTS:
			legend_lines.append("How many quests name this place as a giver region, a turn-in zone or an objective's zone.")
			legend_lines.append("")
			legend_lines.append("[color=#6b3333]__[/color]  a place with NO quest pointing at it")
			legend_lines.append("[color=#8cf27f]__[/color]  eight or more")
		View.PEOPLE:
			legend_lines.append("Scheduled residents standing in each cell at %02d:00. Anyone whose station is indoors is absent, exactly as the game has them." % hour)
		View.SCENES:
			legend_lines.append("[color=#59b866]__[/color]  the cell a level is pinned to")
			legend_lines.append("[color=#386b42]__[/color]  also covered by that level's footprint")
			legend_lines.append("A big town covers more than one cell. Painting terrain under a covered cell changes nothing a player will ever see.")
	legend.text = "\n".join(legend_lines)

	var lines: Array[String] = []

	if cells.has(hovered):
		var info: Dictionary = cells[hovered]
		lines.append("[b]Cell %d, %d[/b]" % [hovered.x, hovered.y])
		lines.append("region: %s" % info["region"])
		lines.append("biome: %s" % _biome_names()[int(info["biome"])])
		lines.append("danger: %d" % int(info["danger"]))
		var loc_id: String = String(info["location_id"])
		if loc_id.is_empty():
			lines.append("[color=#888]wilderness[/color]")
		else:
			lines.append("")
			lines.append("[b]%s[/b]  (%s)" % [info["location_name"], loc_id])
			if String(info["scene_path"]).is_empty():
				lines.append("[color=#d8b878]no scene - streams procedurally[/color]")
			else:
				lines.append("scene: %s" % String(info["scene_path"]).get_file())
			if bool(info["wip"]):
				lines.append("[color=#d8b878]WIP[/color]")
			lines.append("quests naming it: %d" % int(quests_per_location.get(loc_id, 0)))
		var here: Array = people_per_cell.get(hovered, [])
		lines.append("people at %02d:00: %d" % [hour, here.size()])
		if not here.is_empty():
			var shown: Array = here.slice(0, mini(8, here.size()))
			lines.append("[color=#999]%s%s[/color]" % [", ".join(shown), ", ..." if here.size() > 8 else ""])
		lines.append("")

	# The standing count: what is furnished and what is not.
	var places: int = 0
	var with_scene: int = 0
	var wip: int = 0
	var placeless_quests: int = 0
	var quiet_places: Array[String] = []
	var empty_places: Array[String] = []
	var known_ids: Dictionary = {}

	for coords: Vector2i in cells:
		var info2: Dictionary = cells[coords]
		var loc_id2: String = String(info2["location_id"])
		if loc_id2.is_empty():
			continue
		known_ids[loc_id2] = true
		places += 1
		if not String(info2["scene_path"]).is_empty():
			with_scene += 1
		if bool(info2["wip"]):
			wip += 1
		if int(quests_per_location.get(loc_id2, 0)) == 0:
			quiet_places.append(loc_id2)
		var here2: Array = people_per_cell.get(coords, [])
		if here2.is_empty() and int(info2["location_type"]) in [1, 2, 3, 4]:
			empty_places.append(loc_id2)

	for zone: String in quests_per_location:
		if not known_ids.has(zone):
			placeless_quests += int(quests_per_location[zone])

	lines.append("[b]The world as it stands[/b]")
	lines.append("%d cells, %d places" % [cells.size(), places])
	lines.append("%d with a hand-built level, %d procedural" % [with_scene, places - with_scene])
	if wip > 0:
		lines.append("%d marked WIP" % wip)
	lines.append("%d scheduled residents" % schedule_records.size())

	if not quiet_places.is_empty():
		quiet_places.sort()
		lines.append("")
		lines.append("[color=#d8b878]%d places no quest points at:[/color]" % quiet_places.size())
		lines.append("[color=#999]%s[/color]" % ", ".join(quiet_places))

	if not empty_places.is_empty():
		empty_places.sort()
		lines.append("")
		lines.append("[color=#d8b878]%d settlements with nobody outdoors at %02d:00:[/color]" % [empty_places.size(), hour])
		lines.append("[color=#999]%s[/color]" % ", ".join(empty_places))

	if placeless_quests > 0:
		lines.append("")
		lines.append("[color=#999]%d quest references name a zone that is not a place on this grid. Some of those are interiors and dungeons and are fine.[/color]" % placeless_quests)

	summary.text = "\n".join(lines)


func _biome_names() -> Array:
	var wg: Script = load("res://scripts/data/world_grid.gd")
	if wg:
		return wg.Biome.keys()
	return []
