# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-source-giant-serpent-terrain.gd"

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Families := {
	22: [["Idle", "Walk", "Run", "Attack", "Attack2", "Hit", "Fidget", "EyeVolley", "EyeSpread"],
		["GazerTentacleSurvey", "GazerEyeFan", "GazerTiltRecoil", "GazerUnfurl",
		"GazerHoverScan", "GazerOrbitFeint", "GazerRaisedEyeAlert"]],
	144: [["CombatGlide", "CombatIdle", "Attack", "Attack2", "Hit", "ForwardRush",
		"Cast", "TailCurl", "Walk", "Uncoil", "Run", "Idle", "Fidget", "LongReach", "Alert"], []],
	205: [["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Eat", "RabbitLunge", "RabbitEarCheck"],
		["RabbitSettleFromRear", "RabbitQuietCrouch", "RabbitLookAround", "RabbitRiseAlert"]],
}


func _initialize() -> void:
	create_timer(290.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var body := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--body="):
			body = int(argument.trim_prefix("--body="))
	assert(Families.has(body), "Specify body 22, 144 or 205.")
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if body == 144:
		assert(enhanced and preload("res://Presentation/SeaHorseProfile.gd").enable())
	else:
		if enhanced:
			assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
		assert(body in preload("res://Presentation/SourceOccurrenceTerrainProfile.gd").enable())
	var clips: Array = Families[body][0]
	if enhanced:
		clips = clips + Families[body][1]
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(2, Step - .1, 0)
	var results := {}
	var checked := 0
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.17, 1.0, -.11).normalized() if support == "slope" else Vector3.UP
		var middle := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), middle - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for clip: String in clips:
			var worst := {"gap": INF}
			var lift_change := 0.0
			for x: float in ([-.48, -.21, -.03, .15, .46] if split else [0.0]):
				for heading: float in [PI * .5, PI * 1.5]:
					var avatar := Avatar.new()
					avatar.initial_body = body
					var anchor := Vector3(x, Step if split and x > 0.0 else 0.0, 0)
					avatar.position = anchor
					avatar.rotation.y = heading
					root.add_child(avatar)
					avatar.apply_server_appearance({"body": body, "hue": 0x8035}, [])
					var actor: Node3D = avatar.horse_visual
					avatar.set_physics_process(false)
					actor.set_process(false)
					actor.set_physics_process(false)
					var rig: Skeleton3D = actor.skeleton
					var skins: Array[Dictionary] = []
					for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
						if mesh.skin != null and mesh.is_visible_in_tree():
							skins.append(Ground.skin_points(mesh, rig))
					assert(not skins.is_empty())
					var player: AnimationPlayer = actor.animator
					player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					actor.current_clip = clip
					actor.action_remaining = 100.0
					for frame in 35:
						avatar._physics_process(1.0 / 60.0)
						avatar.animate(false, heading, 1.0 / 60.0, 0.0)
					actor._physics_process(1.0 / 60.0)
					player.play(clip, 0.0)
					player.advance(0.0)
					var previous_y := INF
					for frame in 31:
						var phase := frame / 30.0
						player.seek(player.current_animation_length * phase, true)
						actor._physics_process(1.0 / 60.0)
						actor.contact._process_modification_with_delta(1.0 / 60.0)
						actor.contact.modification_processed.emit()
						rig.force_update_all_bone_transforms()
						var gap := INF
						for skin: Dictionary in skins:
							var clearance := step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
							gap = minf(gap, clearance)
						assert(avatar.position == anchor and actor.native_hue == 0x8035 and is_finite(gap))
						assert(gap >= .0018, "%s %s body=%s x=%s phase=%s gap=%s" % [support, clip, body, x, phase, gap])
						if gap < worst.gap:
							worst = {"gap": gap, "x": x, "phase": phase, "heading": heading}
						var current_y: float = actor.model.global_position.y
						if is_finite(previous_y):
							lift_change = maxf(lift_change, absf(current_y - previous_y))
						previous_y = current_y
						checked += 1
					avatar.free()
			results[support + ":" + clip] = worst.merged({"maximum_lift_change": lift_change})
	for key: String in results:
		print("CREATURE TERRAIN ", body, " ", key, " ", results[key])
	print("RABBIT GAZER SEA HORSE TERRAIN: ", body, " ", checked, " full-skin poses; Enhanced ", enhanced)
	quit(0 if checked == clips.size() * 434 else 1)
