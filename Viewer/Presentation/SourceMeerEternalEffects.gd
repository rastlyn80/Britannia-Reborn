# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Body := 772
const Outgoing := 9533
const Returning := 9535
const AreaWarning := 9537


static func caster_for(scene: Node3D, serial: int) -> Node3D:
	var avatar: Node3D = scene.avatars.get(serial)
	if avatar == null or avatar.native_body != Body:
		return null
	var caster: Node3D = avatar.horse_visual
	if not is_instance_valid(caster) or caster.dead or not caster.has_method("cue_life_leech"):
		return null
	return caster


static func cue(scene: Node3D, effect: Dictionary) -> void:
	var warning: bool = effect.kind == "fixed_mobile" and effect.graphic == 0x376a and (
		int(effect.get("tile", 0)) == AreaWarning or not effect.has("tile") and
		effect.speed == 10 and effect.duration == 10 and effect.hue == 33)
	if not outgoing(effect) and not warning:
		return
	var caster := caster_for(scene, int(effect.get("source", 0)))
	if caster != null:
		caster.cue_life_leech()


static func bolt_origin(scene: Node3D, effect: Dictionary) -> Variant:
	if not outgoing(effect):
		return null
	var caster := caster_for(scene, int(effect.get("source", 0)))
	return caster.life_leech_hand() if caster != null else null


static func bolt_target(scene: Node3D, effect: Dictionary) -> Variant:
	if effect.get("kind") != "moving" or effect.get("graphic") != 0x36f4 or not matches_particle(effect, Returning, 32):
		return null
	var caster := caster_for(scene, int(effect.get("target", 0)))
	return caster.life_leech_hand() if caster != null else null


static func outgoing(effect: Dictionary) -> bool:
	return effect.get("kind") == "moving" and effect.get("graphic") == 0x36fa and matches_particle(effect, Outgoing, 1108)


static func matches_particle(effect: Dictionary, particle: int, hue: int) -> bool:
	# ModernUO sends the hued 0xC0 form to clients without particle support.
	if effect.has("tile"):
		return effect.tile == particle
	return effect.speed == 1 and effect.duration == 0 and effect.hue == hue and not effect.explodes
