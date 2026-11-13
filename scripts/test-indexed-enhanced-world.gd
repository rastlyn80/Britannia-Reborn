# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const PEACE := 0
const COMBAT := 0x40
const FLIGHT := 0x04

# Body, flags, packet type, and expected clips in original variation order.
const TRACKED := [
	[267, COMBAT, 5, ["TroglodyteSettleFidget", "TroglodyteRaisedFidget"]],
	[267, PEACE, 5, ["TroglodyteSettleFidget"]],
	[267, COMBAT, 8, ["TroglodyteOpenReach"]],
	[692, COMBAT, 5, ["UopHalberdHover"]],
	[692, PEACE, 5, ["UopHalberdReadyHover"]],
	[705, COMBAT, 5, ["StonePeaceGesture", "StoneWarGesture"]],
	[705, PEACE, 5, ["StonePeaceGesture"]],
	[753, COMBAT, 5, ["UopGargoyleQuietFidget", "UopGargoyleLunge"]],
	[753, PEACE, 5, ["UopGargoyleQuietFidget"]],
	[831, COMBAT, 5, ["UopParrotWingTuck", "Idle"]],
	[831, PEACE, 5, ["UopParrotWingTuck"]],
	[1246, COMBAT, 5, ["Idle"]],
	[1246, PEACE, 5, ["DormantShuffle"]],
	[1247, COMBAT, 5, ["Idle"]],
	[1247, PEACE, 5, ["Dormant"]],
]


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	if not expect(world.enhanced_creature_actions == ("--enhanced-creature-actions" in OS.get_cmdline_user_args()),
			"World loaded the requested creature mode"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var checked := 0
	if world.enhanced_creature_actions:
		for row: Array in TRACKED + [[831, FLIGHT, 5, ["UopParrotWingTuck", "Idle"]]]:
			var body: int = row[0]
			var flags: int = row[1]
			var type: int = row[2]
			var serial := 0x278000 + body
			world.game._handle(mobile_packet(at, serial, body, flags))
			var avatar: Node3D = world.avatars.get(serial)
			if not expect(avatar != null and avatar.horse_visual != null, "Resolved renderer for body %d" % body):
				return
			var actor: Node3D = avatar.horse_visual
			var clips := expected_choices(row, actor)
			for variation in range(128):
				world.game._handle(action_packet(serial, type, variation))
				var expected: String = clips[variation % clips.size()]
				var received: Dictionary = world.game.last_mobile_actions.get(serial, {})
				if actor.current_clip != expected or received.get("type") != type or received.get("variation") != variation:
					expect(false, "Body %d flags %d type %d variation %d expected %s, got %s" %
						[body, flags, type, variation, expected, actor.current_clip])
					return
				checked += 1
		print("ENHANCED ARCHIVE GAPS: ", checked, " decoded selections across 15 tracked records and Parrot flight")
	else:
		var serial := 0x278000 + 267
		for flags in [PEACE, COMBAT]:
			world.game._handle(mobile_packet(at, serial, 267, flags))
			var actor: Node3D = world.avatars[serial].horse_visual
			for spec: Array in [[5, "TroglodyteSway"], [8, "Pillage"]]:
				world.game._handle(action_packet(serial, spec[0], 1))
				if not expect(actor.current_clip == spec[1], "Classic Troglodyte retains " + spec[1]):
					return
				checked += 1
		print("CLASSIC ARCHIVE PARITY: ", checked, " decoded selections")
	quit()


func expected_choices(row: Array, actor: Node3D) -> Array:
	if not actor.entry.has("enhanced_variant_falls"):
		return row[3]
	if row[0] == 831 and row[1] != PEACE:
		return ["UopParrotWingTuck", "ParrotRestingCrouch"]
	if row[0] == 1247 and row[1] == PEACE:
		return ["EnhancedPumpkinDormant"]
	return row[3]
