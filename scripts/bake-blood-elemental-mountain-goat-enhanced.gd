# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-goat-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/blood-elemental-mountain-goat/"
const BloodClips := {23: "BloodElementalPoolRise", 28: "BloodElementalSurgeAlert"}
const BloodLengths := {23: 1.18, 28: .74}
const MountainClips := {25: "MountainGoatQuietStand", 26: "MountainGoatLoweredHornCheck"}
const MountainLengths := {25: 1.05, 26: 1.18}
const ShellPath := "res://Presentation/blood-elemental-shell.gd"
const FluidJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	prepare_body(88, MountainClips, MountainLengths, CommonJoints + ["bip01 neck1"], pose_goat, Destination)
	var row := Registry.entry(159)
	for treatment: String in row.assets:
		bake_blood(row, treatment)
	quit()


func bake_blood(row: Dictionary, treatment: String) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.play("Idle", 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var shell_recipe := load(ShellPath if ResourceLoader.exists(ShellPath) else Destination + "blood-elemental-shell.gd") as GDScript
	var shell: MeshInstance3D = shell_recipe.build(model, rig)
	var skins: Array[Dictionary] = [Ground.skin_points(model.find_child("Body", true, false), rig), Ground.skin_points(shell, rig)]
	for group: int in BloodClips:
		var clip := fit_grounded(player, rig, skins, BloodLengths[group], "__root", FluidJoints, pose_blood.bind(group), .005)
		add_root_scale(clip, player, rig, group == 23)
		assert(library.add_animation(BloodClips[group], clip) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, Destination + "159-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("BLOOD ELEMENTAL ", treatment, ": pool rise and surging alert on the original fluid body")


func pose_blood(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var fold := 1.0 - smoothstep(.11, .87, phase) if rise else .36 * envelope(phase, .05, .29, .48, .91)
	var alert := .23 * envelope(phase, .35, .64, .85, 1.0) if rise else smoothstep(.14, .82, phase)
	var lean := .12 * sin(PI * phase) if rise else .17 * alert
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .33 * fold)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .31 * fold - .11 * alert)
	turn_world(rig, "bip01 spine2", Vector3.UP, lean)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.20 * fold + .08 * alert)
	turn_world(rig, "bip01 head", Vector3.UP, -.36 * lean)
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand := joint_world(rig, "bip01 %s hand" % side)
		hand = hand.lerp(chest + Vector3(sign_x * .21, -.06, .40), fold)
		hand = hand.lerp(chest + Vector3(sign_x * .70, -.19, .18 + .10 * sign_x), alert)
		fit_arm(rig, side, hand)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.25 * fold + .08 * alert)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .31 * fold)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.12 * fold)


func add_root_scale(clip: Animation, player: AnimationPlayer, rig: Skeleton3D, rise: bool) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var track := clip.find_track(path, Animation.TYPE_SCALE_3D)
	if track < 0:
		track = clip.add_track(Animation.TYPE_SCALE_3D)
		clip.track_set_path(track, path)
	else:
		clip.track_remove_key(track, 0)
	if not rise:
		clip.scale_track_insert_key(track, 0.0, Vector3.ONE)
		return
	var root_bone := rig.find_bone("__root")
	var up := (rig.global_basis * rig.get_bone_global_rest(root_bone).basis).inverse() * Vector3.UP
	var vertical := up.normalized().abs()
	for frame in 81:
		var phase := float(frame) / 80.0
		var width := lerpf(.29, 1.0, smoothstep(.01, .70, phase))
		var height := lerpf(.10, 1.0, smoothstep(.13, .94, phase))
		clip.scale_track_insert_key(track, phase * clip.length, Vector3.ONE * width + vertical * (height - width))
