# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Wisp := preload("bake-shadow-wisp-enhanced.gd")
const Renderer := "res://Presentation/SourceEnhancedShadowWispVisual.gd"
const Surface := "res://Presentation/ShadowWispActionSurface.gdshader"
const Hue := preload("res://Presentation/HumanHue.gd")


static func source_routes() -> Dictionary:
	var arc := Wisp.Clips[4]
	return {"0": {"0": [arc, arc, arc, arc, arc, arc], "2": ["Idle", "Idle"], "3": ["Death", "Death"],
		"4": [Wisp.Clips[10]], "5": ["Idle", "Idle"], "8": ["Idle"], "11": [arc, arc, arc], "14": ["Idle"],
		"15": [Wisp.Clips[23]]}, "1": {"5": ["Idle"]}}


func run() -> void:
	var base := Registry.entry(Wisp.Body)
	var row := base.duplicate(true)
	row.assets.modern = Wisp.Destination + "165-modern.scn"
	row.enhanced_source_action_groups = source_routes()
	if "--installed" in OS.get_cmdline_user_args():
		assert(Installed.enable())
		row = Registry.entry(Wisp.Body)
		assert(row.presentation_script == Renderer and row.enhanced_source_action_groups == source_routes())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Wisp.Body] = {"serial": Wisp.Body, "body": Wisp.Body, "hue": 0x901}
	var actor := create_wisp(row)
	var avatar := Avatar.new()
	avatar.horse_visual = actor
	var checks := 0
	for native_hue: int in [0, 0x901, 0x8035]:
		actor.apply_identity(Wisp.Body, native_hue)
		var palette := Hue.palette(native_hue)
		assert(not actor.energy_materials.is_empty())
		assert((palette != null) == (native_hue != 0))
		for material: ShaderMaterial in actor.energy_materials:
			assert(material.shader.resource_path == Surface)
			assert(material.get_shader_parameter("hue_palette") == palette)
			assert(material.get_shader_parameter("use_hue") == (native_hue != 0))
			assert(material.get_shader_parameter("partial_hue") == (native_hue == 0x8035))
		var spark_colour := palette.get_image().get_pixel(25, 0) if palette != null else Color("#b69af1")
		assert(actor.arc_material.albedo_color.is_equal_approx(spark_colour))
		checks += 1
	actor.apply_identity(Wisp.Body, 0x901)
	for flags: int in [0, 64]:
		for kind: String in source_routes()["0"]:
			for variant: int in [0, 1, 2, 7, 127]:
				var packet := decode(game, Wisp.Body, int(kind), variant)
				var options: Array = source_routes()["0"][kind]
				actor.dead = false
				assert(Dispatch.dispatch(avatar, packet, true, flags))
				assert(actor.current_clip == options[variant % options.size()] and actor.get_meta("native_action") == packet)
				checks += 1
	actor.dead = false
	actor.action_remaining = 0.0
	for speed: float in [0., 1.8, 4.8]:
		actor.play_gait(speed > 0.0, speed)
		assert(actor.current_clip == "Idle")
		checks += 1
	for clip: String in Wisp.Clips.values():
		actor.current_clip = clip
		actor.animator.play(clip, 0.0)
		actor.animator.advance(0.0)
		for phase: float in [0.0, .19, .41, .67, .82, 1.0]:
			seek(actor, phase)
			assert(actor.arc_sparks.visible == (clip == Wisp.Clips[4]))
			checks += 1
			var fallen := create_wisp(row)
			fallen.global_transform = actor.global_transform.rotated(Vector3.UP, .31)
			assert(fallen.begin_death_from(actor) > 0.0 and not fallen.arc_sparks.visible)
			var rig := actor.skeleton as Skeleton3D
			var frozen_rig := fallen.skeleton as Skeleton3D
			assert(rig.get_bone_count() == frozen_rig.get_bone_count())
			for joint in rig.get_bone_count():
				var source_pose := rig.global_transform * rig.get_bone_global_pose(joint)
				var fall_pose := frozen_rig.global_transform * frozen_rig.get_bone_global_pose(joint)
				assert(fall_pose.is_equal_approx(source_pose))
			fallen.animator.advance(.19)
			seek(fallen, 1.0)
			var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
			assert(not snapshot.is_empty())
			var corpse: Node3D = snapshot.scene.instantiate()
			assert(corpse.get_meta("native_hue") == 0x901 and corpse.get_meta("corpse_body") == Wisp.Body)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			assert(corpse.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
			corpse.free()
			fallen.free()
			checks += 4
	avatar.free()
	actor.free()
	game.free()
	assert(checks == 186)
	var receipt := FileAccess.open(Wisp.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"checks": checks, "handoffs": 18, "routes": 90,
		"scene_sha256": FileAccess.get_sha256(row.assets.modern),
		"renderer_sha256": FileAccess.get_sha256(Renderer), "surface_sha256": FileAccess.get_sha256(Surface)}, "\t"))
	receipt.close()
	print("SHADOW WISP FOCUSED ", checks)
	await process_frame
	quit()


func create_wisp(row: Dictionary) -> Node3D:
	var actor := load(Renderer).new() as Node3D
	actor.entry = row
	root.add_child(actor)
	actor.apply_identity(Wisp.Body, 0x901)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor
