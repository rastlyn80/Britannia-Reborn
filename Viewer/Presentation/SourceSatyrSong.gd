# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Sounds := [0x58a, 0x58c, 0x58d]
const Body := 271


static func cue(scene: Node3D, sound: Dictionary) -> void:
	if scene.game.phase != "world" or sound.get("id", 0) not in Sounds:
		return
	# Sound packets identify a tile, so ambiguity leaves the normal audio alone.
	var singer: Node3D
	for serial: int in scene.avatars:
		var entity: Dictionary = scene.game.entities.get(serial, {})
		if entity.get("body", 0) != Body or entity.x != sound.x or entity.y != sound.y or entity.z != sound.z:
			continue
		var actor: Node3D = scene.avatars[serial].horse_visual
		if not is_instance_valid(actor) or actor.dead or not actor.has_method("cue_bard_song"):
			continue
		if singer != null:
			return
		singer = actor
	if singer != null:
		singer.cue_bard_song()
