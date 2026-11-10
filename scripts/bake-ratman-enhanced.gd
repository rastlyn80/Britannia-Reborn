# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/troll-ratman/"
const RatmanClips := {4: "RatmanOverheadAxe", 23: "RatmanAxeSomersault", 26: "RatmanQuietGuard",
	27: "RatmanAxeCheck", 28: "RatmanAxeAlert"}
const Lengths := {4: .80, 23: .90, 26: .80, 27: 1.0, 28: 1.1}
const AxeJoint := "ratman enhanced axe"
const RatmanJoints := ["bip01", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head", "jaw_lower",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 r thigh", "bip01 r calf",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", AxeJoint]

func run() -> void:
	var row := Registry.entry(42)
	var corners: Array = JSON.parse_string(FileAccess.get_file_as_string(Folder + "ratman-axe-corners.json"))
	assert(corners.size() == 198)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(Folder + "ratman-axe-atlas.png"))
	material.roughness = .76
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var socket := rig.find_bone("cp_grasp_rhand")
		assert(socket >= 0)
		var joint := rig.add_bone(AxeJoint)
		rig.set_bone_parent(joint, socket)
		rig.set_bone_rest(joint, Transform3D(Basis.IDENTITY, Vector3(0.0, .03, 0.0)))
		rig.reset_bone_pose(joint)
		add_axe(model, rig, joint, corners, material)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		var retained := player.get_animation_list()
		for group: int in RatmanClips:
			var motion := fit_grounded(player, rig, skins, Lengths[group], "bip01", RatmanJoints, pose_ratman.bind(group), .008)
			if group == 23:
				add_flip_height(motion, rig, player)
			assert(library.add_animation(RatmanClips[group], motion) == OK)
		verify_base_clips(player, source)
		for name: String in retained:
			add_carry(player, rig, name)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, Folder + "42-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("RATMAN ENHANCED ", treatment, ": five fitted motions, 66 archived axe triangles on the original socket")
	quit()

func add_axe(model: Node3D, rig: Skeleton3D, joint: int, corners: Array, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in corners:
		builder.set_normal(Vector3(row[3], row[4], row[5]).normalized())
		builder.set_uv(Vector2(row[6], row[7]))
		builder.set_bones(PackedInt32Array([0, 0, 0, 0]))
		builder.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		builder.add_vertex(Vector3(row[0], row[1], row[2]))
	var axe := MeshInstance3D.new()
	axe.name = "EnhancedRatmanAxe"
	axe.mesh = builder.commit()
	var skin := Skin.new()
	skin.add_bind(joint, Transform3D.IDENTITY)
	axe.skin = skin
	axe.skeleton = NodePath("..")
	rig.add_child(axe)
	axe.owner = model

func aim_ratman_axe(rig: Skeleton3D, shaft: Vector3) -> void:
	var joint := rig.find_bone(AxeJoint)
	var pose := rig.get_bone_global_pose(joint)
	var target := (rig.global_basis.inverse() * shaft).normalized()
	pose.basis = Basis(Quaternion(pose.basis.y.normalized(), target)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()

func add_carry(player: AnimationPlayer, rig: Skeleton3D, name: String) -> void:
	var animation := player.get_animation(name)
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	animation.track_set_path(track, NodePath("%s:%s" % [rig_path, AxeJoint]))
	player.play(name, 0.0)
	player.advance(0.0)
	var keys: Array[Quaternion] = []
	for index in 31:
		var phase := float(index) / 30.0
		player.seek(animation.length * phase, true)
		rig.reset_bone_pose(rig.find_bone(AxeJoint))
		var shaft := Vector3(.04, .09 if name == "Run" else .24, .91)
		if name in ["Death", "Death2"]:
			shaft = shaft.lerp(Vector3(-.92, .0, .15), smoothstep(.30, .79, phase))
		aim_ratman_axe(rig, shaft)
		keys.append(rig.get_bone_pose_rotation(rig.find_bone(AxeJoint)))
	player.stop()
	for index in keys.size():
		animation.rotation_track_insert_key(track, animation.length * index / (keys.size() - 1), keys[index])

func window(phase: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, phase) * (1.0 - smoothstep(c, d, phase))

func pose_ratman(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	var lean := 0.0
	var guard := 0.0
	var tuck := 0.0
	var swing := 0.0
	var shaft := Vector3(.04, .23, .92)
	match group:
		4:
			var lift := window(phase, .02, .24, .33, .53)
			swing = window(phase, .35, .54, .68, .98)
			guard = 1.0 * lift + .15 * swing
			lean = -.35 * lift + .52 * swing
			shaft = shaft.lerp(Vector3(-.10, 1.0, -.27), lift).lerp(Vector3(-.21, -.16, .92), swing)
		23:
			var turn := smoothstep(.13, .55, phase)
			tuck = window(phase, .09, .29, .46, .64)
			guard = smoothstep(.53, .78, phase)
			turn_world(rig, "bip01", Vector3.RIGHT, TAU * turn)
			shaft = (Basis(Vector3.RIGHT, TAU * turn) * Vector3(.13, .22 + .54 * guard, .84)).normalized()
			lean = .29 * tuck
		26:
			lean = .13 * pulse
			guard = .11 + .15 * pulse
		27:
			guard = window(phase, .04, .35, .72, 1.0)
			lean = -.18 * guard
			shaft = shaft.lerp(Vector3(.26, .92, .40), guard)
		28:
			guard = .72 * smoothstep(.04, .81, phase)
			lean = -.19 * guard
			shaft = shaft.lerp(Vector3(.10, .77, .53), guard)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .60 * lean)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .31 * lean)
	turn_world(rig, "bip01 spine2", Vector3.UP, .28 * swing - .16 * guard)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.21 * lean)
	turn_world(rig, "bip01 head", Vector3.UP, .18 * pulse)
	turn_world(rig, "jaw_lower", Vector3.RIGHT, .18 * guard)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.83 * guard - .52 * swing)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -.64 * guard + .33 * swing)
	turn_world(rig, "bip01 l upperarm", Vector3.BACK, .39 * guard)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -.63 * guard - .69 * tuck)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.71 * tuck)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.19 * tuck)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .47 * tuck + .19 * lean)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .52 * tuck)
	turn_world(rig, "bip01 tail2", Vector3.UP, .31 * pulse)
	turn_world(rig, "bip01 tail3", Vector3.UP, -.22 * pulse)
	aim_ratman_axe(rig, shaft)

func add_flip_height(clip: Animation, rig: Skeleton3D, player: AnimationPlayer) -> void:
	var root_bone := rig.find_bone("bip01")
	var parent := rig.get_bone_parent(root_bone)
	var inverse := (rig.global_basis * rig.get_bone_global_pose(parent).basis).inverse()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := clip.find_track(NodePath("%s:bip01" % rig_path), Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	for key in clip.track_get_key_count(track):
		var phase := clip.track_get_key_time(track, key) / clip.length
		var air := window(phase, .10, .30, .41, .61)
		var travel := window(phase, .12, .43, .60, .96)
		var start: Vector3 = clip.track_get_key_value(track, key)
		clip.track_set_key_value(track, key, start + inverse * Vector3(0.0, .57 * air, .27 * travel))
