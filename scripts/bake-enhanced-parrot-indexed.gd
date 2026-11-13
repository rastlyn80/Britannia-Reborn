# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-preferred-uop-actions.gd"

const Fits := {2: "ParrotFallingTuck", 10: "ParrotRaisedWingRecoil", 25: "ParrotRestingCrouch"}
const Durations := {2: .88, 10: .62, 25: .9}
const Joints := ["bip01 pelvis", "bip01 neck1", "bip01 head", "bip01 tail",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh"]


func run() -> void:
	var destination := OS.get_environment("BR_INDEXED_BAKE_DIRECTORY")
	assert(not destination.is_empty(), "Set BR_INDEXED_BAKE_DIRECTORY to the local build folder.")
	destination = destination.path_join("parrot-variants/")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination)) == OK)
	var row := Registry.entry(831)
	for treatment: String in ["original", "rounded", "modern"]:
		var previous := Registry.asset_path(row, treatment)
		var model := (load(previous) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skin: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				skin.append(Ground.skin_points(mesh, rig))
		for group: int in Fits:
			var motion := fit_grounded(player, rig, skin, Durations[group], "bip01 pelvis",
				Joints, pose_parrot.bind(group), .004)
			assert(library.add_animation(Fits[group], motion) == OK)
		Exact.check_earlier_keys(player, previous)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, destination + "831-%s.scn" % treatment,
			ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("PARROT VARIANTS FIT ", treatment, ": three motion references")
	quit()


func pose_parrot(rig: Skeleton3D, phase: float, group: int) -> void:
	var settle := smoothstep(.06, .85, phase)
	var startle := smoothstep(.01, .23, phase) * (1.0 - smoothstep(.43, .96, phase))
	var pitch := .17 + .05 * cos(TAU * phase)
	var lift := 0.0
	var fold := 0.0
	if group == 2:
		pitch = .75 * settle
		lift = .87 * (1.0 - settle)
		fold = .31 * settle
	elif group == 10:
		pitch = -.37 * startle
		lift = .97 * startle
		fold = .26 * startle
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, pitch)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.39 * pitch)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.36 * pitch + .21 * startle)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.62 * pitch)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, sign * lift)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.BACK, -sign * fold)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.19 * pitch)
