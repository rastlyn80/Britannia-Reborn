# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const DonorProfile := preload("res://Presentation/SourceGiantSerpentProfile.gd")
const Profile := preload("res://Presentation/SourceSilverSerpentProfile.gd")
const Donor := preload("res://Presentation/SourceEnhancedGiantSerpentVisual.gd")
const Serpent := preload("res://Presentation/SourceEnhancedSilverSerpentVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")

var poses := 0
var transfers := 0
var highest_jump := 0.
var lowest_gap := INF


func _initialize() -> void:
	create_timer(120.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if not require(preload("res://Presentation/EnhancedCreatureProfile.gd").enable() and DonorProfile.enable() and Profile.enable(),
			"the preceding Enhanced scenes and added Giant Serpent clips load"):
		return
	var board := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(20., .2, 20.)
	collider.shape = slab
	board.add_child(collider)
	root.add_child(board)
	for normal: Vector3 in [Vector3.UP, Vector3(.18, 1., .09).normalized(), Vector3(-.13, 1., .17).normalized()]:
		board.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.10 * normal)
		await physics_frame
		await physics_frame
		for style: String in ["original", "rounded", "modern"]:
			for angle: float in [0., PI / 2., PI]:
				if not sample_routes(style, angle, board):
					return
				for phase: Array in [[-1, .25], [-2, .25], [0, .38], [1, .67]]:
					if not check_transfer(style, angle, board, phase[0], phase[1]):
						return
	var off := spawn("modern", 0., Vector3(30., 0., 0.))
	off._physics_process(.016)
	assert(not off.living_floor.has("collider"))
	off.free()
	print("SILVER SERPENT TERRAIN: ", poses, " finite-plane full-skin poses, ", transfers,
		" fall transfers, min adjusted gap ", lowest_gap, " m, max handoff ", highest_jump, " m")
	quit()


func spawn(style: String, angle: float, at := Vector3.ZERO) -> Serpent:
	var actor := Profile.Registry.create(Profile.Body) as Serpent
	actor.treatment = style
	actor.position = at
	actor.rotation.y = angle
	root.add_child(actor)
	actor.apply_identity(Profile.Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func sample_routes(style: String, angle: float, board: StaticBody3D) -> bool:
	var actor := spawn(style, angle)
	actor._physics_process(.016)
	if not require(actor.living_floor.get("collider") == board, "the actual finite test plane is sampled"):
		return false
	var floor_data := actor.living_floor
	for clip: String in Donor.Groups.values():
		if clip in ["Death", "Death2"]:
			continue
		actor.current_clip = clip
		actor.animator.play(clip, 0.)
		actor.animator.advance(0.)
		for frame in 17:
			var phase := float(frame) / 16.
			actor.animator.seek(actor.animator.current_animation_length * phase, true)
			actor.apply_ground()
			var depth := .73 * (1. - smoothstep(.03, .85, phase)) if clip == Donor.Surface else 0.
			if not check_gap(actor, floor_data, depth):
				return false
	actor.free()
	return true


func check_transfer(style: String, angle: float, board: StaticBody3D, variant: int, phase: float) -> bool:
	var source := spawn(style, angle)
	var target := spawn(style, angle)
	source._physics_process(.016)
	if variant >= 0:
		var action := {"protocol": "new", "body": Profile.Body, "type": 3, "variation": variant}
		if not require(source.receive_enhanced_action(action, 0x40), "the Enhanced fall request plays"):
			return false
	elif variant == -2:
		var action := {"protocol": "new", "body": Profile.Body, "type": 15, "variation": 0}
		if not require(source.receive_enhanced_action(action, 0), "the surfacing request plays"):
			return false
	else:
		source.play_gait(true, 1.8)
	source.animator.advance(.14)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	source.apply_ground()
	var before := joints(source)
	target.model.transform = source.model.transform
	var remaining := target.begin_death_from(source)
	var after := joints(target)
	var jump := 0.
	for index in before.size():
		jump = maxf(jump, before[index].distance_to(after[index]))
	highest_jump = maxf(highest_jump, jump)
	if not require(jump < .003 and remaining > 0., "fall preserves the displayed joints for variant %d, jump %.6f m" % [variant, jump]):
		return false
	if not require(target.fall.plane.get("collider") == board, "the handoff keeps the sampled finite plane"):
		return false
	var start := target.animator.current_animation_position
	var finish := target.animator.current_animation_length
	for frame in 17:
		var time := lerpf(start, finish, float(frame) / 16.)
		target.animator.seek(time, true)
		target.apply_ground()
		var depth := 0.
		if variant == -2 and target.fall.blend_length > 0.:
			depth = target.fall.initial_depth * (1. - smoothstep(0., target.fall.blend_length, time))
		if not check_gap(target, target.fall.plane, depth):
			return false
	transfers += 1
	source.free()
	target.free()
	return true


func joints(actor: Serpent) -> PackedVector3Array:
	var values := PackedVector3Array()
	var rig := actor.skeleton
	rig.force_update_all_bone_transforms()
	for index in rig.get_bone_count():
		values.append(rig.to_global(rig.get_bone_global_pose(index).origin))
	return values


func check_gap(actor: Serpent, floor_data: Dictionary, depth: float) -> bool:
	var rig := actor.skeleton
	rig.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(actor.support_skin, rig, rig.global_transform, floor_data.position, floor_data.normal)
	lowest_gap = minf(lowest_gap, gap + depth)
	poses += 1
	return require(is_finite(gap) and gap + depth >= .0018, "%s full skin clears its support, gap %.6f m" % [actor.current_clip, gap + depth])


func require(value: bool, detail: String) -> bool:
	if not value:
		printerr("SILVER SERPENT TERRAIN FAIL: ", detail)
		quit(1)
	return value
