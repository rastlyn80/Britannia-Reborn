# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Clips := ["Idle", "Walk", "Run", "WideSwipe", "Attack", "RisingSweep", "KneelingSwing",
	"Hit", "OverheadGuard", "ShoulderGuard", "Fidget", "KnuckleCheck"]


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var enhanced := "--enhanced" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(preload("res://Presentation/SourceTrollLivingTerrainProfile.gd").enable())
	var board := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(6.0, .20, 6.0)
	collider.shape = slab
	board.add_child(collider)
	root.add_child(board)
	var poses := 0
	for body: int in [53, 54, 55]:
		var minima := {}
		var native := Registry.entry(body)
		assert(str(native.kind).begins_with("trolls_troll"))
		var selected: Array = Clips.duplicate()
		if enhanced:
			selected.append_array(native.get("archive_grounded_gestures", []))
		for normal: Vector3 in [Vector3.UP, Vector3(.18, 1.0, .1).normalized(), Vector3(-.13, 1.0, .15).normalized()]:
			board.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.10 * normal)
			await physics_frame
			await physics_frame
			for heading: float in [0.0, PI / 2.0, PI]:
				for clip: String in selected:
					scan(body, heading, clip, normal, minima)
					poses += 17
		print("TROLL LIVING TERRAIN ", body, " ", minima.size(), " retained and fitted clips")
	assert(poses == (7803 if enhanced else 5508))
	print("TROLL LIVING TERRAIN: ", poses, " full-skin poses")
	quit()


func scan(body: int, heading: float, clip: String, normal: Vector3, minima: Dictionary) -> void:
	var actor := Registry.create(body)
	actor.rotation.y = heading
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = actor.skeleton
	var skins := {}
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins[str(mesh.name)] = {"node": mesh, "skin": Ground.skin_points(mesh, rig)}
	assert(not skins.is_empty())
	if not minima.has(clip):
		minima[clip] = {}
	player.play(clip, 0.0)
	actor.current_clip = clip
	player.advance(0.0)
	for frame in 17:
		player.seek(player.current_animation_length * frame / 16.0, true)
		actor._physics_process(1.0 / 60.0)
		assert(actor.contact.contacts.size() == 2)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		actor.contact.modification_processed.emit()
		rig.force_update_all_bone_transforms()
		var nearest := INF
		for foot: Dictionary in actor.contact.feet:
			nearest = minf(nearest, normal.dot(actor.contact.sole(foot)))
		minima[clip]["nearest_foot_max_m"] = maxf(nearest, minima[clip].get("nearest_foot_max_m", 0.0))
		if actor.living_lift > float(minima[clip].get("visual_lift_max_m", 0.0)):
			minima[clip]["visual_lift_max_m"] = actor.living_lift
			minima[clip]["lift_worst"] = {
				"heading": heading, "phase": frame / 16.0, "normal": str(normal),
				"stance": actor.contact.stance_gaps.duplicate(),
				"body": skin_floor(skins["Body"].skin, rig, normal),
			}
		for mesh: String in skins:
			if not skins[mesh].node.is_visible_in_tree():
				continue
			var gap := Ground.minimum_plane_gap(skins[mesh].skin, rig, rig.global_transform, Vector3.ZERO, normal)
			assert(is_finite(gap) and gap >= .0029 and actor.living_lift < .002)
			var label := mesh
			if gap < float(minima[clip].get(label, INF)):
				minima[clip][label] = gap
				minima[clip][label + "_worst"] = {"heading": heading, "phase": frame / 16.0, "normal": str(normal)}
	actor.free()


func skin_floor(skin: Dictionary, rig: Skeleton3D, normal: Vector3) -> Dictionary:
	var transforms: Array[Transform3D] = []
	for bind in skin.bones.size():
		transforms.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
	var minimum := INF
	var result := {}
	for surface: Dictionary in skin.surfaces:
		for vertex: int in surface.points.size():
			var point := Vector3.ZERO
			var influences := {}
			for slot in surface.stride:
				var index: int = vertex * surface.stride + slot
				var weight: float = surface.weights[index]
				var bind: int = surface.bindings[index]
				if weight > 0.0:
					point += transforms[bind] * surface.points[vertex] * weight
					influences[rig.get_bone_name(skin.bones[bind])] = weight
			var gap := normal.dot(point)
			if gap < minimum:
				minimum = gap
				result = {"point": str(point), "weights": influences, "gap": gap}
	return result
