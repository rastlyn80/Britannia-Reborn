# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const MeerLeech := preload("res://Presentation/SourceMeerEternalEffects.gd")
const SnowWind := preload("res://Presentation/SourceSnowLadyWind.gd")
const LifeDrain := preload("res://Presentation/SourceLifeDrainNotice.gd")
const SatyrSong := preload("res://Presentation/SourceSatyrSong.gd")
const BetrayerPoison := preload("res://Presentation/SourceBetrayerPoison.gd")
func configure(effects: Node3D, world_scene: Node3D) -> void:
	presenter = effects
	scene = world_scene
	scene.game.module("messages").localized_speech.connect(on_creature_notice)
	scene.game.module("environment").sound.connect(on_creature_sound)


func on_creature_sound(sound: Dictionary) -> void:
	SatyrSong.cue(scene, sound)


func on_creature_notice(_serial: int, _graphic: int, _kind: int, cliloc: int) -> void:
	SnowWind.present(presenter, cliloc)
	LifeDrain.present(presenter, cliloc)


var scene: Node3D
var presenter: Node3D


func present(effect: Dictionary) -> bool:
	if scene == null or scene.game.phase != "world":
		return false
	MeerLeech.cue(scene, effect)
	var betrayer := BetrayerPoison.source(scene, effect)
	if betrayer == null:
		return false
	mobile_bloom(betrayer.poison_gas_origin(), presenter.COLOURS.poison, effect, 0, betrayer.poison_gas_origin)
	return true


func bolt_origin(effect: Dictionary) -> Variant:
	var leech: Variant = MeerLeech.bolt_origin(scene, effect)
	if leech is Vector3:
		return leech
	if int(effect.graphic) != 0x36d4:
		return null
	var avatar: Node3D = scene.avatars.get(int(effect.source))
	if avatar == null or avatar.native_body != 276:
		return null
	var creature: Node3D = avatar.horse_visual
	return creature.fire_breath_origin() if is_instance_valid(creature) and creature.has_method("fire_breath_origin") else null


func mobile_bloom(at: Vector3, tint: Color, effect: Dictionary, follow: int, origin := Callable()) -> void:
	var seconds := clampf(float(effect.get("duration",10))*0.1,0.6,3.0)
	var bloom: GPUParticles3D = presenter.sparks(tint,70,0.9,0.35,1.2)
	bloom.position = at
	bloom.local_coords = not origin.is_valid()
	presenter.add_child(bloom)
	# A soft halo at the heart of the effect.
	var halo := MeshInstance3D.new()
	halo.mesh = QuadMesh.new()
	halo.mesh.size = Vector2(1.4,1.4)
	halo.material_override = presenter._glow(Color(tint,0.55),2.5)
	bloom.add_child(halo)
	var light: OmniLight3D = presenter._light(at+Vector3.UP*0.3,tint,2.2,4.5)
	if origin.is_valid():
		var track := func():
			if origin.is_valid() and is_instance_valid(bloom) and is_instance_valid(light):
				bloom.global_position = origin.call()
				light.global_position = bloom.global_position
		presenter.get_tree().process_frame.connect(track)
		presenter.get_tree().create_timer(seconds+0.5).timeout.connect(func(): presenter.get_tree().process_frame.disconnect(track))
	elif follow and scene.avatars.has(follow):
		var target: Node3D = scene.avatars[follow]
		var track := func():
			if is_instance_valid(target) and is_instance_valid(bloom):
				bloom.global_position = target.global_position+Vector3.UP*1.0
				light.global_position = bloom.global_position
		presenter.get_tree().process_frame.connect(track)
		presenter.get_tree().create_timer(seconds+0.9).timeout.connect(func(): presenter.get_tree().process_frame.disconnect(track))
	presenter.get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(bloom): bloom.emitting = false)
	presenter.create_tween().tween_property(light,"light_energy",0.0,seconds+0.4)
	presenter._expire(bloom,seconds+1.0)
	presenter._expire(light,seconds+0.5)


func leech_target(effect: Dictionary) -> Variant:
	return MeerLeech.bolt_target(scene, effect)
