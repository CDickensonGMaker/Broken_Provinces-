## citizen_rig_driver.gd - the node that gives a RiggedVisual a heartbeat.
##
## CharacterVisual is a RefCounted adapter so that BillboardVisual can build
## exactly the node tree the game already reads by path. A RefCounted has no
## _process, and a rig without clips has to be posed every frame, so the rigged
## implementation hangs this one node under the host and forwards the tick.
class_name CitizenRigDriver
extends Node3D

var visual: RiggedVisual = null


func _process(delta: float) -> void:
	if visual != null:
		visual.tick(delta)
