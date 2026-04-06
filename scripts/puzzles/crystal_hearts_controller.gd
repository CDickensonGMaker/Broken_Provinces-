## crystal_hearts_controller.gd - Crystal Hearts specific puzzle controller
## A star-pattern sequence puzzle that frees an apprentice trapped in a portal
## Sequence: 1 -> 3 -> 5 -> 2 -> 4 (star pattern on pentagon)
class_name CrystalHeartsController
extends PuzzleRoomController

## Crystal Hearts specific signals
signal apprentice_freed
signal portal_opened

const CORRECT_SEQUENCE: Array[int] = [1, 3, 5, 2, 4]  ## Star pattern order

@export var portal_node_path: NodePath
@export var apprentice_spawn_position: Vector3 = Vector3.ZERO

var _portal: Node3D
var _apprentice_spawned: bool = false


func _ready() -> void:
	super._ready()
	puzzle_id = "crystal_hearts_puzzle"
	puzzle_name = "Crystal Hearts"
	required_sequence = CORRECT_SEQUENCE
	completion_flag = "crystal_hearts_solved"

	if portal_node_path:
		_portal = get_node_or_null(portal_node_path)

	puzzle_completed.connect(_on_crystal_puzzle_completed)


func _on_crystal_puzzle_completed() -> void:
	# Open the portal
	if _portal and _portal.has_method("open_portal"):
		_portal.open_portal()
	portal_opened.emit()

	# Spawn the apprentice NPC
	_spawn_freed_apprentice()

	# Notify quest system
	if QuestManager:
		QuestManager.on_puzzle_solved("crystal_hearts_puzzle")


func _spawn_freed_apprentice() -> void:
	if _apprentice_spawned:
		return
	_apprentice_spawned = true

	# Determine spawn position
	var spawn_pos: Vector3 = apprentice_spawn_position
	if spawn_pos == Vector3.ZERO and _portal:
		spawn_pos = _portal.global_position + Vector3(0, 0, 2)

	# Spawn Marcus NPC using the preloaded script class
	var ApprenticeMarcusScript: GDScript = preload("res://scripts/npcs/apprentice_marcus_npc.gd")
	var marcus: Node = ApprenticeMarcusScript.spawn_apprentice_marcus(self, spawn_pos)
	if marcus:
		apprentice_freed.emit()
	else:
		push_warning("[CrystalHeartsController] Failed to spawn apprentice Marcus")


func get_progress_hint() -> String:
	var progress: int = _current_sequence.size()
	match progress:
		0: return "Touch the first pillar to begin..."
		1: return "One down, four to go. The star guides the way."
		2: return "Two points lit. Follow the star's path."
		3: return "Three illuminated. Almost there."
		4: return "One more pillar to complete the pattern!"
		_: return ""


## Static factory for creating a Crystal Hearts puzzle room
static func create_crystal_hearts_room(
	parent: Node,
	center_position: Vector3,
	pillar_radius: float = 5.0
) -> CrystalHeartsController:
	var controller := CrystalHeartsController.new()
	controller.name = "CrystalHeartsController"
	controller.position = center_position
	parent.add_child(controller)

	# Create central portal
	var portal_script: GDScript = load("res://scripts/puzzles/crystal_portal.gd")
	if portal_script:
		var portal: Node3D = portal_script.new()
		portal.name = "CrystalPortal"
		portal.position = Vector3.ZERO
		controller.add_child(portal)
		controller._portal = portal
		controller.portal_node_path = controller.get_path_to(portal)

	# Create 5 pillars in pentagon formation
	# Pentagon angles: 0, 72, 144, 216, 288 degrees
	# Numbered 1-5 clockwise from top
	for i in range(5):
		var angle: float = deg_to_rad(-90 + i * 72)  # Start from top (-90 degrees)
		var pillar_pos: Vector3 = Vector3(
			cos(angle) * pillar_radius,
			0,
			sin(angle) * pillar_radius
		)

		var pillar := PuzzlePillar.spawn_pillar(
			controller,
			pillar_pos,
			"pillar_%d" % (i + 1),
			i + 1,  # sequence_index is 1-5
			2.5  # pillar height
		)
		pillar.element_name = "Crystal Pillar %d" % (i + 1)
		pillar.glow_color_inactive = Color(0.3, 0.2, 0.4)  # Purple inactive
		pillar.glow_color_active = Color(0.8, 0.4, 1.0)    # Bright purple active

	return controller
