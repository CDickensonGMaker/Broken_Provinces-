## billboard_visual.gd - the CharacterVisual every character in the game wears.
##
## It wraps BillboardSprite and changes nothing. The node it builds is the same
## Sprite3D-in-a-Node3D named "Billboard", in the same place in the tree, with
## the same properties, as the code that used to live inline in CivilianNPC and
## QuestGiver. The point of this class is that RiggedVisual can exist beside it,
## not that billboards should behave differently.
class_name BillboardVisual
extends CharacterVisual

var billboard: BillboardSprite = null


func attach(p_host: Node3D) -> bool:
	host = p_host
	var texture: Texture2D = config.get("texture", null) as Texture2D
	if texture == null:
		return false

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = texture
	billboard.h_frames = int(config.get("h_frames", 1))
	billboard.v_frames = int(config.get("v_frames", 1))
	billboard.pixel_size = float(config.get("pixel_size", 0.0256))
	billboard.idle_frames = int(config.get("idle_frames", billboard.h_frames))
	billboard.walk_frames = int(config.get("walk_frames", billboard.h_frames))
	billboard.idle_fps = float(config.get("idle_fps", 3.0))
	billboard.walk_fps = float(config.get("walk_fps", 6.0))
	billboard.offset_y = float(config.get("offset_y", 0.0))
	billboard.name = "Billboard"
	host.add_child(billboard)
	return true


## A billboard has one drawn state per action and it is the one it already had.
## The sit flag and the facing were always the whole of what a schedule could
## say to a sprite (npc_scheduler.gd, "ART RULE"), and that has not changed.
func set_action(action: StringName) -> void:
	super.set_action(action)


func set_moving(moving: bool) -> void:
	super.set_moving(moving)
	if billboard != null:
		billboard.set_walking(moving)


func set_facing(dir: Vector3) -> void:
	super.set_facing(dir)
	if billboard != null:
		billboard.facing_direction = _facing


func play_attack() -> void:
	if billboard != null:
		billboard.play_attack()


func play_hurt() -> void:
	if billboard != null:
		billboard.play_hurt()


func play_death() -> void:
	if billboard != null:
		billboard.play_death()


func set_talking(talking: bool) -> void:
	super.set_talking(talking)


func set_tint(colour: Color) -> void:
	super.set_tint(colour)
	if billboard != null and billboard.sprite != null:
		billboard.sprite.modulate = colour


func node() -> Node3D:
	return billboard


func billboard_sprite() -> BillboardSprite:
	return billboard
