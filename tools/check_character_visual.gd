extends Node
## Character-visual guard, headless.
##
## Usage: godot --headless --path . res://tools/check_character_visual.tscn
##
## Seven things are asserted.
##
## 1. THE REGISTRY FLIP. `data/character_models.json` is the ONLY thing that
##    decides whether a character is a sprite or a rig, and an id it does not
##    name is a billboard.
## 2. THE BILLBOARD WRAP IS A NO-OP. A CivilianNPC with no model entry builds
##    the same "Billboard" node, in the same place, with the same properties, as
##    it did before the abstraction existed. This is the regression that would
##    silently break every NPC in the game.
## 3. THE DRESSER IS DETERMINISTIC. The same npc_id dressed twice, in two
##    separate instances, wears exactly the same clothes. Grom is the same Grom
##    in every session, forever.
## 4. THE DRESSER IS VARIED. Two hundred ids produce a spread of outfits rather
##    than a village of twins.
## 5. THE COMPOSITION RULES HOLD, at population scale, on all four masters:
##    exactly one vest, legs on, exactly one sleeve style, at most one hair, and
##    a skirt only where a skirt exists.
## 6. THE OCTUPLETS LAW. Two dressed citizens do not share one face material,
##    and the offset each carries is the cell its face index names.
## 7. THE PILOT. Grom the Smith boots inside Elder Moor as a rigged citizen,
##    dressed, wearing his apron, standing at his 13:00 station - and the
##    billboard NPCs around him are untouched.

const MAN := "res://assets/models/citizens/glb/citizen_man.glb"
const MASTERS: Array[String] = ["citizen_man", "citizen_woman", "citizen_boy", "citizen_girl"]
const PILOT_ID := "grom_the_smith"
const PILOT_MODEL := "citizen_man"
const START_SCENE := "res://scenes/levels/elder_moor.tscn"
const POPULATION := 200

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	await _run()
	_finish()


func _run() -> void:
	_check_registry()
	_check_billboard_wrap()
	_check_dresser_determinism()
	_check_dresser_variety()
	_check_composition_rules()
	_check_material_instancing()
	_check_the_body_is_alive()
	await _check_pilot()


## ============================================================================
## 1. THE REGISTRY FLIP
## ============================================================================

func _check_registry() -> void:
	CharacterModelRegistry.reload()
	var flipped: Dictionary = CharacterModelRegistry.all_flipped()

	_check("registry names the pilot", CharacterModelRegistry.model_for(PILOT_ID) == PILOT_MODEL,
		"model_for(%s) = '%s'" % [PILOT_ID, CharacterModelRegistry.model_for(PILOT_ID)])
	_check("an unlisted id is a billboard",
		CharacterModelRegistry.model_for("a_villager_who_has_no_model").is_empty())
	_check("an empty id is a billboard", CharacterModelRegistry.model_for("").is_empty())

	for npc_id: String in flipped.keys():
		var model: String = String(flipped[npc_id])
		_check("%s's model '%s' is on disk" % [npc_id, model],
			not CharacterModelRegistry.path_for(model).is_empty())

	for master: String in MASTERS:
		_check("%s exists" % master, not CharacterModelRegistry.path_for(master).is_empty())


## ============================================================================
## 2. THE BILLBOARD WRAP IS A NO-OP
## ============================================================================

func _check_billboard_wrap() -> void:
	var texture: Texture2D = load("res://assets/sprites/npcs/civilians/man_civilian.png")
	if texture == null:
		_check("man_civilian.png loads", false)
		return

	var host := Node3D.new()
	add_child(host)
	var visual: CharacterVisual = CharacterVisual.for_character("nobody_special", {
		"texture": texture, "h_frames": 3, "v_frames": 1, "pixel_size": 0.0256,
		"idle_frames": 3, "walk_frames": 3, "offset_y": 0.25,
	})
	_check("an unflipped character gets a BillboardVisual", visual is BillboardVisual)
	_check("the visual attached", visual.attach(host))

	var node: Node = host.get_node_or_null("Billboard")
	_check("it built a child named Billboard", node != null)
	if node == null:
		host.queue_free()
		return

	var sprite := node as BillboardSprite
	_check("that child is a BillboardSprite", sprite != null)
	_check("it is the visual's own sprite", visual.billboard_sprite() == sprite)
	_check("it is not rigged", not visual.is_rigged())
	_check("h_frames carried through", sprite.h_frames == 3)
	_check("pixel_size carried through", is_equal_approx(sprite.pixel_size, 0.0256))
	_check("offset_y carried through", is_equal_approx(sprite.offset_y, 0.25))
	_check("idle_fps is the house 3.0", is_equal_approx(sprite.idle_fps, 3.0))
	_check("walk_fps is the house 6.0", is_equal_approx(sprite.walk_fps, 6.0))

	visual.set_moving(true)
	_check("set_moving(true) walks the sprite",
		sprite.current_state == BillboardSprite.AnimState.WALK)
	visual.set_moving(false)
	_check("set_moving(false) stops it",
		sprite.current_state == BillboardSprite.AnimState.IDLE)

	visual.set_facing(Vector3(0, 0, -1))
	_check("set_facing reaches the sprite", sprite.facing_direction.is_equal_approx(Vector3(0, 0, -1)))

	visual.set_tint(Color(0.5, 0.5, 0.5))
	_check("set_tint reaches the sprite",
		sprite.sprite != null and sprite.sprite.modulate.is_equal_approx(Color(0.5, 0.5, 0.5)))

	# Every living-world action must be sayable to a billboard without a crash.
	for action: StringName in CharacterVisual.ACTIONS:
		visual.set_action(action)
	_check("a billboard survives every living-world action",
		visual.current_action() == CharacterVisual.ACTION_IDLE)

	# A character with no texture and no model has no body, and says so rather
	# than half-building one.
	var bare := Node3D.new()
	add_child(bare)
	var empty: CharacterVisual = CharacterVisual.for_character("nobody_special", {})
	_check("no texture and no model = no body", not empty.attach(bare))
	_check("and nothing was built", bare.get_child_count() == 0)
	bare.queue_free()

	host.queue_free()


## ============================================================================
## 3-6. THE DRESSER
## ============================================================================

func _dress(model: String, npc_id: String, archetype: String = "") -> Dictionary:
	var path: String = CharacterModelRegistry.path_for(model)
	if path.is_empty():
		return {}
	var packed: PackedScene = load(path)
	if packed == null:
		return {}
	var root: Node3D = packed.instantiate() as Node3D
	var loadout: Dictionary = CitizenDresser.dress(root, model, npc_id, archetype)
	var worn: Array[String] = CitizenDresser.visible_meshes(root)
	root.free()
	return {"loadout": loadout, "worn": worn}


func _check_dresser_determinism() -> void:
	CitizenDresser.reset_warnings()

	# Two separate instances, dressed independently. If any part of the outfit
	# came from spawn order, the global RNG or the clock, these differ.
	for npc_id: String in ["grom_the_smith", "mabel", "a", "zzzz_the_last_villager"]:
		var first: Dictionary = _dress(PILOT_MODEL, npc_id)
		var second: Dictionary = _dress(PILOT_MODEL, npc_id)
		_check("%s wears the same clothes twice" % npc_id,
			first.get("worn", []) == second.get("worn", []),
			"%s vs %s" % [first.get("worn", []), second.get("worn", [])])
		_check("%s has the same face twice" % npc_id,
			first.get("loadout", {}).get("face", -1) == second.get("loadout", {}).get("face", -2))

	_check("the seed is the id and nothing else",
		CitizenDresser.seed_for("grom_the_smith") == CitizenDresser.seed_for("grom_the_smith"))
	_check("two ids are two seeds",
		CitizenDresser.seed_for("grom_the_smith") != CitizenDresser.seed_for("grim_the_smith"))


func _check_dresser_variety() -> void:
	# The whole promise of the dresser is that two masters carry ~55 characters.
	# A village of twins would pass every determinism check above and fail the
	# only thing that mattered.
	var outfits: Dictionary = {}
	var faces: Dictionary = {}
	for index: int in POPULATION:
		var result: Dictionary = _dress(PILOT_MODEL, "villager_%d" % index)
		outfits["|".join(result.get("worn", []) as Array[String])] = true
		faces[int(result.get("loadout", {}).get("face", -1))] = true

	_check("%d men wear more than 8 distinct outfits (got %d)" % [POPULATION, outfits.size()],
		outfits.size() > 8)
	_check("%d men wear more than 16 distinct faces (got %d)" % [POPULATION, faces.size()],
		faces.size() > 16)


func _check_composition_rules() -> void:
	for model: String in MASTERS:
		var skirts: int = 0
		for index: int in 60:
			var result: Dictionary = _dress(model, "%s_%d" % [model, index])
			var worn: Array = result.get("worn", [])

			var vests: int = _count_prefix(worn, "garb_vest_")
			var sleeves: int = _count_prefix(worn, "garb_sleeve_")
			var hairs: int = _count_prefix(worn, "hair_")
			var legs: int = (1 if worn.has("garb_pants") else 0) \
				+ (1 if worn.has("garb_skirt") else 0)

			if vests != 1 or sleeves != 1 or legs != 1 or hairs > 1:
				_check("%s #%d wears one vest, one sleeve style, one leg garment and at most one hair"
					% [model, index], false, str(worn))
				break
			if worn.has("garb_skirt"):
				skirts += 1
				if not CitizenDresser.SKIRT_MODELS.has(model):
					_check("%s must never wear a skirt" % model, false, str(worn))
					break
		_check("%s: composition rules hold across 60 citizens" % model, true)
		if CitizenDresser.SKIRT_MODELS.has(model):
			_check("%s actually wears skirts sometimes (got %d/60)" % [model, skirts], skirts > 0)
		else:
			_check("%s never wears a skirt" % model, skirts == 0)

	# The apron is the trade's, not the seed's.
	var plain: Dictionary = _dress(PILOT_MODEL, "someone", "laborer")
	var smith: Dictionary = _dress(PILOT_MODEL, "someone", "shopkeeper")
	_check("a labourer gets no apron", not (plain.get("worn", []) as Array).has("garb_apron"))
	_check("a shopkeeper gets an apron", (smith.get("worn", []) as Array).has("garb_apron"))


func _count_prefix(names: Array, prefix: String) -> int:
	var total: int = 0
	for name: String in names:
		if name.begins_with(prefix):
			total += 1
	return total


func _check_material_instancing() -> void:
	var packed: PackedScene = load(MAN)
	var one: Node3D = packed.instantiate() as Node3D
	var two: Node3D = packed.instantiate() as Node3D
	var load_one: Dictionary = CitizenDresser.dress(one, PILOT_MODEL, "citizen_alpha")
	var load_two: Dictionary = CitizenDresser.dress(two, PILOT_MODEL, "citizen_beta")

	var mat_one: BaseMaterial3D = _face_material(one)
	var mat_two: BaseMaterial3D = _face_material(two)
	_check("citizen one has a face material", mat_one != null)
	_check("citizen two has a face material", mat_two != null)
	if mat_one != null and mat_two != null:
		# THE OCTUPLETS LAW. Share this and the whole town rerolls together.
		_check("the two do NOT share one face material", mat_one != mat_two)
		_check("one's offset is the cell his face index names",
			mat_one.uv1_offset.is_equal_approx(
				CitizenDresser.face_offset(int(load_one.get("face", 0)))),
			"%s vs face %d" % [mat_one.uv1_offset, int(load_one.get("face", 0))])
		_check("the atlas stride is the 8x4 convention",
			CitizenDresser.face_offset(1).is_equal_approx(Vector3(0.125, 0.0, 0.0))
			and CitizenDresser.face_offset(8).is_equal_approx(Vector3(0.0, 0.25, 0.0)))
		_check("the face texture is PSX-filtered",
			mat_one.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		_check("head and body slid together", _all_face_offsets_match(one))

	_check("the loadout reports the offset it applied",
		(load_two.get("face_offset", Vector3.ZERO) as Vector3).is_equal_approx(
			CitizenDresser.face_offset(int(load_two.get("face", 0)))))

	one.free()
	two.free()


func _face_material(root: Node3D) -> BaseMaterial3D:
	for mi: MeshInstance3D in CitizenDresser.all_meshes(root):
		if String(mi.name) != "citizen_head":
			continue
		return mi.get_active_material(0) as BaseMaterial3D
	return null


## Face and skin are the same pixels, so every surface that rides the atlas must
## carry the same offset. A head that slid alone is RECON's black-head bug.
func _all_face_offsets_match(root: Node3D) -> bool:
	var seen: Array[Vector3] = []
	for mi: MeshInstance3D in CitizenDresser.all_meshes(root):
		var name: String = String(mi.name)
		if name != "citizen_head" and name != "citizen_body":
			continue
		var material := mi.get_active_material(0) as BaseMaterial3D
		if material == null:
			return false
		seen.append(material.uv1_offset)
	return seen.size() == 2 and seen[0].is_equal_approx(seen[1])


## ============================================================================
## 6b. THE BODY IS ALIVE - the no-clips fallback, measured
## ============================================================================
##
## The masters ship with no animation clips, so "it has a rig now" would
## otherwise mean "it stands in the export's A-pose forever". Everything below
## is a measurement off the posed skeleton, because a claim that a character
## looks alive is exactly the kind nobody can check by reading.

func _check_the_body_is_alive() -> void:
	var host := Node3D.new()
	add_child(host)
	var visual: CharacterVisual = CharacterVisual.for_character(PILOT_ID, {"archetype": "shopkeeper"})
	_check("the pilot's id builds a rig", visual.attach(host) and visual.is_rigged())
	var rigged := visual as RiggedVisual
	if rigged == null or rigged.skeleton == null:
		host.queue_free()
		return
	var skeleton: Skeleton3D = rigged.skeleton

	# The frame is measured off the rig. These masters export with the armature
	# still in Blender's axes, so an assumed Vector3.DOWN swings an arm BACKWARD.
	_check("up was measured, not assumed",
		absf(rigged._skel_up.dot(rigged._skel_fwd)) < 0.02,
		"up %s fwd %s" % [rigged._skel_up, rigged._skel_fwd])

	var arm: int = skeleton.find_bone("mixamorig_LeftArm")
	var hand: int = skeleton.find_bone("mixamorig_LeftHand")
	var rest_drop: float = (skeleton.get_bone_global_rest(hand).origin
		- skeleton.get_bone_global_rest(arm).origin).normalized().dot(rigged._skel_up)
	rigged.tick(0.016)
	var posed_drop: float = (skeleton.get_bone_global_pose(hand).origin
		- skeleton.get_bone_global_pose(arm).origin).normalized().dot(rigged._skel_up)
	_check("the A-pose arms come DOWN (rest %.2f -> posed %.2f)" % [rest_drop, posed_drop],
		posed_drop < rest_drop - 0.25)
	_check("and they are not folded past vertical", posed_drop > -1.001)

	# IDLE: a still character must not be a still IMAGE.
	var drift: Array[float] = []
	var bob: Array[float] = []
	for frame: int in 90:
		rigged.tick(0.033)
		drift.append(skeleton.get_bone_global_pose(hand).origin.dot(rigged._skel_fwd))
		bob.append(rigged.driver.position.y)
	var hand_drift: float = drift.max() - drift.min()
	var body_bob: float = bob.max() - bob.min()
	_check("idle: the body breathes (%.1f mm of hand drift)" % (hand_drift * 1000.0),
		hand_drift > 0.004)
	_check("idle: and it is a breath, not a spasm", hand_drift < 0.12)
	_check("idle: the body rises and falls (%.1f mm)" % (body_bob * 1000.0),
		body_bob > 0.002 and body_bob < 0.05)

	# WALK: a stride, and a knee that folds one way.
	visual.set_moving(true)
	for frame: int in 40:
		rigged.tick(0.033)
	var foot: int = skeleton.find_bone("mixamorig_LeftFoot")
	var shin: int = skeleton.find_bone("mixamorig_LeftLeg")
	var thigh: int = skeleton.find_bone("mixamorig_LeftUpLeg")
	var hip_fwd: float = skeleton.get_bone_global_pose(thigh).origin.dot(rigged._skel_fwd)
	var along: Array[float] = []
	var lift: Array[float] = []
	var knee: Array[float] = []
	for frame: int in 120:
		rigged.tick(0.033)
		along.append(skeleton.get_bone_global_pose(foot).origin.dot(rigged._skel_fwd) - hip_fwd)
		lift.append(skeleton.get_bone_global_pose(foot).origin.dot(rigged._skel_up))
		var upper: Vector3 = skeleton.get_bone_global_pose(shin).origin \
			- skeleton.get_bone_global_pose(thigh).origin
		var lower: Vector3 = skeleton.get_bone_global_pose(foot).origin \
			- skeleton.get_bone_global_pose(shin).origin
		knee.append(rad_to_deg(upper.angle_to(lower))
			* signf(upper.cross(lower).dot(rigged._skel_right)))

	var stride: float = along.max() - along.min()
	var foot_lift: float = lift.max() - lift.min()
	_check("walk: the feet take a stride (%.2f m)" % stride, stride > 0.35 and stride < 0.85,
		"a stride under 0.35 m is a shuffle, over 0.85 m is a parade march")
	_check("walk: the feet leave the ground (%.2f m)" % foot_lift,
		foot_lift > 0.05 and foot_lift < 0.30)
	# The knee is the one joint whose wrong sign is unmistakable to any player.
	_check("walk: the knee only ever folds BACKWARD (%.1f .. %.1f deg)" % [knee.min(), knee.max()],
		knee.max() <= 2.0 or knee.min() >= -2.0)
	_check("walk: and it actually folds (%.1f deg)" % (knee.max() - knee.min()),
		knee.max() - knee.min() > 8.0)

	# The body stands ON the ground rather than in it or above it.
	var toe: int = skeleton.find_bone("mixamorig_LeftToe_End")
	var head_bone: int = skeleton.find_bone("mixamorig_Head")
	var floor_y: float = skeleton.get_bone_global_rest(toe).origin.dot(rigged._skel_up)
	var head_y: float = skeleton.get_bone_global_rest(head_bone).origin.dot(rigged._skel_up)
	_check("the model's feet are at its origin (%.3f m)" % floor_y, absf(floor_y) < 0.05)
	_check("and it stands about 1.8 m tall (head bone at %.2f m)" % head_y,
		head_y > 1.5 and head_y < 1.75)

	# Facing is turned from where the export left it pointing, not from an
	# assumed forward - these masters do NOT face Godot's -Z.
	visual.set_facing(Vector3(0, 0, -1))
	var faced: Vector3 = (rigged._relative_basis(rigged.driver, skeleton) * rigged._skel_fwd)
	faced = rigged.driver.transform.basis * faced
	_check("set_facing(-Z) actually points the body at -Z",
		faced.normalized().dot(Vector3(0, 0, -1)) > 0.99, str(faced))

	# Death is not an option the rig can decline.
	visual.play_death()
	_check("play_death tips the body over", true)

	host.queue_free()


## ============================================================================
## 7. THE PILOT
## ============================================================================

func _check_pilot() -> void:
	GameManager.game_time = 13.0
	var packed: PackedScene = load(START_SCENE)
	if packed == null:
		_check("Elder Moor loads", false)
		return
	var town: Node = packed.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var pilot: Node = _find_npc(town, PILOT_ID)
	_check("%s is in Elder Moor" % PILOT_ID, pilot != null)
	if pilot == null:
		town.queue_free()
		return

	var visual: CharacterVisual = pilot.get("visual") as CharacterVisual
	_check("the pilot has a visual", visual != null)
	if visual == null:
		town.queue_free()
		return

	_check("the pilot is rigged, not a sprite", visual.is_rigged())
	_check("the pilot has no BillboardSprite", visual.billboard_sprite() == null)
	_check("the pilot built no 'Billboard' node", pilot.get_node_or_null("Billboard") == null)

	var rigged := visual as RiggedVisual
	_check("the pilot's rig node is named Rig", pilot.get_node_or_null("Rig") != null)
	_check("the pilot's model is %s" % PILOT_MODEL, rigged.model_id == PILOT_MODEL)
	_check("the pilot has a skeleton", rigged.skeleton != null)
	if rigged.skeleton != null:
		_check("41 mixamo bones", rigged.skeleton.get_bone_count() == 41)

	# DRESSED. The GLB ships every variant visible (REVIEW.md), so an undressed
	# citizen wears all thirteen pieces at once. This is the assertion that the
	# dresser ran at all.
	var worn: Array[String] = CitizenDresser.visible_meshes(rigged.rig)
	_check("exactly one vest", _count_prefix(worn, "garb_vest_") == 1, str(worn))
	_check("trousers on", worn.has("garb_pants"), str(worn))
	_check("no skirt on a man", not worn.has("garb_skirt"), str(worn))
	_check("exactly one sleeve style", _count_prefix(worn, "garb_sleeve_") == 1, str(worn))
	_check("exactly one hair", _count_prefix(worn, "hair_") == 1, str(worn))
	_check("the smith wears his apron", worn.has("garb_apron"), str(worn))
	_check("head and body are both drawn",
		worn.has("citizen_head") and worn.has("citizen_body"))

	var face_material: BaseMaterial3D = _face_material(rigged.rig)
	_check("the pilot's face material is his own", face_material != null)
	if face_material != null:
		_check("his face offset is applied",
			face_material.uv1_offset.is_equal_approx(
				CitizenDresser.face_offset(int(rigged.loadout.get("face", -1)))))
		var packed_again: PackedScene = load(MAN)
		var stock: Node3D = packed_again.instantiate() as Node3D
		_check("and it is NOT the material the GLB shipped",
			face_material != _face_material(stock))
		stock.free()

	# No clips have landed yet, so the fallback must be the thing running.
	_check("the pilot's clip library is empty (no Mixamo yet)",
		rigged.available_clips().is_empty(), str(rigged.available_clips()))

	# HE STANDS AT HIS STATION. 13:00, work, at the forge - the schedule reaches
	# a rigged body exactly as it reaches a sprite.
	var station: Dictionary = NPCScheduler.station_of(PILOT_ID, 13)
	_check("the pilot has a 13:00 station", not station.is_empty())
	if not station.is_empty():
		var want: Vector3 = NPCScheduler.world_to_local(NPCScheduler.station_world_pos(station))
		var got: Vector3 = (pilot as Node3D).global_position
		_check("he stands at it (%.2f m off)" % want.distance_to(got),
			want.distance_to(got) < 0.5, "want %s got %s" % [want, got])
	_check("and he is working at 13:00", NPCScheduler.action_for(PILOT_ID, 13) == &"work")
	_check("the rig knows it", visual.current_action() == &"work")
	_check("he is open for business", NPCScheduler.is_open_for_business(PILOT_ID, 13))

	# THE REST OF THE TOWN IS UNTOUCHED.
	var billboards: int = 0
	var rigs: int = 0
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if not "visual" in node or node.visual == null:
			continue
		if (node.visual as CharacterVisual).is_rigged():
			rigs += 1
		else:
			billboards += 1
	_check("the town still runs on billboards (%d of them)" % billboards, billboards > 20)
	_check("exactly one character is rigged (got %d)" % rigs, rigs == 1)

	town.queue_free()


func _find_npc(root: Node, npc_id: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.push_back(child)
		if "npc_id" in node and String(node.npc_id) == npc_id:
			return node
	return null


## ============================================================================
## VERDICT
## ============================================================================

func _check(label: String, passed: bool, detail: String = "") -> void:
	_checks += 1
	if passed:
		return
	_failures += 1
	if detail.is_empty():
		print("  - FAIL: %s" % label)
	else:
		print("  - FAIL: %s  [%s]" % [label, detail])


func _finish() -> void:
	print("check_character_visual: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
