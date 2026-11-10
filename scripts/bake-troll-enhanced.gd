# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-orc-enhanced.gd"

const Geometry := preload("res://Presentation/SkinGeometry.gd")
const WeaponInput := "res://../work/creatures/late-client-inputs/troll-action-trial/"
const TrollOutput := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/troll-%s.scn"
const TrollActions := {4: "TrollOverheadChop", 23: "TrollRise", 26: "TrollWatch", 27: "TrollRaiseAxe", 28: "TrollAlert"}
const TrollLengths := {4: 1.0, 23: 1.0, 26: 1.2, 27: .9, 28: .7}
const WeaponBone := "troll enhanced axe"

func run() -> void:
	var row := Registry.entry(54)
	assert(row.kind == "trolls_troll_slot11_54")
	var materials := StandardMaterial3D.new()
	materials.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(WeaponInput + "weapon-atlas.png"))
	materials.roughness = .77
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WeaponInput + "weapon-sources.json"))
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		bake_troll_enhanced(source, treatment, shapes.Axe, materials)
	quit()

func bake_troll_enhanced(source: String, treatment: String, axe: Array, material: Material) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	var weapon := rig.add_bone(WeaponBone)
	rig.set_bone_parent(weapon, grip)
	rig.set_bone_rest(weapon, Transform3D(Basis.IDENTITY, Vector3(0.0, .10, 0.0)))
	rig.reset_bone_pose(weapon)
	var prop := add_axe(rig, model, weapon, axe, material)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	var bones := Joints.filter(func(bone: String): return rig.find_bone(bone) >= 0)
	bones.append(WeaponBone)
	var existing := player.get_animation_list()
	for group: int in TrollActions:
		var clip := fit_grounded(player, rig, skins, TrollLengths[group], "bip01", bones,
			pose_troll_enhanced.bind(group, prop), .010)
		assert(library.add_animation(TrollActions[group], clip) == OK)
	Exact.check_earlier_keys(player, source)
	for name: String in existing:
		bake_axe_carry(player, rig, prop, name)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, TrollOutput % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	print("TROLL ENHANCED ", treatment, ": ", TrollActions.size(), " fitted motions and the Third Dawn axe")
	model.free()

func add_axe(rig: Skeleton3D, model: Node, weapon: int, axe: Array, material: Material) -> MeshInstance3D:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in axe:
		var height := float(row[1])
		var blade := smoothstep(.54, .95, height)
		var point := Vector3(row[0], height + .17 * blade, float(row[2]) * (1.0 + .20 * blade))
		builder.set_normal(Vector3(row[3], row[4], row[5]).normalized())
		builder.set_uv(Vector2(row[6], row[7]))
		builder.set_bones(PackedInt32Array([0, 0, 0, 0]))
		builder.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		builder.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name = "EnhancedAxe"
	mesh.mesh = builder.commit()
	var skin := Skin.new()
	skin.add_bind(weapon, Transform3D.IDENTITY)
	mesh.skin = skin
	mesh.skeleton = NodePath("..")
	rig.add_child(mesh)
	mesh.owner = model
	return mesh

func bake_axe_carry(player: AnimationPlayer, rig: Skeleton3D, prop: MeshInstance3D, name: String) -> void:
	var clip := player.get_animation(name)
	var joint := rig.find_bone(WeaponBone)
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	clip.track_set_path(track, NodePath("%s:%s" % [rig_path, WeaponBone]))
	if name not in ["Death", "Death2", "LieDown"]:
		clip.rotation_track_insert_key(track, 0.0, Quaternion.IDENTITY)
		return

	# Roll the blade onto its side as the wrist approaches the ground.
	# Keep the hand socket and the original character motion untouched.
	var rotations: Array[Quaternion] = []
	var count := maxi(2, ceili(clip.length * 60.0) + 1)
	player.play(name, 0.0)
	player.advance(0.0)
	for frame in count:
		player.seek(clip.length * float(frame) / (count - 1), true)
		rig.set_bone_pose_rotation(joint, Quaternion.IDENTITY)
		rig.force_update_all_bone_transforms()
		var gap := Geometry.deformed_bounds(prop, rig).position.y
		var weight := 1.0 - smoothstep(.025, .30, gap)
		var pose := rig.global_transform * rig.get_bone_global_pose(joint)
		var outward := pose.origin - joint_world(rig, "bip01 pelvis")
		outward.y = 0.0
		var shaft := (Vector3.RIGHT if outward.length_squared() < .01 else outward).normalized()
		var rested := Basis(Vector3.UP, shaft, Vector3.UP.cross(shaft))
		pose.basis = pose.basis.orthonormalized().slerp(rested, weight)
		rig.set_bone_global_pose(joint, rig.global_transform.affine_inverse() * pose)
		rotations.append(rig.get_bone_pose_rotation(joint))
	player.stop()
	for frame in count:
		clip.rotation_track_insert_key(track, clip.length * float(frame) / (count - 1), rotations[frame])

func pose_troll_enhanced(rig: Skeleton3D, phase: float, group: int, prop: MeshInstance3D) -> void:
	var pulse := sin(PI * phase)
	var depth := .06
	var lean := .08
	var turn := .0
	var right := Vector3(-.57, -.41, .21)
	var left := Vector3(.55, -.43, .17)
	var shaft := Vector3(-.24, -.72, .54)
	match group:
		4:
			var windup := smoothstep(0.0, .25, phase) * (1.0 - smoothstep(.28, .46, phase))
			var hit := smoothstep(.29, .51, phase) * (1.0 - smoothstep(.61, .98, phase))
			depth += .63 * hit
			lean += .74 * hit - .22 * windup
			turn = -.43 * windup + .48 * hit
			right += Vector3(-.13, 1.78, -.38) * windup + Vector3(.24, -.19, .68) * hit
			left += Vector3(.18, .72, .30) * windup + Vector3(.17, .03, .52) * hit
			shaft = shaft.lerp(Vector3(-.21, .93, -.47), windup).lerp(Vector3(.42, -.34, .75), hit)
		23:
			var rise := smoothstep(.10, .79, phase)
			depth += .64 * (1.0 - rise)
			lean += .88 * (1.0 - rise)
			right += Vector3(.14, -.15, .52) * (1.0 - rise)
			left += Vector3(-.12, -.10, .63) * (1.0 - rise)
			shaft = Vector3(-.10, -.18, .96).lerp(shaft, rise)
		26:
			depth += .055 * pulse
			lean += .12 * pulse
			turn = .20 * pulse
			right += Vector3(.05, .10, .18) * pulse
			left += Vector3(-.08, .04, .12) * pulse
		27:
			var lift := smoothstep(.12, .61, phase) * (1.0 - .48 * smoothstep(.71, 1.0, phase))
			depth += .31 * lift
			lean += .46 * lift
			turn = -.18 * lift
			right += Vector3(-.26, .98, .14) * lift
			left += Vector3(.33, .42, .34) * lift
			shaft = shaft.lerp(Vector3(-.51, .61, .32), lift)
		28:
			var lift := smoothstep(.05, .90, phase)
			depth += .22 * lift
			lean += .31 * lift
			turn = -.16 * lift
			right += Vector3(-.18, .91, .28) * lift
			left += Vector3(.16, .33, .35) * lift
			shaft = shaft.lerp(Vector3(-.28, .36, .81), lift)
	var hips := rig.find_bone("bip01")
	var root_pose := rig.get_bone_global_pose(hips)
	root_pose.origin += rig.global_basis.inverse() * Vector3(0.0, -depth, -.21 * depth)
	rig.set_bone_global_pose(hips, root_pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, lean * .59)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, lean * .25)
	turn_world(rig, "bip01 spine2", Vector3.UP, turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.18 * lean)
	for side: String in ["l", "r"]:
		var side_sign := 1.0 if side == "l" else -1.0
		var foot := rig.find_bone("bip01 %s foot" % side)
		var support := rig.get_bone_global_pose(foot)
		var position := Vector3(side_sign * .47, .20, .24 if side == "l" else -.11)
		support.origin = rig.to_local(position)
		fit_foot(rig, side, support)
	var pelvis := joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "r", pelvis + right)
	fit_arm(rig, "l", pelvis + left)
	var joint := rig.find_bone(WeaponBone)
	var local := rig.get_bone_global_pose(joint)
	var direction := (rig.global_basis.inverse() * shaft).normalized()
	local.basis = Basis(Quaternion(local.basis.y.normalized(), direction)) * local.basis
	rig.set_bone_global_pose(joint, local)
	rig.force_update_all_bone_transforms()
	var gap := Geometry.deformed_bounds(prop, rig).position.y
	if gap < .045:
		var flat := (rig.global_basis.inverse() * Vector3(shaft.x, .18, shaft.z)).normalized()
		local.basis = Basis(Quaternion(local.basis.y.normalized(), flat)) * local.basis
		rig.set_bone_global_pose(joint, local)
		rig.force_update_all_bone_transforms()
