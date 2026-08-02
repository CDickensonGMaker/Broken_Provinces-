## character_model_registry.gd - which characters have a 3D body yet.
##
## ONE DATA FIELD FLIPS A CHARACTER. `data/character_models.json` maps an npc_id
## to a model id; ActorRegistry's `model` key on an actor config overrides it for
## characters the Actor Zoo already knows. Absent from both = billboard, which is
## every character in the game until its model lands.
##
##     { "models": { "grom_the_smith": "citizen_man" } }
##
## No code changes when a model lands - the day Caleb exports citizen_woman's
## replacement, the line goes here and the character is 3D.
class_name CharacterModelRegistry
extends RefCounted

const REGISTRY_PATH: String = "res://data/character_models.json"
const MODEL_DIR: String = "res://assets/models/citizens/glb/"

## npc_id -> model id, loaded once.
static var _models: Dictionary = {}
static var _loaded: bool = false


## The model id this character wears, or "" for a billboard.
static func model_for(npc_id: String) -> String:
	if npc_id.is_empty():
		return ""
	_ensure_loaded()

	# The Actor Zoo wins where it has an opinion: it is the tool Caleb patches
	# visuals from, and a patch that could not override the file would be a lie.
	var tree := Engine.get_main_loop() as SceneTree
	var registry: Node = tree.root.get_node_or_null("/root/ActorRegistry") if tree != null else null
	if registry != null and registry.has_method("get_actor_config"):
		var config: Dictionary = registry.get_actor_config(npc_id)
		var patched: String = String(config.get("model", ""))
		if not patched.is_empty():
			return patched

	return String(_models.get(npc_id, ""))


## Absolute path to a model id's GLB, or "" when it is not on disk.
static func path_for(model_id: String) -> String:
	if model_id.is_empty():
		return ""
	var path: String = MODEL_DIR + model_id + ".glb"
	if ResourceLoader.exists(path):
		return path
	return ""


## Every character the registry file flips, for the gates.
static func all_flipped() -> Dictionary:
	_ensure_loaded()
	return _models.duplicate()


## Re-read the file. The gates use this; the game never needs it.
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_models.clear()

	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[CharacterModelRegistry] %s: %s (line %d)"
			% [REGISTRY_PATH, json.get_error_message(), json.get_error_line()])
		return
	if not json.data is Dictionary:
		push_error("[CharacterModelRegistry] %s root is not an object" % REGISTRY_PATH)
		return

	var models: Variant = (json.data as Dictionary).get("models", {})
	if not models is Dictionary:
		push_error("[CharacterModelRegistry] %s has no models object" % REGISTRY_PATH)
		return

	for npc_id: String in (models as Dictionary).keys():
		_models[npc_id] = String((models as Dictionary)[npc_id])
