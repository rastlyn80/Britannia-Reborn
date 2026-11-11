# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-skeleton-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/crystal-elemental-enhanced/"
const Body := 300
const CrystalJoin := .74
const ShardSeeds := [
	Vector3(.50, .79, .76), Vector3(.25, .46, .68), Vector3(.75, .46, .68),
	Vector3(.50, .56, .48), Vector3(.28, .22, .39), Vector3(.72, .22, .39),
	Vector3(.50, .25, .22), Vector3(.50, .28, .07),
]
const Clips := {11: "CrystalCrestFlick", 12: "CrystalShardCast", 15: "CrystalSpineFan",
	23: "CrystalShardAssembly", 25: "CrystalQuietStill", 26: "CrystalLowInspection",
	27: "CrystalRaisedSpines", 28: "CrystalLowGuard"}
const Durations := {11: .85, 12: 1.10, 15: .62, 23: 1.42, 25: 1.17, 26: .95, 27: .89, 28: .71}
const CrystalJoints := ["bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 spine4",
	"bip01 neck1", "bip01 head", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bone43", "bone41", "bone47", "bone49",
	"bone65", "bone67", "bone69", "bone70"]


func run() -> void:
	var row := Registry.entry(Body)
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
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in Clips:
			var motion: Animation
			if group in [12, 23]:
				motion = resample_shards(player, rig, skins, group)
			else:
				motion = fit_grounded(player, rig, skins, Durations[group], "bip01", CrystalJoints, pose_crystal.bind(group), .004)
			if group == 25:
				motion.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Clips[group], motion) == OK)
		player.stop()
		player.play(Clips[23], 0.0)
		player.advance(0.0)
		player.seek(Durations[23] * CrystalJoin, true)
		rig.force_update_all_bone_transforms()
		build_shards(model, rig, player, library.get_animation(Clips[23]))
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [Body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("CRYSTAL ELEMENTAL FIT ", treatment, ": six posed motions and two articulated shard sequences")
	quit()


func build_shards(model: Node3D, rig: Skeleton3D, player: AnimationPlayer, clip: Animation) -> void:
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(body.mesh.get_surface_count() == 1)
	var arrays := body.mesh.surface_get_arrays(0)
	var triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var posed := posed_vertices(arrays, body.skin, rig, model)
	var positions: PackedVector3Array = posed.positions
	var bounds := AABB(positions[0], Vector3.ZERO)
	for position: Vector3 in positions:
		bounds = bounds.expand(position)
	var groups: Array[PackedInt32Array] = []
	for index in ShardSeeds.size():
		groups.append(PackedInt32Array())
	for face in range(0, triangles.size(), 3):
		var center := (positions[triangles[face]] + positions[triangles[face + 1]] + positions[triangles[face + 2]]) / 3.0
		var normalized := (center - bounds.position) / bounds.size
		var group := 0
		for index in range(1, ShardSeeds.size()):
			if normalized.distance_squared_to(ShardSeeds[index]) < normalized.distance_squared_to(ShardSeeds[group]):
				group = index
		for index in range(face, face + 3):
			groups[group].append(triangles[index])
	var fragments := Node3D.new()
	fragments.name = "CrystalFragments"
	model.add_child(fragments)
	fragments.owner = model
	fragments.hide()
	var root_node := player.get_node(player.root_node)
	var counts := PackedInt32Array()
	for index in groups.size():
		assert(groups[index].size() >= 12, "Crystal partition lost a shard.")
		var part := make_piece(index, groups[index], arrays, posed, body.mesh.surface_get_material(0))
		part.name = "CrystalShard%02d" % index
		fragments.add_child(part)
		part.owner = model
		add_shard_motion(model, clip, root_node.get_path_to(part), part, index)
		counts.append(groups[index].size() / 3)
	print("CRYSTAL SOURCE TRIANGLES ", counts)


func add_shard_motion(model: Node3D, clip: Animation, path: NodePath, part: MeshInstance3D, index: int) -> void:
	var rotation := add_shard_track(clip, path, Animation.TYPE_ROTATION_3D)
	var position := add_shard_track(clip, path, Animation.TYPE_POSITION_3D)
	var angle := float(index) * 2.3999632
	var up := (model.global_basis.inverse() * Vector3.UP).normalized()
	var sideways := (model.global_basis.inverse() * Vector3.RIGHT).normalized()
	var start_rotation := Quaternion(up, angle) * Quaternion(sideways, .56 * float(index % 3 - 1))
	var scatter := Vector3(cos(angle), 0.0, sin(angle)) * (1.55 + .22 * float(index % 3))
	var floor_gap := INF
	for point: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		floor_gap = minf(floor_gap, (model.global_basis * (start_rotation * point)).y)
	scatter.y = .025 + .22 * float(index % 4) - floor_gap
	var start := model.global_basis.inverse() * scatter
	for frame in 61:
		var phase := CrystalJoin * frame / 60.0
		var joined := smoothstep(.08 + .018 * index, CrystalJoin, phase)
		var time := phase * clip.length
		clip.rotation_track_insert_key(rotation, time, start_rotation.slerp(Quaternion.IDENTITY, joined))
		clip.position_track_insert_key(position, time, start.lerp(part.position, joined) + up * (.32 * sin(PI * joined)))


func envelope(phase: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, phase) * (1.0 - smoothstep(c, d, phase))


func resample_shards(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], group: int) -> Animation:
	var assembly := group == 23
	var seed := "Death" if assembly else "Cast"
	var result := Animation.new()
	result.length = Durations[group]
	var path := player.get_node(player.root_node).get_path_to(rig)
	var positions := PackedInt32Array()
	var rotations := PackedInt32Array()
	var scales := PackedInt32Array()
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	var reference: Array[Transform3D] = []
	for index in rig.get_bone_count():
		var track_path := NodePath("%s:%s" % [path, rig.get_bone_name(index)])
		positions.append(add_shard_track(result, track_path, Animation.TYPE_POSITION_3D))
		rotations.append(add_shard_track(result, track_path, Animation.TYPE_ROTATION_3D))
		scales.append(add_shard_track(result, track_path, Animation.TYPE_SCALE_3D))
		reference.append(rig.get_bone_pose(index))
	var root_joint := rig.find_bone("bip01")
	assert(root_joint >= 0)
	var origin := rig.get_bone_global_pose(root_joint).origin
	player.stop()
	player.play(seed, 0.0)
	player.advance(0.0)
	var duration := player.current_animation_length
	for frame in 91:
		var phase := float(frame) / 90.0
		var travel := 1.0 - smoothstep(.10, .92, phase) if assembly else phase
		var amount := 1.0 - smoothstep(.72, 1.0, phase) if assembly else envelope(phase, .0, .20, .81, 1.0)
		rig.reset_bone_poses()
		player.seek(duration * travel, true)
		for index in rig.get_bone_count():
			var pose := reference[index].interpolate_with(rig.get_bone_pose(index), amount)
			rig.set_bone_pose(index, pose)
		rig.force_update_all_bone_transforms()
		var anchor := rig.get_bone_global_pose(root_joint)
		var motion := rig.global_basis * (anchor.origin - origin)
		anchor.origin -= rig.global_basis.inverse() * motion.slide(Vector3.UP)
		rig.set_bone_global_pose(root_joint, anchor)
		rig.force_update_all_bone_transforms()
		var gap := INF
		for skin: Dictionary in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(is_finite(gap))
		anchor.origin += rig.global_basis.inverse() * Vector3.UP * (.004 - gap)
		rig.set_bone_global_pose(root_joint, anchor)
		var time := result.length * phase
		for index in rig.get_bone_count():
			result.position_track_insert_key(positions[index], time, rig.get_bone_pose_position(index))
			result.rotation_track_insert_key(rotations[index], time, rig.get_bone_pose_rotation(index))
			result.scale_track_insert_key(scales[index], time, rig.get_bone_pose_scale(index))
	return result


func add_shard_track(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := clip.add_track(type)
	clip.track_set_path(track, path)
	return track


func pose_crystal(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := envelope(phase, .08, .42, .58, .98)
	var spread := 0.0
	var dip := 0.0
	var lift := 0.0
	var twist := 0.0
	var flick := 0.0
	match group:
		11:
			flick = .75 * pulse
			twist = .15 * sin(TAU * phase)
		15:
			spread = .63 * pulse
			dip = .23 * pulse
		25:
			dip = .026 * sin(TAU * phase)
			twist = .031 * sin(TAU * phase)
		26:
			twist = .29 * pulse
			lift = .16 * pulse
			spread = .21 * pulse
		27:
			lift = .49 * pulse
			flick = .57 * pulse
			spread = .36 * pulse
		28:
			dip = .29 * smoothstep(.12, .82, phase)
			spread = .23 * pulse
			twist = -.21 * pulse
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .16 * dip - .17 * lift)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .42 * dip - .41 * lift)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .28 * dip - .19 * lift)
	turn_world(rig, "bip01 head", Vector3.UP, twist)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.28 * lift + .18 * dip)
	turn_world(rig, "bone70", Vector3.RIGHT, -.83 * flick)
	turn_world(rig, "bone65", Vector3.RIGHT, -.47 * flick)
	turn_world(rig, "bone67", Vector3.RIGHT, -.30 * flick)
	turn_world(rig, "bone69", Vector3.RIGHT, -.21 * flick)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .18 * lift - .22 * dip)
	turn_world(rig, "bip01 tail2", Vector3.UP, .19 * twist)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.UP, sign_x * .37 * spread)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.28 * spread + .16 * dip)
	for shard: String in ["bone43", "bone47"]:
		turn_world(rig, shard, Vector3.BACK, -.41 * spread)
	for shard: String in ["bone41", "bone49"]:
		turn_world(rig, shard, Vector3.BACK, .41 * spread)
