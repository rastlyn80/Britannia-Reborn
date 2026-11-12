# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Forms := {
	62: "SourceTerrainWyvernVisual.gd",
	81: "SourceTerrainFrogVisual.gd",
	238: "SourceTerrainOrdinaryRatVisual.gd",
	213: "SourceLivingStepQuadrupedVisual.gd",
	34: "SourceLivingStepQuadrupedVisual.gd",
	37: "SourceLivingStepQuadrupedVisual.gd",
	221: "SourceTerrainWalrusVisual.gd",
	163: "SourceTerrainSnowElementalVisual.gd",
	9: "SourceTerrainDaemonVisual.gd",
	60: "SourceTerrainDrakeVisual.gd",
	61: "SourceTerrainDrakeVisual.gd",
	89: "SourceTerrainIceSerpentVisual.gd",
	24: "SourceTerrainLichVisual.gd",
	208: "SourceTerrainChickenVisual.gd",
	52: "SourceTerrainSmallSnakeVisual.gd",
	15: "SourceTerrainFireElementalVisual.gd",
	138: "SourceTerrainOrcishLordVisual.gd",
	6: "SourceTerrainTropicalBirdVisual.gd",
	779: "SourceTerrainBoglingVisual.gd",
	31: "SourceTerrainHeadlessVisual.gd",
	13: "SourceTerrainAirElementalVisual.gd",
	29: "SourceTerrainGorillaVisual.gd",
	58: "SourceTerrainWispVisual.gd",
	153: "SourceTerrainGhoulVisual.gd",
	1: "SourceTerrainOgreVisual.gd",
	3: "SourceTerrainZombieVisual.gd",
	8: "SourceTerrainCorpserVisual.gd",
	21: "SourceTerrainGiantSerpentVisual.gd",
	22: "SourceTerrainGazerVisual.gd",
	30: "SourceTerrainHarpyVisual.gd",
	39: "SourceMongbatTerrainVisual.gd",
	47: "SourceReaperGroundVisual.gd",
	205: "SourceTerrainRabbitVisual.gd",
}


func run() -> void:
	var requested := 0
	var selected := PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--body="):
			requested = int(argument.trim_prefix("--body="))
		if argument.begins_with("--bodies="):
			selected = argument.trim_prefix("--bodies=").split(",", false)
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var tile := Vector2i(int(world.world.originX) + 14, int(world.world.originY) + 14)
	for body: int in Forms:
		if (requested != 0 and body != requested) or (not selected.is_empty() and str(body) not in selected):
			continue
		var serial := 0x6a00 + body
		var hue := 0x8035
		var packet := mobile_packet(tile, serial, body, 0)
		packet[13] = hue >> 8
		packet[14] = hue & 0xff
		world.game._handle(packet)
		var actor: Node3D = world.avatars.get(serial)
		if not expect(actor != null and actor.horse_visual != null, "World receives source body %d" % body):
			return
		var visual: Node3D = actor.horse_visual
		var expected: String = Forms[body]
		if body == 205 and world.enhanced_creature_actions and ResourceLoader.exists("res://local-art/creatures/enhanced-creature-actions/205-modern.scn"):
			expected = "SourceEnhancedTerrainRabbitVisual.gd"
		if not expect(visual.get_script().resource_path.ends_with(expected), "World selects grounded body %d" % body):
			return
		if not expect(visual.native_body == body and visual.native_hue == hue, "World preserves body and hue"):
			return
	var enhanced: bool = world.enhanced_creature_actions
	if not expect(enhanced == ("--enhanced-creature-actions" in OS.get_cmdline_user_args()), "World selects requested profile"):
		return
	print("OCCURRENCE WORLD: ", checks, " native-wire checks; body ", requested, ", Enhanced ", enhanced)
	world.queue_free()
	await process_frame
	quit()
