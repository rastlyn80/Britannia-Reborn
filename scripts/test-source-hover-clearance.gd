# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Profile := preload("res://Presentation/SourceOccurrenceTerrainProfile.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Step := .22
const AirMotions := ["Attack", "Attack2", "Attack3", "Cast", "Cast2", "Cast3", "Fidget", "Hit", "Hit2", "Idle", "Pillage", "Run", "Walk", "Eat", "LieDown", "ElementalOverhead", "ElementalHeldReach",
	"GustSway", "CloudBrace", "WindScatter"]
const AirFits := ["AirSpreadAlert", "AirVortexFormation"]
const FireMotions := ["Attack", "Attack2", "Attack3", "Cast", "Cast2", "Cast3", "Fidget", "Hit", "Hit2",
	"Idle", "Pillage", "Run", "Walk", "Eat", "LieDown", "ElementalOverhead", "ElementalHeldReach",
	"EmberFlinch", "FlameGuard", "FlareSpread"]
const FireFits := ["FireCrownAlert", "FireKindleAndRise"]
const WispMotions := ["Idle", "Walk", "Run", "Attack", "Attack2", "Attack3", "Hit", "Fidget", "Fidget2",
	"Cast", "Eat", "Pillage", "Alert", "LieDown", "TallFlare", "SplitFlicker", "RayDrift"]


func _initialize() -> void:
	create_timer(290.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var enhanced := "--enhanced-creature-actions" in arguments
	var body := 0
	for argument: String in arguments:
		if argument.begins_with("--body="):
			body = int(argument.trim_prefix("--body="))
	if enhanced and not preload("res://Presentation/EnhancedCreatureProfile.gd").enable():
		quit(1)
		return
	if body not in [13, 15, 58] or body not in Profile.enable():
		push_error("Requested hover terrain renderer is unavailable.")
		quit(1)
		return
	var motions := WispMotions if body == 58 else (FireMotions if body == 15 else AirMotions)
	if body == 15 and enhanced and Registry.asset_path(Registry.entry(body)).ends_with("/15-modern.scn"):
		motions = motions + FireFits
	if body == 13 and enhanced and Registry.asset_path(Registry.entry(body)).ends_with("/13-modern.scn"):
		motions = motions + AirFits
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(2, Step - .1, 0)
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
		for clip: String in motions:
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
					var skins := {}
					for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
						if mesh.skin != null:
							skins[mesh] = Ground.skin_points(mesh, rig)
					assert(not skins.is_empty())
					var dust := actor.model.find_child("Ash" if body == 15 else "Dust", true, false) as MeshInstance3D
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
					for frame in 31:
						var phase := frame / 30.0
						player.seek(player.current_animation_length * phase, true)
						actor._physics_process(1.0 / 60.0)
						actor.contact._process_modification_with_delta(1.0 / 60.0)
						actor.contact.modification_processed.emit()
						rig.force_update_all_bone_transforms()
						var gap := INF
						for mesh: MeshInstance3D in skins:
							if not mesh.is_visible_in_tree():
								continue
							var skin: Dictionary = skins[mesh]
							var clearance := step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
							gap = minf(gap, clearance)
						if dust != null and dust.visible:
							gap = minf(gap, rigid_gap(dust, normal, split))
						if avatar.position != anchor or actor.native_hue != 0x8035 or not is_finite(gap) or gap < .0015:
							push_error("Hover body %d %s %s x=%f phase=%f gap=%f" % [body, support, clip, x, phase, gap])
							quit(1)
							return
						checked += 1
					avatar.free()
	print("HOVER TERRAIN: ", body, " ", checked, " complete geometry samples; Enhanced ", enhanced)
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


func rigid_gap(mesh: MeshInstance3D, normal: Vector3, split: bool) -> float:
	var gap := INF
	for surface in mesh.mesh.get_surface_count():
		for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var point := mesh.to_global(vertex)
			gap = minf(gap, point.y - (Step if point.x >= 0.0 else 0.0) if split else normal.dot(point))
	return gap
