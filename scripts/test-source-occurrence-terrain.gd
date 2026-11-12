# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Step := .22
const Profile := preload("res://Presentation/SourceOccurrenceTerrainProfile.gd")
const NativeMotions := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget"]
const LivingVariants := {
	208: ["RearStrike", "Eat", "SourceIdle2", "SourcePecking2", "LieDown"],
	52: ["SourceRun", "Eat", "LieDown"],
	138: ["Attack2", "Attack3", "Cast", "Pillage", "Eat", "LieDown"],
	6: ["Attack2", "Attack3", "Cast", "Eat", "LieDown", "TakeOff", "Fly", "Land", "Alert"],
	779: ["SourceRun", "Attack2", "Attack3", "Cast", "Pillage", "Dance", "Eat", "LieDown", "RootGuard", "Uncurl"],
	31: ["Attack2", "Attack3", "Cast", "Pillage", "Eat", "LieDown"],
	29: ["Stomp", "Eat", "LieDown"],
	153: ["Attack2", "Attack3", "Cast", "Pillage", "Eat", "LieDown"],
}
const Corpses := ["Death", "Death2", "AirDeath"]
const Rooted := [8, 47]
const Emergence := {3: "ZombieGraveRise", 8: "Emerge"}
const Flight := ["TakeOff", "Fly", "Land", "Wingbeat", "HarpyBank", "HarpyDoubleWingbeat", "HarpyGlideSettle"]
const HarpyAerial := ["HarpyBank", "HarpyDoubleWingbeat", "HarpyGlideSettle"]


func _initialize() -> void:
	create_timer(110.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var enhanced := "--enhanced-creature-actions" in arguments
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	var body := 0
	for argument: String in arguments:
		if argument.begins_with("--body="):
			body = int(argument.trim_prefix("--body="))
	if not body in Profile.enable():
		printerr("Requested source occurrence profile is unavailable: ", body)
		quit(1)
		return
	var row := Registry.entry(body)
	var motions: Array = ["Idle", "Attack", "Hit", "Fidget"] if body in Rooted else NativeMotions.duplicate()
	motions.append_array(LivingVariants.get(body, []))
	var choices: Array = row.get("classic_action_categories", {}).values() + row.get("archive_grounded_gestures", [])
	if enhanced and body == 30:
		choices.append_array(HarpyAerial)
	if enhanced and body == 6 and Registry.asset_path(row).ends_with("/6-modern.scn"):
		choices.append_array(["BirdGlance", "BirdQuietSettle"])
	for clip: String in choices:
		if not clip in Corpses and not clip in motions and (not body in Rooted or not clip in ["Walk", "Run"]):
			motions.append(clip)
	if body == 39:
		for clip: String in ["TakeOff", "Fly", "Land"]:
			if not clip in motions:
				motions.append(clip)
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(6, Step - .1, 0)
	(upper.get_child(0).shape as BoxShape3D).size = Vector3(12, .2, 16)
	var results := {}
	var checked := 0
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.17, 1.0, -.11).normalized() if support == "slope" else Vector3.UP
		var middle := Vector3(-6, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), middle - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size = Vector3(12 if split else 24, .2, 16)
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for clip: String in motions:
			var worst := {"gap": INF}
			var lift_change := 0.0
			for x: float in ([-.48, -.21, -.03, .15, .46] if split else [0.0]):
				for heading: float in [PI * .5, PI * 1.5]:
					var actor := Registry.create(body)
					root.add_child(actor)
					actor.set_process(false)
					actor.set_physics_process(false)
					actor.apply_identity(body, 0x8035)
					var rig: Skeleton3D = actor.skeleton
					var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
					var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
					if body == 208:
						for part: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
							if part != mesh and part.skin != null and part.is_visible_in_tree():
								skins.append(Ground.skin_points(part, rig))
						assert(skins.size() == 2)
					if body == 138:
						var axe := actor.model.find_child("OrcLordAxe", true, false) as MeshInstance3D
						assert(axe != null and axe.skin != null)
						skins.append(Ground.skin_points(axe, rig))
					var player: AnimationPlayer = actor.animator
					player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					var anchor := Vector3(x, Step if split and x > 0.0 else 0.0, 0)
					actor.position = anchor
					actor.rotation.y = heading
					actor.current_clip = clip
					actor.contact.enabled = clip not in Flight or (body == 30 and clip == "Land")
					actor._physics_process(1.0 / 60.0)
					player.play(clip, 0.0)
					player.advance(0.0)
					var previous_y := INF
					var intentionally_buried: bool = clip == Emergence.get(body, "")
					for frame in 31:
						var phase := frame / 30.0
						player.seek(player.current_animation_length * phase, true)
						actor._physics_process(1.0 / 60.0)
						actor.contact._process_modification_with_delta(1.0 / 60.0)
						actor.contact.modification_processed.emit()
						rig.force_update_all_bone_transforms()
						var gap := INF
						for skin: Dictionary in skins:
							gap = minf(gap, step_gap(skin, rig) if split else Ground.minimum_plane_gap(
								skin, rig, rig.global_transform, Vector3.ZERO, normal))
						assert(actor.position == anchor and actor.native_hue == 0x8035 and is_finite(gap))
						if intentionally_buried and frame == 0:
							assert(gap < -.25, "The original emergence lost its buried start.")
						if not intentionally_buried or frame == 30:
							assert(gap >= .002, "%s %s %s frame %d: gap %.6f" % [body, support, clip, frame, gap])
						if gap < worst.gap:
							worst = {"gap": gap, "x": x, "phase": phase, "heading": heading}
						var current_y: float = actor.model.global_position.y
						if is_finite(previous_y):
							lift_change = maxf(lift_change, absf(current_y - previous_y))
						previous_y = current_y
						checked += 1
					actor.free()
			results[support + ":" + clip] = worst.merged({"maximum_lift_change": lift_change})
	if body == 52:
		assert(float(results["step:Run"].maximum_lift_change) < .13)
		assert(float(results["step:Attack"].maximum_lift_change) < .14)
	var evidence := OS.get_environment("BR_OCCURRENCE_METRICS")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence, FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "  "))
		file.close()
	print("OCCURRENCE TERRAIN: ", body, " ", checked, " full-skin poses, ", motions.size(), " clips; Enhanced ", enhanced)
	quit(0 if checked == motions.size() * 434 else 1)



func floor_box() -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, .2, 8)
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body


func step_gap(skin: Dictionary, rig: Skeleton3D) -> float:
	var matrices: Array[Transform3D] = []
	for index in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
	var minimum := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			for influence in surface.stride:
				var slot: int = vertex * surface.stride + influence
				var weight: float = surface.weights[slot]
				if weight > 0.0:
					point += (matrices[surface.bindings[slot]] * surface.points[vertex]) * weight
			minimum = minf(minimum, point.y - (Step if point.x >= 0.0 else 0.0))
	return minimum
