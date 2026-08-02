extends Node

func _ready() -> void:
	var host := Node3D.new()
	add_child(host)
	var v: CharacterVisual = CharacterVisual.for_character("grom_the_smith", {"archetype": "shopkeeper"})
	v.attach(host)
	var r := v as RiggedVisual
	var sk: Skeleton3D = r.skeleton
	print("up=", r._skel_up, " fwd=", r._skel_fwd, " right=", r._skel_right,
		" model_yaw_deg=", rad_to_deg(r._model_yaw))
	print("signs=", r._sign)

	var arm := sk.find_bone("mixamorig_LeftArm")
	var hand := sk.find_bone("mixamorig_LeftHand")
	var lf := sk.find_bone("mixamorig_LeftFoot")
	var lk := sk.find_bone("mixamorig_LeftLeg")
	var lu := sk.find_bone("mixamorig_LeftUpLeg")
	var rest_dir: float = (sk.get_bone_global_rest(hand).origin
		- sk.get_bone_global_rest(arm).origin).normalized().dot(r._skel_up)
	r.tick(0.016)
	var pose_dir: float = (sk.get_bone_global_pose(hand).origin
		- sk.get_bone_global_pose(arm).origin).normalized().dot(r._skel_up)
	print("arm dot(up): rest=%.3f posed=%.3f  (negative = hanging down)" % [rest_dir, pose_dir])

	var hx: Array[float] = []
	var bob: Array[float] = []
	for i in 90:
		r.tick(0.033)
		hx.append(sk.get_bone_global_pose(hand).origin.dot(r._skel_fwd))
		bob.append(r.driver.position.y)
	print("idle hand fwd drift = %.5f m, driver bob = %.5f m" % [hx.max() - hx.min(), bob.max() - bob.min()])

	v.set_moving(true)
	for i in 30:
		r.tick(0.033)
	var fwd: Array[float] = []
	var up: Array[float] = []
	var knee: Array[float] = []
	var hipf: float = sk.get_bone_global_pose(lu).origin.dot(r._skel_fwd)
	for i in 120:
		r.tick(0.033)
		fwd.append(sk.get_bone_global_pose(lf).origin.dot(r._skel_fwd) - hipf)
		up.append(sk.get_bone_global_pose(lf).origin.dot(r._skel_up))
		var thigh: Vector3 = sk.get_bone_global_pose(lk).origin - sk.get_bone_global_pose(lu).origin
		var shin: Vector3 = sk.get_bone_global_pose(lf).origin - sk.get_bone_global_pose(lk).origin
		knee.append(rad_to_deg(thigh.angle_to(shin)) * signf(thigh.cross(shin).dot(r._skel_right)))
	print("walk foot fwd range = %.3f .. %.3f m (stride %.3f)" % [fwd.min(), fwd.max(), fwd.max() - fwd.min()])
	print("walk foot up range  = %.3f .. %.3f" % [up.min(), up.max()])
	print("knee signed angle   = %.1f .. %.1f deg" % [knee.min(), knee.max()])
	print("rig aabb=", _aabb(r.rig))
	get_tree().quit()


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in CitizenDresser.all_meshes(n):
		if not mi.visible or mi.mesh == null:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out
