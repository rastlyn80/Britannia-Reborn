# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 301
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/treefellow-enhanced/"
const QuietWalk := "TreefellowQuietWalk"
const Clips := {1: "TreefellowCombatIdle", 3: "Death2", 4: "TreefellowBranchHammer",
	5: "TreefellowRakingSwipe", 10: "TreefellowBarkRecoil", 11: "TreefellowLowGather",
	12: "TreefellowRootCast", 15: "TreefellowBracedGuard", 23: "TreefellowSlowRise",
	25: "TreefellowQuietIdle", 26: "TreefellowWoodlandWatch", 27: "TreefellowCanopyLift",
	28: "TreefellowRootReady"}
const Lengths := {1: 1.30, 3: 1.16, 4: .90, 5: .88, 10: .60, 11: 1.27, 12: .84,
	15: .63, 23: 1.23, 25: 1.85, 26: 1.34, 27: 1.10, 28: .82}
const TreeJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"box01", "box02", "box05"]
const GaitJoints := ["bip01 spine1", "bip01 spine3", "bip01 neck", "bip01 head", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "box01", "box02", "box05"]


func run() -> void:
	prepare_body(Body, Clips, Lengths, TreeJoints, pose_tree, Destination, set_loop)
	var row := Registry.entry(Body)
	for treatment: String in row.assets:
		var path := Destination + "%d-%s.scn" % [Body, treatment]
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var gait := fit_quiet_walk(player, rig)
		assert(player.get_animation_library("").add_animation(QuietWalk, gait) == OK)
		verify_base_clips(player, Registry.asset_path(row, treatment))
		player.stop()
		rig.reset_bone_poses()
		if treatment == "modern":
			paint_canopy(model)
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TREEFELLOW ", treatment, ": ", Clips.size() + 1, " fitted motions / ", FileAccess.get_sha256(path))
	quit()


func set_loop(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group in [1, 25]:
		clip.loop_mode = Animation.LOOP_LINEAR


func paint_canopy(model: Node3D) -> void:
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var source := body.mesh
	assert(source.get_surface_count() == 1)
	var arrays := source.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var masks := PackedColorArray()
	for index in points.size():
		var position := body.to_global(points[index])
		var normal := (body.global_basis * normals[index]).normalized()
		var crown := smoothstep(1.71, 2.73, position.y)
		var exposed := smoothstep(-.20, .82, normal.y)
		var cover := crown * (.45 + .55 * exposed)
		masks.append(Color(cover, exposed, 0.0, 1.0))
	arrays[Mesh.ARRAY_COLOR] = masks
	var format := int(source.surface_get_format(0)) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
	result.surface_set_material(0, source.surface_get_material(0))
	body.mesh = result


func fit_quiet_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var source := player.get_animation("Walk")
	var clip := source.duplicate(true) as Animation
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for label: String in GaitJoints:
		var joint_path := NodePath("%s:%s" % [path, label])
		var track := clip.find_track(joint_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, joint_path)
		else:
			for index in range(clip.track_get_key_count(track) - 1, -1, -1):
				clip.track_remove_key(track, index)
		tracks[label] = track
	var previous_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_LINEAR
	clip.loop_mode = Animation.LOOP_LINEAR
	player.play("Walk", 0.0)
	player.advance(0.0)
	for sample in 73:
		var phase := float(sample) / 72.0
		var time := phase * clip.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var stride := sin(TAU * phase)
		var settle := cos(2.0 * TAU * phase)
		turn_world(rig, "bip01 spine1", Vector3.UP, -.049 * stride)
		turn_world(rig, "bip01 spine3", Vector3.RIGHT, -.068 + .044 * settle)
		turn_world(rig, "bip01 neck", Vector3.BACK, .04 * stride)
		turn_world(rig, "bip01 head", Vector3.UP, .08 * stride)
		for side: String in ["l", "r"]:
			var sign_x := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, .11 - sign_x * .13 * stride)
			turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .09 + sign_x * .08 * stride)
		bend_canopy(rig, .037 * sin(TAU * phase - .8), .035 * settle)
		for label: String in tracks:
			clip.rotation_track_insert_key(tracks[label], time, rig.get_bone_pose_rotation(rig.find_bone(label)))
	source.loop_mode = previous_loop
	for track in source.get_track_count():
		var label := str(source.track_get_path(track).get_concatenated_subnames())
		if label in GaitJoints and source.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			continue
		assert(source.get("tracks/%d/keys" % track) == clip.get("tracks/%d/keys" % track))
	return clip


func pose_tree(rig: Skeleton3D, phase: float, group: int) -> void:
	var wind := 0.0
	var swing := 0.0
	var lift := 0.0
	var hunch := 0.0
	var lean := 0.0
	var twist := 0.0
	var spread := 0.0
	var settle := 0.0
	var lead := 1.0
	var sway := sin(TAU * phase)
	match group:
		1:
			spread = .14 + .055 * sway
			twist = .07 * sway
			hunch = .075 + .025 * cos(TAU * phase)
		3:
			lift = .57 * envelope(phase, 0.0, .14, .24, .64)
			settle = smoothstep(.15, .72, phase)
			hunch = .38 * settle
			lean = -.13 * settle
			twist = -.15 * settle
		4:
			wind = .91 * envelope(phase, .03, .30, .43, .61)
			swing = envelope(phase, .34, .58, .66, .92)
			lift = .84 * wind
			hunch = .56 * swing
			twist = .24 * wind - .31 * swing
		5:
			lead = -1.0
			wind = .75 * envelope(phase, .04, .30, .42, .68)
			swing = .95 * envelope(phase, .27, .51, .68, .93)
			spread = .49 * wind
			hunch = .28 * swing
			twist = -.40 * wind + .53 * swing
		10:
			var recoil := envelope(phase, .02, .24, .38, .93)
			lean = -.38 * recoil
			twist = -.27 * recoil
			spread = .23 * recoil
		11:
			hunch = .71 * envelope(phase, .03, .45, .63, .97)
			spread = .17 * hunch
			twist = -.13 * hunch
		12:
			lift = .62 * envelope(phase, .07, .32, .65, .96)
			swing = .54 * envelope(phase, .31, .61, .68, .98)
			spread = .38 * lift
		15:
			hunch = .39 * envelope(phase, .02, .31, .57, .97)
			spread = .35 * hunch
			swing = .50 * hunch
		23:
			var rise := smoothstep(.16, .82, phase)
			hunch = .58 * (1.0 - rise)
			lift = .18 * sin(PI * rise)
		25:
			twist = .032 * sway
			hunch = .023 * (1.0 - cos(TAU * phase))
		26:
			twist = .33 * sway * sin(PI * phase)
			lean = .10 * sin(PI * phase)
		27:
			lift = .82 * envelope(phase, .04, .36, .65, .99)
			spread = .57 * lift
			lean = -.21 * lift
		28:
			var ready := smoothstep(.14, .88, phase)
			hunch = .12 * ready
			spread = .30 * ready
			lift = .21 * ready
	var feet := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.UP, .19 * twist)
	turn_world(rig, RootJoint, Vector3.RIGHT, .13 * hunch + .20 * lean)
	turn_world(rig, "bip01 spine2", Vector3.UP, .47 * twist)
	turn_world(rig, "bip01 spine3", Vector3.UP, .57 * twist)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .54 * hunch + lean - .18 * lift)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .29 * hunch - .14 * lean)
	turn_world(rig, "bip01 head", Vector3.UP, .21 * twist)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.19 * lift + .21 * settle)
	bend_canopy(rig, -.32 * lift + .43 * settle + .09 * hunch, .20 * twist)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var leading := 1.0 if sign_x == lead else .52
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.52 * spread + .23 * wind + .12 * settle))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, leading * (-1.17 * lift - .63 * swing + .43 * wind) + .37 * hunch + .22 * settle)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.59 * wind - .31 * lift + .42 * swing + .41 * settle)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.38 * swing - .16 * lift))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.21 * hunch - .12 * settle)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .29 * hunch + .18 * settle)
	anchor_hind_paws(rig, feet)


func bend_canopy(rig: Skeleton3D, pitch: float, yaw: float) -> void:
	turn_world(rig, "box01", Vector3.RIGHT, pitch)
	turn_world(rig, "box02", Vector3.UP, yaw)
	turn_world(rig, "box05", Vector3.UP, -yaw * .74)
