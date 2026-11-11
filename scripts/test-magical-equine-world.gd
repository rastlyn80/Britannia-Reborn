# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-llama-world.gd"

const Magical := preload("res://Presentation/SourceMagicalEquine.gd")
const Actions := {
	122: {
		"attack": ["RearingStrike", "HornLunge"], "recoil": "HeadRecoil", "warning": "WarningRear",
		"cast": "CastingRear", "quiet": "QuietHeadCheck", "combat_fidget": "HighFidget",
		"other": ["Idle", "Idle"],
	},
	132: {
		"attack": ["LowSnap", "RaisedForeStrike"], "recoil": "LowRecoil", "warning": "WarningPaw",
		"cast": "HeadSweepCast", "quiet": "Idle", "combat_fidget": "ForwardFidget",
		"other": ["DeepBow", "StretchAndRise"],
	},
}


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	if not expect(world.enhanced_creature_actions and Magical.available_forms.size() == 2, "normal World activates both original rigs"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x5c01
	for body: int in Actions:
		world.game._handle(mobile_packet(at, serial, body, 0))
		var avatar: Node3D = world.avatars[serial]
		var actor := avatar.horse_visual as Magical
		if not expect(actor != null and actor.fitted and actor.animator.has_animation("OriginalDeath"),
				"the candidate keeps the original fall and installs two fitted falls"):
			return
		for flags: int in [0, 0x40, 0x04] if body == 132 else [0, 0x40]:
			world.game._handle(mobile_packet(at, serial, body, flags))
			for index in 3:
				var speed: float = [0., 1.8, 5.5][index]
				var expected: String = ["Idle", "Walk", "Run"][index]
				if flags == 0x40 and index < 2:
					expected = ["CombatIdle", "CombatWalk"][index]
				if flags == 0x04:
					expected = "HoverGather"
				avatar.animate(speed > 0., 0., .1, speed)
				if not expect(actor.current_clip == expected, "stock appearance mode picks the matching movement group"):
					return
			if not verify_actions(world, serial, actor, body, flags):
				return
		serial += 1
		var rider_body := 401 if body == 122 else 400
		world.game._handle(mobile_packet(at, serial, rider_body, 0))
		world.game._handle(wear_packet(serial, Magical.Forms[body].item, CorpseHue))
		var rider: Node3D = world.avatars[serial]
		if not expect(rider.horse_visual is Magical, "the exact native worn graphic selects its own source rig"):
			return
		for index in 3:
			var speed: float = [0., 1.8, 5.5][index]
			var expected: String = ["MountedIdle", "MountedWalk", "MountedRun"][index] if body == 132 else ["Idle", "Walk", "Run"][index]
			rider.animate(speed > 0., 0., .1, speed)
			if not expect(rider.horse_visual.current_clip == expected, "the mounted form uses the registered gait"):
				return
		for sample: Array in [[-1, "Death"], [0, "Death"], [1, "Death2"], [12, "Death"]]:
			serial += 1
			if not await verify_fall(world, at, serial, sample[0], sample[1], body):
				return
		serial += 1
	print("MAGICAL EQUINE WORLD: ", checks, " checks for two original living mounts, including both corpse orders and late dye")
	quit()


func verify_actions(world: Node3D, serial: int, actor: Magical, body: int, flags: int) -> bool:
	var expected: Dictionary = Actions[body]
	var combat := (flags & 0x44) != 0
	for variation in 6:
		for subaction: int in [0, 1, 2, 9, 255]:
			var alternate := variation % 3 == 1 if subaction == 0 else variation % 6 == 1 if subaction == 255 else false
			if not send_action(world, serial, actor, 0, subaction, variation, expected.attack[int(alternate)]):
				return false
		var fidget: String = expected.combat_fidget if combat and variation % 2 == 1 else expected.quiet
		var cases: Array = [[2, expected.warning], [4, expected.recoil], [5, fidget], [8, "GuardAlert"],
			[11, expected.cast], [14, expected.other[0]], [15, expected.other[1]]]
		for sample: Array in cases:
			if not send_action(world, serial, actor, sample[0], 0, variation, sample[1]):
				return false
	actor.action_remaining = 0.
	return true


func send_action(world: Node3D, serial: int, actor: Magical, type: int, subaction: int, variant: int, expected: String) -> bool:
	var packet := action_packet(serial, type, variant)
	packet[8] = subaction
	world.game._handle(packet)
	return expect(actor.current_clip == expected and actor.animator.has_animation(expected),
		"body %d type %d subtype %d variation %d selects %s (got %s)" % [
			actor.native_body, type, subaction, variant, expected, actor.current_clip])
