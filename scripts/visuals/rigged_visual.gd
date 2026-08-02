## rigged_visual.gd - a PSX citizen GLB standing in for a billboard.
##
## THE HONEST PART, said first. The four citizen masters ship with NO animation
## clips (docs/design/citizen_review/REVIEW.md - the exports carry meshes, a rig
## and nothing else). A rig with no clips renders in its rest pose, and the rest
## pose is the soldier's A-pose it was cloned from: arms out at forty-five
## degrees, dead still. That is unacceptable in a town, so until Mixamo clips
## land this class poses the skeleton in code:
##
##   1. A REST CORRECTION that brings the arms down to the sides. Static, solved
##      once at attach, and the single largest difference between "a person" and
##      "a mannequin on a shop floor".
##   2. AN IDLE: a breath on the chest, a slow drift of the head, and a
##      millimetric rise and fall of the whole body.
##   3. A WALK: thigh swing, a knee that folds the right way, counter-swinging
##      arms and a two-per-stride bob. Legs rather than a slide, because a
##      sliding body reads as a bug and a rough walk reads as a cheap walk - and
##      because the sign of every rotation here is MEASURED off the rig at
##      attach time rather than guessed (see [method _solve_axis_sign]).
##
## None of it is a substitute for authored animation. It is a body that is alive
## in the frame instead of a T-pose, and it retires itself the moment real clips
## exist: [constant CLIP_DIR] is checked first, and any action a loaded
## AnimationLibrary can play is played instead of posed.
class_name RiggedVisual
extends CharacterVisual

## Where the shared animation library lands. One skeleton, one library - the
## masters share two rigs (PSXRig for adults, PSXRig_child for children), so a
## clip authored once serves every citizen on that rig.
const CLIP_DIR: String = "res://assets/models/citizens/clips/"

## Action -> the clip name looked for in the library. Absent = posed in code.
const CLIP_FOR_ACTION: Dictionary = {
	&"idle": "idle",
	&"work": "work",
	&"eat": "eat",
	&"socialise": "talk",
	&"sleep": "sleep",
	&"travel": "walk",
}
const CLIP_WALK: String = "walk"
const CLIP_ATTACK: String = "attack"
const CLIP_HURT: String = "hurt"
const CLIP_DEATH: String = "death"

const BONE_PREFIX: String = "mixamorig_"

## The rest correction, in degrees about the world axis named. Solved against
## the rig, not typed in: [member ARM_REST_DROP] is how far past straight-down
## the upper arm is allowed to travel, and the direction is measured.
const ARM_REST_DROP_DEG: float = 62.0
const FOREARM_REST_BEND_DEG: float = 8.0

const BREATH_RATE: float = 0.55
const BREATH_DEG: float = 1.3
const BREATH_RISE_M: float = 0.007
const HEAD_DRIFT_DEG: float = 3.2
const TALK_NOD_DEG: float = 2.6
const TALK_RATE: float = 2.4

## Tuned by measurement, not by eye: at these numbers the foot travels ~0.62 m
## per stride and lifts ~0.17 m, which is a walk. The first pass ran 24/34 and
## measured 0.94 m and 0.26 m - a parade march on a villager.
const WALK_RATE: float = 1.5
const STRIDE_DEG: float = 17.0
const KNEE_DEG: float = 24.0
const ARM_SWING_DEG: float = 12.0
const WALK_BOB_M: float = 0.022
## How fast the body eases between standing and walking, in blend-units/second.
const GAIT_BLEND: float = 6.0
const HURT_RECOIL_DEG: float = 11.0
const HURT_RECOVER: float = 0.28

var model_id: String = ""
var model_path: String = ""
var dress_seed_id: String = ""
var archetype: String = ""

## What the dresser actually put on this citizen. Read by the gates.
var loadout: Dictionary = {}

var driver: CitizenRigDriver = null
var rig: Node3D = null
var skeleton: Skeleton3D = null
var player: AnimationPlayer = null

## bone key -> index, for the bones this class poses. A bone the rig does not
## carry is simply absent and every use of it is skipped.
var _bones: Dictionary = {}
## bone key -> Quaternion, the static rest correction in bone-local space.
var _rest_fix: Dictionary = {}
## bone key -> Basis, rest global basis with the rest correction folded in, so
## a "rotate about world up" reads correctly on a bone that has been moved.
var _frame: Dictionary = {}
## bone key -> +1.0 / -1.0, the measured sign that makes a positive angle move
## the limb the way this class means it to.
var _sign: Dictionary = {}

var _time: float = 0.0
var _gait: float = 0.0
var _dead: bool = false
## 1.0 the instant a blow lands, decaying to 0 - the recoil the rig shows in
## place of the sprite's red flash.
var _hurt: float = 0.0
var _own_materials: Array[BaseMaterial3D] = []
var _own_albedo: Array[Color] = []
var _library_actions: Dictionary = {}

## THE BODY'S OWN FRAME, measured off the rig at attach and never assumed.
##
## These masters export with the armature still in Blender's frame: inside
## Skeleton3D, up is -Z and the body faces +Y, and the conversion to Godot's
## Y-up lives on the PSXRig node above it. Writing Vector3.DOWN into a bone
## rotation here therefore swings an arm BACKWARD, not down - which is exactly
## the class of mistake that costs a day when a rig's axes are guessed at
## instead of measured.
var _skel_up: Vector3 = Vector3.UP
var _skel_fwd: Vector3 = Vector3.FORWARD
var _skel_right: Vector3 = Vector3.RIGHT
## The yaw the model already carries, so set_facing turns it to face a direction
## rather than to face a direction plus whatever the exporter left behind.
var _model_yaw: float = 0.0

const _SPINE: String = "Spine1"
const _HEAD: String = "Head"
const _ARM_L: String = "LeftArm"
const _ARM_R: String = "RightArm"
const _FOREARM_L: String = "LeftForeArm"
const _FOREARM_R: String = "RightForeArm"
const _THIGH_L: String = "LeftUpLeg"
const _THIGH_R: String = "RightUpLeg"
const _SHIN_L: String = "LeftLeg"
const _SHIN_R: String = "RightLeg"
const _HIPS: String = "Hips"
const _FOOT_L: String = "LeftFoot"
const _TOE_L: String = "LeftToe_End"


## ============================================================================
## BUILD
## ============================================================================

func attach(p_host: Node3D) -> bool:
	host = p_host
	if model_path.is_empty():
		return false
	var packed: PackedScene = load(model_path) as PackedScene
	if packed == null:
		push_warning("[RiggedVisual] %s did not load" % model_path)
		return false

	driver = CitizenRigDriver.new()
	driver.name = "Rig"
	driver.visual = self
	host.add_child(driver)

	rig = packed.instantiate() as Node3D
	if rig == null:
		driver.queue_free()
		driver = null
		return false
	driver.add_child(rig)

	skeleton = _find_skeleton(rig)
	if skeleton == null:
		push_warning("[RiggedVisual] %s has no Skeleton3D - it will stand where it was exported"
			% model_id)

	loadout = CitizenDresser.dress(rig, model_id, _seed_id(), archetype, config.get("dress", {}))

	_load_clip_library()
	if skeleton != null:
		_index_bones()
		_solve_body_frame()
		_solve_rest_correction()
		_solve_walk_signs()
	return true


## Which way is up, forward and right INSIDE this skeleton. Both are read off
## bones whose meaning is not in doubt: the spine runs up and the toes point
## forward.
func _solve_body_frame() -> void:
	var hips: int = int(_bones.get(_HIPS, -1))
	var head: int = int(_bones.get(_HEAD, -1))
	if hips < 0 or head < 0:
		return
	var up: Vector3 = skeleton.get_bone_global_rest(head).origin \
		- skeleton.get_bone_global_rest(hips).origin
	if up.length_squared() < 0.000001:
		return
	_skel_up = up.normalized()

	var foot: int = int(_bones.get(_FOOT_L, -1))
	var toe: int = int(_bones.get(_TOE_L, -1))
	if foot >= 0 and toe >= 0:
		var forward: Vector3 = skeleton.get_bone_global_rest(toe).origin \
			- skeleton.get_bone_global_rest(foot).origin
		forward -= _skel_up * forward.dot(_skel_up)
		if forward.length_squared() > 0.000001:
			_skel_fwd = forward.normalized()
	_skel_right = _skel_fwd.cross(_skel_up).normalized()

	# The yaw baked into the export, measured through the node chain rather than
	# through global_transform, so this holds before the host enters the tree.
	var to_driver: Basis = _relative_basis(driver, skeleton)
	var facing: Vector3 = to_driver * _skel_fwd
	if absf(facing.x) > 0.000001 or absf(facing.z) > 0.000001:
		_model_yaw = atan2(facing.x, facing.z)


## The basis that carries a vector from [param to]'s space up into [param from]'s,
## multiplied out of the local transforms so no node need be inside the tree.
func _relative_basis(from: Node3D, to: Node3D) -> Basis:
	var out := Basis()
	var node: Node3D = to
	while node != null and node != from:
		out = node.transform.basis * out
		node = node.get_parent() as Node3D
	return out


func _seed_id() -> String:
	if not dress_seed_id.is_empty():
		return dress_seed_id
	if host != null:
		return String(host.name)
	return model_id


func _find_skeleton(node: Node) -> Skeleton3D:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Skeleton3D:
			return current as Skeleton3D
		for child: Node in current.get_children():
			stack.push_back(child)
	return null


## The shared library, if it has landed. Named for the rig root - PSXRig.res
## serves both adults, PSXRig_child.res both children - because one skeleton is
## one library and that is the whole reason the masters share armatures.
func _load_clip_library() -> void:
	if rig == null:
		return
	var rig_name: String = ""
	for child: Node in rig.get_children():
		if child is Node3D and String(child.name).begins_with("PSXRig"):
			rig_name = String(child.name)
			break
	if rig_name.is_empty():
		return

	var library: AnimationLibrary = null
	for extension: String in [".res", ".tres"]:
		var path: String = CLIP_DIR + rig_name + extension
		if ResourceLoader.exists(path):
			library = load(path) as AnimationLibrary
			if library != null:
				break
	if library == null:
		return

	player = AnimationPlayer.new()
	player.name = "Clips"
	driver.add_child(player)
	player.add_animation_library("citizen", library)
	for name: StringName in library.get_animation_list():
		_library_actions[String(name)] = true


func _index_bones() -> void:
	for key: String in [_HIPS, _SPINE, _HEAD, _ARM_L, _ARM_R, _FOREARM_L, _FOREARM_R,
			_THIGH_L, _THIGH_R, _SHIN_L, _SHIN_R, _FOOT_L, _TOE_L]:
		var index: int = skeleton.find_bone(BONE_PREFIX + key)
		if index < 0:
			index = skeleton.find_bone("mixamorig:" + key)
		if index >= 0:
			_bones[key] = index


## ============================================================================
## THE REST CORRECTION - measured, never typed
## ============================================================================

## Bring the upper arms down from the export's A-pose. The rotation is solved
## from where the bone actually points to where it should point, so it holds on
## any rig whose bone axes differ - which is exactly the class of mistake that
## costs a day when it is guessed at instead.
func _solve_rest_correction() -> void:
	_drop_arm(_ARM_L, _FOREARM_L)
	_drop_arm(_ARM_R, _FOREARM_R)

	# The frames every per-frame rotation is expressed in. Computed AFTER the
	# rest correction so "rotate about the body's right" still means that on an
	# arm which has just been moved sixty degrees.
	for key: String in _bones.keys():
		var basis: Basis = skeleton.get_bone_global_rest(int(_bones[key])).basis
		if _rest_fix.has(key):
			basis = basis * Basis(_rest_fix[key] as Quaternion)
		_frame[key] = basis


func _drop_arm(arm_key: String, forearm_key: String) -> void:
	if not _bones.has(arm_key) or not _bones.has(forearm_key):
		return
	var arm: int = int(_bones[arm_key])
	var forearm: int = int(_bones[forearm_key])

	var arm_rest: Transform3D = skeleton.get_bone_global_rest(arm)
	var elbow: Vector3 = skeleton.get_bone_global_rest(forearm).origin
	var along: Vector3 = elbow - arm_rest.origin
	if along.length_squared() < 0.0000001:
		return
	along = along.normalized()

	# Straight down, then eased back toward the rest direction so the arms hang
	# with a little air under the armpit instead of clamped to the ribs.
	var target: Vector3 = along.lerp(-_skel_up, clampf(ARM_REST_DROP_DEG / 90.0, 0.0, 1.0))
	if target.length_squared() < 0.0000001:
		return
	target = target.normalized()

	var inverse: Basis = arm_rest.basis.inverse()
	var from: Vector3 = (inverse * along).normalized()
	var to: Vector3 = (inverse * target).normalized()
	_rest_fix[arm_key] = Quaternion(from, to)

	# A dead-straight arm is the other half of the mannequin read. A few degrees
	# of elbow, folded the way the knee solver folds a knee.
	var forearm_rest: Basis = skeleton.get_bone_global_rest(forearm).basis
	var axis: Vector3 = (forearm_rest.inverse() * _skel_right).normalized()
	var direction: float = _solve_axis_sign(forearm, axis, -_skel_fwd)
	_rest_fix[forearm_key] = Quaternion(axis, deg_to_rad(FOREARM_REST_BEND_DEG) * direction)


## Which way does a positive rotation about [param axis] move this bone's tip?
##
## Poses the bone by a test angle, reads the resulting global pose, and returns
## +1 or -1 so that a positive angle moves the tip toward [param want]. This is
## the "measure, do not guess" rule applied to a rig whose bone axes nobody in
## this repository has ever looked at.
func _solve_axis_sign(bone: int, axis: Vector3, want: Vector3) -> float:
	var rest: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	var before: Vector3 = skeleton.get_bone_global_pose(bone).origin
	var reference: Vector3 = _tip_of(bone, before)

	skeleton.set_bone_pose_rotation(bone, rest * Quaternion(axis, deg_to_rad(12.0)))
	var moved: Vector3 = _tip_of(bone, skeleton.get_bone_global_pose(bone).origin)
	skeleton.set_bone_pose_rotation(bone, rest)

	var delta: Vector3 = moved - reference
	if delta.length_squared() < 0.0000001:
		return 1.0
	return 1.0 if delta.normalized().dot(want.normalized()) >= 0.0 else -1.0


## A bone's tip: its first child's origin, or a point along its own axis when it
## is a leaf. Rotating a bone does not move its own origin, so the origin alone
## can never answer which way it swung.
func _tip_of(bone: int, fallback: Vector3) -> Vector3:
	var children: PackedInt32Array = skeleton.get_bone_children(bone)
	if children.size() > 0:
		return skeleton.get_bone_global_pose(children[0]).origin
	return fallback + skeleton.get_bone_global_pose(bone).basis.y * 0.1


func _solve_walk_signs() -> void:
	# A positive thigh angle must swing the leg FORWARD (-Z in Godot), and a
	# positive knee angle must fold the shin BACKWARD (+Z).
	_measure(_THIGH_L, _skel_right, _skel_fwd)
	_measure(_THIGH_R, _skel_right, _skel_fwd)
	_measure(_SHIN_L, _skel_right, -_skel_fwd)
	_measure(_SHIN_R, _skel_right, -_skel_fwd)
	_measure(_ARM_L, _skel_right, _skel_fwd)
	_measure(_ARM_R, _skel_right, _skel_fwd)
	_measure(_SPINE, _skel_right, -_skel_fwd)
	_measure(_HEAD, _skel_up, _skel_right)


func _measure(key: String, body_axis: Vector3, want: Vector3) -> void:
	if not _bones.has(key) or not _frame.has(key):
		return
	var bone: int = int(_bones[key])
	var axis: Vector3 = ((_frame[key] as Basis).inverse() * body_axis).normalized()
	_sign[key] = _solve_axis_sign(bone, axis, want)


## ============================================================================
## THE TICK
## ============================================================================

func tick(delta: float) -> void:
	if _dead or skeleton == null:
		return
	_time += delta
	_gait = move_toward(_gait, 1.0 if _moving else 0.0, GAIT_BLEND * delta)

	if _hurt > 0.0:
		_hurt = maxf(0.0, _hurt - delta / HURT_RECOVER)

	# A real clip beats anything below it. The moment the library lands, this
	# whole file becomes a fallback nobody reaches.
	if player != null and player.is_playing():
		return

	# Every bone this class owns goes back to rest-plus-correction first, so the
	# idle and the walk can both be written as additions and neither can inherit
	# last frame's pose.
	_reset_pose()
	_pose_idle()
	if _gait > 0.001:
		_pose_walk()


func _reset_pose() -> void:
	for key: String in _bones.keys():
		var bone: int = int(_bones[key])
		var rest: Quaternion = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var fix: Quaternion = _rest_fix.get(key, Quaternion.IDENTITY)
		skeleton.set_bone_pose_rotation(bone, rest * fix)


func _pose_idle() -> void:
	var breath: float = sin(_time * TAU * BREATH_RATE)
	var still: float = 1.0 - _gait

	_rotate(_SPINE, _skel_right, deg_to_rad(BREATH_DEG) * breath * still
		- deg_to_rad(HURT_RECOIL_DEG) * _hurt)

	var drift: float = sin(_time * 0.31) * HEAD_DRIFT_DEG
	if _talking:
		drift += sin(_time * TAU * TALK_RATE) * TALK_NOD_DEG
	_rotate(_HEAD, _skel_up, deg_to_rad(drift) * still)

	if driver != null:
		driver.position.y = BREATH_RISE_M * breath * still - WALK_BOB_M * absf(
			cos(_time * TAU * WALK_RATE)) * _gait

	# Arms hang from the rest correction; the idle only adds the breath's echo.
	_rotate(_ARM_L, _skel_right, deg_to_rad(0.8) * breath * still)
	_rotate(_ARM_R, _skel_right, deg_to_rad(-0.8) * breath * still)


func _pose_walk() -> void:
	var phase: float = _time * TAU * WALK_RATE
	var swing: float = sin(phase)

	_rotate(_THIGH_L, _skel_right, deg_to_rad(STRIDE_DEG) * swing * _gait)
	_rotate(_THIGH_R, _skel_right, deg_to_rad(-STRIDE_DEG) * swing * _gait)

	# A knee only bends one way, so the fold is a half-wave, never a sine.
	_rotate(_SHIN_L, _skel_right, deg_to_rad(KNEE_DEG) * maxf(0.0, -swing) * _gait)
	_rotate(_SHIN_R, _skel_right, deg_to_rad(KNEE_DEG) * maxf(0.0, swing) * _gait)

	_rotate(_ARM_L, _skel_right, deg_to_rad(-ARM_SWING_DEG) * swing * _gait)
	_rotate(_ARM_R, _skel_right, deg_to_rad(ARM_SWING_DEG) * swing * _gait)


## Add [param angle] radians about an axis of the BODY'S frame (see
## [member _skel_right]) to whatever this frame has already written to the bone.
## Always additive - [method _reset_pose] is what clears the slate, once, at the
## top of the tick.
func _rotate(key: String, body_axis: Vector3, angle: float) -> void:
	if not _bones.has(key) or not _frame.has(key):
		return
	if absf(angle) < 0.000001:
		return
	var bone: int = int(_bones[key])
	var axis: Vector3 = ((_frame[key] as Basis).inverse() * body_axis).normalized()
	var direction: float = float(_sign.get(key, 1.0))
	var current: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, current * Quaternion(axis, angle * direction))


## ============================================================================
## THE INTERFACE
## ============================================================================

func set_action(action: StringName) -> void:
	super.set_action(action)
	_play_clip(String(CLIP_FOR_ACTION.get(action, "")))


func set_moving(moving: bool) -> void:
	super.set_moving(moving)
	if moving:
		_play_clip(CLIP_WALK)
	else:
		_play_clip(String(CLIP_FOR_ACTION.get(_action, "")))


func set_facing(dir: Vector3) -> void:
	super.set_facing(dir)
	if driver == null:
		return
	var flat := Vector3(_facing.x, 0.0, _facing.z)
	if flat.length_squared() < 0.0001:
		return
	# Turn the model from wherever the export left it pointing, not from an
	# assumed forward - _model_yaw is measured off the toes at attach.
	driver.rotation.y = atan2(flat.x, flat.z) - _model_yaw


func play_attack() -> void:
	_play_clip(CLIP_ATTACK)


func play_hurt() -> void:
	if _play_clip(CLIP_HURT):
		return
	# No clip: a recoil the eye can see, on the one bone that carries the torso.
	_hurt = 1.0


func play_death() -> void:
	if _play_clip(CLIP_DEATH):
		_dead = true
		return
	_dead = true
	if driver == null:
		return
	# A corpse that stands up is worse than no death animation at all.
	var tween: Tween = driver.create_tween()
	tween.tween_property(driver, "rotation:x", -PI * 0.5, 0.45)
	tween.parallel().tween_property(driver, "position:y", 0.12, 0.45)


func set_talking(talking: bool) -> void:
	super.set_talking(talking)


func set_tint(colour: Color) -> void:
	super.set_tint(colour)
	if rig == null:
		return
	if _own_materials.is_empty():
		_claim_materials()
	for index: int in _own_materials.size():
		_own_materials[index].albedo_color = _own_albedo[index] * colour


## Take a private copy of every material on this body. Only done when something
## actually asks for a tint - the dresser deliberately SHARES the garb and hair
## palettes, and promoting them for every citizen would undo that.
func _claim_materials() -> void:
	for mi: MeshInstance3D in CitizenDresser.all_meshes(rig):
		if mi.mesh == null:
			continue
		for surface: int in mi.mesh.get_surface_count():
			var material: Material = mi.get_active_material(surface)
			var base := material as BaseMaterial3D
			if base == null:
				continue
			var mine := base.duplicate() as BaseMaterial3D
			mi.set_surface_override_material(surface, mine)
			_own_materials.append(mine)
			_own_albedo.append(mine.albedo_color)


func node() -> Node3D:
	return driver


func is_rigged() -> bool:
	return true


## True when the library could actually play this, so every caller can fall back
## honestly instead of assuming the clip took.
func _play_clip(clip: String) -> bool:
	if player == null or clip.is_empty():
		return false
	if not _library_actions.has(clip):
		return false
	player.play("citizen/" + clip)
	return true


## Which clips this citizen's library can play. Empty until Mixamo lands.
func available_clips() -> Array[String]:
	var out: Array[String] = []
	for name: String in _library_actions.keys():
		out.append(name)
	out.sort()
	return out
