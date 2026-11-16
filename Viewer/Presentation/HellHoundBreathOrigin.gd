# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Avatar := preload("res://Presentation/HumanAvatar.gd")


static func holds_melee(creature: Node3D, request: Dictionary) -> bool:
	if request.get("body") != 98 or not is_instance_valid(creature) \
			or not creature.has_method("fire_breath_origin"):
		return false
	var melee: bool = (request.get("protocol") == "classic" and request.get("action") in [5, 6]) \
		or (request.get("protocol") == "new" and request.get("type") == 0)
	return melee and creature.fire_breath_origin() is Vector3


static func resolve(scene: Node3D, effect: Dictionary) -> Variant:
	if int(effect.graphic) != 0x36d4:
		return null
	var avatar := scene.avatars.get(int(effect.source)) as Avatar
	if avatar == null or avatar.native_body not in [98, 206] or not is_instance_valid(avatar.horse_visual):
		return null
	var creature: Node3D = avatar.horse_visual
	return creature.fire_breath_origin() if creature.has_method("fire_breath_origin") else null
