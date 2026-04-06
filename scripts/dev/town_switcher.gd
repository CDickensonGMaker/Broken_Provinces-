extends Node3D
## Town Switcher - Preview different town JSON layouts with free camera
## WASD + mouse to fly, ESC to toggle mouse capture, dropdown to switch towns

const BUILDING_MODELS_PATH := "res://assets/models/buildings/"
const PROP_MODELS_PATH := "res://assets/models/props/"

const TOWN_FILES: Dictionary = {
	"Thornfield": "res://scenes/levels/town editor towns/thornfield.json",
	"Millbrook": "res://scenes/levels/town editor towns/millbrook.json",
	"Aberdeen": "res://scenes/levels/town editor towns/aberdeen.json",
	"Larton": "res://scenes/levels/town editor towns/larton.json",
	"Pirate Cove": "res://scenes/levels/town editor towns/pirate_cove.json",
	"Elven Sanctuary": "res://scenes/levels/town editor towns/elven_sanctuary.json",
	"Combat Arena": "res://scenes/levels/town editor towns/combat_arena.json",
}

var current_town_container: Node3D = null
var level_data: LevelEditorData.LevelData = null

@onready var camera: Camera3D = $FreeCam
@onready var town_dropdown: OptionButton = $UI/Panel/VBoxContainer/TownDropdown
@onready var status_label: Label = $UI/Panel/VBoxContainer/StatusLabel
@onready var element_count_label: Label = $UI/Panel/VBoxContainer/ElementCountLabel


func _ready() -> void:
	print("[TownSwitcher] === TOWN SWITCHER READY ===")
	print("[TownSwitcher] Available towns: %s" % str(TOWN_FILES.keys()))

	# Populate dropdown
	var idx: int = 0
	for town_name: String in TOWN_FILES.keys():
		town_dropdown.add_item(town_name, idx)
		idx += 1
	print("[TownSwitcher] Dropdown populated with %d towns" % idx)

	town_dropdown.item_selected.connect(_on_town_selected)
	print("[TownSwitcher] Signal connected: item_selected -> _on_town_selected")

	# Add refresh button dynamically
	var vbox: VBoxContainer = $UI/Panel/VBoxContainer
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Models"
	refresh_btn.pressed.connect(_on_refresh_pressed)
	vbox.add_child(refresh_btn)

	# Load first town by default
	if TOWN_FILES.size() > 0:
		print("[TownSwitcher] Loading first town: %s" % TOWN_FILES.keys()[0])
		_load_town(TOWN_FILES.keys()[0])


func _on_refresh_pressed() -> void:
	# Reload current town to pick up updated models
	var current_idx: int = town_dropdown.selected
	if current_idx >= 0:
		var town_name: String = town_dropdown.get_item_text(current_idx)
		status_label.text = "Refreshing models..."
		_load_town(town_name)


func _on_town_selected(index: int) -> void:
	var town_name: String = town_dropdown.get_item_text(index)
	print("[TownSwitcher] Dropdown selected index: %d, town: %s" % [index, town_name])
	_load_town(town_name)


func _load_town(town_name: String) -> void:
	print("[TownSwitcher] _load_town() called with: '%s'" % town_name)

	if not TOWN_FILES.has(town_name):
		print("[TownSwitcher] ERROR: Unknown town '%s'" % town_name)
		status_label.text = "ERROR: Unknown town: " + town_name
		return

	var file_path: String = TOWN_FILES[town_name]
	print("[TownSwitcher] File path: %s" % file_path)
	status_label.text = "Loading " + town_name + "..."

	# Clear existing town immediately (not queue_free which delays removal)
	if current_town_container:
		print("[TownSwitcher] Clearing existing container: %s" % current_town_container.name)
		current_town_container.free()
		current_town_container = null
	else:
		print("[TownSwitcher] No existing container to clear")

	# Load JSON
	print("[TownSwitcher] Opening file: %s" % file_path)
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var err: int = FileAccess.get_open_error()
		print("[TownSwitcher] ERROR: Cannot open file. Error code: %d" % err)
		status_label.text = "ERROR: Cannot open " + file_path
		return

	var json_str: String = file.get_as_text()
	file.close()
	print("[TownSwitcher] JSON loaded, length: %d chars" % json_str.length())

	level_data = LevelEditorData.LevelData.from_json(json_str)
	if not level_data:
		print("[TownSwitcher] ERROR: Failed to parse JSON")
		status_label.text = "ERROR: Invalid JSON in " + file_path
		return

	print("[TownSwitcher] LevelData parsed. Elements count: %d" % level_data.elements.size())

	# Create container for town elements
	current_town_container = Node3D.new()
	current_town_container.name = town_name + "_Container"
	add_child(current_town_container)
	print("[TownSwitcher] Created container: %s" % current_town_container.name)

	# Spawn all elements
	var building_count: int = 0
	var npc_count: int = 0
	var prop_count: int = 0
	var failed_count: int = 0

	print("[TownSwitcher] Spawning %d elements..." % level_data.elements.size())
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		var node: Node3D = null

		match elem.element_type:
			LevelEditorData.ElementType.BUILDING:
				node = _create_building_node(elem.properties, elem.position)
				building_count += 1
			LevelEditorData.ElementType.NPC:
				node = _create_npc_node(elem.properties, elem.position)
				npc_count += 1
			LevelEditorData.ElementType.PROP:
				node = _create_prop_node(elem.properties, elem.position)
				prop_count += 1
			LevelEditorData.ElementType.FUNCTIONAL:
				node = _create_functional_node(elem.properties, elem.position)
				prop_count += 1
			LevelEditorData.ElementType.CUSTOM_MODEL:
				var model_path: String = elem.properties.get("model_path", "")
				if model_path == "":
					model_path = elem.properties.get("scene_path", "")
				node = _create_custom_model_node(model_path, elem.position)
				building_count += 1

		if node:
			node.rotation_degrees = elem.rotation
			node.scale = elem.scale
			current_town_container.add_child(node)
		else:
			failed_count += 1

	print("[TownSwitcher] Spawning complete:")
	print("  - Buildings: %d" % building_count)
	print("  - NPCs: %d" % npc_count)
	print("  - Props: %d" % prop_count)
	print("  - Failed: %d" % failed_count)
	print("  - Container children: %d" % current_town_container.get_child_count())

	status_label.text = "Loaded: " + town_name
	element_count_label.text = "Buildings: %d | NPCs: %d | Props: %d" % [building_count, npc_count, prop_count]

	# Reset camera position
	camera.position = Vector3(0, 15, 25)
	camera.rotation = Vector3(-0.5, 0, 0)
	print("[TownSwitcher] Camera reset. Town '%s' load complete." % town_name)


## ============================================================================
## BUILDING CREATION
## ============================================================================

func _create_building_node(data: Dictionary, pos: Vector3) -> Node3D:
	var building := Node3D.new()
	# Check both "id" and "building_id" keys for compatibility
	var building_id: String = data.get("building_id", data.get("id", "building"))
	building.name = building_id + "_" + str(randi() % 1000)
	building.position = pos

	var width: float = data.get("width", 8)
	var height: float = data.get("height", 4)
	var depth: float = data.get("depth", 6)
	var style: String = data.get("style", "timber")

	# Try to load custom model first (GLB or FBX)
	var model_path: String = _find_model_path(BUILDING_MODELS_PATH, building_id)
	if model_path != "":
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "Model"
			building.add_child(model_instance)
			# Adjust Y position so model sits on ground (handle models with center origin)
			_ground_model(model_instance)
			return building

	# Fall back to CSG placeholder if no model exists
	match style:
		"timber":
			_build_timber_house(building, width, height, depth)
		"stone":
			_build_stone_building(building, width, height, depth)
		"wood":
			_build_wood_shack(building, width, height, depth)
		"stall":
			_build_market_stall(building, width, height, depth)
		"forge":
			_build_blacksmith(building, width, height, depth)
		"barn":
			_build_barn(building, width, height, depth)
		"church":
			_build_church(building, width, height, depth)
		"civic":
			_build_civic_building(building, width, height, depth)
		"well":
			_build_well(building)
		"fountain":
			_build_fountain(building, width, depth)
		_:
			_build_generic_building(building, width, height, depth)

	return building


func _find_model_path(base_path: String, item_id: String) -> String:
	# Map building IDs to actual model filenames where they differ
	# Must match town_editor_dock.gd's special_names dictionary
	var special_names: Dictionary = {
		# Shops - use shop.glb
		"inn": ["shop"],
		"general_store": ["shop"],
		"magic_shop": ["shop"],
		"tavern": ["shop"],
		# Houses - direct matches exist for most
		"shack": ["hovel"],
		# Temples
		"temple": ["temple_harvest", "chapel"],
		"cathedral": ["temple_harvest", "chapel"],
		"church": ["chapel", "temple_harvest"],
		# Military/Industrial
		"tower": ["guard_tower", "watch_tower"],
		"barracks": ["warehouse"],
		"armorer": ["blacksmith"],
		"barn": ["farm"],
		"palace": ["castle_keep", "manor"],
		# Guilds
		"guild_hall": ["guild_adventure", "adventure_guildglb"],
		"guild_adventure": ["adventure_guildglb", "guild_adventure"],
		"guild_mage": ["MAGE_guildglb", "mage_guild", "guild_mage"],
		"guild_mercenary": ["Mercenary_guild", "mercenary_guild", "guild_mercenary"],
		"guild_thieves": ["thieves_guild", "guild_thieves"],
		# Walls
		"wall_large_tower_U": ["wall_large_tower_Uglb", "wall_large_tower_U"],
	}

	# Try patterns in order of preference
	var ids_to_try: Array[String] = [item_id]
	if special_names.has(item_id):
		for alt_name: String in special_names[item_id]:
			ids_to_try.append(alt_name)

	for try_id: String in ids_to_try:
		var patterns: Array[String] = [
			base_path + try_id + ".glb",
			base_path + try_id + ".fbx",
			base_path + try_id + "_001.glb",
			base_path + try_id + "_001.fbx",
			base_path + "kenney_" + try_id + ".glb",
			base_path + "kenney_" + try_id + ".fbx",
		]
		for path: String in patterns:
			if ResourceLoader.exists(path):
				return path
	return ""


## Adjust model Y position so its bottom sits at Y=0 (ground level)
func _ground_model(model: Node3D) -> void:
	# Calculate combined AABB of all mesh children
	var aabb := AABB()
	var has_aabb := false

	for child in model.get_children():
		if child is MeshInstance3D:
			var mesh_inst: MeshInstance3D = child
			var child_aabb: AABB = mesh_inst.get_aabb()
			# Transform to model space
			child_aabb.position += mesh_inst.position
			if not has_aabb:
				aabb = child_aabb
				has_aabb = true
			else:
				aabb = aabb.merge(child_aabb)
		# Check nested children (GLB models often have nested structure)
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D:
				var mesh_inst: MeshInstance3D = grandchild
				var child_aabb: AABB = mesh_inst.get_aabb()
				child_aabb.position += grandchild.position + child.position
				if not has_aabb:
					aabb = child_aabb
					has_aabb = true
				else:
					aabb = aabb.merge(child_aabb)

	if has_aabb:
		# Move model up so its bottom is at Y=0
		var bottom_y: float = aabb.position.y
		if bottom_y < -0.1:  # Only adjust if noticeably below ground
			model.position.y = -bottom_y


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _build_timber_house(parent: Node3D, w: float, h: float, d: float) -> void:
	# Stone foundation
	var foundation := CSGBox3D.new()
	foundation.size = Vector3(w + 0.2, 0.4, d + 0.2)
	foundation.position.y = 0.2
	foundation.use_collision = false  # Preview only - no collision needed
	foundation.material = _mat(Color(0.4, 0.38, 0.35))
	parent.add_child(foundation)

	# Main walls
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h - 0.4, d)
	walls.position.y = 0.4 + (h - 0.4) / 2.0
	walls.use_collision = false  # Preview only - no collision needed
	walls.material = _mat(Color(0.82, 0.78, 0.7))
	parent.add_child(walls)

	# Pitched roof
	var roof_h: float = h * 0.35
	var roof_l := CSGBox3D.new()
	roof_l.size = Vector3(w/2 + 0.5, 0.15, d + 0.5)
	roof_l.position = Vector3(-w/4, h + roof_h/2 - 0.1, 0)
	roof_l.rotation_degrees.z = 30
	roof_l.material = _mat(Color(0.42, 0.26, 0.18))
	parent.add_child(roof_l)

	var roof_r := CSGBox3D.new()
	roof_r.size = Vector3(w/2 + 0.5, 0.15, d + 0.5)
	roof_r.position = Vector3(w/4, h + roof_h/2 - 0.1, 0)
	roof_r.rotation_degrees.z = -30
	roof_r.material = _mat(Color(0.42, 0.26, 0.18))
	parent.add_child(roof_r)


func _build_stone_building(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = false  # Preview only
	walls.material = _mat(Color(0.5, 0.48, 0.45))
	parent.add_child(walls)

	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.4, 0.3, d + 0.4)
	roof.position.y = h + 0.15
	roof.material = _mat(Color(0.35, 0.32, 0.3))
	parent.add_child(roof)


func _build_wood_shack(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = false  # Preview only
	walls.material = _mat(Color(0.45, 0.35, 0.25))
	parent.add_child(walls)

	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.3, 0.2, d + 0.3)
	roof.position.y = h + 0.1
	roof.rotation_degrees.x = 10
	roof.material = _mat(Color(0.38, 0.32, 0.22))
	parent.add_child(roof)


func _build_market_stall(parent: Node3D, w: float, h: float, d: float) -> void:
	# Counter
	var counter := CSGBox3D.new()
	counter.size = Vector3(w, 1.0, d * 0.4)
	counter.position = Vector3(0, 0.5, d * 0.3)
	counter.use_collision = false  # Preview only
	counter.material = _mat(Color(0.5, 0.4, 0.3))
	parent.add_child(counter)

	# Awning
	var awning := CSGBox3D.new()
	awning.size = Vector3(w + 0.4, 0.1, d)
	awning.position = Vector3(0, h, 0)
	awning.rotation_degrees.x = 15
	awning.material = _mat(Color(0.7, 0.2, 0.2))
	parent.add_child(awning)


func _build_blacksmith(parent: Node3D, w: float, h: float, d: float) -> void:
	_build_stone_building(parent, w, h, d)
	# Add chimney
	var chimney := CSGBox3D.new()
	chimney.size = Vector3(1.0, 2.0, 1.0)
	chimney.position = Vector3(w/3, h + 1.0, -d/3)
	chimney.material = _mat(Color(0.3, 0.28, 0.25))
	parent.add_child(chimney)


func _build_barn(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = false  # Preview only
	walls.material = _mat(Color(0.55, 0.3, 0.2))
	parent.add_child(walls)

	# Gambrel roof (simplified)
	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.5, 0.25, d + 0.5)
	roof.position.y = h + h * 0.2
	roof.material = _mat(Color(0.4, 0.35, 0.3))
	parent.add_child(roof)


func _build_church(parent: Node3D, w: float, h: float, d: float) -> void:
	_build_stone_building(parent, w, h, d)
	# Add steeple
	var steeple := CSGCylinder3D.new()
	steeple.radius = 1.0
	steeple.height = h * 0.8
	steeple.sides = 4
	steeple.position = Vector3(0, h + h * 0.4, -d/3)
	steeple.material = _mat(Color(0.45, 0.42, 0.4))
	parent.add_child(steeple)


func _build_civic_building(parent: Node3D, w: float, h: float, d: float) -> void:
	_build_stone_building(parent, w, h, d)
	# Add columns
	for i in range(3):
		var col := CSGCylinder3D.new()
		col.radius = 0.3
		col.height = h - 0.5
		col.position = Vector3(-w/3 + i * w/3, (h - 0.5)/2, d/2 + 0.3)
		col.material = _mat(Color(0.7, 0.68, 0.65))
		parent.add_child(col)


func _build_well(parent: Node3D) -> void:
	var base := CSGCylinder3D.new()
	base.radius = 1.0
	base.height = 0.8
	base.position.y = 0.4
	base.use_collision = false  # Preview only
	base.material = _mat(Color(0.45, 0.43, 0.4))
	parent.add_child(base)


func _build_fountain(parent: Node3D, w: float, _d: float) -> void:
	var basin := CSGCylinder3D.new()
	basin.radius = w / 2
	basin.height = 0.6
	basin.position.y = 0.3
	basin.use_collision = false  # Preview only
	basin.material = _mat(Color(0.5, 0.48, 0.45))
	parent.add_child(basin)


func _build_generic_building(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = false  # Preview only
	walls.material = _mat(Color(0.6, 0.55, 0.5))
	parent.add_child(walls)


## ============================================================================
## NPC CREATION
## ============================================================================

func _create_npc_node(data: Dictionary, pos: Vector3) -> Node3D:
	var npc := Node3D.new()
	# Support both "id" (from brush) and "npc_id" (from saved JSON)
	var npc_id: String = data.get("id", data.get("npc_id", "npc"))
	npc.name = npc_id + "_" + str(randi() % 1000)
	npc.position = pos

	var body := CSGCylinder3D.new()
	body.radius = 0.35
	body.height = 1.8
	body.position.y = 0.9

	var mat := StandardMaterial3D.new()
	match npc_id:
		"guard", "guard_captain":
			mat.albedo_color = Color(0.28, 0.32, 0.48)
		"merchant_general", "merchant_weapons", "merchant_armor", "merchant_magic":
			mat.albedo_color = Color(0.58, 0.48, 0.28)
		"priest":
			mat.albedo_color = Color(0.8, 0.78, 0.7)
		"noble":
			mat.albedo_color = Color(0.5, 0.2, 0.5)
		_:
			mat.albedo_color = Color(0.48, 0.38, 0.32)
	body.material = mat
	npc.add_child(body)

	var head := CSGSphere3D.new()
	head.radius = 0.25
	head.position.y = 2.0
	head.material = mat
	npc.add_child(head)

	# Label
	var label := Label3D.new()
	label.text = data.get("name", data.get("npc_name", npc_id))
	label.position.y = 2.5
	label.font_size = 20
	label.outline_size = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	npc.add_child(label)

	return npc


## ============================================================================
## PROP CREATION
## ============================================================================

func _create_prop_node(data: Dictionary, pos: Vector3) -> Node3D:
	var prop := Node3D.new()
	# Support both "id" (from brush) and "prop_id" (from saved JSON)
	var prop_id: String = data.get("id", data.get("prop_id", "prop"))
	prop.name = prop_id + "_" + str(randi() % 1000)
	prop.position = pos

	# Try to load custom model first
	var model_path: String = _find_model_path(PROP_MODELS_PATH, prop_id)
	if model_path != "":
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "Model"
			prop.add_child(model_instance)
			# Adjust Y position so model sits on ground
			_ground_model(model_instance)
			return prop

	# Fall back to CSG placeholder
	var mesh: CSGShape3D

	match prop_id:
		"barrel":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.35
			(mesh as CSGCylinder3D).height = 0.9
			mesh.position.y = 0.45
		"crate", "crate_stack":
			mesh = CSGBox3D.new()
			var h: float = 0.7 if prop_id == "crate" else 1.4
			(mesh as CSGBox3D).size = Vector3(0.7, h, 0.7)
			mesh.position.y = h / 2
		"bench":
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(1.8, 0.45, 0.5)
			mesh.position.y = 0.22
		"torch_wall", "torch_standing":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.08
			(mesh as CSGCylinder3D).height = 2.2
			mesh.position.y = 1.1
		"table":
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(1.2, 0.1, 0.8)
			mesh.position.y = 0.75
		"chair":
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(0.45, 0.45, 0.45)
			mesh.position.y = 0.22
		"tree_oak", "tree_pine":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.3
			(mesh as CSGCylinder3D).height = 4.0
			mesh.position.y = 2.0
		"rock", "boulder":
			mesh = CSGSphere3D.new()
			(mesh as CSGSphere3D).radius = 0.8
			mesh.position.y = 0.4
		"hay_bale":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.5
			(mesh as CSGCylinder3D).height = 0.8
			mesh.position.y = 0.4
			mesh.rotation_degrees.x = 90
		_:
			# Generic prop placeholder
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(0.5, 0.5, 0.5)
			mesh.position.y = 0.25

	mesh.material = _mat(Color(0.5, 0.45, 0.4))
	prop.add_child(mesh)
	return prop


## ============================================================================
## FUNCTIONAL & CUSTOM MODEL CREATION
## ============================================================================

func _create_functional_node(data: Dictionary, pos: Vector3) -> Node3D:
	var func_node := Node3D.new()
	# Support both "id" (from brush) and "func_type" (from saved JSON)
	var func_type: String = data.get("id", data.get("func_type", "unknown"))
	func_node.name = func_type + "_" + str(randi() % 1000)
	func_node.position = pos

	# Only create visual for certain functional types
	match func_type:
		"fast_travel_shrine":
			# Stone pillar with glowing orb
			var pillar := CSGCylinder3D.new()
			pillar.radius = 0.4
			pillar.height = 2.5
			pillar.position.y = 1.25
			pillar.material = _mat(Color(0.5, 0.52, 0.55))
			func_node.add_child(pillar)

			var orb := CSGSphere3D.new()
			orb.radius = 0.3
			orb.position.y = 2.7
			var orb_mat := StandardMaterial3D.new()
			orb_mat.albedo_color = Color(0.4, 0.7, 1.0)
			orb_mat.emission_enabled = true
			orb_mat.emission = Color(0.3, 0.5, 0.9)
			orb_mat.emission_energy_multiplier = 1.5
			orb.material = orb_mat
			func_node.add_child(orb)
		"bounty_board":
			# Wooden post with board
			var post := CSGBox3D.new()
			post.size = Vector3(0.15, 2.2, 0.15)
			post.position.y = 1.1
			post.material = _mat(Color(0.4, 0.3, 0.2))
			func_node.add_child(post)

			var board := CSGBox3D.new()
			board.size = Vector3(1.2, 0.9, 0.08)
			board.position = Vector3(0, 1.8, 0.1)
			board.material = _mat(Color(0.5, 0.4, 0.3))
			func_node.add_child(board)
		"spawn_point":
			# Invisible - spawn points shouldn't be visible in the world
			pass
		_:
			# Unknown functional - skip visual
			pass

	return func_node


func _create_custom_model_node(model_path: String, pos: Vector3) -> Node3D:
	var container := Node3D.new()
	container.name = model_path.get_file().get_basename() + "_" + str(randi() % 1000)
	container.position = pos

	if model_path != "" and ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			container.add_child(model_instance)
			# Adjust Y position so model sits on ground
			_ground_model(model_instance)
			return container

	# Fallback placeholder
	var placeholder := CSGBox3D.new()
	placeholder.size = Vector3(2.0, 2.0, 2.0)
	placeholder.position.y = 1.0
	placeholder.use_collision = false  # Preview only
	placeholder.material = _mat(Color(0.8, 0.2, 0.8))
	container.add_child(placeholder)

	return container
