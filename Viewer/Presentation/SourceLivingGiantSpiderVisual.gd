# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/GiantSpiderActionsVisual.gd"

const Footing := preload("res://Presentation/SourceGiantSpiderGround.gd")
const GaitLoop := preload("res://Presentation/SourceCreatureGaitLoop.gd")


func _ready() -> void:
	super._ready()
	var mesh: MeshInstance3D = contact.surface
	contact.free()
	contact = Footing.new()
	skeleton.add_child(contact)
	contact.setup(self, mesh)
	remove_baked_travel()
	GaitLoop.close_gaits(animator)


func remove_baked_travel() -> void:
	# The server already places the actor. Retain the original leg cycles and
	# vertical body motion while removing the translation of each source stride.
	var root_joint := skeleton.find_bone("dummy01")
	var parent := skeleton.get_bone_parent(root_joint)
	var path := animator.get_node(animator.root_node).get_path_to(skeleton)
	var track_path := NodePath(str(path) + ":dummy01")
	for clip: String in ["Walk", "Run"]:
		animator.play(clip, 0.0)
		animator.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		# The imported parent rotates between Idle and the two gaits.
		var parent_basis := skeleton.global_basis * skeleton.get_bone_global_pose(parent).basis
		var up := (parent_basis.inverse() * Vector3.UP).normalized()
		var motion := animator.get_animation(clip)
		var track := motion.find_track(track_path, Animation.TYPE_POSITION_3D)
		assert(track >= 0 and motion.track_get_key_count(track) > 1)
		var last := motion.track_get_key_count(track) - 1
		var from: Vector3 = motion.track_get_key_value(track, 0)
		var to: Vector3 = motion.track_get_key_value(track, last)
		var start := motion.track_get_key_time(track, 0)
		var span := motion.track_get_key_time(track, last) - start
		for key in last + 1:
			var value: Vector3 = motion.track_get_key_value(track, key)
			var progress := (motion.track_get_key_time(track, key) - start) / span
			var travel := (to - from) * progress
			motion.track_set_key_value(track, key, value - travel.slide(up))
	animator.play("Idle", 0.0)
	animator.advance(0.0)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "AbdomenRock"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		collapse_plane = {}
		contact.prepare_death()
	return accepted


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	if not contact.death.plane.is_empty():
		return contact.death.snapshot_floor(self)
	return super.corpse_snapshot_floor()
