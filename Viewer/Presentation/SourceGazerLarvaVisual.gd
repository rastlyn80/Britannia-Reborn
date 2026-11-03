extends "res://Presentation/CreatureVisual.gd"
## The source hover and the paired affine factors remain in the saved clips.

const DEATH_ENTRY_SECONDS := 0.08

func _physics_process(_delta: float) -> void:
	# The server owns this mobile's height. Terrain must not plant or tilt its cards.
	pass

func begin_death_from(source: Node3D) -> float:
	var death := animator.get_animation("Death")
	animator.stop()
	animator.speed_scale = 1.
	animator.play("Death", 0.)
	animator.seek(0., true)
	animator.advance(0.)

	# Keep the exact original Death library intact. A separate short clip joins
	# the currently displayed pose to the first native death frame.
	var entry_animation := Animation.new()
	entry_animation.length = DEATH_ENTRY_SECONDS
	var animation_root := animator.get_node(animator.root_node)
	var rig_path := str(animation_root.get_path_to(skeleton))
	for bone in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(bone)
		var from: int = source.skeleton.find_bone(name)
		assert(from >= 0)
		var path := NodePath(rig_path + ":" + name)
		var position := entry_animation.add_track(Animation.TYPE_POSITION_3D)
		var rotation := entry_animation.add_track(Animation.TYPE_ROTATION_3D)
		var scale := entry_animation.add_track(Animation.TYPE_SCALE_3D)
		entry_animation.track_set_path(position, path)
		entry_animation.track_set_path(rotation, path)
		entry_animation.track_set_path(scale, path)
		entry_animation.position_track_insert_key(position, 0., source.skeleton.get_bone_pose_position(from))
		entry_animation.rotation_track_insert_key(rotation, 0., source.skeleton.get_bone_pose_rotation(from))
		entry_animation.scale_track_insert_key(scale, 0., source.skeleton.get_bone_pose_scale(from))
		entry_animation.position_track_insert_key(position, DEATH_ENTRY_SECONDS, skeleton.get_bone_pose_position(bone))
		entry_animation.rotation_track_insert_key(rotation, DEATH_ENTRY_SECONDS, skeleton.get_bone_pose_rotation(bone))
		entry_animation.scale_track_insert_key(scale, DEATH_ENTRY_SECONDS, skeleton.get_bone_pose_scale(bone))
	var library := AnimationLibrary.new()
	library.add_animation("Blend", entry_animation)
	animator.add_animation_library("gazer_death_entry", library)
	animator.play("gazer_death_entry/Blend", 0.)
	animator.seek(0., true)
	animator.advance(0.)
	animator.queue("Death")
	action_remaining = DEATH_ENTRY_SECONDS + death.length
	return action_remaining
