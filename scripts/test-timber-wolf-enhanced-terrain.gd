# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Profile := preload("res://Presentation/SourceTimberWolfProfile.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Wolf := preload("res://Presentation/SourceEnhancedTimberWolfVisual.gd")

var poses := 0
var falls := 0
var lowest_gap := INF
var largest_paw := 0.0
var largest_stance := 0.0
var worst_stance := {}
var largest_jump := 0.0


func _initialize() -> void:
	create_timer(100.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable() and Profile.enable())
	var board := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(4.0, .2, 4.0)
	collider.shape = slab
	board.add_child(collider)
	root.add_child(board)
	for normal: Vector3 in [Vector3.UP, Vector3(.17, 1.0, -.08).normalized(), Vector3(-.13, 1.0, .16).normalized()]:
		board.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.10 * normal)
		await physics_frame
		await physics_frame
		for heading: float in [0.0, PI / 2.0, PI]:
			for style: String in ["original", "rounded", "modern"]:
				for clip: String in Profile.Motions.values():
					if not exercise(clip, heading, board, style):
						return
	print("TIMBER WOLF TERRAIN: ", poses, " poses, ", falls, " fall transfers; min clearance ", lowest_gap,
		" m; max planted-paw gap ", largest_stance, " m; max transition ", largest_jump, " m")
	quit()


func actor(heading: float, style: String) -> Wolf:
	var visual := Profile.Registry.create(Profile.Body) as Wolf
	visual.treatment = style
	visual.rotation.y = heading
	root.add_child(visual)
	visual.apply_identity(Profile.Body, 0)
	visual.set_process(false)
	visual.set_physics_process(false)
	visual.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return visual


func exercise(clip: String, heading: float, board: StaticBody3D, style: String) -> bool:
	var live := actor(heading, style)
	live.current_clip = clip
	live.animator.play(clip, 0.0)
	live.animator.advance(0.0)
	var mesh: Dictionary = live.gesture_ground.skin
	for sample in 17:
		live.animator.seek(live.animator.current_animation_length * sample / 16.0, true)
		live._physics_process(1.0 / 60.0)
		if not expect(live.contact.contacts.size() == 4, "%s samples all four paws" % clip):
			return false
		var hit: Dictionary = live.contact.contacts[0]
		if not expect(hit.collider == board, "%s uses the actual finite plane" % clip):
			return false
		live.contact._process_modification_with_delta(1.0 / 60.0)
		live.contact.modification_processed.emit()
		if not check_skin(live, mesh, hit):
			return false
		var stance := INF
		for foot: Dictionary in live.contact.feet:
			var point: Vector3 = live.contact.sole(foot)
			var gap: float = hit.normal.dot(point - hit.position)
			stance = minf(stance, gap)
			largest_paw = maxf(largest_paw, gap)
		if stance > largest_stance:
			largest_stance = stance
			worst_stance = {"clip": clip, "treatment": style, "sample": sample, "heading": heading,
				"normal": str(hit.normal)}
		if not expect(stance < .03, "%s has a paw within reach of the floor: %.6f" % [clip, stance]):
			return false
		if sample == 6:
			var fallen := actor(heading, style)
			fallen.model.transform = live.model.transform
			var old := joints(live)
			var duration := fallen.begin_death_from(live)
			var first := joints(fallen)
			var jump := 0.0
			for joint in old.size():
				jump = maxf(jump, old[joint].distance_to(first[joint]))
			largest_jump = maxf(largest_jump, jump)
			if not expect(jump < .003 and duration > 0.0 and fallen.fall.plane.get("collider") == board,
					"%s enters the fall from the displayed skin on its plane: %.6f" % [clip, jump]):
				return false
			for step in 13:
				fallen.animator.seek(duration * step / 12.0, true)
				if not check_skin(fallen, mesh, fallen.fall.plane):
					return false
			falls += 1
			fallen.queue_free()
	live.queue_free()
	return true


func joints(wolf: Wolf) -> PackedVector3Array:
	wolf.skeleton.force_update_all_bone_transforms()
	var points := PackedVector3Array()
	for bone in wolf.skeleton.get_bone_count():
		points.append(wolf.skeleton.to_global(wolf.skeleton.get_bone_global_pose(bone).origin))
	return points


func check_skin(wolf: Wolf, mesh: Dictionary, hit: Dictionary) -> bool:
	var rig := wolf.skeleton
	rig.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(mesh, rig, rig.global_transform, hit.position, hit.normal)
	poses += 1
	lowest_gap = minf(lowest_gap, gap)
	return expect(is_finite(gap) and gap > .0017, "%s skin support %.6f m" % [wolf.current_clip, gap])


func expect(value: bool, detail: String) -> bool:
	if not value:
		printerr("TIMBER WOLF TERRAIN FAIL: ", detail)
		quit(1)
	return value
