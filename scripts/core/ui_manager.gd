## ui_manager.gd - Owns the canvas every popup lives on, and keeps one of each.
##
## Before this, each menu built its own CanvasLayer, guessed a layer number and
## parented itself to whatever node happened to open it - so a merchant who
## streamed out took his shop with him, and half the menus drew under the HUD.
## Now there is one canvas, above the HUD, owned here and outliving scenes.
extends Node

## Above the HUD, which sits at the default layer
const POPUP_LAYER := 100

var _canvas: CanvasLayer = null
## popup_name -> Control. One live instance per name.
var _popups: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_canvas()
	if SceneManager and SceneManager.has_signal("scene_load_started"):
		SceneManager.scene_load_started.connect(_on_scene_load_started)


func _ensure_canvas() -> void:
	if is_instance_valid(_canvas):
		return
	_canvas = CanvasLayer.new()
	_canvas.name = "PopupCanvas"
	_canvas.layer = POPUP_LAYER
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)


## The layer popups draw on. Callers that build their own node use this.
func get_popup_canvas() -> CanvasLayer:
	_ensure_canvas()
	return _canvas


## Put an already-built popup on the popup canvas.
func host(popup: Node, popup_name: String = "") -> void:
	if not is_instance_valid(popup):
		return
	_ensure_canvas()
	if popup_name != "":
		popup.name = popup_name
		_popups[popup_name] = popup
	if popup.get_parent() == _canvas:
		return
	if popup.get_parent() != null:
		popup.get_parent().remove_child(popup)
	_canvas.add_child(popup)


## Get the single live instance of a popup, building it from `script` if needed.
## This is what replaces the per-caller "free the old one and rebuild" dance.
func get_or_create(popup_name: String, script: Script) -> Node:
	var existing: Variant = _popups.get(popup_name)
	if existing is Node and is_instance_valid(existing):
		return existing

	var popup: Node = Control.new()
	popup.set_script(script)
	host(popup, popup_name)
	return popup


func get_popup(popup_name: String) -> Node:
	var existing: Variant = _popups.get(popup_name)
	if existing is Node and is_instance_valid(existing):
		return existing
	return null


func close_popup(popup_name: String) -> void:
	var popup: Node = get_popup(popup_name)
	if popup and popup.has_method("close"):
		popup.call("close")


## Any popup still open when the world changes underneath it is a stranded
## pause and a captured mouse. Shut them all before the new scene loads.
func close_all() -> void:
	for popup_name: String in _popups.keys():
		var popup: Variant = _popups[popup_name]
		if popup is Node and is_instance_valid(popup):
			if popup.has_method("close"):
				popup.call("close")
			popup.queue_free()
	_popups.clear()


func _on_scene_load_started(_scene_path: String) -> void:
	close_all()
