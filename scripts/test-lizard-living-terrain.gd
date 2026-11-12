# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Profile := preload("res://Presentation/SourceLizardLivingTerrainProfile.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Clips := ["Idle", "Walk", "Run", "ClassicOverhead", "Attack2", "Attack3", "Pillage",
	"Hit", "RightGuard", "LeftGuard", "Fidget", "Fidget2"]


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	assert(Profile.enable())
	var board := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(6.0, .20, 6.0)
	collider.shape = slab
	board.add_child(collider)
	root.add_child(board)
	var poses := 0
	for body: int in [35, 36]:
		check_gait_interrupt(body)
		var minima := {}
		var native := Registry.entry(body)
		assert(native.presentation_script == "res://Presentation/SourceLivingArmedLizardVisual.gd")
		for normal: Vector3 in [Vector3.UP, Vector3(.18, 1.0, .1).normalized(), Vector3(-.13, 1.0, .15).normalized()]:
			board.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.10 * normal)
			await physics_frame
			await physics_frame
			for heading: float in [0.0, PI / 2.0, PI]:
				for clip: String in Clips:
					scan(body, heading, clip, normal, minima)
					poses += 17
		for clip: String in minima:
			var sample: Dictionary = minima[clip]
			if sample.body < .0028 or sample.weapon < .024 or sample.maximum_lift > .0011 \
					or sample.maximum_nearest_foot_gap > .056:
				printerr("Armed Lizardman living terrain regression: ", body, " ", clip, " ", sample)
				quit(1)
				return
	assert(poses == 3672)
	print("ARMED LIZARD TERRAIN: ", poses, " active full-skin poses")
	quit()


func scan(body: int, heading: float, clip: String, normal: Vector3, minima: Dictionary) -> void:
	var actor := Registry.create(body)
	actor.rotation.y = heading
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	var native_transform := actor.global_transform
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = actor.skeleton
	var skins := {}
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins[str(mesh.name)] = Ground.skin_points(mesh, rig)
	assert(skins.size() == 2)
	if not minima.has(clip):
		minima[clip] = {"body": INF, "weapon": INF, "maximum_nearest_foot_gap": 0.0, "maximum_lift": 0.0}
	player.play(clip, 0.0)
	actor.current_clip = clip
	player.advance(0.0)
	for frame in 17:
		player.seek(player.current_animation_length * frame / 16.0, true)
		actor._physics_process(1.0 / 60.0)
		assert(actor.contact.contacts.size() == 2)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		actor.contact.modification_processed.emit()
		assert(actor.global_transform == native_transform)
		rig.force_update_all_bone_transforms()
		var nearest := INF
		for foot: Dictionary in actor.contact.feet:
			nearest = minf(nearest, normal.dot(actor.contact.sole(foot)))
		if nearest > minima[clip]["maximum_nearest_foot_gap"]:
			minima[clip]["maximum_nearest_foot_gap"] = nearest
			minima[clip]["worst_stance"] = {
				"heading": heading, "phase": frame / 16.0, "normal": str(normal),
				"skin_minima": skin_minima(skins, rig, normal),
				"contact_gaps": actor.contact.stance_gaps.duplicate(),
				"lift": actor.living_lift,
			}
		minima[clip]["maximum_lift"] = maxf(minima[clip]["maximum_lift"], actor.living_lift)
		for mesh: String in skins:
			var gap := Ground.minimum_plane_gap(skins[mesh], rig, rig.global_transform, Vector3.ZERO, normal)
			var label := "weapon" if mesh in ["Spear", "Mace"] else "body"
			if gap < float(minima[clip][label]):
				minima[clip][label] = gap
				minima[clip][label + "_worst"] = {"heading": heading, "phase": frame / 16.0, "normal": str(normal)}
	actor.queue_free()


func skin_minima(skins: Dictionary, rig: Skeleton3D, normal: Vector3) -> Dictionary:
	var result := {}
	for mesh: String in skins:
		var skin: Dictionary = skins[mesh]
		var matrices: Array[Transform3D] = []
		for bind in skin.bones.size():
			matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
		var gap := INF
		for surface: Dictionary in skin.surfaces:
			for vertex in surface.points.size():
				var point := Vector3.ZERO
				var heaviest := 0.0
				var bone := 0
				for slot in surface.stride:
					var index: int = vertex * surface.stride + slot
					var weight: float = surface.weights[index]
					var bind: int = surface.bindings[index]
					if weight > 0.0:
						point += matrices[bind] * surface.points[vertex] * weight
					if weight > heaviest:
						heaviest = weight
						bone = skin.bones[bind]
				var distance := normal.dot(point)
				if distance < gap:
					gap = distance
					result[mesh] = {"gap": gap, "point": str(point), "bone": rig.get_bone_name(bone)}
	return result


func check_gait_interrupt(body: int) -> void:
	var actor := Registry.create(body)
	root.add_child(actor)
	actor.apply_identity(body, 0)
	assert(actor.receive_action({"protocol": "classic", "action": 18}))
	assert(actor.current_clip == "Fidget2" and actor.action_remaining > 0.0)
	actor.play_gait(true, 5.5)
	assert(actor.current_clip == "Run")
	assert(actor.receive_action({"protocol": "classic", "action": 4}))
	actor.play_gait(true, 5.5)
	assert(actor.current_clip == "ClassicOverhead")
	actor.free()
