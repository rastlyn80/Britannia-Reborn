# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Lord := preload("bake-juka-lord-enhanced.gd")
const Body := 766
const BodyHue := 0x8035
const BowHue := 0x0453
const Renderer := "res://Presentation/SourceEnhancedJukaLordVisual.gd"
const Bow := {"id": 0x13b2, "layer": 2, "hue": BowHue}


static func source_routes() -> Dictionary:
	var clips := Lord.LordClips
	return {"0": {"5": [clips[26], clips[27]], "8": [clips[28]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func fitted_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = source_routes()
	row.archive_grounded_gestures = Lord.LordClips.values()
	row.presentation_script = Renderer
	for treatment: String in row.assets:
		row.assets[treatment] = Lord.Destination + "%d-%s.scn" % [Body, treatment]
	return row


func run() -> void:
	var base := Registry.entry(Body)
	var row := fitted_row(base)
	if "--installed" in OS.get_cmdline_user_args():
		assert(Installed.enable())
		row = Registry.entry(Body)
		assert(row.enhanced_source_action_groups == source_routes() and row.presentation_script == Renderer)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": BodyHue}
	var report := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "body_gap": INF,
		"bow_gap": INF, "fall_bow_gap": INF, "handoff": 0.0, "grip": 0.0, "hashes": {}}
	var clips := Lord.LordClips
	var packets := {
		clips[23]: decode(game, Body, 15, 0), clips[26]: decode(game, Body, 5, 0),
		clips[27]: decode(game, Body, 5, 1), clips[28]: decode(game, Body, 8, 0),
	}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := create_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			actor.set_equipment([Bow])
			if slope == Vector3.ZERO:
				check_equipment(actor)
				Giants.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var routes := check_routes(avatar, game, Body, source_routes())
				report.routes += routes.x
				report.classic += routes.y
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in packets:
				start_action(avatar, packets[clip], clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var body_gap := minimum_gap(actor, floor, [actor.support_skin])
					var bow_gap := bow_floor_gap(actor, floor)
					var grip: float = actor.bow_holder.global_position.distance_to(landmark(actor, "cp_grasp_lhand"))
					assert(body_gap >= .0018 and bow_gap >= .0018 and grip < .0005,
						"%s, phase %d, body %.5f, bow %.5f, grip %.5f" % [clip, sample, body_gap, bow_gap, grip])
					report.body_gap = minf(report.body_gap, body_gap)
					report.bow_gap = minf(report.bow_gap, bow_gap)
					report.grip = maxf(report.grip, grip)
					report.poses += 1
				for phase: float in [.19, .67]:
					start_action(avatar, packets[clip], clip)
					seek(actor, phase)
					var fall := check_fall(actor, floor, row)
					report.fall_bow_gap = minf(report.fall_bow_gap, fall.bow_gap)
					report.handoff = maxf(report.handoff, fall.handoff)
					report.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	game.free()
	assert(report.poses == 1860 and report.falls == 120 and report.routes == 72 and report.classic == 54)
	print("JUKA LORD RUNTIME ", report)
	var receipt := FileAccess.open(Lord.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(report, "\t"))
	receipt.close()
	quit()


func create_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = load(Renderer).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, BodyHue)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_equipment(actor: Node3D) -> void:
	assert(actor.bow_holder.visible and actor.bow_hue == BowHue)
	var shader := actor.bow_mesh.get_active_material(0) as ShaderMaterial
	assert(shader != null and shader.get_shader_parameter("hue_palette") == actor.Hue.palette(BowHue))
	actor.set_hue(0x0481)
	shader = actor.bow_mesh.get_active_material(0) as ShaderMaterial
	assert(shader != null and shader.get_shader_parameter("hue_palette") == actor.Hue.palette(BowHue))
	actor.set_hue(BodyHue)
	actor.set_equipment([{"id": 0x13b2, "layer": 1, "hue": BowHue}])
	assert(not actor.bow_holder.visible)
	actor.set_equipment([{"id": 0x13b1, "layer": 2, "hue": 0}])
	assert(actor.bow_holder.visible and actor.bow_mesh.get_active_material(0) is StandardMaterial3D)
	actor.set_equipment([Bow])
	assert(actor.receive_action({"protocol": "classic", "action": 7}))
	actor.animator.advance(.16)
	seek(actor, .40)
	assert(actor.current_clip == "AttackBow" and actor.applied_draw.length() > .01)
	seek(actor, .73)
	assert(actor.applied_draw.is_zero_approx() and actor.bow_mesh.mesh == actor.rest_mesh)


func bow_floor_gap(actor: Node3D, floor: StaticBody3D) -> float:
	var points: PackedVector3Array = actor.bow_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var gap := INF
	for point: Vector3 in points:
		gap = minf(gap, floor.basis.y.dot(actor.bow_mesh.to_global(point) - floor.position))
	return gap


func check_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> Dictionary:
	var fallen := create_actor(row, source.treatment)
	fallen.set_equipment(source.server_equipment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	fallen.update_bow()
	var jump := 0.0
	for label: String in ["bip01 head", "bip01 r foot", "cp_grasp_lhand"]:
		jump = maxf(jump, landmark(source, label).distance_to(landmark(fallen, label)))
	assert(jump < .002 and fallen.bow_holder.global_position.distance_to(source.bow_holder.global_position) < .002)
	var bow_gap := INF
	for sample in 31:
		seek(fallen, sample / 30.0)
		assert(minimum_gap(fallen, floor, [fallen.support_skin]) >= .0016)
		bow_gap = minf(bow_gap, bow_floor_gap(fallen, floor))
	assert(bow_gap >= .0029, "The bow clips the support plane by %.4f m in %s" % [bow_gap, source.current_clip])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == BodyHue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	var bow := corpse.get_node_or_null("JukaBow") as MeshInstance3D
	assert(bow != null)
	var material := bow.get_active_material(0) as ShaderMaterial
	assert(material != null and material.get_shader_parameter("hue_palette") == fallen.Hue.palette(BowHue))
	corpse.free()
	fallen.free()
	return {"handoff": jump, "bow_gap": bow_gap}
