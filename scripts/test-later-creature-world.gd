# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Shared := {
	9: ["daemons_daemon_slot11_9", [1636]],
	40: ["daemons_daemon_elder", [243]],
	43: ["daemons_daemon_ice_fiend", [1863]],
	51: ["slimes_slime", [242, 243, 244, 245]],
	52: ["small_snakes", [33]],
	62: ["dragons_wyvern", [243]],
	78: ["liche_liche_lord_retro", [0]],
	98: ["canines_hell_hound", [44]],
	128: ["fey_race_pixie", [0]],
	158: ["elementals_acid_elemental", [0]],
	238: ["rat_ordinary", [52]],
	303: ["devourer", [0]],
	309: ["patchskeleton", [1345]],
}
const Fitted := [287, 334, 714, 715, 716, 717, 718, 720, 722, 723, 726, 732, 733, 736, 737, 738]
const GargoyleSpectral := preload("res://Presentation/WraithSpectralSurface.gdshader")


func run() -> void:
	var body := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--body="):
			body = int(argument.trim_prefix("--body="))
	if not expect(body in [4, 181] or body in Fitted or Shared.has(body), "Specify one reviewed body"):
		return
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	if body == 4:
		if not await check_gargoyle_shade(world, at):
			return
	elif body == 181:
		if not await check_orc_scout(world, at):
			return
	elif Shared.has(body):
		if not await check_shared_body(world, at, body):
			return
	else:
		if not await check_creature(world, at, body):
			return
	print("LATER CREATURE WORLD: ", body, ", ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func check_gargoyle_shade(world: Node, at: Vector2i) -> bool:
	const Body := 4
	const Hue := 0x4001
	const Serial := 0x37704
	const Corpse := 0x40000000 + Serial
	create_actor(world, at, Serial, Body, 0, Hue)
	var actor: Node3D = world.avatars[Serial].horse_visual
	if not expect(actor.native_hue == Hue and has_gargoyle_spectral_surface(actor),
			"The native spectral flag uses the original Gargoyle mesh and translucency"):
		return false
	create_actor(world, at, Serial + 1, Body, 0, 53)
	var ordinary: Node3D = world.avatars[Serial + 1].horse_visual
	if not expect(not has_gargoyle_spectral_surface(ordinary), "An ordinary dyed Gargoyle keeps its normal material"):
		return false
	world.game._handle(corpse_packet(at, Corpse, Body, Hue))
	world.game._handle(death_packet(Serial, Corpse))
	world.creature_deaths.finish(Serial)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[Corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("corpse_body") == Body and frozen.get_meta("native_hue") == Hue
			and has_gargoyle_spectral_surface(frozen) and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
			"The native Gargoyle Shade corpse remains spectral after freezing")


func has_gargoyle_spectral_surface(actor: Node3D) -> bool:
	for part: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for index in part.mesh.get_surface_count():
			var material := part.get_active_material(index) as ShaderMaterial
			if material != null and material.shader == GargoyleSpectral and material.get_shader_parameter("source_atlas") != null:
				return true
	return false


func create_actor(world: Node, at: Vector2i, serial: int, body: int, flags: int, hue: int) -> PackedByteArray:
	var wire := mobile_packet(at, serial, body, flags)
	wire[13] = hue >> 8
	wire[14] = hue & 255
	world.game._handle(wire)
	return wire


func check_orc_scout(world: Node, at: Vector2i) -> bool:
	const Body := 181
	const Serial := 0x377B5
	const Hue := 0x8359
	create_actor(world, at, Serial, Body, 64, Hue)
	var actor: Node3D = world.avatars[Serial].horse_visual
	if not expect(actor != null and actor.native_body == Body and actor.native_hue == Hue,
			"The Orc Scout retains its original body and the supplied hue"):
		return false
	if not expect(actor.bow_mount != null and not actor.bow_mount.visible, "No bow appears without worn equipment"):
		return false
	actor.set_equipment([{"layer": 2, "id": 0x13B2, "hue": 1107}])
	var material := actor.bow_mesh.get_surface_override_material(0) as ShaderMaterial
	if not expect(actor.bow_mount.visible and material != null and material.get_shader_parameter("use_hue"),
			"The server's bow layer sets the visible grip and dye"):
		return false
	classic_action(world, Serial, 7)
	if not expect(actor.current_clip == "AttackBow", "The real Classic bow action plays the original motion"):
		return false
	if world.enhanced_creature_actions:
		world.game._handle(action_packet(Serial, 0, 0))
		if not expect(actor.current_clip == "AttackBow", "The Enhanced primary attack also draws the bow"):
			return false
	classic_action(world, Serial, 2)
	return await check_corpse(world, at, Serial, Body, Hue, "Death")


func check_creature(world: Node, at: Vector2i, body: int) -> bool:
	var entry := Registry.entry(body)
	var renderer := "SourceLaterFlyingVisual.gd" if body in [718, 733] else "SourceModeCreatureVisual.gd"
	if not expect(entry.get("presentation_script") == "res://Presentation/" + renderer, "Local model profile is active"):
		return false
	var actions: Dictionary = entry.classic_action_categories
	for flags: int in [0, 64]:
		var serial := 0x37700 + flags
		var hue := body_hue(body, flags)
		var wire := create_actor(world, at, serial, body, flags, hue)
		var actor: Node3D = world.avatars[serial].horse_visual
		if not expect(actor != null and actor.native_body == body and actor.native_hue == hue, "Birth packet retains body and hue"):
			return false
		if body in [714, 716, 723]:
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var material := mesh.get_surface_override_material(0) as ShaderMaterial
			if not expect(material != null and material.get_shader_parameter("use_hue") == (hue != 0),
					"Dyed variants get their native palette and neutral forms keep the base palette"):
				return false
		actor.play_gait(true, 2.0)
		if not expect(actor.current_clip == actions["0" if flags else "22"], "Combat flag selects the walk"):
			return false
		actor.play_gait(false, 0.0)
		if not expect(actor.current_clip == actions["1" if flags else "25"], "Combat flag selects the idle"):
			return false
		if not flags:
			wire[15] = 64
			world.game._handle(wire)
			if not expect(actor.current_clip == actions["28"], "Entering combat plays group 28"):
				return false
			wire[15] = 0
			world.game._handle(wire)
		for group: String in actions:
			if group in ["2", "3"]:
				continue
			classic_action(world, serial, int(group))
			if not expect(actor.current_clip == actions[group], "Classic group %s dispatches" % group):
				return false
		var death_group := 3 if flags else 2
		if world.enhanced_creature_actions:
			if body in [718, 733]:
				if not check_flight(world, actor, serial, wire, flags, actions):
					return false
			if body in [720, 722]:
				world.game._handle(action_packet(serial, 11, 1))
				if not expect(actor.current_clip == actions["12"], "Enhanced type 11 selects the indexed casting group"):
					return false
			for variant in 128:
				world.game._handle(action_packet(serial, 0, variant))
				var expected: String = actions["5" if variant % 3 == 1 else "4"]
				if not expect(actor.current_clip == expected, "Enhanced attack selects variant %d" % variant):
					return false
				world.game._handle(action_packet(serial, 5, variant))
				expected = actions["1"] if body == 714 else actions["27" if flags and variant % 2 else "26"]
				if not expect(actor.current_clip == expected, "Enhanced gesture selects mode and variant %d" % variant):
					return false
			world.game._handle(action_packet(serial, 3, death_group - 2))
		else:
			classic_action(world, serial, death_group)
		var fall: String = actions[str(death_group)]
		if not expect(actor.current_clip == fall and actor.dead, "The requested fall is distinct"):
			return false
		if body == 717 and not check_scorpion_shell(actor, death_group == 3):
			return false
		if not await check_corpse(world, at, serial, body, hue if body in [714, 716, 723] else CorpseHue, fall):
			return false
	return true


func check_scorpion_shell(actor: Node3D, scatters: bool) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var pieces := {}
	for bone in rig.get_bone_count():
		var name := rig.get_bone_name(bone)
		if name.begins_with("fracture_"):
			var piece := int(name.get_slice("_", 1))
			if not pieces.has(piece):
				pieces[piece] = []
			pieces[piece].append(bone)
	if not expect(pieces.size() == 11, "The shell has eleven independently skinned pieces"):
		return false
	var start := player.current_animation_position
	player.advance(.12)
	for phase: float in [.12, .95]:
		player.seek(phase * player.current_animation_length, true)
		rig.force_update_all_bone_transforms()
		var broken := 0
		for bones: Array in pieces.values():
			var displacement := 0.0
			for bone: int in bones:
				var attached := rig.get_bone_global_pose(rig.get_bone_parent(bone))
				var actual := rig.get_bone_global_pose(bone)
				displacement = maxf(displacement, (rig.global_basis * (actual.origin - attached.origin)).length())
			broken += int(displacement > .12)
		var expected := pieces.size() if scatters and phase > .9 else 0
		if not expect(broken == expected, "Shell separation phase %.2f moved %d pieces, expected %d" % [phase, broken, expected]):
			return false
	player.seek(start, true)
	return true


func body_hue(body: int, flags: int) -> int:
	match body:
		714:
			return 2219 if flags else 0
		716:
			return 1173 if flags else 0
		723:
			return 1900 if flags else 0
		_:
			return 0x8359


func check_flight(world: Node, actor: Node3D, serial: int, wire: PackedByteArray, flags: int, actions: Dictionary) -> bool:
	actor.action_remaining = 0.0
	wire[15] = 4
	world.game._handle(wire)
	actor.play_gait(false, 0.0)
	if not expect(actor.native_flight and actor.current_clip == "Fly", "Flight flag selects group 19 at rest"):
		return false
	actor.play_gait(true, 2.0)
	if not expect(actor.current_clip == "Fly", "Flight group stays selected during movement"):
		return false
	world.game._handle(action_packet(serial, 5, 1))
	if not expect(actor.current_clip == actions["27"], "Flight inherits the combat variation table"):
		return false
	world.game._handle(action_packet(serial, 14, 0))
	var group := "25" if actor.native_body == 718 else "11"
	if not expect(actor.current_clip == actions[group], "Enhanced type 14 selects group " + group):
		return false
	wire[15] = flags
	world.game._handle(wire)
	return true


func classic_action(world: Node, serial: int, group: int) -> void:
	var wire := PackedByteArray([0x6e])
	wire.append_array(Wire.uint_be(serial, 4))
	wire.append_array(PackedByteArray([0, group, 0, 7, 0, 1, 1, 0, 0]))
	world.game._handle(wire)


func check_corpse(world: Node, at: Vector2i, serial: int, body: int, hue: int, fall: String) -> bool:
	var corpse := 0x40000000 + serial
	world.game._handle(corpse_packet(at, corpse, body, hue))
	world.game._handle(death_packet(serial, corpse))
	var state: Dictionary = world.creature_deaths.active.get(serial, {})
	if not fall.is_empty() and not expect(not state.is_empty() and state.visual.current_clip == fall, "The death packet continues the selected fall"):
		return false
	await create_timer(float(state.get("remaining", 0.0)) + .15).timeout
	var frozen: Node = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("corpse_body") == body and frozen.get_meta("native_hue") == hue
		and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "The static corpse retains body and hue")


func check_shared_body(world: Node, at: Vector2i, body: int) -> bool:
	var kind: String = Shared[body][0]
	var hues: Array = Shared[body][1]
	if not expect(Registry.entry(body).kind == kind, "The shared body keeps its reviewed model"):
		return false
	for hue: int in hues:
		var serial := 0x37700 + hue
		create_actor(world, at, serial, body, 0, hue)
		var actor: Node3D = world.avatars[serial].horse_visual
		if not expect(actor != null and actor.native_body == body and actor.native_hue == hue, "The living model retains its appearance"):
			return false
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var material := mesh.get_surface_override_material(0) as ShaderMaterial
		if hue != 0 and not expect(material != null and material.get_shader_parameter("use_hue") and
				material.get_shader_parameter("hue_palette") != null, "The living model has the supplied palette"):
			return false
		if hue == 0 and not expect(material == null or material.get_shader_parameter("use_hue") != true,
				"The living model retains its original surface with no dye"):
			return false
		if not await check_corpse(world, at, serial, body, hue, ""):
			return false
	return true
