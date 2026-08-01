## wilderness_tile.gd - Base script for hand-crafted wilderness tile scenes
## These tiles are loaded by WildernessRoom as biome-specific variations
class_name WildernessTile
extends Node3D

## Biome type this tile belongs to (forest, plains, swamp, hills, rocky)
@export var biome: String = "forest"

## Variant number for this tile (allows multiple tiles per biome)
@export var variant: int = 1

## Danger level multiplier for enemy spawning (1.0 = normal, higher = more dangerous)
@export var danger_level: float = 1.0

## Movement speed modifier (1.0 = normal, lower = slower movement like swamp)
@export var movement_modifier: float = 1.0

## Points of interest in this tile (for map/compass markers)
@export var poi_markers: Array[Marker3D] = []


func _ready() -> void:
	# Register POIs if any exist
	_register_pois()


## Register points of interest for compass/map
func _register_pois() -> void:
	var pois: Node3D = get_node_or_null("POIs")
	if not pois:
		return

	for child: Node in pois.get_children():
		if child is Marker3D:
			child.add_to_group("compass_poi")


## Get spawn points for enemies
func get_enemy_spawn_points() -> Array[Node3D]:
	var spawns: Array[Node3D] = []
	var spawn_container: Node3D = get_node_or_null("Spawns")
	if spawn_container:
		for child: Node in spawn_container.get_children():
			if child is Node3D and child.name.begins_with("EnemySpawn"):
				spawns.append(child)
	return spawns


## Get exit points for cell transitions
func get_exit_points() -> Dictionary:
	var exits: Dictionary = {}
	var exit_container: Node3D = get_node_or_null("Exits")
	if exit_container:
		for child: Node in exit_container.get_children():
			if child is Node3D:
				if child.name == "Exit_North":
					exits["north"] = child
				elif child.name == "Exit_South":
					exits["south"] = child
				elif child.name == "Exit_East":
					exits["east"] = child
				elif child.name == "Exit_West":
					exits["west"] = child
	return exits
