# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const SeaHorse := preload("res://Presentation/SeaHorseProfile.gd")


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x3871
	var rider := 0x3890
	world.game._handle(mobile_packet(at, serial, SeaHorse.BODY, 0x40))
	world.game._handle(mobile_packet(at, rider, 401, 0))
	world.game._handle(wear_packet(rider, SeaHorse.MOUNT, CorpseHue))
	var actor: Node3D = world.avatars[serial].horse_visual
	var ridden: Node3D = world.avatars[rider].horse_visual
	if not expect(is_seahorse(actor) == enhanced and is_seahorse(ridden) == enhanced, "optional loose and mounted SeaHorse route"):
		return
	if not expect(actor.native_body == SeaHorse.BODY and ridden.native_body == SeaHorse.BODY \
			and ridden.native_mount_item == SeaHorse.MOUNT and ridden.native_hue == CorpseHue,
			"exact native identity and raw mounted hue in either mode"):
		return
	if not enhanced:
		if not expect(actor is Mounts.Horse and ridden is Mounts.Horse, "Classic uses its available horse fallback"):
			return
		print("SEAHORSE WORLD: ", checks, " checks, Enhanced false")
		world.queue_free()
		await process_frame
		quit()
		return
	for case in [[0, 0, 1, "Attack2"], [0, 0, 4, "Attack2"], [0, 1, 1, "Attack"],
			[0, 255, 4, "Attack"], [2, 0, 0, "TailCurl"], [4, 0, 0, "Hit"], [5, 0, 1, "LongReach"],
			[8, 0, 0, "Alert"], [11, 0, 0, "Cast"], [14, 0, 0, "ForwardRush"], [15, 0, 0, "Uncoil"]]:
		var action := action_packet(serial, case[0], case[2])
		action[8] = case[1]
		world.game._handle(action)
		if not expect(actor.current_clip == case[3], "decoded Enhanced selector " + str(case)):
			return
	world.game._handle(mobile_packet(at, serial, SeaHorse.BODY, 0))
	world.game._handle(action_packet(serial, 5, 1))
	if not expect(actor.current_clip == "Fidget", "peaceful fidget uses the one native group"):
		return
	for variant in 2:
		serial += 1
		if not await verify_fall(world, at, serial, variant):
			return
	print("SEAHORSE WORLD: ", checks, " checks, Enhanced true")
	world.queue_free()
	await process_frame
	quit()


func is_seahorse(visual: Node3D) -> bool:
	return is_instance_valid(visual) and visual.get_script().resource_path == SeaHorse.RENDERER


func verify_fall(world: Node3D, at: Vector2i, serial: int, variant: int) -> bool:
	world.game._handle(mobile_packet(at, serial, SeaHorse.BODY, 0))
	var actor: Node3D = world.avatars[serial].horse_visual
	var clip := "Death" if variant == 0 else "Death2"
	world.game._handle(action_packet(serial, 3, variant))
	if not expect(actor.current_clip == clip and actor.dead, "decoded selected fall"):
		return false
	actor.animator.advance(0.0)
	actor.animator.seek(0.29 * actor.animator.current_animation_length, true)
	var before: Vector3 = actor.socket("mouth").origin
	var corpse := 0x4001f000 + serial
	world.game._handle(corpse_packet(at, corpse, SeaHorse.BODY, 0))
	world.game._handle(death_packet(serial, corpse))
	var active: Dictionary = world.creature_deaths.active.get(serial, {})
	var holder: Node3D = world.world_items.nodes[corpse]
	if not expect(not active.is_empty() and not holder.visible and active.visual.current_clip == clip,
			"the real transition holder continues the selected fall"):
		return false
	var displacement := before.distance_to(active.visual.socket("mouth").origin)
	if not expect(displacement < 0.001, "mouth socket continues across the fall handoff"):
		return false
	await create_timer(float(active.remaining) + 0.12).timeout
	var frozen: Node3D = holder.get_node("CorpseVisual")
	if not expect(holder.visible and frozen.get_meta("death_clip") == clip and frozen.find_children("*", "Skeleton3D").is_empty(),
			"native item releases the static SeaHorse pose"):
		return false
	var placement := frozen.global_transform
	var bounds: AABB = frozen.get_meta("corpse_bounds")
	world.game._handle(corpse_packet(at, corpse, SeaHorse.BODY, CorpseHue))
	var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
	return expect(dyed.get_meta("death_clip") == clip and dyed.get_meta("native_hue") == CorpseHue \
		and dyed.global_transform.is_equal_approx(placement) and dyed.get_meta("corpse_bounds") == bounds,
		"late corpse dye preserves placement and selected fall")
