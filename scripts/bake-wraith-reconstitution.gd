# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-skeleton-enhanced.gd"

const Undead := preload("res://../scripts/bake-zombie-wraith-enhanced.gd")
const Reconstitution := "WraithReconstitute"
const GatherDuration := 1.38
const PartNames := ["Veil", "Skull", "LeftArm", "RightArm", "UpperRibs", "LowerBones"]
const Samples := [Vector3(.333333, .333333, .333334), Vector3(.64, .18, .18),
	Vector3(.18, .64, .18), Vector3(.18, .18, .64)]
var atlas: Image

func run() -> void:
	var row := Registry.entry(26)
	atlas = Image.new()
	var source_png := FileAccess.get_file_as_bytes("res://local-art/creatures/" + str(row.source_alpha_texture))
	assert(atlas.load_png_from_buffer(source_png) == OK and not atlas.is_empty())
	for treatment: String in row.assets:
		var source := Undead.UndeadStage + "26-%s.scn" % treatment
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
		var clip := fit_grounded(player, rig, skins, GatherDuration, Undead.RootJoint,
			Undead.UndeadTorso + Undead.WraithCloth, pose_reconstitution, .004)
		lift_reconstitution(clip, rig)
		assert(library.add_animation(Reconstitution, clip) == OK)
		player.play(Reconstitution, 0.0)
		player.advance(0.0)
		player.seek(JoinPhase * GatherDuration, true)
		rig.force_update_all_bone_transforms()
		build_wraith_parts(model, body, rig, player, clip)
		verify_base_clips(player, source)
		player.stop()
		body.visible = true
		model.get_node("AssemblyPieces").visible = false
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var output := Undead.UndeadStage + "26-reconstitute-%s.scn" % treatment
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
	quit()

func pose_reconstitution(rig: Skeleton3D, phase: float) -> void:
	var bow := 1.0 - smoothstep(.59, .97, phase)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .40 * bow)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .28 * bow)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.47 * bow)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, .68 * sign_x * bow)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.43 * bow)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, -.42 * bow)
	turn_world(rig, "bip01 ponytail2", Vector3.RIGHT, -.42 * bow)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.37 * bow)

func lift_reconstitution(clip: Animation, rig: Skeleton3D) -> void:
	var joint := rig.find_bone(Undead.RootJoint)
	var parent := rig.get_bone_parent(joint)
	var up := (rig.global_basis * rig.get_bone_global_pose(parent).basis).inverse() * Vector3.UP
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_POSITION_3D or not str(clip.track_get_path(track)).ends_with(":" + Undead.RootJoint):
			continue
		for key in clip.track_get_key_count(track):
			var phase := clip.track_get_key_time(track, key) / clip.length
			var pose: Vector3 = clip.track_get_key_value(track, key)
			clip.track_set_key_value(track, key, pose + up * (.15 + .13 * smoothstep(.50, 1.0, phase)))
		return
	assert(false, "Wraith reconstitution requires its pelvis translation")

func build_wraith_parts(model: Node3D, body: MeshInstance3D, rig: Skeleton3D, player: AnimationPlayer,
		clip: Animation) -> void:
	var source := body.mesh.surface_get_arrays(0)
	var triangles: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var joints: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var stride := joints.size() / uv.size()
	var groups: Array[PackedInt32Array] = []
	for index in PartNames.size():
		groups.append(PackedInt32Array())
	for index in range(0, triangles.size(), 3):
		var a := triangles[index]
		var b := triangles[index + 1]
		var c := triangles[index + 2]
		var group := 0
		if bone_texels(uv[a], uv[b], uv[c], atlas):
			var joint := dominant_joint(rig, body.skin, [a, b, c], joints, weights, stride)
			group = bone_group(joint)
		groups[group].append(a)
		groups[group].append(b)
		groups[group].append(c)
	var layer := Node3D.new()
	layer.name = "AssemblyPieces"
	layer.visible = false
	model.add_child(layer)
	layer.owner = model
	var animation_root := player.get_node(player.root_node)
	add_visibility(clip, animation_root.get_path_to(layer), true, false)
	add_visibility(clip, animation_root.get_path_to(body), false, true)
	var poses := posed_vertices(source, body.skin, rig, model)
	var material := body.mesh.surface_get_material(0)
	var counts := {}
	for index in groups.size():
		assert(not groups[index].is_empty(), PartNames[index])
		var piece := make_piece(index, groups[index], source, poses, material)
		piece.name = PartNames[index]
		layer.add_child(piece)
		piece.owner = model
		add_wraith_piece_motion(model, clip, animation_root.get_path_to(piece), piece, index)
		counts[PartNames[index]] = groups[index].size() / 3
	print("WRAITH ASSEMBLY ", counts)

func bone_group(joint: String) -> int:
	if joint in ["bip01 head", "bip01 neck"]:
		return 1
	if joint.begins_with("bip01 l "):
		return 2
	if joint.begins_with("bip01 r "):
		return 3
	if joint in ["bip01 spine1", "bip01 spine2"]:
		return 4
	return 5

func add_wraith_piece_motion(model: Node3D, clip: Animation, path: NodePath, piece: MeshInstance3D, index: int) -> void:
	var rotation := clip.add_track(Animation.TYPE_ROTATION_3D)
	var position := clip.add_track(Animation.TYPE_POSITION_3D)
	var scale_track := clip.add_track(Animation.TYPE_SCALE_3D)
	for track in [rotation, position, scale_track]:
		clip.track_set_path(track, path)
	var angle := float(index) * 2.3999632
	var start_rotation := Quaternion(Vector3.UP, angle) * Quaternion(Vector3.FORWARD, .67 * float(index % 3 - 1))
	var radius := .78 + .095 * float(index) if index > 0 else .0
	var scatter := Vector3(cos(angle), 0.0, sin(angle)) * radius
	var initial_scale := .04 if index == 0 else 1.0
	var floor_gap := INF
	for point: Vector3 in piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		floor_gap = minf(floor_gap, (model.global_basis * (start_rotation * point * initial_scale)).y)
	scatter.y = .022 - floor_gap
	var start := model.to_local(scatter)
	var lift := model.global_basis.inverse() * Vector3.UP
	for frame in 61:
		var phase := JoinPhase * frame / 60.0
		var catch := smoothstep(.105 + .021 * float(index), JoinPhase, phase)
		var scale_value := lerpf(initial_scale, 1.0, smoothstep(.16, .51, phase))
		var time := phase * clip.length
		clip.rotation_track_insert_key(rotation, time, start_rotation.slerp(Quaternion.IDENTITY, catch))
		clip.position_track_insert_key(position, time, start.lerp(piece.position, catch) + lift * (.19 * sin(PI * catch)))
		clip.scale_track_insert_key(scale_track, time, Vector3.ONE * scale_value)
	if index == 0:
		var visibility := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(visibility, NodePath("%s:visible" % path))
		clip.value_track_set_update_mode(visibility, Animation.UPDATE_DISCRETE)
		clip.track_insert_key(visibility, 0.0, false)
		clip.track_insert_key(visibility, .16 * clip.length, true)

static func bone_texels(a: Vector2, b: Vector2, c: Vector2, atlas: Image) -> bool:
	var votes := 0
	for sample: Vector3 in Samples:
		var uv := a * sample.x + b * sample.y + c * sample.z
		var point := Vector2i((uv * Vector2(atlas.get_size())).floor()).clamp(Vector2i.ZERO, atlas.get_size() - Vector2i.ONE)
		var texel := atlas.get_pixelv(point)
		if texel.a > .4 and texel.r > .21 and texel.r - texel.b > .055 and texel.g - texel.b > .032:
			votes += 1
	return votes >= 2

static func dominant_joint(rig: Skeleton3D, skin: Skin, vertices: Array, joints: PackedInt32Array,
		weights: PackedFloat32Array, stride: int) -> String:
	var influences := {}
	for vertex: int in vertices:
		for slot in stride:
			var key := vertex * stride + slot
			var joint := joints[key]
			influences[joint] = influences.get(joint, 0.0) + weights[key]
	var dominant := -1
	var strongest := 0.0
	for bind: int in influences:
		if influences[bind] > strongest:
			strongest = influences[bind]
			dominant = skin.get_bind_bone(bind)
			if dominant < 0:
				dominant = rig.find_bone(skin.get_bind_name(bind))
	assert(dominant >= 0)
	return str(rig.get_bone_name(dominant))
