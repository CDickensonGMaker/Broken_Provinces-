## character_visual.gd - the one interface every character's body answers to.
##
## THE MIGRATION (docs/design/ART_GUIDE.md, "THE MIGRATION"). The game is moving
## from billboard sprites to PSX 3D models one character at a time, and both must
## stand in the same town at the same time, indefinitely. This is the seam that
## lets them: gameplay code says what a character is DOING, and the implementation
## decides whether that is a sprite row or a bone pose.
##
## Two implementations:
##   BillboardVisual - wraps today's BillboardSprite exactly. The default.
##   RiggedVisual    - a citizen GLB with a skeleton.
##
## It is a RefCounted adapter, not a node, on purpose. A wrapper NODE would have
## pushed the sprite one level down the tree, and `get_node("Billboard")` is read
## by NPCScheduler and by half a dozen call sites that flash a sprite red. The
## adapter builds exactly the node the host used to build, in the same place,
## under the same name.
class_name CharacterVisual
extends RefCounted

## The living-world actions. These are NPCScheduler's vocabulary
## (npc_scheduler.gd ACTIONS) and nothing else may be passed to set_action().
const ACTION_IDLE: StringName = &"idle"
const ACTION_SLEEP: StringName = &"sleep"
const ACTION_WORK: StringName = &"work"
const ACTION_EAT: StringName = &"eat"
const ACTION_SOCIALISE: StringName = &"socialise"
const ACTION_TRAVEL: StringName = &"travel"

const ACTIONS: Array[StringName] = [
	ACTION_SLEEP, ACTION_TRAVEL, ACTION_WORK, ACTION_EAT, ACTION_SOCIALISE, ACTION_IDLE,
]

## The host body this visual is dressed onto. Set by attach().
var host: Node3D = null

var _action: StringName = ACTION_IDLE
var _moving: bool = false
var _talking: bool = false
var _facing: Vector3 = Vector3.FORWARD
var _tint: Color = Color.WHITE

## What the host asked for, kept from the factory call so that attach() needs
## only the host. A config that had to be handed over twice was handed over once
## and every billboard in the game lost its body - caught by
## tools/check_character_visual.tscn before it left the branch.
var config: Dictionary = {}


## ============================================================================
## THE INTERFACE
## ============================================================================

## Build this visual's nodes under [param p_host]. Returns false when it could
## not - a missing texture, a missing model - and the caller is then responsible
## for the character having no body, exactly as it was before.
func attach(p_host: Node3D) -> bool:
	host = p_host
	return false


## What this character is doing right now, in the living world's vocabulary.
func set_action(action: StringName) -> void:
	_action = action


## Walking or standing. Separate from the action because an NPC travels to work
## and then works, and both are true of the same minute.
func set_moving(moving: bool) -> void:
	_moving = moving


## Which way the body is pointing, in world space. Y is ignored.
func set_facing(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		_facing = dir


func play_attack() -> void:
	pass


func play_hurt() -> void:
	pass


func play_death() -> void:
	pass


## Mid-conversation. Billboards have nothing to say about this; rigs do.
func set_talking(talking: bool) -> void:
	_talking = talking


## Colour multiplier - the damage flash, the unconscious grey, the dress tints.
func set_tint(colour: Color) -> void:
	_tint = colour


func get_tint() -> Color:
	return _tint


## The node this visual built, or null.
func node() -> Node3D:
	return null


## The BillboardSprite this visual owns, or null when it is not a billboard.
## Every existing `if billboard and billboard.sprite:` guard reads this, and a
## rigged character correctly answers null to all of them.
func billboard_sprite() -> BillboardSprite:
	return null


func is_rigged() -> bool:
	return false


func current_action() -> StringName:
	return _action


func is_moving() -> bool:
	return _moving


func is_talking() -> bool:
	return _talking


func facing() -> Vector3:
	return _facing


## ============================================================================
## THE FACTORY - one data field, no code change per character
## ============================================================================

## Build the right visual for this character.
##
## [param npc_id] is looked up in the model registry (CharacterModelRegistry).
## No entry means a billboard, which is what every character in the game is
## today. An entry naming a model that does not load falls back to a billboard
## and says so, because a character with no body is worse than an old one.
static func for_character(npc_id: String, billboard_config: Dictionary) -> CharacterVisual:
	var model_id: String = CharacterModelRegistry.model_for(npc_id)
	if model_id.is_empty():
		var sprite := BillboardVisual.new()
		sprite.config = billboard_config
		return sprite

	var path: String = CharacterModelRegistry.path_for(model_id)
	if path.is_empty():
		push_warning("[CharacterVisual] %s wants model '%s', which is not on disk - billboard instead"
			% [npc_id, model_id])
		var fallback := BillboardVisual.new()
		fallback.config = billboard_config
		return fallback

	var rigged := RiggedVisual.new()
	rigged.config = billboard_config
	rigged.model_id = model_id
	rigged.model_path = path
	rigged.dress_seed_id = npc_id
	rigged.archetype = String(billboard_config.get("archetype", ""))
	return rigged
