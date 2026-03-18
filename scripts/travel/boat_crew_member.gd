## boat_crew_member.gd - Crew NPC for boat voyages
## Has health, combat, and simple AI - fights enemies during encounters
class_name BoatCrewMember
extends CharacterBody3D

signal died(crew_member: BoatCrewMember)

## Display name shown on interaction
@export var display_name: String = "Crew Member"

## Health
@export var max_health: int = 40
var current_health: int = 40
var is_dead: bool = false

## Combat stats
@export var damage: int = 8
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
var attack_timer: float = 0.0
var current_target: Node3D = null
var in_combat: bool = false

## Whether this crew member wanders around (when not fighting)
@export var enable_wandering: bool = false
@export var wander_radius: float = 3.0
@export var wander_speed: float = 1.5
@export var combat_speed: float = 3.0

## Visual components
var billboard: BillboardSprite
var collision_shape: CollisionShape3D

## Wandering state
var home_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
const WANDER_INTERVAL := 4.0

## Sprite settings
const PIXEL_SIZE := 0.0256  # Scaled for boat scene
const DEFAULT_SPRITE_PATH := "res://assets/sprites/npcs/civilians/guard_civilian.png"

## Custom sprite path (set via metadata before adding to scene)
var custom_sprite_path: String = ""


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	wander_target = home_position

	# Check for custom sprite metadata
	if has_meta("custom_sprite"):
		custom_sprite_path = get_meta("custom_sprite")

	_setup_collision()
	_setup_billboard()

	add_to_group("boat_crew")
	add_to_group("allies")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer -= delta

	# Combat behavior - find and attack enemies
	if in_combat:
		_combat_behavior(delta)
		return

	# Wandering behavior when peaceful
	if not enable_wandering:
		return

	wander_timer -= delta
	if wander_timer <= 0:
		_pick_new_wander_target()
		wander_timer = WANDER_INTERVAL + randf_range(-1.0, 1.0)

	# Move toward target
	var to_target: Vector3 = wander_target - global_position
	to_target.y = 0

	if to_target.length() > 0.3:
		var direction: Vector3 = to_target.normalized()
		velocity = direction * wander_speed
		velocity.y = 0
		move_and_slide()

		if billboard:
			billboard.set_walking(true)
	else:
		velocity = Vector3.ZERO
		if billboard:
			billboard.set_walking(false)


## Combat AI - move to and attack enemies
func _combat_behavior(delta: float) -> void:
	# Find a target if we don't have one
	if not is_instance_valid(current_target) or _target_is_dead():
		current_target = _find_nearest_enemy()
		if not current_target:
			in_combat = false
			return

	# Move toward target
	var to_target: Vector3 = current_target.global_position - global_position
	to_target.y = 0
	var dist: float = to_target.length()

	if dist > attack_range:
		# Move closer
		var direction: Vector3 = to_target.normalized()
		velocity = direction * combat_speed
		velocity.y = 0
		move_and_slide()
		if billboard:
			billboard.set_walking(true)
	else:
		# In range - attack
		velocity = Vector3.ZERO
		if billboard:
			billboard.set_walking(false)
		if attack_timer <= 0:
			_attack_target()
			attack_timer = attack_cooldown


func _target_is_dead() -> bool:
	if current_target.has_method("is_dead"):
		return current_target.is_dead
	if current_target.has_property("is_dead"):
		return current_target.is_dead
	return false


func _find_nearest_enemy() -> Node3D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("boat_enemies")
	var nearest: Node3D = null
	var nearest_dist: float = 100.0

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy is EnemyBase and enemy.is_dead:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


func _attack_target() -> void:
	if not is_instance_valid(current_target):
		return

	# Play attack animation
	if billboard:
		billboard.play_attack()

	# Play melee combat sound
	if AudioManager:
		AudioManager.play_melee_hit_sound_3d(global_position)

	# Deal damage
	if current_target.has_method("take_damage"):
		current_target.take_damage(damage, self)
	elif current_target is EnemyBase:
		current_target.take_damage(damage)


## Called when enemies appear - crew enters combat mode
func enter_combat() -> void:
	in_combat = true
	current_target = null
	attack_timer = 0.0


## Called when combat ends - return to normal behavior
func exit_combat() -> void:
	in_combat = false
	current_target = null
	wander_target = home_position


## Take damage from an attack
func take_damage(amount: int, _attacker: Node = null) -> void:
	if is_dead:
		return

	current_health -= amount

	# Visual feedback
	if billboard:
		billboard.play_hurt()

	if current_health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	in_combat = false
	velocity = Vector3.ZERO

	if billboard:
		billboard.play_death()

	died.emit(self)

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

	# Remove after death animation
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _pick_new_wander_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.5, wander_radius)
	wander_target = home_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _setup_collision() -> void:
	collision_layer = 2  # NPC layer
	collision_mask = 1   # Collide with world

	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collision_shape.shape = capsule
	collision_shape.position.y = 0.9
	add_child(collision_shape)


func _setup_billboard() -> void:
	billboard = BillboardSprite.new()

	# Use custom sprite if set, otherwise use default
	var sprite_path: String = custom_sprite_path if not custom_sprite_path.is_empty() else DEFAULT_SPRITE_PATH

	if ResourceLoader.exists(sprite_path):
		billboard.sprite_sheet = load(sprite_path)
	else:
		billboard.sprite_sheet = load(DEFAULT_SPRITE_PATH)

	billboard.h_frames = 1
	billboard.v_frames = 1
	billboard.pixel_size = PIXEL_SIZE
	billboard.idle_frames = 1
	billboard.walk_frames = 1
	billboard.idle_fps = 3.0
	billboard.walk_fps = 6.0
	add_child(billboard)


## Static factory method - spawn a crew member
static func spawn_crew(parent: Node, pos: Vector3, crew_name: String = "Crew Member", wandering: bool = false, sprite_path: String = "") -> BoatCrewMember:
	var crew := BoatCrewMember.new()
	crew.display_name = crew_name
	crew.enable_wandering = wandering

	# Set custom sprite before adding to tree (so _ready can use it)
	if not sprite_path.is_empty():
		crew.set_meta("custom_sprite", sprite_path)

	crew.global_position = pos
	parent.add_child(crew)
	return crew
