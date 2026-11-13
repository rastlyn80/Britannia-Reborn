# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Primary := "EnslavedGargoyleCrossingSwipe"
const Secondary := "EnslavedGargoyleFlyingKick"
const Motions := {
	4: ["EnslavedGargoyleChestRecoil"], 5: ["UopGargoyleQuietFidget", "UopGargoyleLunge"],
	8: ["EnslavedGargoyleForwardBrace"], 11: [Primary],
	2: ["EnslavedGargoyleBackwardGuard"], 14: ["EnslavedGargoyleLowSearch"],
	15: ["EnslavedGargoyleCrouchRise"],
}

func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	assert(world.enhanced_creature_actions)
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for flags: int in [0, 64]:
		var serial := 0x364000 + flags
		world.game._handle(mobile_packet(at, serial, 753, flags))
		var actor: Node3D = world.avatars[serial].horse_visual
		for sub: int in [0, 1, 2, 9, 37, 255, 257, 65535]:
			var choices := [Primary, Secondary, Primary, Primary, Primary, Primary]
			if sub == 0:
				choices.resize(3)
			elif sub & 255 in [1, 2, 9]:
				choices.resize(1)
			for variation in range(128):
				var action := action_packet(serial, 0, variation)
				action[7] = sub >> 8
				action[8] = sub & 255
				world.game._handle(action)
				var expected: String = choices[variation % choices.size()]
				if not expect(actor.current_clip == expected, "Attack %d/%d expected %s got %s" % [sub, variation, expected, actor.current_clip]):
					return
		for type: int in Motions:
			var choices: Array = Motions[type] if flags != 0 or type != 5 else ["UopGargoyleQuietFidget"]
			for variation in range(128):
				world.game._handle(action_packet(serial, type, variation))
				var expected: String = choices[variation % choices.size()]
				if not expect(actor.current_clip == expected, "Action %d/%d expected %s got %s" % [type, variation, expected, actor.current_clip]):
					return
	print("ENSLAVED GARGOYLE COMBAT WORLD: ", checks, " decoded action choices")
	quit(0)
