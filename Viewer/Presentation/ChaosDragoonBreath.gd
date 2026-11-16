# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const SwampDragon := preload("res://Presentation/SourceSwampDragonVisual.gd")
const HumanBody := 400
const Names := ["a chaos dragoon", "a chaos dragoon elite"]
const MountItems := [0x3ebd, 0x3ebe]
const DragonHelm := 0x2645
const ChaosShield := 0x1bc3
const BreathClip := "dragoon/FireBreath"
const BreathDuration := 2.05


static func dispatch(avatar: Node3D, request: Dictionary, server_name: String) -> bool:
	if request.get("protocol") != "classic" or request.get("action") != 12 \
			or request.get("frames") != 5 or request.get("repeat_count") != 1 \
			or request.get("reverse") != false or request.get("repeat") != false or request.get("delay") != 0:
		return false
	if int(request.get("body", 0)) != HumanBody or server_name.to_lower() not in Names:
		return false
	var mount := mounted_dragon(avatar)
	if mount == null:
		return false
	var helm := false
	var shield := false
	for item: Dictionary in avatar.server_appearance.get("equipment", []):
		helm = helm or (item.get("layer") == 6 and item.get("id") == DragonHelm)
		shield = shield or (item.get("layer") == 2 and item.get("id") == ChaosShield)
	return helm and shield and start_mount_breath(mount)


static func start_mount_breath(mount: SwampDragon) -> bool:
	if mount.dead or not mount.animator.has_animation("Attack2"):
		return false
	var animator: AnimationPlayer = mount.animator
	if not animator.has_animation(BreathClip):
		var library := AnimationLibrary.new()
		library.add_animation("FireBreath", animator.get_animation("Attack2"))
		animator.add_animation_library("dragoon", library)
	mount.current_clip = BreathClip
	mount.contact.enabled = true
	mount.action_remaining = BreathDuration
	animator.speed_scale = 1.0
	animator.play(BreathClip, .12, animator.get_animation(BreathClip).length / BreathDuration)
	animator.seek(0.0, false)
	return true


static func origin(avatar: Node3D, effect: Dictionary) -> Variant:
	if effect.get("kind") != "moving" or effect.get("hue", 0) != 0 or effect.get("explodes", false):
		return null
	var mount := mounted_dragon(avatar)
	if mount == null or mount.dead or mount.current_clip != BreathClip or mount.action_remaining <= 0.0:
		return null
	mount.skeleton.force_update_all_bone_transforms()
	return mount.socket("mouth").origin


static func mounted_dragon(avatar: Node3D) -> SwampDragon:
	if avatar == null or avatar.native_body != HumanBody or avatar.human_visual == null \
			or not avatar.human_visual.mounted_live_enabled or avatar.retiring_horse:
		return null
	var mount := avatar.horse_visual as SwampDragon
	if not is_instance_valid(mount) or not mount.is_visible_in_tree() or mount.native_mount_item not in MountItems:
		return null
	return mount
