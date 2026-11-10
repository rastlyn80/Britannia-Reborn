# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-skeleton-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ogre-earth/"
const Formation := "EarthStoneFormation"
const Duration := 1.34
const FormationJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]

func run() -> void:
	var row := Registry.entry(14)
	for treatment: String in row.assets:
		var source := Stage + "14-%s.scn" % treatment
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
		var clip := fit_grounded(player, rig, skins, Duration, "bip01 pelvis", FormationJoints, pose_formation, .004)
		assert(library.add_animation(Formation, clip) == OK)
		player.play(Formation, 0.0)
		player.advance(0.0)
		player.seek(JoinPhase * Duration, true)
		rig.force_update_all_bone_transforms()
		assert(make_assembly(model, body, rig, player, clip) == 15)
		verify_base_clips(player, source)
		player.stop()
		body.visible = true
		model.get_node("AssemblyPieces").visible = false
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var output := Stage + "14-formation-%s.scn" % treatment
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("EARTH STONE FORMATION ", treatment, ": 15 source rock meshes")
	quit()

func pose_formation(rig: Skeleton3D, phase: float) -> void:
	var settle := 1.0 - smoothstep(.61, 1.0, phase)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .24 * settle)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.34 * settle)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .16 * settle)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * 1.24 * settle)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.12 * settle)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.34 * settle)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .61 * settle)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.28 * settle)

func add_piece_motion(model: Node3D, clip: Animation, path: NodePath, piece: MeshInstance3D, index: int) -> void:
	var rotation := clip.add_track(Animation.TYPE_ROTATION_3D)
	var position := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(rotation, path)
	clip.track_set_path(position, path)
	var angle := float(index) * 2.3999632
	var start_rotation := Quaternion(Vector3.UP, angle) * Quaternion(Vector3.FORWARD, .31 * float(index % 5 - 2))
	var radius := (.40 + .80 * sqrt(float(index) / 14.0)) if index != 13 else .05
	var start := Vector3(cos(angle), 0.0, sin(angle)) * radius
	var lowest := INF
	var vertices: PackedVector3Array = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		lowest = minf(lowest, (model.global_basis * (start_rotation * vertex)).y)
	start.y = .014 - lowest
	var placement := model.to_local(start)
	var lifted := model.global_basis.inverse() * Vector3.UP
	var visible_from := 0.0 if index == 13 else .075 + .023 * float(index % 7)
	var gather_from := .18 + .012 * float(index % 8)
	for frame in 61:
		var phase := JoinPhase * frame / 60.0
		var time := phase * clip.length
		var catch := smoothstep(gather_from, JoinPhase, phase)
		var lift := sin(PI * catch) * (.15 + .085 * float(index % 4))
		clip.rotation_track_insert_key(rotation, time, start_rotation.slerp(Quaternion.IDENTITY, catch))
		clip.position_track_insert_key(position, time, placement.lerp(piece.position, catch) + lifted * lift)
	if visible_from > 0.0:
		var visibility := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(visibility, NodePath("%s:visible" % path))
		clip.value_track_set_update_mode(visibility, Animation.UPDATE_DISCRETE)
		clip.track_insert_key(visibility, 0.0, false)
		clip.track_insert_key(visibility, visible_from * clip.length, true)
