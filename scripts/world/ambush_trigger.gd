## ambush_trigger.gd - Area3D trigger that spawns enemies when escort enters
## Used for escort quest ambush encounters
class_name AmbushTrigger
extends Area3D

## Signal emitted when ambush is triggered
signal ambush_triggered(trigger_id: String)
signal ambush_enemies_spawned(enemy_count: int)
signal ambush_cleared  # All spawned enemies killed

## Trigger identification
@export var trigger_id: String = ""

## Enemy configuration
## Format: [{"enemy_data_path": String, "sprite_path": String, "h_frames": int, "v_frames": int, "count": int}]
@export var enemies_to_spawn: Array[Dictionary] = []

## Spawn configuration
@export var spawn_radius: float = 5.0  # Radius around trigger to spawn enemies
@export var spawn_delay: float = 0.5  # Delay between enemy spawns for dramatic effect
@export var trigger_on_player: bool = false  # Also trigger on player (not just escort)
@export var trigger_on_any_npc: bool = false  # Trigger on any NPC entering

## One-time trigger
@export var one_time_only: bool = true
var has_triggered: bool = false

## Spawned enemy tracking
var spawned_enemies: Array[Node] = []
var enemies_remaining: int = 0

## Visual debug (editor only)
@export var debug_color: Color = Color(1.0, 0.3, 0.3, 0.3)


func _ready() -> void:
	# Generate trigger_id if not set
	if trigger_id.is_empty():
		trigger_id = "ambush_%d" % get_instance_id()

	# Setup collision
	collision_layer = 0  # Don't collide with anything
	collision_mask = 3   # Detect layers 1 (player/NPCs) and 2

	# Connect signals
	body_entered.connect(_on_body_entered)

	# Setup collision shape if not present
	if get_child_count() == 0 or not _has_collision_shape():
		_create_default_collision()

	add_to_group("ambush_triggers")


func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _create_default_collision() -> void:
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 5.0
	col.shape = sphere
	add_child(col)


func _on_body_entered(body: Node3D) -> void:
	if has_triggered and one_time_only:
		return

	var should_trigger: bool = false

	# Check if it's an escort NPC
	if body is EscortNPC:
		should_trigger = true
	# Check if it's the player (optional)
	elif trigger_on_player and body.is_in_group("player"):
		should_trigger = true
	# Check if it's any NPC (optional)
	elif trigger_on_any_npc and body.is_in_group("npcs"):
		should_trigger = true

	if should_trigger:
		_trigger_ambush()


func _trigger_ambush() -> void:
	has_triggered = true
	ambush_triggered.emit(trigger_id)

	# Show warning notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Ambush!")

	# Play ambush sound
	if AudioManager:
		AudioManager.play_sfx("ambush_alert")

	# Spawn enemies with delay for dramatic effect
	_spawn_enemies_sequentially()


func _spawn_enemies_sequentially() -> void:
	var spawn_list: Array[Dictionary] = []

	# Build spawn list from configuration
	for config: Dictionary in enemies_to_spawn:
		var count: int = config.get("count", 1)
		for i in range(count):
			spawn_list.append(config)

	if spawn_list.is_empty():
		push_warning("[AmbushTrigger] No enemies configured to spawn!")
		return

	enemies_remaining = spawn_list.size()

	# Spawn each enemy with delay
	for i in range(spawn_list.size()):
		var config: Dictionary = spawn_list[i]
		var delay: float = float(i) * spawn_delay
		get_tree().create_timer(delay).timeout.connect(_spawn_single_enemy.bind(config))


func _spawn_single_enemy(config: Dictionary) -> void:
	var enemy_data_path: String = config.get("enemy_data_path", "")
	var sprite_path: String = config.get("sprite_path", "")
	var h_frames: int = config.get("h_frames", 3)
	var v_frames: int = config.get("v_frames", 4)

	if enemy_data_path.is_empty() or sprite_path.is_empty():
		push_warning("[AmbushTrigger] Invalid enemy config - missing data or sprite path")
		return

	# Load sprite texture
	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_error("[AmbushTrigger] Failed to load sprite: %s" % sprite_path)
		return

	# Calculate spawn position (random offset from trigger center)
	var spawn_pos: Vector3 = global_position + _get_random_spawn_offset()

	# Spawn enemy using EnemyBase factory
	var enemy := EnemyBase.spawn_billboard_enemy(
		get_parent(),
		spawn_pos,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.add_to_group("enemies")
		enemy.add_to_group("ambush_enemies")
		spawned_enemies.append(enemy)

		# Connect to death signal to track remaining enemies
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_spawned_enemy_died)
		elif enemy.has_signal("died"):
			enemy.died.connect(_on_spawned_enemy_died)

	ambush_enemies_spawned.emit(spawned_enemies.size())


func _get_random_spawn_offset() -> Vector3:
	var angle: float = randf() * TAU
	var distance: float = randf_range(spawn_radius * 0.3, spawn_radius)
	return Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)


func _on_spawned_enemy_died() -> void:
	enemies_remaining -= 1

	# Clean up dead enemies from tracking list
	var alive_enemies: Array[Node] = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			if enemy.has_method("is_dead"):
				if not enemy.is_dead():
					alive_enemies.append(enemy)
			else:
				alive_enemies.append(enemy)
	spawned_enemies = alive_enemies

	# Check if all enemies cleared
	if enemies_remaining <= 0 and spawned_enemies.is_empty():
		ambush_cleared.emit()

		# Notification
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Ambush cleared!")


## Reset trigger (for reusable ambushes)
func reset_trigger() -> void:
	has_triggered = false
	spawned_enemies.clear()
	enemies_remaining = 0


## Add enemy to spawn list programmatically
func add_enemy_to_spawn(
	enemy_data_path: String,
	sprite_path: String,
	h_frames: int = 3,
	v_frames: int = 4,
	count: int = 1
) -> void:
	enemies_to_spawn.append({
		"enemy_data_path": enemy_data_path,
		"sprite_path": sprite_path,
		"h_frames": h_frames,
		"v_frames": v_frames,
		"count": count
	})


## Static factory for creating ambush triggers in code
static func create_ambush(
	parent: Node,
	pos: Vector3,
	radius: float,
	enemy_configs: Array[Dictionary],
	p_trigger_id: String = ""
) -> AmbushTrigger:
	var trigger := AmbushTrigger.new()
	trigger.position = pos
	trigger.trigger_id = p_trigger_id
	trigger.spawn_radius = radius

	# Set enemies to spawn
	for config: Dictionary in enemy_configs:
		trigger.enemies_to_spawn.append(config)

	# Create collision shape
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	col.shape = sphere
	trigger.add_child(col)

	parent.add_child(trigger)
	return trigger
