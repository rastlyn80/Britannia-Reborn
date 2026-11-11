# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Bake := preload("bake-gargoyle-destroyer-enhanced.gd")
const RendererPath := "res://Presentation/SourceEnhancedArmoredGargoyleVisual.gd"
const Renderer := preload(RendererPath)
const PresenterPath := "res://Presentation/SourceEnhancedArmoredGargoyleProjectilePresenter.gd"
const Presenter := preload(PresenterPath)
const Dispatch := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Effects := preload("res://Network/Packets/Effects.gd")

class EmptyItems extends RefCounted:
	var nodes := {}


class Arena extends Node3D:
	var avatars := {}
	var game: Node
	var world_items := EmptyItems.new()

	func entity_point(x: int, y: int, z: int) -> Vector3:
		return Vector3(x, .1 * z, y)


static func source_routes() -> Dictionary:
	var clips := Bake.CommonClips
	return {"0": {"2": [clips[15], clips[15]], "3": ["Death", "Death2"], "4": ["Hit"],
		"5": [clips[26], clips[27]], "8": [clips[28]], "11": [clips[4], clips[4], clips[4]],
		"14": [clips[11]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func source_attacks() -> Dictionary:
	var clips := Bake.CommonClips
	return {"0": [clips[4], clips[5], clips[4]], "1": [clips[4]], "2": [clips[4]], "9": [clips[4]],
		"255": [clips[4], clips[5], clips[4], clips[4], clips[4], clips[4]]}


static func fitted_row(body: int) -> Dictionary:
	var row := Registry.entry(body).duplicate(true)
	row.archive_grounded_gestures.append_array(Bake.review_clips(body).values())
	row.enhanced_source_action_groups = source_routes()
	row.enhanced_attack_subactions = source_attacks()
	row.presentation_script = RendererPath
	for treatment: String in row.assets:
		row.assets[treatment] = Bake.destination(body) + "%d-%s.scn" % [body, treatment]
	return row


func _initialize() -> void:
	create_timer(100.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var game := Game.new()
	arena.add_child(game)
	arena.game = game
	game.set_process(false)
	game.phase = "world"
	var effects := Presenter.new()
	arena.add_child(effects)
	effects.configure(arena)
	var checks := 0
	var report := {}
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	for body in [755, 754]:
		var row := Registry.entry(body) if installed else fitted_row(body)
		assert(row.presentation_script == RendererPath and row.enhanced_source_action_groups == source_routes())
		var hashes := {}
		for treatment: String in row.assets:
			var visual := Renderer.new()
			visual.entry = row
			visual.treatment = treatment
			arena.add_child(visual)
			visual.apply_identity(body, 0x8035)
			visual.set_physics_process(false)
			visual.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var avatar := Avatar.new()
			arena.add_child(avatar)
			avatar.set_physics_process(false)
			avatar.set_process(false)
			avatar.native_body = body
			avatar.horse_visual = visual
			arena.avatars[body] = avatar
			game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
			checks += check_modes(game, avatar, body)
			checks += check_effect(effects, visual, body)
			visual.action_remaining = 0.0
			visual.dead = false
			var air := {"serial": body, "body": body, "protocol": "classic", "action": 21, "frames": 8,
				"repeat_count": 1, "reverse": false, "repeat": false, "delay": 0}
			assert(Dispatch.dispatch(avatar, air, true, 4))
			assert(visual.current_clip == "AirDeath" and visual.dead and not visual.contact.enabled)
			checks += 2
			arena.avatars.erase(body)
			avatar.free()
			visual.free()
			hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
		report[str(body)] = hashes
	var receipt := FileAccess.open(Bake.destination(755) + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null and checks == 2034)
	receipt.store_string(JSON.stringify({"checks": checks, "scenes": report,
		"renderer_sha256": FileAccess.get_sha256(RendererPath),
		"presenter_sha256": FileAccess.get_sha256(PresenterPath)}, "\t"))
	receipt.close()
	print("ARMORED GARGOYLE RUNTIME: ", checks, " checks ", report)
	await process_frame
	arena.free()
	quit()


func check_modes(game: Node, avatar: Node3D, body: int) -> int:
	var visual: Node3D = avatar.horse_visual
	var checks := 0
	for flags in [0, 64, 4, 68]:
		visual.set_native_combat_flags(flags)
		visual.action_remaining = 0.0
		var flying: bool = (flags & 4) != 0
		var peace: bool = (flags & 64) == 0
		visual.play_gait(false, 0.0)
		assert(visual.current_clip == ("Fly" if flying else "GargoyleQuietHover" if peace else "Idle"))
		visual.play_gait(true, 1.8)
		assert(visual.current_clip == ("Fly" if flying else "GargoylePeaceWalk" if peace else "Walk"))
		assert(visual.contact.enabled != flying)
		checks += 3
		var routes := source_routes()
		for type: String in routes["0"]:
			for variant in [0, 1, 2, 5, 127]:
				visual.dead = false
				var choices: Array = routes["0"][type]
				if (flying or peace) and type == "5":
					choices = routes["1"][type]
				var decoded := decode(game, body, int(type), 0, variant)
				assert(Dispatch.dispatch(avatar, decoded, true, flags))
				assert(visual.current_clip == choices[variant % choices.size()],
					"body %d flags %d type %s variation %d actual %s expected %s" %
						[body, flags, type, variant, visual.current_clip, choices[variant % choices.size()]])
				assert(visual.get_meta("native_action") == decoded)
				checks += 1
		for subaction: int in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
			for variant in [0, 1, 2, 5, 127]:
				visual.dead = false
				var attacks := source_attacks()
				var choices: Array = attacks.get(str(subaction & 0xff), attacks["255"])
				var decoded := decode(game, body, 0, subaction, variant)
				assert(Dispatch.dispatch(avatar, decoded, true, flags) and visual.current_clip == choices[variant % choices.size()])
				checks += 1
	visual.set_native_combat_flags(0)
	visual.action_remaining = 0.0
	visual.dead = false
	visual.play_gait(true, 5.5)
	assert(visual.current_clip == "Run")
	return checks + 1


func check_effect(presenter: Node3D, visual: Node3D, body: int) -> int:
	visual.dead = false
	var previous: String = visual.current_clip
	var wrong := effect_packet(2, body, 0, 0x3728, 10, 14)
	presenter.present(Effects.parse(wrong))
	assert(visual.current_clip == previous)
	var packet := effect_packet(0, body, 0, 0x0f43, 10, 0) if body == 755 else effect_packet(3, body, 0, 0x3728, 10, 15)
	var effect := Effects.parse(packet)
	presenter.present(effect)
	assert(visual.current_clip == (Renderer.Hatchet if body == 755 else Renderer.Sweep))
	assert(visual.action_remaining > .4)
	if body == 755:
		var projectile := presenter.find_child("NativeDestroyerHatchet*", false, false) as Node3D
		assert(projectile != null and projectile.get_child_count() == 2)
		var grip: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.counter_hand).origin)
		assert(projectile.global_position.distance_to(grip) < .00001)
		projectile.name = "CheckedHatchet"
		return 5
	return 3


static func decode(game: Node, body: int, type: int, subaction: int, variation: int) -> Dictionary:
	var packet := PackedByteArray([0xe2])
	packet.append_array(Wire.uint_be(body, 4))
	packet.append_array(Wire.uint_be(type, 2))
	packet.append_array(Wire.uint_be(subaction, 2))
	packet.append(variation)
	var found := [{}]
	var record := func(action: Dictionary): found[0] = action
	game.mobile_action_received.connect(record, CONNECT_ONE_SHOT)
	game._handle(packet)
	assert(not found[0].is_empty())
	return found[0]


static func effect_packet(kind: int, source: int, target: int, graphic: int, speed: int, duration: int) -> PackedByteArray:
	var packet := PackedByteArray([0xc0, kind])
	packet.append_array(Wire.uint_be(source, 4))
	packet.append_array(Wire.uint_be(target, 4))
	packet.append_array(Wire.uint_be(graphic, 2))
	for position in [Vector3i(1, 1, 0), Vector3i(5, 2, 0)]:
		packet.append_array(Wire.uint_be(position.x, 2))
		packet.append_array(Wire.uint_be(position.y, 2))
		packet.append(position.z)
	packet.append_array(PackedByteArray([speed, duration, 0, 0, int(kind == 3), 0]))
	packet.resize(36)
	return packet
