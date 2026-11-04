extends SceneTree
## Independent slot-11 gestures based on the Classic directional frame references.

const FORMS := {
	1: ["ogres_ogre", "FaceWipe"],
	3: ["walking_dead_zombie", "ArmsRaise"],
	50: ["skeletons_skeleton", "Reach"],
	42: ["rat_race_ratman", "Hunch"],
}
const LENGTH := 1.0
const TIMES := [0.0, 0.10, 0.26, 0.43, 0.64, 0.80, 1.0]

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func rotate_joint(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone("bip01 " + name)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion(axis, angle)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func aim(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var from := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(from, (target - pose.origin).normalized())) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func ogre_wipe(rig: Skeleton3D, amount: float, sweep: float) -> void:
	var shoulder := rig.find_bone("bip01 r upperarm")
	var elbow := rig.find_bone("bip01 r forearm")
	var hand := rig.find_bone("bip01 r hand")
	var head := rig.find_bone("bip01 head")
	var a := rig.get_bone_global_pose(shoulder).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var mouth := rig.to_global(rig.get_bone_global_pose(head).origin)
	var goal := rig.to_local(mouth + Vector3(-0.26 + 0.09 * sweep, -0.13, 0.33))
	var target := c.lerp(goal, amount)
	var direction := (target - a).normalized()
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var outside := (rig.global_basis.inverse() * Vector3(-1.0, -0.25, 0.3)).normalized()
	var pole := (outside - direction * direction.dot(outside)).normalized()
	aim(rig, shoulder, elbow, a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along)))
	aim(rig, elbow, hand, target)

func animate(rig: Skeleton3D, body: int, phase: int, right: Vector3) -> void:
	match body:
		1:
			var amount: float = [0.0, 0.5, 0.95, 1.0, 0.88, 0.43, 0.0][phase]
			if amount > 0.0:
				ogre_wipe(rig, amount, [-0.5, -0.5, -0.35, 0.45, 0.7, 0.5, 0.0][phase])
		3:
			var lift: float = [0.0, 0.42, 1.0, 0.82, 0.32, 0.18, 0.0][phase]
			var stoop: float = [0.0, 0.0, 0.03, 0.13, 0.82, 1.0, 0.0][phase]
			rotate_joint(rig, "spine1", right, 0.42 * stoop)
			rotate_joint(rig, "spine2", right, 0.32 * stoop)
			rotate_joint(rig, "r upperarm", right, -2.32 * lift)
			rotate_joint(rig, "l upperarm", right, -2.05 * lift)
			rotate_joint(rig, "r forearm", right, -0.34 * lift)
			rotate_joint(rig, "l forearm", right, -0.47 * lift)
		50:
			var reach: float = [0.0, 0.2, 0.8, 1.0, 0.98, 0.55, 0.0][phase]
			rotate_joint(rig, "spine1", right, 0.21 * reach)
			rotate_joint(rig, "r upperarm", right, -1.55 * reach)
			rotate_joint(rig, "r forearm", right, -0.12 * reach)
			rotate_joint(rig, "l upperarm", right, -0.21 * reach)
		42:
			var hunch: float = [0.0, 0.42, 1.0, 0.91, 0.58, 0.23, 0.0][phase]
			var reach: float = [0.0, 0.64, 1.0, 0.57, 0.16, 0.0, 0.0][phase]
			rotate_joint(rig, "spine1", right, 0.25 * hunch)
			rotate_joint(rig, "spine2", right, 0.19 * hunch)
			rotate_joint(rig, "head", right, -0.14 * hunch)
			rotate_joint(rig, "r upperarm", right, -0.95 * reach)
			rotate_joint(rig, "r forearm", right, -0.45 * reach)
			rotate_joint(rig, "l upperarm", right, 0.07 * hunch)

func run() -> void:
	var bodies := [42] if "--ratman" in OS.get_cmdline_user_args() else [1, 3, 50]
	for body: int in bodies:
		for treatment in ["original", "rounded", "modern"]:
			bake(body, treatment)
	quit()

func bake(body: int, treatment: String) -> void:
	var form: Array = FORMS[body]
	var model := (load("res://local-art/creatures/%s-%s.gltf" % [form[0], treatment]) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	player.play("Idle")
	player.advance(0.0)
	var idle: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		idle.append(rig.get_bone_pose(bone))
	var motion := Animation.new()
	motion.length = LENGTH
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var rotation_tracks: Array[int] = []
	for bone in rig.get_bone_count():
		var path := NodePath("%s:%s" % [rig_path, rig.get_bone_name(bone)])
		var position := motion.add_track(Animation.TYPE_POSITION_3D)
		motion.track_set_path(position, path)
		motion.position_track_insert_key(position, 0.0, idle[bone].origin)
		var rotation := motion.add_track(Animation.TYPE_ROTATION_3D)
		motion.track_set_path(rotation, path)
		rotation_tracks.append(rotation)
		var scale := motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(scale, path)
		motion.scale_track_insert_key(scale, 0.0, idle[bone].basis.get_scale())
	var right := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	for phase in TIMES.size():
		for bone in rig.get_bone_count():
			var pose := idle[bone]
			rig.set_bone_pose_position(bone, pose.origin)
			rig.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
			rig.set_bone_pose_scale(bone, pose.basis.get_scale())
		rig.force_update_all_bone_transforms()
		animate(rig, body, phase, right)
		for bone in rig.get_bone_count():
			motion.rotation_track_insert_key(rotation_tracks[bone], TIMES[phase], rig.get_bone_pose_rotation(bone))
	player.stop()
	player.get_animation_library("").add_animation(form[1], motion)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	var suffix := "" if treatment == "modern" else "-" + treatment
	var output := "res://local-art/creatures/slot11-%d-trial%s.scn" % [body, suffix]
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	print("Slot 11 body ", body, " baked ", form[1], " on ", rig.get_bone_count(), " original joints")
	model.free()
