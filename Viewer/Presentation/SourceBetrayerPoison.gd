# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 767
const GasGraphic := 0x376a
const GasParticle := 0x2539
const LeftHand := 2


static func source(scene: Node3D, effect: Dictionary) -> Node3D:
	if effect.kind != "fixed_mobile" or effect.graphic != GasGraphic:
		return null
	if effect.has("tile"):
		if effect.tile != GasParticle or effect.layer != LeftHand:
			return null
	elif effect.speed != 9 or effect.duration != 32 or effect.hue != 0:
		# Clients without particle support receive the native hued effect.
		return null
	var avatar: Node3D = scene.avatars.get(int(effect.source))
	if avatar == null or avatar.native_body != Body:
		return null
	var caster: Node3D = avatar.horse_visual
	if caster == null or caster.dead or not caster.has_method("poison_gas_origin") or caster.poison_socket < 0:
		return null
	return caster
