# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Recover the original root scale when a retained clip has no scale channel.

var active := false
var leaving_scale := Vector3.ONE


func apply(actor: Node3D, growth_clip: String) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var root := rig.find_bone("__root")
	if actor.current_clip == growth_clip:
		active = true
		leaving_scale = rig.get_bone_pose_scale(root)
		return false
	if not active:
		return false
	var speed := maxf(.001, absf(actor.animator.get_playing_speed()))
	var elapsed: float = actor.animator.current_animation_position / speed
	var blend := smoothstep(0.0, .22, elapsed)
	rig.set_bone_pose_scale(root, leaving_scale.lerp(Vector3.ONE, blend))
	rig.force_update_all_bone_transforms()
	active = blend < 1.0
	return true

