## prison.gd - Prison system for handling jailed players
## Enclosed jail building with cell, guard, and exit door
## Escape options: serve time, bribe guard, lockpick, or kill guard and take key
class_name Prison
extends Node3D

## Signals
signal player_jailed(player: Node3D)
signal player_released(player: Node3D)
signal player_escaped(player: Node3D)
signal escape_attempted(success: bool)

## Prison configuration
@export var prison_name: String = "Town Jail"
@export var region_id: String = "elder_moor"

## Lock difficulty for escape lockpicking
@export var cell_lock_dc: int = 18  # Hard to pick - it's a prison
@export var exit_door_lock_dc: int = 15  # Exit door is slightly easier

## Bribe costs (base multiplier on bounty)
@export var bribe_multiplier: float = 0.5  # Bribe costs 50% of bounty

## Building dimensions
const ROOM_WIDTH := 10.0
const ROOM_DEPTH := 8.0
const ROOM_HEIGHT := 3.5
const WALL_THICKNESS := 0.3
const CELL_WIDTH := 4.0
const CELL_DEPTH := 4.0

## Spawn points (local offsets)
var cell_spawn_point: Vector3 = Vector3(-2.5, 0.5, -1.5)  # Inside cell
var guard_area_spawn: Vector3 = Vector3(2.0, 0.5, 0.0)  # Guard area
var release_spawn_point: Vector3 = Vector3(0, 0.5, 5.0)  # Outside exit door

## State
var is_player_inside: bool = false
var current_prisoner: Node3D = null
var cell_door_locked: bool = true
var exit_door_locked: bool = true

## References to spawned objects
var jail_guard: Node3D = null
var cell_door_interactable: Node3D = null
var exit_door_interactable: Node3D = null

## PS1-style materials
var wall_material: StandardMaterial3D
var bars_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var wood_material: StandardMaterial3D

## Lockpick break chance formula
func _get_lockpick_break_chance(lockpicking_skill: int) -> float:
	return maxf(0.10, 0.50 - (lockpicking_skill * 0.04))


func _ready() -> void:
	add_to_group("prisons")

	# Check if geometry already exists (loaded from scene) or needs to be built
	var existing_building: Node3D = get_node_or_null("JailBuilding")
	if not existing_building:
		# Build programmatically if not in scene
		_create_materials()
		_build_jail_building()
	else:
		# Use scene geometry - just create materials for dynamic elements
		_create_materials()
		# Update spawn points from scene markers if they exist
		var cell_marker: Marker3D = get_node_or_null("SpawnPoints/CellSpawn")
		var guard_marker: Marker3D = get_node_or_null("SpawnPoints/GuardSpawn")
		var release_marker: Marker3D = get_node_or_null("SpawnPoints/ReleaseSpawn")
		if cell_marker:
			cell_spawn_point = cell_marker.position
			# Mark as spawn point for SceneManager
			cell_marker.add_to_group("spawn_points")
			cell_marker.set_meta("spawn_id", "cell")
		if guard_marker:
			guard_area_spawn = guard_marker.position
		if release_marker:
			release_spawn_point = release_marker.position

	_spawn_jail_guard()
	_create_cell_door_interactable()
	_create_exit_door_interactable()

	# Connect to CrimeManager signals
	CrimeManager.player_released.connect(_on_crime_manager_released)

	print("[Prison] %s initialized at %s" % [prison_name, global_position])

	# Auto-jail player if they have jail state
	_on_scene_ready()


func _exit_tree() -> void:
	# Disconnect signals to prevent stale reference issues
	if CrimeManager and CrimeManager.player_released.is_connected(_on_crime_manager_released):
		CrimeManager.player_released.disconnect(_on_crime_manager_released)


## Create PS1-style materials
func _create_materials() -> void:
	# Stone wall material
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.3, 0.28, 0.25)
	wall_material.roughness = 0.95

	var stone_tex: Texture2D = load("res://assets/textures/environment/floors/stonefloor.png")
	if stone_tex:
		wall_material.albedo_texture = stone_tex
		wall_material.uv1_scale = Vector3(2, 2, 1)
		wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Metal bars material
	bars_material = StandardMaterial3D.new()
	bars_material.albedo_color = Color(0.2, 0.2, 0.22)
	bars_material.metallic = 0.7
	bars_material.roughness = 0.5

	# Prison floor material
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.25, 0.23, 0.2)
	floor_material.roughness = 0.98

	# Wood material for furniture
	wood_material = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.4, 0.3, 0.2)
	wood_material.roughness = 0.8


## Build the enclosed jail building
func _build_jail_building() -> void:
	var building := Node3D.new()
	building.name = "JailBuilding"
	add_child(building)

	# Floor
	_add_box_mesh(building, "Floor", Vector3(ROOM_WIDTH, 0.2, ROOM_DEPTH),
		Vector3(0, 0.1, 0), floor_material, true)

	# Ceiling
	_add_box_mesh(building, "Ceiling", Vector3(ROOM_WIDTH, 0.3, ROOM_DEPTH),
		Vector3(0, ROOM_HEIGHT + 0.15, 0), wall_material, false)

	# Back wall (solid)
	_add_box_mesh(building, "BackWall", Vector3(ROOM_WIDTH, ROOM_HEIGHT, WALL_THICKNESS),
		Vector3(0, ROOM_HEIGHT / 2, -ROOM_DEPTH / 2 + WALL_THICKNESS / 2), wall_material, true)

	# Front wall with exit door opening
	var front_wall_left_width: float = (ROOM_WIDTH - 1.5) / 2
	_add_box_mesh(building, "FrontWallLeft", Vector3(front_wall_left_width, ROOM_HEIGHT, WALL_THICKNESS),
		Vector3(-ROOM_WIDTH / 4 - 0.375, ROOM_HEIGHT / 2, ROOM_DEPTH / 2 - WALL_THICKNESS / 2), wall_material, true)
	_add_box_mesh(building, "FrontWallRight", Vector3(front_wall_left_width, ROOM_HEIGHT, WALL_THICKNESS),
		Vector3(ROOM_WIDTH / 4 + 0.375, ROOM_HEIGHT / 2, ROOM_DEPTH / 2 - WALL_THICKNESS / 2), wall_material, true)
	# Top of doorway
	_add_box_mesh(building, "FrontWallTop", Vector3(1.5, ROOM_HEIGHT - 2.5, WALL_THICKNESS),
		Vector3(0, ROOM_HEIGHT - (ROOM_HEIGHT - 2.5) / 2, ROOM_DEPTH / 2 - WALL_THICKNESS / 2), wall_material, true)

	# Left wall (solid)
	_add_box_mesh(building, "LeftWall", Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_DEPTH),
		Vector3(-ROOM_WIDTH / 2 + WALL_THICKNESS / 2, ROOM_HEIGHT / 2, 0), wall_material, true)

	# Right wall (solid)
	_add_box_mesh(building, "RightWall", Vector3(WALL_THICKNESS, ROOM_HEIGHT, ROOM_DEPTH),
		Vector3(ROOM_WIDTH / 2 - WALL_THICKNESS / 2, ROOM_HEIGHT / 2, 0), wall_material, true)

	# Cell divider wall (partial wall separating cell from guard area)
	_add_box_mesh(building, "CellDivider", Vector3(WALL_THICKNESS, ROOM_HEIGHT, CELL_DEPTH - 1.5),
		Vector3(-CELL_WIDTH / 2 + ROOM_WIDTH / 2 - CELL_WIDTH, ROOM_HEIGHT / 2, -ROOM_DEPTH / 4 - 0.25), wall_material, true)

	# Cell bars (front of cell facing guard area)
	_build_cell_bars(building)

	# Guard furniture
	_build_guard_area(building)


## Build cell bars
func _build_cell_bars(parent: Node3D) -> void:
	var bars_container := Node3D.new()
	bars_container.name = "CellBars"
	parent.add_child(bars_container)

	var bar_height := ROOM_HEIGHT - 0.5
	var bar_radius := 0.03
	var bar_spacing := 0.25
	var bars_width := CELL_WIDTH - 1.2  # Leave room for door
	var num_bars := int(bars_width / bar_spacing)

	var bars_x := -ROOM_WIDTH / 2 + CELL_WIDTH + WALL_THICKNESS
	var bars_z := -ROOM_DEPTH / 2 + CELL_DEPTH + 0.5

	# Vertical bars
	for i in range(num_bars):
		var bar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = bar_radius
		cylinder.bottom_radius = bar_radius
		cylinder.height = bar_height
		bar.mesh = cylinder
		bar.material_override = bars_material
		bar.position = Vector3(bars_x + i * bar_spacing - bars_width / 2, bar_height / 2 + 0.25, bars_z)
		bars_container.add_child(bar)

	# Horizontal bars
	for y in [0.5, 1.5, 2.5]:
		var h_bar := MeshInstance3D.new()
		var h_box := BoxMesh.new()
		h_box.size = Vector3(bars_width, bar_radius * 2, bar_radius * 2)
		h_bar.mesh = h_box
		h_bar.material_override = bars_material
		h_bar.position = Vector3(bars_x, y, bars_z)
		bars_container.add_child(h_bar)

	# Collision for bars
	var bars_body := StaticBody3D.new()
	bars_body.name = "BarsCollision"
	var bars_col := CollisionShape3D.new()
	var bars_shape := BoxShape3D.new()
	bars_shape.size = Vector3(bars_width, bar_height, 0.1)
	bars_col.shape = bars_shape
	bars_col.position = Vector3(bars_x, bar_height / 2, bars_z)
	bars_body.add_child(bars_col)
	parent.add_child(bars_body)


## Build guard area with desk
func _build_guard_area(parent: Node3D) -> void:
	var guard_area := Node3D.new()
	guard_area.name = "GuardArea"
	parent.add_child(guard_area)

	# Desk
	_add_box_mesh(guard_area, "Desk", Vector3(1.5, 0.8, 0.8),
		Vector3(2.0, 0.4, 0), wood_material, true)

	# Chair (simple box)
	_add_box_mesh(guard_area, "Chair", Vector3(0.5, 0.5, 0.5),
		Vector3(2.0, 0.25, 1.0), wood_material, true)

	# Main torch/light in guard area
	var torch := OmniLight3D.new()
	torch.name = "TorchLight"
	torch.light_color = Color(1.0, 0.8, 0.5)
	torch.light_energy = 1.2
	torch.omni_range = 10.0
	torch.shadow_enabled = true
	torch.position = Vector3(3.0, 2.5, 0)
	guard_area.add_child(torch)

	# Cell area light (dimmer, gloomy atmosphere)
	var cell_light := OmniLight3D.new()
	cell_light.name = "CellLight"
	cell_light.light_color = Color(0.8, 0.7, 0.5)  # Slightly dimmer, cooler
	cell_light.light_energy = 0.6
	cell_light.omni_range = 6.0
	cell_light.position = Vector3(-3.0, 2.5, -2.0)  # Inside cell area
	guard_area.add_child(cell_light)

	# Additional ambient fill light
	var fill_light := OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color(0.6, 0.6, 0.7)
	fill_light.light_energy = 0.4
	fill_light.omni_range = 12.0
	fill_light.position = Vector3(0, 3.0, 0)
	guard_area.add_child(fill_light)


## Helper to add a box mesh with optional collision
func _add_box_mesh(parent: Node3D, mesh_name: String, size: Vector3, pos: Vector3,
		mat: StandardMaterial3D, add_collision: bool) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = mesh_name
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = pos
	parent.add_child(mesh_inst)

	if add_collision:
		var body := StaticBody3D.new()
		body.name = mesh_name + "Body"
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		body.add_child(col)
		parent.add_child(body)

	return mesh_inst


## Spawn the jail guard NPC
func _spawn_jail_guard() -> void:
	# Create a simple guard using CivilianNPC base
	# The guard will be a special NPC that handles jail interactions
	var guard_script: Script = load("res://scripts/world/jail_guard.gd")
	if guard_script:
		jail_guard = guard_script.new()
	else:
		# Fallback: create basic guard node
		jail_guard = Node3D.new()

	jail_guard.name = "JailGuard"
	jail_guard.position = guard_area_spawn

	# Set guard properties directly - JailGuard has these as public vars
	jail_guard.set("prison", self)
	jail_guard.set("region_id", region_id)

	add_child(jail_guard)
	print("[Prison] Spawned jail guard")


## Create interactable cell door using JailCellDoor class
func _create_cell_door_interactable() -> void:
	# Check if scene has CellDoor mesh - use its position
	var scene_cell_door: Node3D = get_node_or_null("JailBuilding/CellDoor")
	var door_pos: Vector3
	if scene_cell_door:
		door_pos = scene_cell_door.position
	else:
		# Fallback to calculated position
		var door_x := -ROOM_WIDTH / 2 + CELL_WIDTH + WALL_THICKNESS + 0.8
		var door_z := -ROOM_DEPTH / 2 + CELL_DEPTH + 0.5
		door_pos = Vector3(door_x, 0, door_z)

	# Use the JailCellDoor class for proper interaction handling
	var cell_door_script: Script = load("res://scripts/world/jail_cell_door.gd")
	if cell_door_script:
		cell_door_interactable = cell_door_script.spawn_cell_door(self, door_pos, self, cell_lock_dc)
	else:
		# Fallback to basic Area3D if script not found
		cell_door_interactable = Area3D.new()
		cell_door_interactable.name = "CellDoorInteract"
		cell_door_interactable.collision_layer = 256
		cell_door_interactable.collision_mask = 0
		cell_door_interactable.set_meta("interact_type", "cell_door")
		cell_door_interactable.set_meta("prison", self)
		cell_door_interactable.set_meta("is_locked", true)
		cell_door_interactable.set_meta("lock_dc", cell_lock_dc)
		cell_door_interactable.set_meta("lockpickable", true)
		cell_door_interactable.set_meta("requires_key", "jail_key")

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 2.5, 0.5)
		shape.shape = box
		shape.position = Vector3(door_pos.x, 1.25, door_pos.z)
		cell_door_interactable.add_child(shape)
		cell_door_interactable.add_to_group("interactable")
		cell_door_interactable.add_to_group("lockpickable")
		add_child(cell_door_interactable)

	# Only add visual door mesh if not loaded from scene (scene already has CellDoor)
	if not scene_cell_door:
		var door_mesh := MeshInstance3D.new()
		var door_box := BoxMesh.new()
		door_box.size = Vector3(1.0, 2.5, 0.1)
		door_mesh.mesh = door_box
		door_mesh.material_override = bars_material
		door_mesh.position = Vector3(door_pos.x, 1.25, door_pos.z)
		add_child(door_mesh)


## Create interactable exit door using JailExitDoor class
func _create_exit_door_interactable() -> void:
	# Check if scene has ExitDoor mesh - use its position
	var scene_exit_door: Node3D = get_node_or_null("JailBuilding/ExitDoor")
	var door_pos: Vector3
	if scene_exit_door:
		door_pos = scene_exit_door.position
	else:
		door_pos = Vector3(0, 0, ROOM_DEPTH / 2)

	# Use the JailExitDoor class for proper interaction handling
	var exit_door_script: Script = load("res://scripts/world/jail_exit_door.gd")
	if exit_door_script:
		exit_door_interactable = exit_door_script.spawn_exit_door(self, door_pos, self, exit_door_lock_dc)
	else:
		# Fallback to basic Area3D if script not found
		exit_door_interactable = Area3D.new()
		exit_door_interactable.name = "ExitDoorInteract"
		exit_door_interactable.collision_layer = 256
		exit_door_interactable.collision_mask = 0
		exit_door_interactable.set_meta("interact_type", "exit_door")
		exit_door_interactable.set_meta("prison", self)
		exit_door_interactable.set_meta("is_locked", true)
		exit_door_interactable.set_meta("lock_dc", exit_door_lock_dc)
		exit_door_interactable.set_meta("lockpickable", true)
		exit_door_interactable.set_meta("requires_key", "jail_key")

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.5, 2.5, 0.5)
		shape.shape = box
		shape.position = Vector3(door_pos.x, 1.25, door_pos.z)
		exit_door_interactable.add_child(shape)
		exit_door_interactable.add_to_group("interactable")
		exit_door_interactable.add_to_group("lockpickable")
		add_child(exit_door_interactable)

	# Only add visual door mesh if not loaded from scene (scene already has ExitDoor)
	if not scene_exit_door:
		var door_mesh := MeshInstance3D.new()
		var door_box := BoxMesh.new()
		door_box.size = Vector3(1.3, 2.3, 0.1)
		door_mesh.mesh = door_box
		door_mesh.material_override = wood_material
		door_mesh.position = Vector3(door_pos.x, 1.25, door_pos.z - WALL_THICKNESS / 2)
		add_child(door_mesh)


## Jail the player - called by guards or on scene load
func jail_player(player: Node3D) -> void:
	if not player:
		return

	current_prisoner = player
	is_player_inside = true
	cell_door_locked = true
	exit_door_locked = true

	# Update door lock states
	if cell_door_interactable and "is_locked" in cell_door_interactable:
		cell_door_interactable.is_locked = true
	if exit_door_interactable and "is_locked" in exit_door_interactable:
		exit_door_interactable.is_locked = true

	# Move player into cell
	player.global_position = global_position + cell_spawn_point

	print("[Prison] Player jailed in %s" % prison_name)
	player_jailed.emit(player)


## Called when prison scene loads - auto-jail if player has jail state
func _on_scene_ready() -> void:
	# Wait a frame for player to spawn
	await get_tree().process_frame

	# Check if player should be jailed
	if CrimeManager.is_jailed:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			jail_player(player)


## Release the player - return to original scene
func release_player() -> void:
	is_player_inside = false
	cell_door_locked = false
	exit_door_locked = false

	print("[Prison] Player released from %s" % prison_name)

	# Get player reference before scene change
	var player: Node3D = current_prisoner
	if not player:
		player = get_tree().get_first_node_in_group("player") as Node3D

	player_released.emit(player)
	current_prisoner = null

	# Teleport to return scene
	_teleport_to_return_scene()


## Teleport player to the return scene via SceneManager
func _teleport_to_return_scene() -> void:
	var return_scene: String = CrimeManager.return_scene
	var return_pos: Vector3 = CrimeManager.return_position

	# Use fallback if no return scene stored
	if return_scene.is_empty():
		return_scene = "res://scenes/levels/elder_moor.tscn"
		return_pos = Vector3(0, 0.5, 0)
		print("[Prison] No return scene stored, using fallback: %s" % return_scene)
	else:
		print("[Prison] Returning to %s at %s" % [return_scene, return_pos])

	# Store spawn position for SceneManager
	SceneManager.set_player_position(return_pos)

	# Clear jail data BEFORE scene change
	CrimeManager.return_scene = ""
	CrimeManager.return_position = Vector3.ZERO

	# Load return scene
	SceneManager.change_scene(return_scene, "from_jail")


## Legacy function - kept for compatibility, now calls scene-based return
func _teleport_to_town_spawn() -> void:
	_teleport_to_return_scene()


## Handle CrimeManager release signal
func _on_crime_manager_released(released_region_id: String) -> void:
	if released_region_id == region_id and is_player_inside:
		release_player()


## Called when player tries to interact with cell door
func on_cell_door_interact() -> void:
	if not CrimeManager.is_jailed:
		_show_notification("The cell is empty.")
		return

	if not cell_door_locked:
		_show_notification("The cell door is unlocked. You push it open.")
		return

	# Check if player has the jail key - instant unlock!
	if _player_has_key():
		_show_notification("You use the jail key to unlock the cell door.")
		cell_door_locked = false
		return

	_show_cell_door_options()


## Called when player tries to interact with exit door
func on_exit_door_interact() -> void:
	if exit_door_locked:
		if _player_has_key():
			_show_notification("You use the jail key to unlock the exit door.")
			exit_door_locked = false
			_complete_escape()
		else:
			_show_notification("The exit door is locked. You need a key.")
	else:
		_complete_escape()


## Check if player has jail key
func _player_has_key() -> bool:
	return InventoryManager.has_item("jail_key", 1)


## Show cell door interaction options
func _show_cell_door_options() -> void:
	var has_lockpick: bool = _player_has_lockpick()

	var lines: Array = []

	# Main prompt
	lines.append(ConversationSystem.create_scripted_line(
		"",
		"The cell door is locked with a heavy iron lock (DC %d)." % cell_lock_dc,
		[
			ConversationSystem.create_scripted_choice("Try to pick the lock" if has_lockpick else "Pick lock (No lockpicks)", 1),
			ConversationSystem.create_scripted_choice("Examine the lock", 2),
			ConversationSystem.create_scripted_choice("Step back", 3)
		]
	))

	# Lockpick attempt
	lines.append(ConversationSystem.create_scripted_line("", "You insert a lockpick into the lock...", [], true))

	# Examine
	lines.append(ConversationSystem.create_scripted_line("", "A sturdy iron lock. The guard probably has a key.", [], true))

	# Cancel
	lines.append(ConversationSystem.create_scripted_line("", "You step away from the door.", [], true))

	_current_door_choice = ""
	ConversationSystem.start_scripted_dialogue(lines, _on_cell_door_choice_made)


var _current_door_choice: String = ""

func _on_cell_door_choice_made() -> void:
	var choice_index: int = ConversationSystem.get_last_scripted_choice_index()

	match choice_index:
		1:  # Lockpick
			_attempt_cell_lockpick()
		2:  # Examine
			pass  # Just showed info
		3:  # Cancel
			pass


## Attempt to lockpick the cell door
func _attempt_cell_lockpick() -> void:
	if not _player_has_lockpick():
		_show_notification("You need a lockpick!")
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	var lockpicking_skill: int = char_data.get_skill(Enums.Skill.LOCKPICKING)
	var agility: int = char_data.get_effective_stat(Enums.Stat.AGILITY)

	# Check lockpick break
	var break_chance := _get_lockpick_break_chance(lockpicking_skill)
	var lockpick_broke := randf() < break_chance

	# Consume lockpick
	_consume_lockpick()

	if lockpick_broke:
		_show_notification("The lockpick broke!")
		escape_attempted.emit(false)
		return

	# Lockpick check
	var roll_result: Dictionary = DiceManager.lockpick_check(
		agility, lockpicking_skill, cell_lock_dc, 1.5
	)

	if roll_result.get("success", false):
		_show_notification("Click! The cell door swings open.")
		cell_door_locked = false
		# Player still needs to get past guard and exit door
	else:
		_show_notification("The lock holds firm...")
		escape_attempted.emit(false)


## Complete the escape (player is outside)
func _complete_escape() -> void:
	CrimeManager.on_jail_escape(region_id)
	is_player_inside = false

	print("[Prison] Player escaped from %s!" % prison_name)

	# Get player reference before scene change
	var player: Node3D = current_prisoner
	if not player:
		player = get_tree().get_first_node_in_group("player") as Node3D

	player_escaped.emit(player)
	current_prisoner = null

	# Teleport to return scene
	_teleport_to_return_scene()


## Called by jail guard when player bribes or serves time
func guard_releases_player() -> void:
	cell_door_locked = false
	exit_door_locked = false

	# Also unlock the JailExitDoor if it exists
	if exit_door_interactable and exit_door_interactable.has_method("set"):
		exit_door_interactable.is_locked = false

	# Clear bounty (legal release)
	CrimeManager.clear_bounty(region_id)

	# Return confiscated items
	_return_confiscated_items()

	# Reset jail state
	CrimeManager.is_jailed = false
	CrimeManager.jail_region = ""
	CrimeManager.jail_time_remaining = 0.0

	_show_notification("The guard unlocks the doors. You are free to go.")
	release_player()


## Called when guard is killed
func on_guard_killed() -> void:
	# Guard drops jail key
	print("[Prison] Jail guard killed - player can loot key")
	# The guard's corpse will have the key in its loot


## Return confiscated items
func _return_confiscated_items() -> void:
	if CrimeManager.confiscated_items.has(region_id):
		var items: Array = CrimeManager.confiscated_items[region_id]
		for item: Dictionary in items:
			var item_id: String = item.get("item_id", "")
			var quality: Enums.ItemQuality = item.get("quality", Enums.ItemQuality.AVERAGE)
			if not item_id.is_empty():
				InventoryManager.add_item(item_id, 1, quality)
		CrimeManager.confiscated_items.erase(region_id)


## Check if player has lockpick
func _player_has_lockpick() -> bool:
	for slot in InventoryManager.inventory:
		if slot.item_id == "lockpick" and slot.quantity > 0:
			return true
	return false


## Consume a lockpick
func _consume_lockpick() -> void:
	InventoryManager.remove_item("lockpick", 1)


## Show notification
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Static factory method for spawning prisons
static func spawn_prison(parent: Node, pos: Vector3, p_name: String = "Town Jail", p_region_id: String = "elder_moor") -> Prison:
	var prison := Prison.new()
	prison.position = pos
	prison.prison_name = p_name
	prison.region_id = p_region_id

	parent.add_child(prison)
	return prison
