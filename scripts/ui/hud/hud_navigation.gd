## hud_navigation.gd - Compass, minimap, and bounty indicator for the game HUD
class_name HUDNavigation
extends Node
## Owns the navigation half of the HUD: the compass strip and its POI, enemy,
## plant and quest markers; the minimap and its coordinate readout; and the
## bounty indicator.
##
## The Controls are parented to the GameHUD itself, not to this node, so the
## draw order of the HUD's children is unchanged.

## Owning HUD, used for parenting controls and writing to the game log
var _hud: GameHUD = null

## Player and enemy references, refreshed once per frame by the HUD
var _cached_player: Node3D = null
var _cached_enemies: Array = []

## Compass
var compass_container: Control
var compass_strip: Control
var compass_markers: Array[Label] = []
var compass_poi_markers: Dictionary = {}  # poi_id -> Label
var compass_quest_marker: Label = null  # Quest objective marker
var compass_enemy_markers: Dictionary = {}  # enemy instance_id -> Label (INTUITION-based radar)
var compass_plant_markers: Dictionary = {}  # plant instance_id -> Label (HERBALISM-based detection)
var compass_quest_target_markers: Dictionary = {}  # enemy instance_id -> Label (quest bounty targets)

## Bounty indicator
var bounty_indicator: Label
var bounty_flash_timer: float = 0.0
const BOUNTY_FLASH_SPEED := 3.0
const COMPASS_WIDTH := 300.0

## Minimap with quest markers
var minimap: Minimap = null
var minimap_coord_label: Label = null

## Town/settlement zone IDs - used for quest routing and turn-in
const TOWN_ZONES: Array[String] = [
	"elder_moor", "village_elder_moor",
	"dalhurst", "city_dalhurst",
	"riverside_village",
	"town_aberdeen", "aberdeen",
	"town_whalers_abyss", "whalers_abyss",
	"city_rotherhine", "rotherhine",
	"capital_falkenhafen", "falkenhafen",
	"village_elven_outpost", "elven_outpost"
]

## Check if a zone ID represents a town/settlement
static func _is_town_zone(zone: String) -> bool:
	return zone in TOWN_ZONES
const COMPASS_HEIGHT := 24.0
const POI_FADE_DISTANCE := 90.0   # Distance at which POI markers start fading
const POI_MAX_DISTANCE := 120.0   # Distance at which POI markers are fully hidden
const ENEMY_DETECTION_BASE := 15.0  # Base detection range for enemies
const ENEMY_DETECTION_PER_INTUITION := 5.0  # Additional range per INTUITION level
const PLANT_DETECTION_MIN_HERBALISM := 5  # Minimum HERBALISM level to see plants on compass
const PLANT_DETECTION_RANGE := 30.0  # Range at which plants appear on compass

## Zone connection map for quest tracking - maps zone IDs to exit door target scenes
## Used to find which door to point to when quest objective is in another zone
var zone_connections: Dictionary = {
	# Format: "current_zone": [{"target_zone": "zone_id", "door_scene": "res://..."}, ...]
	# This is populated dynamically from zone doors in the scene
}


## Build the compass, minimap and bounty indicator under the owning HUD
func setup(hud: GameHUD) -> void:
	_hud = hud
	_setup_compass()
	_setup_minimap()
	_setup_bounty_indicator()

	# World/cell change signals - for immediate location name updates
	if PlayerGPS and PlayerGPS.has_signal("cell_changed"):
		if not PlayerGPS.cell_changed.is_connected(_on_cell_changed_hud):
			PlayerGPS.cell_changed.connect(_on_cell_changed_hud)


## Per-frame refresh, driven by the HUD's _process
func update(delta: float, player: Node3D, enemies: Array) -> void:
	_cached_player = player
	_cached_enemies = enemies
	_update_compass()
	_update_minimap_coordinates()
	_update_bounty_indicator(delta)


## Show or hide the minimap and its coordinate readout (menus hide them while open)
func set_minimap_visible(value: bool) -> void:
	if minimap:
		minimap.visible = value
	if minimap_coord_label:
		minimap_coord_label.visible = value


## Drop compass POI markers before a zone transition
func clear_poi_markers() -> void:
	_clear_all_poi_markers()


## Rebuild the zone-connection map once a new scene has initialised
func rebuild_zone_connections() -> void:
	_rebuild_zone_connections()


## Forward a line to the HUD's game log
func _add_log_entry(message: String, color: Color = Color.WHITE) -> void:
	if _hud:
		_hud.add_log_entry(message, color)


## Setup compass at top-center of screen
func _setup_compass() -> void:
	# Container with clipping mask
	compass_container = Control.new()
	compass_container.name = "CompassContainer"
	compass_container.clip_contents = true
	compass_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_container.offset_left = -COMPASS_WIDTH / 2
	compass_container.offset_right = COMPASS_WIDTH / 2
	compass_container.offset_top = 8
	compass_container.offset_bottom = 8 + COMPASS_HEIGHT
	_hud.add_child(compass_container)

	# Background panel
	var bg := ColorRect.new()
	bg.name = "CompassBG"
	bg.color = Color(0.1, 0.1, 0.12, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	compass_container.add_child(bg)

	# Center tick mark (indicates current heading)
	var center_tick := ColorRect.new()
	center_tick.name = "CenterTick"
	center_tick.color = Color(1.0, 0.9, 0.6)
	center_tick.size = Vector2(2, COMPASS_HEIGHT)
	center_tick.position = Vector2(COMPASS_WIDTH / 2 - 1, 0)
	compass_container.add_child(center_tick)

	# Strip that holds the direction markers (wider than container, scrolls)
	compass_strip = Control.new()
	compass_strip.name = "CompassStrip"
	compass_strip.size = Vector2(COMPASS_WIDTH * 2, COMPASS_HEIGHT)
	compass_strip.position = Vector2(-COMPASS_WIDTH / 2, 0)
	compass_container.add_child(compass_strip)

	# Create direction markers for the strip
	# Full rotation = 360 degrees, strip covers 720 degrees worth for seamless wrapping
	var directions: Array[Dictionary] = [
		{"label": "N", "angle": 0.0, "is_cardinal": true},
		{"label": "NE", "angle": 45.0, "is_cardinal": false},
		{"label": "E", "angle": 90.0, "is_cardinal": true},
		{"label": "SE", "angle": 135.0, "is_cardinal": false},
		{"label": "S", "angle": 180.0, "is_cardinal": true},
		{"label": "SW", "angle": 225.0, "is_cardinal": false},
		{"label": "W", "angle": 270.0, "is_cardinal": true},
		{"label": "NW", "angle": 315.0, "is_cardinal": false},
	]

	# Create two sets of markers for seamless wrap
	for offset in [0.0, 360.0]:
		for dir_data in directions:
			var marker := Label.new()
			marker.text = dir_data.label
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			# Cardinals are larger and brighter
			if dir_data.is_cardinal:
				marker.add_theme_font_size_override("font_size", 14)
				marker.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
			else:
				marker.add_theme_font_size_override("font_size", 10)
				marker.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))

			marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			marker.add_theme_constant_override("outline_size", 1)

			# Store the angle for positioning
			marker.set_meta("compass_angle", dir_data.angle + offset)

			marker.size = Vector2(30, COMPASS_HEIGHT)
			compass_strip.add_child(marker)
			compass_markers.append(marker)

	# Add tick marks between directions
	for offset in [0.0, 360.0]:
		for i in range(16):
			var tick_angle: float = i * 22.5 + offset
			# Skip where labels are
			if int(tick_angle) % 45 == 0:
				continue
			var tick := ColorRect.new()
			tick.color = Color(0.5, 0.5, 0.5, 0.5)
			tick.size = Vector2(1, 6)
			tick.set_meta("compass_angle", tick_angle)
			compass_strip.add_child(tick)
			# We don't track ticks in compass_markers since they use same update logic


## Setup minimap with quest markers and cell coordinates
func _setup_minimap() -> void:
	# Create minimap instance
	minimap = Minimap.new()
	minimap.name = "Minimap"
	_hud.add_child(minimap)

	# Create cell coordinates label below minimap
	minimap_coord_label = Label.new()
	minimap_coord_label.name = "CellCoordinates"
	minimap_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_coord_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_coord_label.offset_left = -130
	minimap_coord_label.offset_right = -10
	minimap_coord_label.offset_top = 165  # Below minimap
	minimap_coord_label.offset_bottom = 185
	minimap_coord_label.add_theme_font_size_override("font_size", 14)
	minimap_coord_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	minimap_coord_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	minimap_coord_label.add_theme_constant_override("outline_size", 2)
	minimap_coord_label.text = "(0, 0)"
	_hud.add_child(minimap_coord_label)


## Update minimap cell coordinates display
## Shows: zone name for current region/area using WorldGrid data directly
func _update_minimap_coordinates() -> void:
	if not minimap_coord_label or not _cached_player:
		return

	# Get cell info directly from WorldGrid using PlayerGPS.current_cell
	if not PlayerGPS:
		minimap_coord_label.visible = false
		return

	# Check for location name override (set by special scenes like boat voyage)
	if not PlayerGPS.location_name_override.is_empty():
		minimap_coord_label.text = PlayerGPS.location_name_override
		minimap_coord_label.visible = true
		return

	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(PlayerGPS.current_cell)
	if not cell_info:
		minimap_coord_label.text = "Unknown"
		minimap_coord_label.visible = true
		return

	# Use location_name if available, otherwise show directional wilderness name
	if not cell_info.location_name.is_empty():
		minimap_coord_label.text = cell_info.location_name
	else:
		minimap_coord_label.text = _get_wilderness_name(PlayerGPS.current_cell, cell_info)

	minimap_coord_label.visible = true


## Get wilderness name with directional context relative to nearest named location
## Returns "Direction of LocationName" or falls back to "Biome Wilderness"
func _get_wilderness_name(cell_coords: Vector2i, cell_info: WorldGrid.CellInfo) -> String:
	# Maximum distance (in cells) to consider for directional naming
	const MAX_DIRECTION_DISTANCE := 8

	var nearest_location_id: String = ""
	var nearest_location_name: String = ""
	var nearest_coords := Vector2i.ZERO
	var nearest_distance: int = 999

	# Search through all locations to find the nearest named one
	for loc_id: String in WorldGrid.locations:
		var loc_coords: Vector2i = WorldGrid.locations[loc_id]
		var loc_cell: WorldGrid.CellInfo = WorldGrid.get_cell(loc_coords)

		# Skip locations without names or dungeons (they often have generic names like "Ruined Temple")
		if not loc_cell or loc_cell.location_name.is_empty():
			continue

		# Skip dungeon-type locations for directional references (use towns/villages/landmarks)
		if loc_cell.location_type == WorldGrid.LocationType.DUNGEON:
			continue

		var distance: int = WorldGrid.grid_distance(cell_coords, loc_coords)
		if distance < nearest_distance and distance > 0:  # distance > 0 to skip self
			nearest_distance = distance
			nearest_location_id = loc_id
			nearest_location_name = loc_cell.location_name
			nearest_coords = loc_coords

	# If no nearby location found within range, fall back to biome name
	if nearest_location_name.is_empty() or nearest_distance > MAX_DIRECTION_DISTANCE:
		var biome_name: String = WorldGrid.Biome.keys()[cell_info.biome].capitalize()
		return "%s Wilderness" % biome_name

	# Calculate cardinal direction from the location to the player
	var direction: String = _get_cardinal_direction(nearest_coords, cell_coords)

	return "%s of %s" % [direction, nearest_location_name]


## Get cardinal direction from source to target coordinates
## Returns "North", "South", "East", "West", or intercardinals like "Northeast"
func _get_cardinal_direction(from_coords: Vector2i, to_coords: Vector2i) -> String:
	var dx: int = to_coords.x - from_coords.x  # Positive = East
	var dy: int = to_coords.y - from_coords.y  # Positive = South (grid Y increases southward)

	# Determine primary and secondary directions
	var ns: String = ""
	var ew: String = ""

	if dy < 0:
		ns = "North"
	elif dy > 0:
		ns = "South"

	if dx > 0:
		ew = "East"
	elif dx < 0:
		ew = "West"

	# If movement is primarily in one direction (ratio > 2:1), use single cardinal
	var abs_dx: int = abs(dx)
	var abs_dy: int = abs(dy)

	if abs_dx == 0 and abs_dy == 0:
		return "Near"

	# Check if strongly one direction or diagonal
	if abs_dx > abs_dy * 2:
		return ew  # Primarily east/west
	elif abs_dy > abs_dx * 2:
		return ns  # Primarily north/south
	elif not ns.is_empty() and not ew.is_empty():
		return ns + ew  # Diagonal: "Northeast", "Southwest", etc.
	elif not ns.is_empty():
		return ns
	elif not ew.is_empty():
		return ew

	return "Near"


## Convert zone ID to friendly display name
func _get_friendly_region_name(zone_id: String) -> String:
	# Map of zone IDs to friendly display names
	var friendly_names: Dictionary = {
		# Elder Moor variants
		"village_elder_moor": "Elder Moor",
		"elder_moor": "Elder Moor",
		"region_elder_moor": "Elder Moor",
		# Dalhurst variants
		"city_dalhurst": "Dalhurst",
		"dalhurst": "Dalhurst",
		"region_dalhurst": "Dalhurst",
		# Thornfield
		"thornfield": "Thornfield",
		"town_thornfield": "Thornfield",
		# Millbrook
		"millbrook": "Millbrook",
		"town_millbrook": "Millbrook",
		# Willow Dale
		"willow_dale": "Willow Dale Ruins",
		"dungeon_willow_dale": "Willow Dale Ruins",
		# Sunken Crypt
		"sunken_crypt": "Sunken Crypt",
		"sunken_crypts": "Sunken Crypts",
		# Bandit Hideout
		"bandit_hideout": "Bandit Hideout",
		"bandit_hideout_exterior": "Bandit Hideout",
		# Kazer-Dun
		"kazer_dun_entrance": "Kazer-Dun Entrance",
		"kazan_dun": "Kazan-Dun",
		"city_kazan_dun": "Kazan-Dun",
		# Crossroads
		"crossroads": "The Crossroads",
		# Other locations
		"falkenhaften": "Falkenhaften",
		"capital_falkenhafen": "Falkenhaften",
		"riverside_village": "Riverside Village",
		"village_riverside": "Riverside Village",
		"aberdeen": "Aberdeen",
		"town_aberdeen": "Aberdeen",
		"larton": "Larton",
		"town_larton": "Larton",
		"whalers_abyss": "Whaler's Abyss",
		"town_whalers_abyss": "Whaler's Abyss",
		"east_hollow": "East Hollow",
		"town_east_hollow": "East Hollow",
		"kings_watch": "King's Watch",
		"outpost_kings_watch": "King's Watch",
		"pola_perron": "Pola Perron",
		"village_pola_perron": "Pola Perron",
		"windmere": "Windmere",
		"hamlet_windmere": "Windmere",
		"stonehaven": "Stonehaven",
		"village_stonehaven": "Stonehaven",
		"duncaster": "Duncaster",
		"town_duncaster": "Duncaster",
		"dusty_hollow": "Dusty Hollow",
		"hamlet_dusty_hollow": "Dusty Hollow",
		"old_crossing": "Old Crossing",
		"village_old_crossing": "Old Crossing",
		"elven_outpost": "Elven Outpost",
		"village_elven_outpost": "Elven Outpost",
		"tenger_camp": "Tenger Camp",
		"outpost_tenger_camp": "Tenger Camp",
		# Dungeons
		"vampire_crypt": "Vampire Crypt",
		"dungeon_vampire_crypt": "Vampire Crypt",
		"mosshall_tombs": "Mosshall Tombs",
		"dungeon_mosshall_tombs": "Mosshall Tombs",
		"goblin_cave": "Goblin Cave",
		"random_cave": "Cave",
		"dark_crypt": "Dark Crypt"
	}

	if friendly_names.has(zone_id):
		return friendly_names[zone_id]

	# Fallback: clean up the zone_id string
	# Remove common prefixes and convert underscores to spaces
	var clean_name: String = zone_id
	for prefix in ["village_", "town_", "city_", "capital_", "dungeon_", "region_", "hamlet_", "outpost_"]:
		if clean_name.begins_with(prefix):
			clean_name = clean_name.substr(prefix.length())
			break

	return clean_name.replace("_", " ").capitalize()


## Handle cell changed signal from PlayerGPS for immediate location updates
func _on_cell_changed_hud(old_cell: Vector2i, new_cell: Vector2i) -> void:
	if not minimap_coord_label:
		return

	# Check for location name override (set by special scenes like boat voyage)
	if PlayerGPS and not PlayerGPS.location_name_override.is_empty():
		minimap_coord_label.text = PlayerGPS.location_name_override
		minimap_coord_label.visible = true
		return

	# Get cell info from WorldGrid
	var cell_info: WorldGrid.CellInfo = WorldGrid.get_cell(new_cell)
	if not cell_info:
		minimap_coord_label.text = "Unknown"
		minimap_coord_label.visible = true
		return

	# Immediately update location display - prioritize cell.location_name
	if not cell_info.location_name.is_empty():
		minimap_coord_label.text = cell_info.location_name
	else:
		# Show directional wilderness name relative to nearest location
		minimap_coord_label.text = _get_wilderness_name(new_cell, cell_info)

	minimap_coord_label.visible = true


## Update compass based on player rotation
func _update_compass() -> void:
	if not compass_strip:
		return

	# Use cached player reference (validated in _process)
	if not _cached_player or not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		return
	var player: Node3D = _cached_player

	# Get camera yaw if available, otherwise player yaw
	var camera := get_viewport().get_camera_3d()
	var yaw_degrees: float = 0.0
	if camera:
		yaw_degrees = rad_to_deg(-camera.global_rotation.y)
	else:
		yaw_degrees = rad_to_deg(-player.global_rotation.y)

	# Normalize to 0-360
	yaw_degrees = fmod(yaw_degrees + 360.0, 360.0)

	# Position markers based on current heading
	# Pixels per degree
	var ppd := COMPASS_WIDTH / 90.0  # Show 90 degrees of view in the compass

	for child in compass_strip.get_children():
		if not child.has_meta("compass_angle"):
			continue

		var marker_angle: float = child.get_meta("compass_angle")

		# Calculate relative angle from current heading
		var rel_angle := marker_angle - yaw_degrees

		# Wrap to -180 to 180 for the first set
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position on strip (center is at COMPASS_WIDTH / 2 relative to strip's position in container)
		# Since strip is offset by -COMPASS_WIDTH/2, and container clips to COMPASS_WIDTH,
		# marker at center of container should be at strip position COMPASS_WIDTH
		var x_pos := COMPASS_WIDTH + rel_angle * ppd

		if child is Label:
			child.position.x = x_pos - child.size.x / 2
			child.position.y = (COMPASS_HEIGHT - child.size.y) / 2
		else:
			# Tick marks
			child.position.x = x_pos
			child.position.y = COMPASS_HEIGHT - child.size.y - 2

	# Update POI markers (currently disabled)
	_update_compass_pois(player, yaw_degrees, ppd)

	# Update enemy radar markers (INTUITION skill)
	_update_compass_enemies(player, yaw_degrees, ppd)

	# Update quest target enemy markers (bounty targets - always visible)
	_update_compass_quest_targets(player, yaw_degrees, ppd)

	# Update harvestable plant markers (HERBALISM skill 5+)
	_update_compass_plants(player, yaw_degrees, ppd)

	# Update compass quest marker (points to objective or door)
	_update_compass_quest_marker(player, yaw_degrees, ppd)


## Update POI markers on compass
## DISABLED: POI markers were cluttering the compass - disabled for now
func _update_compass_pois(_player: Node3D, _yaw_degrees: float, _ppd: float) -> void:
	# POI markers disabled - return early
	# Clear any existing markers
	for poi_id: String in compass_poi_markers:
		var marker: Label = compass_poi_markers[poi_id]
		if is_instance_valid(marker):
			marker.queue_free()
	compass_poi_markers.clear()
	# Note: POI marker code removed - can restore from git if needed


## Create a POI marker for the compass
func _create_poi_marker(poi_node: Node3D) -> Label:
	var marker := Label.new()
	var poi_name: String = poi_node.get_meta("display_name", poi_node.get_meta("poi_name", "?"))
	var poi_color: Color = poi_node.get_meta("poi_color", Color.WHITE)
	var poi_icon: String = poi_node.get_meta("poi_icon", "◆")  # Default diamond

	# Use custom icon or default diamond
	marker.text = poi_icon
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 14)
	marker.add_theme_color_override("font_color", poi_color)
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 2)
	marker.tooltip_text = poi_name
	marker.size = Vector2(20, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update enemy radar markers on compass (INTUITION skill)
## Shows red dots for nearby enemies based on player's INTUITION skill level
func _update_compass_enemies(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# Get player's INTUITION skill to determine detection range
	var intuition_level: int = 0
	if GameManager.player_data:
		intuition_level = GameManager.player_data.get_skill(Enums.Skill.INTUITION)

	# Calculate detection range: base + (INTUITION * bonus per level)
	var detection_range: float = ENEMY_DETECTION_BASE + (intuition_level * ENEMY_DETECTION_PER_INTUITION)

	# PERFORMANCE: Use cached enemies instead of get_nodes_in_group()
	# Track which enemy IDs are still valid this frame
	var valid_enemy_ids: Dictionary = {}

	for enemy in _cached_enemies:
		if not enemy is Node3D:
			continue

		var enemy_node := enemy as Node3D

		# Skip dead enemies
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var enemy_id: int = enemy_node.get_instance_id()
		valid_enemy_ids[enemy_id] = true

		# Calculate distance to enemy
		var to_enemy := enemy_node.global_position - player.global_position
		var distance := to_enemy.length()

		# Skip if too far (beyond detection range)
		if distance > detection_range:
			if compass_enemy_markers.has(enemy_id):
				compass_enemy_markers[enemy_id].visible = false
			continue

		# Calculate angle to enemy (in degrees, 0 = north/+Z)
		var enemy_angle := rad_to_deg(atan2(-to_enemy.x, -to_enemy.z))
		enemy_angle = fmod(enemy_angle + 360.0, 360.0)

		# Get or create marker
		var marker: Label
		if compass_enemy_markers.has(enemy_id):
			marker = compass_enemy_markers[enemy_id]
			# Validate the marker is still valid
			if not is_instance_valid(marker):
				marker = _create_enemy_marker()
				compass_enemy_markers[enemy_id] = marker
		else:
			marker = _create_enemy_marker()
			compass_enemy_markers[enemy_id] = marker

		# Calculate relative angle
		var rel_angle := enemy_angle - yaw_degrees
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position marker
		var x_pos := COMPASS_WIDTH + rel_angle * ppd
		marker.position.x = x_pos - marker.size.x / 2
		marker.position.y = COMPASS_HEIGHT - 10  # Position at bottom of compass

		# Fade based on distance (closer = more opaque)
		var alpha := 1.0 - (distance / detection_range) * 0.5  # Fade from 1.0 to 0.5
		marker.modulate.a = alpha

		# Only show if within view arc (roughly 90 degrees)
		marker.visible = abs(rel_angle) < 50.0

	# Clean up stale enemy markers
	var stale_ids: Array[int] = []
	for enemy_id in compass_enemy_markers:
		var marker = compass_enemy_markers[enemy_id]
		if not valid_enemy_ids.has(enemy_id) or not is_instance_valid(marker):
			stale_ids.append(enemy_id)

	# Remove stale entries
	for enemy_id in stale_ids:
		var marker = compass_enemy_markers.get(enemy_id)
		compass_enemy_markers.erase(enemy_id)
		if marker and is_instance_valid(marker):
			marker.queue_free()


## Create an enemy radar marker for the compass (red dot)
func _create_enemy_marker() -> Label:
	var marker := Label.new()

	# Small red circle/dot for enemy
	marker.text = "●"  # Filled circle
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 10)
	marker.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red for enemies
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 1)
	marker.tooltip_text = "Enemy"
	marker.size = Vector2(16, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update quest target enemy markers on compass (bounty targets)
## Shows gold/teal markers for enemies that are targets of active kill quests
## Always visible regardless of INTUITION skill - these are marked targets
const QUEST_TARGET_RANGE := 100.0  # Range at which quest targets appear on compass
func _update_compass_quest_targets(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# PERFORMANCE: Use cached enemies instead of get_nodes_in_group()
	# Track which enemy IDs are still valid this frame
	var valid_enemy_ids: Dictionary = {}

	for enemy in _cached_enemies:
		if not enemy is Node3D:
			continue

		var enemy_node := enemy as Node3D

		# Skip dead enemies
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		# Get enemy data ID to check against quest targets
		var enemy_id_str: String = ""
		if enemy.has_method("get_enemy_data"):
			var enemy_data = enemy.get_enemy_data()
			if enemy_data:
				enemy_id_str = enemy_data.id if "id" in enemy_data else ""

		if enemy_id_str.is_empty():
			continue

		# Check if this enemy is a quest target
		var target_info: Dictionary = QuestManager.is_enemy_quest_target(enemy_id_str)
		if target_info.is_empty():
			continue

		var enemy_instance_id: int = enemy_node.get_instance_id()
		valid_enemy_ids[enemy_instance_id] = true

		# Calculate distance to enemy
		var to_enemy := enemy_node.global_position - player.global_position
		var distance := to_enemy.length()

		# Skip if too far
		if distance > QUEST_TARGET_RANGE:
			if compass_quest_target_markers.has(enemy_instance_id):
				compass_quest_target_markers[enemy_instance_id].visible = false
			continue

		# Calculate angle to enemy (in degrees, 0 = north/+Z)
		var enemy_angle := rad_to_deg(atan2(-to_enemy.x, -to_enemy.z))
		enemy_angle = fmod(enemy_angle + 360.0, 360.0)

		# Get or create marker
		var marker: Label
		var is_main: bool = target_info.get("is_main", false)
		if compass_quest_target_markers.has(enemy_instance_id):
			marker = compass_quest_target_markers[enemy_instance_id]
			if not is_instance_valid(marker):
				marker = _create_quest_target_marker(is_main)
				compass_quest_target_markers[enemy_instance_id] = marker
		else:
			marker = _create_quest_target_marker(is_main)
			compass_quest_target_markers[enemy_instance_id] = marker

		# Calculate relative angle
		var rel_angle := enemy_angle - yaw_degrees
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position marker
		var x_pos := COMPASS_WIDTH + rel_angle * ppd
		marker.position.x = x_pos - marker.size.x / 2
		marker.position.y = (COMPASS_HEIGHT - marker.size.y) / 2  # Center vertically (like quest markers)

		# Update tooltip with remaining count
		var remaining: int = target_info.get("remaining", 1)
		marker.tooltip_text = "Quest Target (%d remaining)" % remaining

		# Only show if within view arc (roughly 90 degrees)
		marker.visible = abs(rel_angle) < 50.0

	# Clean up stale markers
	var stale_ids: Array[int] = []
	for enemy_id in compass_quest_target_markers:
		var marker = compass_quest_target_markers[enemy_id]
		if not valid_enemy_ids.has(enemy_id) or not is_instance_valid(marker):
			stale_ids.append(enemy_id)

	for enemy_id in stale_ids:
		var marker = compass_quest_target_markers.get(enemy_id)
		compass_quest_target_markers.erase(enemy_id)
		if marker and is_instance_valid(marker):
			marker.queue_free()


## Create a quest target marker for the compass (gold/teal star)
func _create_quest_target_marker(is_main_quest: bool) -> Label:
	var marker := Label.new()

	# Star icon for quest targets
	marker.text = "★"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 14)

	# Gold for main quests, teal for side quests/bounties
	if is_main_quest:
		marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # Gold
	else:
		marker.add_theme_color_override("font_color", Color(0.2, 0.8, 0.8))  # Teal

	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 2)
	marker.tooltip_text = "Quest Target"
	marker.size = Vector2(18, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update harvestable plant markers on compass (HERBALISM skill)
## Shows green dots for nearby plants if player has HERBALISM 5+
func _update_compass_plants(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# Check if player has minimum HERBALISM skill
	var herbalism_level: int = 0
	if GameManager.player_data:
		herbalism_level = GameManager.player_data.get_skill(Enums.Skill.HERBALISM)

	# If HERBALISM is below threshold, hide all plant markers and return
	if herbalism_level < PLANT_DETECTION_MIN_HERBALISM:
		for plant_id in compass_plant_markers:
			var marker = compass_plant_markers[plant_id]
			if is_instance_valid(marker):
				marker.visible = false
		return

	# Get all harvestable plants in the scene
	var plants := get_tree().get_nodes_in_group("harvestable_plants")

	# Track which plant IDs are still valid this frame
	var valid_plant_ids: Dictionary = {}

	for plant in plants:
		if not plant is Node3D:
			continue

		var plant_node := plant as Node3D

		# Skip harvested plants
		if "has_been_harvested" in plant and plant.has_been_harvested:
			continue

		var plant_id: int = plant_node.get_instance_id()
		valid_plant_ids[plant_id] = true

		# Calculate distance to plant
		var to_plant := plant_node.global_position - player.global_position
		var distance := to_plant.length()

		# Skip if too far
		if distance > PLANT_DETECTION_RANGE:
			if compass_plant_markers.has(plant_id):
				compass_plant_markers[plant_id].visible = false
			continue

		# Calculate angle to plant (in degrees, 0 = north/+Z)
		var plant_angle := rad_to_deg(atan2(-to_plant.x, -to_plant.z))
		plant_angle = fmod(plant_angle + 360.0, 360.0)

		# Get or create marker
		var marker: Label
		if compass_plant_markers.has(plant_id):
			marker = compass_plant_markers[plant_id]
			if not is_instance_valid(marker):
				marker = _create_plant_marker()
				compass_plant_markers[plant_id] = marker
		else:
			marker = _create_plant_marker()
			compass_plant_markers[plant_id] = marker

		# Calculate relative angle
		var rel_angle := plant_angle - yaw_degrees
		while rel_angle < -180.0:
			rel_angle += 360.0
		while rel_angle > 180.0:
			rel_angle -= 360.0

		# Position marker
		var x_pos := COMPASS_WIDTH + rel_angle * ppd
		marker.position.x = x_pos - marker.size.x / 2
		marker.position.y = COMPASS_HEIGHT - 10  # Position at bottom of compass

		# Fade based on distance (closer = more opaque)
		var alpha := 1.0 - (distance / PLANT_DETECTION_RANGE) * 0.5
		marker.modulate.a = alpha

		# Only show if within view arc
		marker.visible = abs(rel_angle) < 50.0

	# Clean up stale plant markers
	var stale_ids: Array[int] = []
	for plant_id in compass_plant_markers:
		var marker = compass_plant_markers[plant_id]
		if not valid_plant_ids.has(plant_id) or not is_instance_valid(marker):
			stale_ids.append(plant_id)

	for plant_id in stale_ids:
		var marker = compass_plant_markers.get(plant_id)
		compass_plant_markers.erase(plant_id)
		if marker and is_instance_valid(marker):
			marker.queue_free()


## Create a plant marker for the compass (green dot)
func _create_plant_marker() -> Label:
	var marker := Label.new()

	# Small green circle for plant
	marker.text = "●"  # Filled circle
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 8)  # Smaller than enemies
	marker.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))  # Green for plants
	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 1)
	marker.tooltip_text = "Herb"
	marker.size = Vector2(14, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Update compass quest marker (points to objective or exit door)
## This is separate from the HUD quest tracker display
## KNOWN BUG: Compass quest marker not displaying for "reach" objectives
## Status: Minimap shows golden marker correctly, compass dial does not.
## Diagnosis: cached_pos is correct (300, 0, 200 for Thornfield).
## Root cause: marker positioning/visibility logic below may have FOV issues.
## Suggested fix: Check _calculate_compass_marker_position() for edge cases
## when target is behind player or at extreme angles. May need to clamp
## marker to edge of compass rather than hiding it.
var _compass_debug_timer: float = 0.0
const COMPASS_DEBUG_ENABLED := false  # Set to true to enable compass debug logging
func _update_compass_quest_marker(player: Node3D, yaw_degrees: float, ppd: float) -> void:
	# Safety check - ensure player and tree are valid
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		if compass_quest_marker and is_instance_valid(compass_quest_marker):
			compass_quest_marker.visible = false
		return

	# Debug: Log tracking state periodically (every 5 seconds) - disabled by default
	_compass_debug_timer += get_process_delta_time()
	var should_log: bool = COMPASS_DEBUG_ENABLED and _compass_debug_timer >= 5.0
	if should_log:
		_compass_debug_timer = 0.0

	var tracked_id := QuestManager.get_tracked_quest_id()
	if should_log and not tracked_id.is_empty():
		pass

	# Get the tracked quest (user-selected from journal)
	var target_quest := QuestManager.get_tracked_quest()
	if not target_quest:
		if compass_quest_marker and is_instance_valid(compass_quest_marker):
			compass_quest_marker.visible = false
		return

	# Determine target position based on objective type and location
	var target_pos: Vector3 = Vector3.ZERO
	var has_target := false
	var target_name: String = ""

	# CRITICAL FIX: Check if ALL objectives are complete FIRST - should point to turn-in NPC
	var all_objectives_complete: bool = QuestManager.are_objectives_complete(target_quest.id)

	if all_objectives_complete:
		# Quest is ready for turn-in - point to quest giver

		# Try to find turn-in NPC in current zone first
		var turnin_location := _find_turnin_npc_in_current_zone(target_quest)
		if turnin_location.found:
			target_pos = turnin_location.position
			has_target = true
			target_name = "Return to " + turnin_location.name
		else:
			# Turn-in NPC not in current zone - find exit to their zone
			var giver_zone := _get_quest_giver_zone(target_quest)
			if not giver_zone.is_empty():
				var exit_door := _find_exit_door_to_zone(giver_zone)
				if exit_door:
					target_pos = exit_door.global_position
					has_target = true
					target_name = "Return to turn in quest"
	else:
		# Quest not complete - find first incomplete objective
		var target_objective: QuestManager.Objective = null

		for obj in target_quest.objectives:
			if not obj.is_satisfied() and not obj.is_optional:
				target_objective = obj
				break

		if not target_objective:
			if compass_quest_marker and is_instance_valid(compass_quest_marker):
				compass_quest_marker.visible = false
			return

		target_name = target_objective.description

		# Check if objective can be found in current zone (pass quest for turn-in NPC lookup)
		var objective_location := _find_objective_in_current_zone(target_objective, target_quest)

		if objective_location.found:
			# Objective is in current zone - point directly to it
			target_pos = objective_location.position
			has_target = true
			target_name = objective_location.name
		else:
			# Objective is not in current zone - determine where to go
			var target_zone: String = ""

			# Check if current objective is effectively complete (for multi-step)
			var objective_complete: bool = _is_objective_effectively_complete(target_objective)
			if objective_complete and target_quest:
				# Need to find quest giver's zone (usually town)
				var giver_zone := _get_quest_giver_zone(target_quest)
				if not giver_zone.is_empty():
					target_zone = giver_zone
					target_name = "Return to turn-in NPC"

			# If not complete (or no giver zone found), find the objective's zone
			if target_zone.is_empty():
				target_zone = _get_objective_target_zone(target_objective)

			# Fallback: if target_zone is empty and we're in town, point to outdoor region
			if target_zone.is_empty():
				var current_zone: String = PlayerGPS.current_location_id if PlayerGPS else ""
				if current_zone in ["town", "riverside_village", "elder_moor", "village_elder_moor"]:
					target_zone = "open_world"

			if not target_zone.is_empty():
				var exit_door := _find_exit_door_to_zone(target_zone)
				if exit_door and is_instance_valid(exit_door) and exit_door.is_inside_tree():
					target_pos = exit_door.global_position
					has_target = true
					target_name = "Exit: " + exit_door.door_name

		# FALLBACK: Use QuestManager's cached world position (same as minimap)
		# This handles outdoor objectives like Bloodsand Arena that are reached via cell streaming
		if not has_target and target_quest and target_objective:
			var cached_pos: Vector3 = QuestManager.get_objective_world_pos(target_quest.id, target_objective.id)
			if cached_pos != Vector3.ZERO:
				target_pos = cached_pos
				has_target = true
				target_name = target_objective.description

	if not has_target:
		if compass_quest_marker and is_instance_valid(compass_quest_marker):
			compass_quest_marker.visible = false
		return

	# Determine if this is a main quest or side quest
	var is_main := target_quest.is_main_quest if target_quest else false

	# Create or update quest marker
	if not compass_quest_marker or not is_instance_valid(compass_quest_marker):
		compass_quest_marker = _create_quest_marker(is_main)
	else:
		# Update marker color based on current quest type
		if is_main:
			compass_quest_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # Gold
		else:
			compass_quest_marker.add_theme_color_override("font_color", Color(0.2, 0.8, 0.8))  # Teal

	# Calculate angle to target (0°=North, 90°=East, 180°=South, 270°=West)
	# In Godot: -Z is North, +X is East, +Z is South, -X is West
	# atan2(x, -z) gives: 0° when facing -Z (North), 90° when facing +X (East)
	var to_target := target_pos - player.global_position
	var target_angle := rad_to_deg(atan2(to_target.x, -to_target.z))
	target_angle = fmod(target_angle + 360.0, 360.0)

	# Calculate relative angle
	var rel_angle := target_angle - yaw_degrees
	while rel_angle < -180.0:
		rel_angle += 360.0
	while rel_angle > 180.0:
		rel_angle -= 360.0

	# Position marker - center it on the compass strip
	var x_pos := COMPASS_WIDTH + rel_angle * ppd
	compass_quest_marker.position.x = x_pos - compass_quest_marker.size.x / 2
	compass_quest_marker.position.y = (COMPASS_HEIGHT - compass_quest_marker.size.y) / 2  # Center vertically

	# Update tooltip
	compass_quest_marker.tooltip_text = target_name

	# Quest markers visible when within compass FOV (50 degrees from center)
	var marker_visible: bool = abs(rel_angle) < 50.0
	compass_quest_marker.visible = marker_visible



## Create the quest tracker marker (distinct from POI markers)
## is_main_quest: true = gold marker (main story), false = teal marker (side quests/bounties)
func _create_quest_marker(is_main_quest: bool = true) -> Label:
	var marker := Label.new()
	marker.name = "QuestMarker"
	marker.text = "◆"  # Diamond - more visible than down arrow
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 16)

	# Color based on quest type - bright, high contrast colors
	if is_main_quest:
		marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))  # Gold for main quests
	else:
		marker.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))  # Cyan for side/bounties

	marker.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	marker.add_theme_constant_override("outline_size", 2)
	marker.custom_minimum_size = Vector2(20, COMPASS_HEIGHT)
	marker.size = Vector2(20, COMPASS_HEIGHT)

	compass_strip.add_child(marker)
	return marker


## Find turn-in NPC for a complete quest in the current zone
## Wrapper around _find_quest_giver_position for consistency
func _find_turnin_npc_in_current_zone(quest: QuestManager.Quest) -> Dictionary:
	return _find_quest_giver_position(quest)


## Find the quest giver NPC position for turn-in
## Returns {found: bool, position: Vector3, name: String} or null if not found in current zone
func _find_quest_giver_position(quest: QuestManager.Quest) -> Dictionary:
	var result := {"found": false, "position": Vector3.ZERO, "name": "Quest Giver"}

	# First check if quest has a giver_npc_id
	var giver_id: String = quest.giver_npc_id
	var giver_name: String = ""

	# If no giver_npc_id on quest, check if this is a bounty quest via BountyManager
	if giver_id.is_empty() and quest.id.begins_with("quest_bounty"):
		# Extract bounty info from BountyManager
		for bounty_id: String in BountyManager.bounties:
			var bounty: BountyManager.Bounty = BountyManager.bounties[bounty_id]
			if bounty.quest_id == quest.id:
				giver_id = bounty.giver_npc_id
				giver_name = bounty.giver_npc_name
				result.name = giver_name
				break

	# Search for the NPC in current zone
	var npcs := get_tree().get_nodes_in_group("npcs")

	# First pass: try matching by npc_id (most reliable)
	if not giver_id.is_empty():
		for npc in npcs:
			if npc is Node3D:
				var npc_id_val: String = ""
				if "npc_id" in npc:
					npc_id_val = str(npc.get("npc_id"))

				if npc_id_val == giver_id:
					result.found = true
					result.position = (npc as Node3D).global_position
					if "display_name" in npc:
						result.name = str(npc.get("display_name"))
					elif "npc_name" in npc:
						result.name = str(npc.get("npc_name"))
					return result

	# Second pass: fallback to matching by npc_name or display_name (case-insensitive)
	# Use giver_name from bounty, or giver_id as a name if available
	var search_name: String = giver_name if not giver_name.is_empty() else giver_id
	if not search_name.is_empty():
		var search_lower: String = search_name.to_lower()
		for npc in npcs:
			if npc is Node3D:
				var npc_name_val: String = ""
				if "npc_name" in npc:
					npc_name_val = str(npc.get("npc_name"))
				elif "display_name" in npc:
					npc_name_val = str(npc.get("display_name"))

				if not npc_name_val.is_empty() and npc_name_val.to_lower() == search_lower:
					result.found = true
					result.position = (npc as Node3D).global_position
					result.name = npc_name_val
					return result

	return result


## Check if an objective is effectively complete (for turn-in purposes)
## For "collect" objectives, checks inventory; for others, checks current_count
func _is_objective_effectively_complete(objective: QuestManager.Objective) -> bool:
	match objective.type:
		"collect":
			# Check inventory for items
			var inventory_count: int = InventoryManager.get_item_count(objective.target)
			return inventory_count >= objective.required_count
		"kill", "destroy":
			return objective.current_count >= objective.required_count
		_:
			return objective.is_completed


## Get the zone where the quest giver NPC is located
## Returns the zone ID or empty string if unknown
func _get_quest_giver_zone(quest: QuestManager.Quest) -> String:
	# Check if quest has a giver_npc_id
	var giver_id: String = quest.giver_npc_id

	# If no giver_npc_id on quest, check if this is a bounty quest via BountyManager
	if giver_id.is_empty() and quest.id.begins_with("quest_bounty"):
		for bounty_id: String in BountyManager.bounties:
			var bounty: BountyManager.Bounty = BountyManager.bounties[bounty_id]
			if bounty.quest_id == quest.id:
				var settlement: String = bounty.giver_settlement
				if not settlement.is_empty():
					return _normalize_zone_id(settlement)
				break

	# For non-bounty quests, use quest metadata or lookup table
	if not giver_id.is_empty():
		# Check if quest has giver_zone metadata
		if "giver_zone" in quest and not quest.giver_zone.is_empty():
			return _normalize_zone_id(quest.giver_zone)

		# Common quest giver IDs and their zones
		var giver_zones: Dictionary = {
			# Elder Moor NPCs
			"tharin_ironbeard": "elder_moor",
			"elder": "elder_moor",
			"village_elder": "elder_moor",
			"elder_moor_guard": "elder_moor",
			"mysterious_stranger": "elder_moor",
			# Guards can be in multiple zones - check quest origin
			"guard": "elder_moor",
			"town_guard": "elder_moor",
			# Dalhurst NPCs
			"aldric_vane": "dalhurst",
			"dalhurst_contact": "dalhurst",
			"dalhurst_merchant": "dalhurst",
			"harbor_master": "dalhurst",
			# Other settlements
			"kazan_dun_smith": "kazan_dun",
			"aberdeen_mayor": "aberdeen",
		}

		if giver_zones.has(giver_id):
			return _normalize_zone_id(giver_zones[giver_id])

		# Check if giver_id contains a zone hint
		if "elder_moor" in giver_id or "elder" in giver_id:
			return "elder_moor"
		if "dalhurst" in giver_id:
			return "dalhurst"
		if "kazan" in giver_id:
			return "kazan_dun"

		# Default to starting town
		return "elder_moor"

	# Last resort - check if quest ID hints at origin
	if "elder_moor" in quest.id:
		return "elder_moor"

	return "elder_moor"  # Default fallback


## Normalize zone ID to a consistent format
func _normalize_zone_id(zone: String) -> String:
	var zone_lower: String = zone.to_lower()

	# Map various formats to canonical IDs
	if "elder" in zone_lower and "moor" in zone_lower:
		return "elder_moor"
	if "dalhurst" in zone_lower:
		return "dalhurst"
	if "kazan" in zone_lower:
		return "kazan_dun"
	if "aberdeen" in zone_lower:
		return "aberdeen"
	# if "larton" in zone_lower:  # REMOVED - orphaned zone
	#	return "larton"
	if "falkenhafen" in zone_lower:
		return "falkenhafen"
	if "riverside" in zone_lower:
		return "riverside_village"

	return zone


## Find an objective target in the current zone
## Returns {found: bool, position: Vector3, name: String, is_turnin: bool}
## Enhanced to check inventory for "collect" objectives and point to turn-in NPC when ready
func _find_objective_in_current_zone(objective: QuestManager.Objective, quest: QuestManager.Quest = null) -> Dictionary:
	var result := {"found": false, "position": Vector3.ZERO, "name": "", "is_turnin": false}

	match objective.type:
		"kill":
			# Check if kill count is already met - point to turn-in NPC
			if objective.current_count >= objective.required_count:
				if quest:
					var giver_result := _find_quest_giver_position(quest)
					if giver_result.found:
						result.found = true
						result.position = giver_result.position
						result.name = "Return to " + giver_result.name
						result.is_turnin = true
						return result
			else:
				# Still need kills - look for enemies of the target type
				# PERFORMANCE: Use cached enemies instead of get_nodes_in_group()
				for enemy in _cached_enemies:
					if enemy is Node3D and enemy.has_method("get_enemy_data"):
						var enemy_data = enemy.get_enemy_data()
						if enemy_data and (enemy_data.id == objective.target or enemy_data.id.begins_with(objective.target)):
							result.found = true
							result.position = (enemy as Node3D).global_position
							result.name = enemy_data.display_name if not enemy_data.display_name.is_empty() else objective.target
							return result

		"collect":
			# CRITICAL FIX: First check if player already has required items in inventory
			var inventory_count: int = InventoryManager.get_item_count(objective.target)
			var needs_more: bool = inventory_count < objective.required_count

			if not needs_more:
				# Player has enough items - point to turn-in NPC
				if quest:
					var giver_result := _find_quest_giver_position(quest)
					if giver_result.found:
						result.found = true
						result.position = giver_result.position
						result.name = "Return to " + giver_result.name
						result.is_turnin = true
						return result

			# Player needs more items - look for sources in priority order:
			# 1. World items on ground
			var items := get_tree().get_nodes_in_group("world_items")
			for item in items:
				if item is Node3D and item.has_method("get_item_id"):
					if item.get_item_id() == objective.target:
						result.found = true
						result.position = (item as Node3D).global_position
						result.name = InventoryManager.get_item_name(objective.target)
						return result

			# 2. Merchants who sell the item
			var merchants := get_tree().get_nodes_in_group("merchants")
			for merchant in merchants:
				if merchant is Node3D and merchant.has_method("get_shop_inventory"):
					var shop_inv: Array = merchant.get_shop_inventory()
					for shop_item in shop_inv:
						if shop_item is Dictionary and shop_item.get("item_id", "") == objective.target:
							result.found = true
							result.position = (merchant as Node3D).global_position
							var merchant_name: String = str(merchant.get("display_name")) if "display_name" in merchant else "Merchant"
							result.name = merchant_name + " (sells " + objective.target + ")"
							return result

			# 3. Containers that might have the item
			var containers := get_tree().get_nodes_in_group("containers")
			for container in containers:
				if container is Node3D:
					# Check if container has been opened and has the item
					if container.has_method("has_item"):
						if container.has_item(objective.target):
							result.found = true
							result.position = (container as Node3D).global_position
							var container_name: String = str(container.get("container_name")) if "container_name" in container else "Container"
							result.name = container_name
							return result

			# 4. If we have some items but not enough, still show turn-in NPC as a secondary option
			# (Player might be able to buy/find rest elsewhere but this gives them direction)

		"talk":
			# Look for NPCs
			var npcs := get_tree().get_nodes_in_group("npcs")
			for npc in npcs:
				if npc is Node3D:
					var npc_id: String = ""
					# Try to get npc_id property directly
					if "npc_id" in npc:
						npc_id = str(npc.get("npc_id"))
					# Also try checking by display_name converted to snake_case
					var display_name_id := ""
					if "display_name" in npc:
						display_name_id = str(npc.get("display_name")).to_lower().replace(" ", "_")

					if npc_id == objective.target or display_name_id == objective.target:
						result.found = true
						result.position = (npc as Node3D).global_position
						var npc_name: String = str(npc.get("display_name")) if "display_name" in npc else objective.target
						result.name = npc_name
						return result

		"reach":
			# First, check QuestManager's cached location for the destination
			if quest and QuestManager:
				var cached_pos: Vector3 = QuestManager.get_objective_world_pos(quest.id, objective.id)
				if cached_pos != Vector3.ZERO:
					result.found = true
					result.position = cached_pos
					# Get location name from WorldGrid
					var location_name: String = WorldGrid.get_location_name(objective.target)
					result.name = location_name if location_name != "Unknown Location" else objective.target
					return result

			# Fallback: Look for location markers or spawn points
			var spawn_points := get_tree().get_nodes_in_group("spawn_points")
			for point in spawn_points:
				if point is Node3D:
					var spawn_id: String = point.get_meta("spawn_id", "")
					if spawn_id == objective.target or point.name == objective.target:
						result.found = true
						result.position = (point as Node3D).global_position
						result.name = objective.target
						return result

		"interact":
			# Look for interactable objects
			var interactables := get_tree().get_nodes_in_group("interactable")
			for obj in interactables:
				if obj is Node3D:
					var obj_id: String = ""
					if obj.has_method("get_interaction_id"):
						obj_id = obj.get_interaction_id()
					elif "object_id" in obj:
						obj_id = obj.get("object_id")
					if obj_id == objective.target:
						result.found = true
						result.position = (obj as Node3D).global_position
						result.name = objective.target
						return result

		"destroy":
			# Check if destroy count is already met - point to turn-in NPC
			if objective.current_count >= objective.required_count:
				if quest:
					var giver_result := _find_quest_giver_position(quest)
					if giver_result.found:
						result.found = true
						result.position = giver_result.position
						result.name = "Return to " + giver_result.name
						result.is_turnin = true
						return result
			else:
				# Look for spawners/totems/destructibles with matching ID
				var spawners := get_tree().get_nodes_in_group("spawners")
				for spawner in spawners:
					if spawner is Node3D:
						var spawner_id: String = ""
						if "spawner_id" in spawner:
							spawner_id = str(spawner.get("spawner_id"))
						if spawner_id == objective.target or spawner_id.begins_with(objective.target):
							result.found = true
							result.position = (spawner as Node3D).global_position
							var spawner_name: String = str(spawner.get("display_name")) if "display_name" in spawner else objective.target
							result.name = spawner_name
							return result
				# Also check cursed_totems group
				var totems := get_tree().get_nodes_in_group("cursed_totems")
				for totem in totems:
					if totem is Node3D:
						var totem_id: String = ""
						if "spawner_id" in totem:
							totem_id = str(totem.get("spawner_id"))
						if totem_id == objective.target or totem_id.begins_with(objective.target):
							result.found = true
							result.position = (totem as Node3D).global_position
							result.name = "Cursed Totem"
							return result

	return result


## Get the zone ID where an objective target is likely located
func _get_objective_target_zone(objective: QuestManager.Objective) -> String:
	# Map objective targets to their known zones
	# This is based on quest design knowledge
	match objective.type:
		"kill":
			match objective.target:
				# Goblins - wilderness and goblin cave
				"goblin", "goblin_soldier", "goblin_archer", "goblin_shaman", "goblin_leader":
					return "open_world"
				"goblin_totem":
					return "goblin_cave"
				# Common wilderness creatures (bounty targets)
				"wolf", "dire_wolf", "giant_rat", "giant_spider", "human_bandit":
					return "open_world"
				# Undead - dungeons and wilderness
				"skeleton_warrior", "skeleton_shade", "drowned_dead":
					return "open_world"
				# Larger creatures - wilderness
				"ogre", "troll", "tree_ent", "wyvern", "basilisk":
					return "open_world"
				# Cultists - dungeons
				"cultist", "cult_leader", "abomination", "vampire_lord":
					return "open_world"  # Was dark_crypt but that zone was removed
				_:
					return "open_world"  # Default to wilderness for kill quests

		"reach":
			match objective.target:
				"goblin_cave_entrance", "goblin_cave":
					return "goblin_cave"
				"elder_moor", "village_elder_moor":
					return "elder_moor"
				"dalhurst", "city_dalhurst":
					return "dalhurst"
				"thornfield", "hamlet_thornfield":
					return "thornfield"
				"millbrook":
					return "millbrook"
				"open_world":
					return "open_world"
				_:
					# For unknown locations, return the target itself as it might be a valid zone
					return objective.target

		"collect":
			match objective.target:
				# Dungeon loot
				"goblin_war_horn", "corrupted_shard":
					return "goblin_cave"
				# Purchasable in town (use current zone if in town, else elder_moor)
				"health_potion", "mana_potion", "stamina_potion", "antidote":
					var current: String = PlayerGPS.current_location_id if PlayerGPS else ""
					return current if _is_town_zone(current) else "elder_moor"
				# Crafting materials - wilderness
				"wolf_pelt", "wolf_fang", "spider_silk", "raw_meat":
					return "open_world"
				# Herbs - wilderness
				"healing_herb", "mana_bloom", "nightshade":
					return "open_world"
				_:
					# Unknown items - check wilderness first
					return "open_world"

		"talk":
			# Check if NPC is in a specific location
			match objective.target:
				"tharin_ironbeard":
					return "elder_moor"  # Tharin is in starting town
				"aldric_vane":
					return "dalhurst"  # Severin Vane is in Dalhurst
				"innkeeper", "blacksmith", "merchant", "alchemist":
					# Use current zone if in town, else return elder_moor
					var current: String = PlayerGPS.current_location_id if PlayerGPS else ""
					return current if _is_town_zone(current) else "elder_moor"
				_:
					# For bounty turn-ins and other NPCs, default to starting town
					# Most NPCs live in settlements
					return "elder_moor"

		"interact":
			match objective.target:
				"goblin_totem":
					return "goblin_cave"
				_:
					return ""

		"destroy":
			# Spawners and totems are typically in wilderness or dungeons
			match objective.target:
				"goblin_totem":
					return "goblin_cave"
				"cursed_totem":
					return "open_world"  # Cursed totems spawn in wilderness near ruins
				_:
					return "open_world"  # Default to wilderness for destroy objectives

	return ""


## Find an exit door that leads to the target zone (or toward it)
## Now finds the NEAREST door when multiple exist
func _find_exit_door_to_zone(target_zone: String) -> ZoneDoor:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var nearest_door: ZoneDoor = null
	var nearest_dist: float = INF

	# Get current zone to determine appropriate routing
	var current_zone: String = PlayerGPS.current_location_id if PlayerGPS else ""

	# Look for doors leading to the target zone
	if target_zone == "open_world" or _is_town_zone(target_zone):
		var region_exit := _find_door_to_zone(player_pos, target_zone)
		if region_exit:
			return region_exit

	# Direct connection - check zone_connections first (now an array)
	if zone_connections.has(target_zone):
		var connections: Array = zone_connections[target_zone]
		if connections.size() > 0:
			# Find nearest door to player
			for connection in connections:
				var conn_dict: Dictionary = connection
				if conn_dict.has("door") and is_instance_valid(conn_dict.door):
					var door: ZoneDoor = conn_dict.door as ZoneDoor
					if door and door is Node3D:
						var dist: float = player_pos.distance_to(door.global_position)
						if dist < nearest_dist:
							nearest_dist = dist
							nearest_door = door
			if nearest_door:
				return nearest_door

	# Check all doors for one that leads to target zone
	var doors := get_tree().get_nodes_in_group("doors")
	nearest_door = null
	nearest_dist = INF
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			var door_target_zone := _scene_path_to_zone_id(zone_door.target_scene)
			if door_target_zone == target_zone:
				var dist: float = player_pos.distance_to(zone_door.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_door = zone_door
	if nearest_door:
		return nearest_door

	# No direct connection - find intermediate zone
	# If we're in town and need to get to goblin_cave, point to open_world exit
	# If we're in goblin_cave and need to get to town, point to open_world exit
	# (current_zone already declared at top of function)

	# Zone path mapping (simplified pathfinding)
	# Towns route through open_world to reach wilderness/dungeon areas
	# Using actual zone names (elder_moor, dalhurst, etc.) instead of generic "town"
	var zone_paths: Dictionary = {
		"elder_moor": {
			"goblin_cave": "open_world",
			"dark_crypt": "open_world",
			"random_cave": "open_world",
			"riverside_village": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"dalhurst": {
			"goblin_cave": "open_world",
			"elder_moor": "open_world",
			"dark_crypt": "open_world",
			"open_world": "open_world"
		},
		"aberdeen": {
			"goblin_cave": "open_world",
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		# "larton" zone paths removed - orphaned zone
		"rotherhine": {
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"falkenhafen": {
			"elder_moor": "open_world",
			"dalhurst": "open_world",
			"open_world": "open_world"
		},
		"goblin_cave": {
			"elder_moor": "open_world",
			"dark_crypt": "open_world",
			"random_cave": "open_world",
			"riverside_village": "open_world",
			"dalhurst": "open_world"
		},
		# "dark_crypt" zone paths removed - orphaned zone
		"random_cave": {
			"elder_moor": "open_world",
			"goblin_cave": "open_world"
		},
		"riverside_village": {
			"elder_moor": "open_world",
			"goblin_cave": "open_world"
		},
		"open_world": {
			# Open world has direct access to everything
		}
	}

	if zone_paths.has(current_zone) and zone_paths[current_zone].has(target_zone):
		var intermediate_zone: String = zone_paths[current_zone][target_zone]
		# Find door to intermediate zone
		for door in doors:
			if door is ZoneDoor:
				var zone_door := door as ZoneDoor
				var door_target_zone := _scene_path_to_zone_id(zone_door.target_scene)
				if door_target_zone == intermediate_zone:
					return zone_door

	# Fallback: If we're in a town and looking for external targets,
	# return ANY door that leads outside (dungeon, other region, etc.)
	if _is_town_zone(current_zone):
		for door in doors:
			if door is ZoneDoor:
				var zone_door := door as ZoneDoor
				var door_target := _scene_path_to_zone_id(zone_door.target_scene)
				# Skip doors to other town interiors (inn, shops)
				if not door_target.contains("inn") and not door_target.contains("shop"):
					return zone_door

	return null


## Cached door references for compass (avoids creating new nodes each frame)
var _cached_region_door: ZoneDoor = null

## Find zone door that leads to a specific region/town
## Used for quest compass navigation
func _find_door_to_zone(player_pos: Vector3, target_zone: String) -> ZoneDoor:
	# First check for direct POIs/doors to the target
	var pois := get_tree().get_nodes_in_group("compass_poi")
	var nearest_exit: Node3D = null
	var nearest_dist: float = INF

	for poi in pois:
		if poi is Node3D:
			var poi_id: String = poi.get_meta("poi_id", "")
			var poi_target: String = poi.get_meta("target_zone", "")
			if poi_target == target_zone or poi_id.contains(target_zone):
				var dist: float = player_pos.distance_to(poi.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_exit = poi

	var doors := get_tree().get_nodes_in_group("doors")
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			var door_target := _scene_path_to_zone_id(zone_door.target_scene)
			if door_target == target_zone:
				var dist: float = player_pos.distance_to(zone_door.global_position)
				if dist < nearest_dist:
					return zone_door

	if nearest_exit:
		if not _cached_region_door:
			_cached_region_door = ZoneDoor.new()
		_cached_region_door.global_position = nearest_exit.global_position
		_cached_region_door.door_name = nearest_exit.get_meta("poi_name", "To " + target_zone.capitalize())
		_cached_region_door.target_scene = target_zone
		return _cached_region_door

	return null


## Calculate direction to a settlement - simplified for region-based system
## Returns null - inter-region navigation should use zone doors
func _calculate_direction_to_settlement(_player_pos: Vector3, _target_zone: String) -> ZoneDoor:
	# In region-based system, navigation between zones is handled by zone doors
	# The compass should point to actual doors in the scene, not virtual directions
	return null


## Find settlement coordinates from WorldGrid by zone ID
func _find_settlement_coords(zone_id: String) -> Vector2i:
	# Initialize WorldGrid if needed
	if WorldGrid.cells.is_empty():
		WorldGrid.initialize()

	# Search all cells for matching location_id
	for coords: Vector2i in WorldGrid.cells:
		var cell: WorldGrid.CellInfo = WorldGrid.cells[coords]
		if cell.location_id == zone_id:
			return coords
		# Also check partial matches (village_elder_moor matches elder_moor)
		if zone_id in cell.location_id or cell.location_id in zone_id:
			return coords

	# Check common aliases
	var aliases: Dictionary = {
		"elder_moor": Vector2i(0, 0),
		"village_elder_moor": Vector2i(0, 0),
		"dalhurst": Vector2i(0, -3),
		"city_dalhurst": Vector2i(0, -3),
		"kazan_dun": Vector2i(0, -6),
		"city_kazan_dun": Vector2i(0, -6),
		"aberdeen": Vector2i(0, -9),
		"town_aberdeen": Vector2i(0, -9),
		"larton": Vector2i(-3, -9),
		"town_larton": Vector2i(-3, -9),
		"falkenhafen": Vector2i(7, -9),
		"capital_falkenhafen": Vector2i(7, -9),
	}

	if aliases.has(zone_id):
		return aliases[zone_id]

	return Vector2i(-9999, -9999)  # Not found marker


## Convert zone ID to display name
func _zone_id_to_display_name(zone_id: String) -> String:
	var names: Dictionary = {
		"elder_moor": "Elder Moor",
		"village_elder_moor": "Elder Moor",
		"dalhurst": "Dalhurst",
		"city_dalhurst": "Dalhurst",
		"kazan_dun": "Kazan-Dun",
		"city_kazan_dun": "Kazan-Dun",
		"aberdeen": "Aberdeen",
		"town_aberdeen": "Aberdeen",
		"larton": "Larton",
		"town_larton": "Larton",
		"falkenhafen": "Falkenhafen",
		"capital_falkenhafen": "Falkenhafen",
	}
	if names.has(zone_id):
		return names[zone_id]
	return zone_id.replace("_", " ").capitalize()


## Find nearest region exit - looks for zone doors leading to other regions
## Returns the nearest zone door for compass compatibility
func _find_nearest_region_exit(player_pos: Vector3) -> ZoneDoor:
	# Safety check - ensure tree is valid
	if not is_inside_tree():
		return null

	var nearest_door: ZoneDoor = null
	var nearest_dist: float = INF

	# Look for zone doors in the scene
	var doors := get_tree().get_nodes_in_group("doors")
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			if zone_door.target_scene and not zone_door.target_scene.is_empty():
				var dist: float = player_pos.distance_to(zone_door.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_door = zone_door

	return nearest_door


## Setup bounty indicator (shows when player has active bounty)
func _setup_bounty_indicator() -> void:
	bounty_indicator = Label.new()
	bounty_indicator.name = "BountyIndicator"
	bounty_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bounty_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at top-right, below gold display
	bounty_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bounty_indicator.offset_top = 35
	bounty_indicator.offset_left = -150
	bounty_indicator.offset_right = -10
	bounty_indicator.offset_bottom = 55

	# Style with red warning color
	bounty_indicator.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	bounty_indicator.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	bounty_indicator.add_theme_constant_override("outline_size", 2)
	bounty_indicator.add_theme_font_size_override("font_size", 14)

	bounty_indicator.visible = false
	_hud.add_child(bounty_indicator)

	# Connect to CrimeManager signals
	if CrimeManager.has_signal("bounty_changed"):
		CrimeManager.bounty_changed.connect(_on_bounty_changed)


## Update bounty indicator display
func _update_bounty_indicator(delta: float) -> void:
	if not bounty_indicator:
		return

	var total_bounty: int = CrimeManager.get_total_bounty()

	if total_bounty <= 0:
		bounty_indicator.visible = false
		return

	# Show bounty indicator
	bounty_indicator.visible = true
	bounty_indicator.text = "WANTED: %d G" % total_bounty

	# Flash effect for high bounty
	if total_bounty >= 500:
		bounty_flash_timer += delta * BOUNTY_FLASH_SPEED
		var flash_alpha := 0.7 + 0.3 * sin(bounty_flash_timer)
		bounty_indicator.modulate.a = flash_alpha

		# Red color intensity based on bounty
		var intensity: float = minf(1.0, total_bounty / 1000.0)
		bounty_indicator.add_theme_color_override("font_color", Color(1.0, 0.3 - intensity * 0.2, 0.2 - intensity * 0.1))
	else:
		bounty_indicator.modulate.a = 1.0
		bounty_indicator.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))


## Handle bounty changed signal
func _on_bounty_changed(region_id: String, new_amount: int) -> void:
	if new_amount > 0:
		log_bounty_added(region_id, new_amount)


## Log bounty gained
func log_bounty_added(region_id: String, amount: int) -> void:
	_add_log_entry("Bounty in %s: %d G" % [region_id.capitalize(), amount], Color(1.0, 0.4, 0.3))


## ============================================================================
## QUEST TRACKER (Top of screen - shows tracked quest title and progress)


## Clear all POI markers from the compass (used on zone transitions)
## This is called when a new scene starts loading to prevent ghost markers
func _clear_all_poi_markers() -> void:
	# Store IDs first, then clear dictionary BEFORE queue_free
	# This prevents race conditions where new markers might use stale IDs
	var markers_to_free: Array[Label] = []
	for poi_id in compass_poi_markers:
		var marker: Label = compass_poi_markers[poi_id]
		if is_instance_valid(marker):
			markers_to_free.append(marker)

	# Clear dictionary first (prevents ghost references)
	compass_poi_markers.clear()

	# Now queue_free the markers
	for marker in markers_to_free:
		marker.queue_free()

	# Also clear quest marker
	if compass_quest_marker and is_instance_valid(compass_quest_marker):
		compass_quest_marker.queue_free()
		compass_quest_marker = null

	# Also clear enemy radar markers
	var enemy_markers_to_free: Array[Label] = []
	for enemy_id in compass_enemy_markers:
		var marker = compass_enemy_markers[enemy_id]
		if marker and is_instance_valid(marker):
			enemy_markers_to_free.append(marker)
	compass_enemy_markers.clear()
	for marker in enemy_markers_to_free:
		marker.queue_free()

	# Also clear plant markers
	var plant_markers_to_free: Array[Label] = []
	for plant_id in compass_plant_markers:
		var marker = compass_plant_markers[plant_id]
		if marker and is_instance_valid(marker):
			plant_markers_to_free.append(marker)
	compass_plant_markers.clear()
	for marker in plant_markers_to_free:
		marker.queue_free()

	# Also clear quest target markers (bounty enemies)
	var quest_target_markers_to_free: Array[Label] = []
	for target_id in compass_quest_target_markers:
		var marker = compass_quest_target_markers[target_id]
		if marker and is_instance_valid(marker):
			quest_target_markers_to_free.append(marker)
	compass_quest_target_markers.clear()
	for marker in quest_target_markers_to_free:
		marker.queue_free()



## Refresh compass quest marker after loading a save
## Call this after scene is fully loaded and NPCs/enemies are initialized
## This forces the compass to recalculate objective positions for tracked quests
func refresh_compass_quest_marker() -> void:
	# Force recreation of quest marker if tracking a quest
	var tracked_id: String = QuestManager.get_tracked_quest_id()
	if tracked_id.is_empty():
		return

	# Clear the existing quest marker so it gets recreated fresh
	if compass_quest_marker and is_instance_valid(compass_quest_marker):
		compass_quest_marker.queue_free()
		compass_quest_marker = null

	# Clear cached enemy references to force fresh lookup
	_cached_enemies.clear()



## Rebuild zone connection map from doors in current scene
## Now stores ARRAY of doors per zone to handle multiple exits
func _rebuild_zone_connections() -> void:
	zone_connections.clear()

	# Find all zone doors and map their targets
	var doors := get_tree().get_nodes_in_group("doors")
	for door in doors:
		if door is ZoneDoor:
			var zone_door := door as ZoneDoor
			if not zone_door.target_scene.is_empty():
				# Extract zone ID from target scene path
				var target_zone := _scene_path_to_zone_id(zone_door.target_scene)
				# Store as array to handle multiple doors to same zone
				if not zone_connections.has(target_zone):
					zone_connections[target_zone] = []
				zone_connections[target_zone].append({
					"door": zone_door,
					"scene_path": zone_door.target_scene
				})

## Convert a scene path to a zone ID (extracts from path)
func _scene_path_to_zone_id(scene_path: String) -> String:
	# Extract filename without extension as zone ID
	# e.g., "res://scenes/levels/goblin_cave.tscn" -> "goblin_cave"
	var filename := scene_path.get_file().get_basename()

	# Map common scene names to their ZONE_IDs (use actual zone names, not generic "town")
	match filename:
		"elder_moor": return "elder_moor"
		"dalhurst": return "dalhurst"
		"aberdeen": return "aberdeen"
		# "larton": return "larton"  # REMOVED - orphaned zone
		"rotherhine": return "rotherhine"
		"falkenhafen": return "falkenhafen"
		"whalers_abyss": return "whalers_abyss"
		# "east_hollow": return "east_hollow"  # REMOVED - orphaned zone
		"open_world": return "open_world"
		"goblin_cave": return "goblin_cave"
		# "dark_crypt": return "dark_crypt"  # REMOVED - orphaned zone
		"random_cave": return "random_cave"
		"riverside_village": return "riverside_village"
		"inn_interior": return "inn_interior"
		_: return filename
