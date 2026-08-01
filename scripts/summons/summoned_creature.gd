## summoned_creature.gd - Base class for player-summoned creatures
## Summoned creatures follow their master and attack enemies
class_name SummonedCreature
extends EnemyBase

## The entity that summoned this creature (typically the player)
var master: Node3D = null

## How far the summon can stray from its master before returning
var master_leash_range: float = 8.0

## Follow distance behind master
var follow_distance: float = 3.0

## Time since last saw master (for returning behavior)
var time_since_master_seen: float = 0.0

## Maximum time before teleporting to master
const MAX_MASTER_SEPARATION_TIME := 5.0


func _ready() -> void:
	super._ready()

	# Override faction to PLAYER_SUMMON so we attack enemies, not the player
	if enemy_data:
		# Create a copy so we don't modify the shared resource
		var data_copy := enemy_data.duplicate() as EnemyData
		data_copy.faction = Enums.Faction.PLAYER_SUMMON
		enemy_data = data_copy

	# Remove from enemies group (don't want player attacking us)
	remove_from_group("enemies")
	add_to_group("player_summons")

	# Summoned creatures don't drop loot
	add_to_group("no_loot")


func _physics_process(delta: float) -> void:
	# Update master tracking
	if master and is_instance_valid(master):
		var dist_to_master := global_position.distance_to(master.global_position)

		# If too far from master, teleport back
		if dist_to_master > master_leash_range * 2.5:
			_teleport_to_master()
		# If far from master and no target, return to master
		elif dist_to_master > master_leash_range and current_target == null:
			_return_to_master()

		time_since_master_seen = 0.0
	else:
		time_since_master_seen += delta
		# If master is gone for too long, despawn
		if time_since_master_seen > MAX_MASTER_SEPARATION_TIME:
			queue_free()
			return

	# Normal enemy behavior (will attack hostile factions)
	super._physics_process(delta)


## Override target acquisition to only target enemies hostile to PLAYER_SUMMON
func _find_target() -> Node3D:
	var closest_enemy: Node3D = null
	var closest_distance := INF

	# Check for enemies in aggro range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		if not is_instance_valid(enemy):
			continue

		# Don't target other summons
		if enemy.is_in_group("player_summons"):
			continue

		# Check if hostile based on faction
		var enemy_faction := Enums.Faction.NEUTRAL
		if enemy is EnemyBase and (enemy as EnemyBase).enemy_data:
			enemy_faction = (enemy as EnemyBase).enemy_data.faction

		if not Enums.are_factions_hostile(Enums.Faction.PLAYER_SUMMON, enemy_faction):
			continue

		var enemy_node := enemy as Node3D
		var dist := global_position.distance_to(enemy_node.global_position)

		# Check if within aggro range
		var aggro := enemy_data.aggro_range if enemy_data else 15.0
		if dist < aggro and dist < closest_distance:
			closest_distance = dist
			closest_enemy = enemy_node

	return closest_enemy


## Called by SpellCaster to set who summoned this creature
func set_master(p_master: Node) -> void:
	if p_master is Node3D:
		master = p_master as Node3D
		# Set initial position near master
		spawn_position = master.global_position


## Called by SpellCaster to set leash range
func set_leash_range(p_range: float) -> void:
	master_leash_range = p_range
	# Also update the regular leash radius for consistency
	leash_radius = p_range


## Return to master's side when idle
func _return_to_master() -> void:
	if not master or not is_instance_valid(master):
		return

	# Move toward a position behind the master
	var target_pos := master.global_position - master.global_transform.basis.z * follow_distance

	if nav_agent:
		nav_agent.target_position = target_pos
	else:
		# Simple movement toward master
		var direction := (target_pos - global_position).normalized()
		velocity = direction * (enemy_data.movement_speed if enemy_data else 4.0)
		move_and_slide()


## Teleport to master if too far away
func _teleport_to_master() -> void:
	if not master or not is_instance_valid(master):
		return

	# Teleport to a random position near master
	var offset := Vector3(
		randf_range(-2.0, 2.0),
		0,
		randf_range(-2.0, 2.0)
	)
	global_position = master.global_position + offset
	spawn_position = global_position


## Override death to not award XP or drop loot (summoned creatures)
func _on_death() -> void:
	# Don't award XP for killing summons
	# Don't spawn loot

	# Play death animation/effect
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

	# Disable collision
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)

	# Queue free after a short delay
	await get_tree().create_timer(1.0).timeout
	queue_free()


## Static factory to spawn a summoned creature from enemy data
static func spawn_summoned_creature(
	parent: Node,
	pos: Vector3,
	p_enemy_data: EnemyData,
	p_master: Node3D
) -> SummonedCreature:
	var summon := SummonedCreature.new()

	# Copy enemy data and set faction
	var data_copy := p_enemy_data.duplicate() as EnemyData
	data_copy.faction = Enums.Faction.PLAYER_SUMMON
	summon.enemy_data = data_copy

	# Setup basic stats
	summon.max_hp = data_copy.max_hp
	summon.current_hp = data_copy.max_hp
	summon.armor_value = data_copy.armor_value

	parent.add_child(summon)
	summon.global_position = pos
	summon.set_master(p_master)

	return summon
