# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-vampire-bat-distinct-actions.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/giant-rat-vampire-bat/"
const BatClips := {4: "VampireBatSwoop", 23: "VampireBatUnfold", 25: "VampireBatWingDip",
	26: "VampireBatHoverWatch"}
const Lengths := {4: .88, 23: 1.28, 25: .76, 26: 1.23}


func run() -> void:
	var row := Registry.entry(317)
	for treatment: String in row.assets:
		bake_treatment(treatment, row)
	quit()


func bake_treatment(treatment: String, row: Dictionary) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for group: int in BatClips:
		assert(library.add_animation(BatClips[group], fit_enhanced(player, rig, skin, group)) == OK)
	Exact.check_earlier_keys(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, Destination + "317-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("VAMPIRE BAT ", treatment, ": four fitted motions")


func fit_enhanced(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, group: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = Lengths[group]
	clip.loop_mode = Animation.LOOP_NONE
	var root_bone := rig.find_bone("bip01")
	var actor := player.get_node(player.root_node)
	var path := actor.get_path_to(rig)
	var node_path := NodePath("VisualRoot/SourceSpace")
	var source_space := actor.get_node(node_path) as Node3D
	var space_track := clip.find_track(node_path, Animation.TYPE_POSITION_3D)
	assert(space_track >= 0)
	var fixed_origin: Vector3 = clip.track_get_key_value(space_track, 0)
	var rotation: Array[int] = []
	var position: Array[int] = []
	var scale: Array[int] = []
	for bone in rig.get_bone_count():
		var key := NodePath("%s:%s" % [path, rig.get_bone_name(bone)])
		rotation.append(channel(clip, key, Animation.TYPE_ROTATION_3D))
		position.append(channel(clip, key, Animation.TYPE_POSITION_3D))
		scale.append(channel(clip, key, Animation.TYPE_SCALE_3D))
	for track in clip.get_track_count():
		clear_keys(clip, track)
	clip.position_track_insert_key(space_track, 0.0, fixed_origin)
	for index in 121:
		var phase := float(index) / 120.0
		var desired := pose_enhanced(player, rig, group, phase)
		source_space.position = fixed_origin
		source_space.force_update_transform()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var placement := rig.get_bone_global_pose(root_bone)
		placement.origin += rig.global_basis.inverse() * Vector3.UP * (desired - gap)
		rig.set_bone_global_pose(root_bone, placement)
		rig.force_update_all_bone_transforms()
		for bone in rig.get_bone_count():
			clip.rotation_track_insert_key(rotation[bone], phase * clip.length, rig.get_bone_pose_rotation(bone))
			clip.position_track_insert_key(position[bone], phase * clip.length, rig.get_bone_pose_position(bone))
			clip.scale_track_insert_key(scale[bone], phase * clip.length, rig.get_bone_pose_scale(bone))
	return clip


func pose_enhanced(player: AnimationPlayer, rig: Skeleton3D, group: int, phase: float) -> float:
	var cycles := 3.0
	var altitude := .39
	var bank := .08 * sin(TAU * phase)
	var pitch := .08 * sin(TAU * phase)
	var fold := 0.0
	var strike := 0.0
	match group:
		4:
			cycles = 3.55
			strike = smoothstep(.09, .39, phase) * (1.0 - smoothstep(.50, .85, phase))
			altitude = .52 - .32 * strike
			pitch = .49 * strike - .15 * sin(PI * phase)
			bank = .28 * sin(TAU * phase) * sin(PI * phase)
		23:
			cycles = 3.85
			fold = 1.0 - smoothstep(.07, .27, phase)
			altitude = lerpf(.12, .51, smoothstep(.06, .76, phase))
			pitch = -.29 * sin(PI * phase)
		25:
			cycles = 1.45
			strike = smoothstep(.12, .49, phase) * (1.0 - smoothstep(.65, 1.0, phase))
			altitude = .41 - .16 * strike
			bank = -.33 * strike
			pitch = .23 * strike
		26:
			cycles = 3.15
			altitude = .46 + .10 * sin(PI * phase) + .05 * sin(3.0 * TAU * phase)
			bank = .22 * sin(TAU * phase) * sin(PI * phase)
	var donor_time := fposmod(phase * cycles + .15, 1.0)
	seek(player, rig, "Walk", donor_time)
	turn(rig, "bip01", Vector3.BACK, bank)
	turn(rig, "bip01", Vector3.RIGHT, pitch)
	turn(rig, "bip01 head", Vector3.RIGHT, -.32 * pitch + .17 * strike)
	turn(rig, "box03", Vector3.RIGHT, .34 * strike)
	turn(rig, "bip01 tail", Vector3.RIGHT, -.42 * pitch)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var limb := "bip01 " + side
		turn(rig, limb + " upperarm", Vector3.BACK, sign * .77 * fold)
		turn(rig, limb + " forearm", Vector3.UP, sign * .88 * fold)
		turn(rig, "wing" + side + "2", Vector3.BACK, -sign * .42 * fold)
	return altitude

