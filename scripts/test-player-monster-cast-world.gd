# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Guards := {1: "ChestBrace", 33: "Fidget", 51: "CrestRise", 54: "Fidget", 285: "ReaperLowGuard", 746: "MolochHighGuard", 747: "BansheeHandCheck", 748: "SpectralClutch"}
const First := 0x4920


func run() -> void:
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var position := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(position, First, 400, 0))
	world.game.player.serial = First
	world.game.phase = "world"
	var cases := 0
	for body: int in Guards:
		var serial := First + body + 1
		world.game._handle(mobile_packet(position + Vector2i(1, 0), serial, 400, 0))
		world.game._handle(mobile_packet(position + Vector2i(1, 0), serial, body, 0))
		var visual: Node3D = world.avatars[serial].horse_visual
		if not expect(visual != null and visual.native_body == body, "Same-serial human morph selects body %d" % body):
			return
		world.game._handle(cast_motion(serial, 5))
		if not expect(visual.current_clip != Guards[body], "The five-frame group does not invoke the Polymorph substitute"):
			return
		world.game._handle(cast_motion(serial, 7))
		if not expect(visual.current_clip == Guards[body] and not visual.dead, "The stock seven-frame cast plays the fitted gesture"):
			return
		var request: Dictionary = visual.get_meta("native_action", {})
		if not expect(request.get("action") == 12 and request.get("frames") == 7 and request.get("body") == body,
				"Original animation metadata is preserved"):
			return
		var row: Dictionary = visual.entry
		var real := Animation.new()
		real.length = 1.0
		var library: AnimationLibrary = visual.animator.get_animation_library("")
		if not visual.animator.has_animation("ProtectedCast"):
			library.add_animation("ProtectedCast", real)
		visual.entry = row.merged({"classic_action_categories": row.get("classic_action_categories", {}).merged({"12": "ProtectedCast"}, true)}, true)
		world.game._handle(cast_motion(serial, 7))
		if not expect(visual.current_clip == "ProtectedCast", "An installed dedicated cast retains priority"):
			return
		visual.entry = row
		library.remove_animation("ProtectedCast")
		world.game._handle(mobile_packet(position + Vector2i(1, 0), serial, 400, 0))
		if not expect(world.avatars[serial].human_visual != null and world.avatars[serial].horse_visual == null,
				"Normal body update returns to the human rig"):
			return
		cases += 6
	print("ALL MONSTER PLAYER CAST WORLD: ", cases, " decoded presentation checks, Enhanced ", enhanced)
	world.game.phase = "offline"
	quit()


func cast_motion(serial: int, frames: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, 12, 0, frames, 0, 1, 0, 0, 0]))
	return packet
