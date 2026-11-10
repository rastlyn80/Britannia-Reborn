# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Hopper := preload("bake-skittering-hopper-enhanced.gd")
const Dancer := preload("bake-fan-dancer-enhanced.gd")
const Bodies := [302, 247]


static func modes_for(body: int) -> Dictionary:
	var clips: Dictionary = Hopper.Clips if body == 302 else Dancer.Clips
	var flourish: String = clips[12] if body == 302 else clips[4]
	return {"0": {"5": [clips[26], clips[27]], "8": [clips[28]], "11": [flourish, flourish, flourish],
		"15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	for variant: String in row.assets:
		row.assets[variant] = Hopper.Destination + "%d-%s.scn" % [body, variant]
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = Hopper.Clips.values() if body == 302 else Dancer.Clips.values()
	return row


func actor_for(body: int, row: Dictionary, treatment: String) -> Node3D:
	if Installed.enabled:
		return super.actor_for(body, row, treatment)
	var file := "SourceEnhancedHopperVisual.gd" if body == 302 else "SourceEnhancedFanDancerVisual.gd"
	var renderer := load(Hopper.Destination + file) as GDScript
	var actor: Node3D = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Bodies:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var results := {}
	for body: int in Bodies:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else row_for(body, base)
		assert(row.enhanced_source_action_groups == modes_for(body))
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var report := await inspect_family(game, body, base, row)
		assert(report.poses == 2325 and report.falls == 150 and report.routes == 96 and report.classic == 72)
		results[str(body)] = report
	game.free()
	if not installed:
		var file := FileAccess.open(Hopper.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": results, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


func inspect_family(game: Node, body: int, base: Dictionary, row: Dictionary) -> Dictionary:
	var report := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0, "routes": 0, "classic": 0, "hashes": {}}
	var modes := modes_for(body)
	var packets := {}
	for kind: String in modes["0"]:
		var clips: Array = modes["0"][kind]
		for variation in clips.size():
			if not packets.has(clips[variation]):
				packets[clips[variation]] = decode(game, body, int(kind), variation)
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for variant: String in row.assets:
			var actor := actor_for(body, row, variant)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if tilt == Vector3.ZERO:
				check_retained_keys(body, row.assets[variant], Registry.asset_path(base, variant))
				var counts := check_routes(avatar, game, body, modes)
				report.routes += counts.x
				report.classic += counts.y
				report.hashes[variant] = FileAccess.get_sha256(row.assets[variant])
			for clip: String in packets:
				start_action(avatar, packets[clip], clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%d %s %s %.2f support gap %.6f" % [body, variant, clip, sample / 30.0, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.19, .67]:
					start_action(avatar, packets[clip], clip)
					seek(actor, phase)
					var result := inspect_fall(actor, floor, body, row)
					report.jump = maxf(report.jump, result.jump)
					report.fall_gap = minf(report.fall_gap, result.gap)
					report.falls += 1
				if body == 302:
					check_retraction(actor)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("HOPPER AND FAN DANCER RUNTIME ", body, " ", report)
	return report


func check_retained_keys(body: int, candidate: String, original: String) -> void:
	var before := (load(original) as PackedScene).instantiate()
	var after := (load(candidate) as PackedScene).instantiate()
	var base := before.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var fitted := after.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if body == 247:
		Giants.verify_base_clips(fitted, original)
	else:
		for name: String in base.get_animation_list():
			var previous := base.get_animation(name)
			var current := fitted.get_animation(name)
			assert(previous.length == current.length and previous.get_track_count() + 4 == current.get_track_count())
			for track in previous.get_track_count():
				assert(previous.track_get_path(track) == current.track_get_path(track))
				assert(previous.get("tracks/%d/keys" % track) == current.get("tracks/%d/keys" % track))
			for index in Hopper.Wings.Joints.size():
				var track := previous.get_track_count() + index
				assert(current.track_get_type(track) == Animation.TYPE_ROTATION_3D)
				assert(current.track_get_path(track).get_subname(0) == Hopper.Wings.Joints[index])
				assert(current.track_get_key_count(track) == 1 and current.track_get_key_time(track, 0) == 0.0)
	before.free()
	after.free()


func check_retraction(actor: Node3D) -> void:
	actor.action_remaining = 0.0
	actor.play_gait(true, 1.8)
	actor.animator.advance(.22)
	var rig: Skeleton3D = actor.skeleton
	assert(actor.current_clip == "Walk")
	for name: String in Hopper.Wings.Joints:
		var joint := rig.find_bone(name)
		assert(rig.get_bone_pose_rotation(joint).is_equal_approx(rig.get_bone_rest(joint).basis.get_rotation_quaternion()))


func inspect_fall(source: Node3D, floor: StaticBody3D, body: int, row: Dictionary) -> Dictionary:
	var fallen := actor_for(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var labels := ["bip01 head", "bip01 l hand", "bip01 r hand"]
	if body == 302:
		labels.append_array(Hopper.Wings.Joints)
	var jump := 0.0
	for label: String in labels:
		jump = maxf(jump, landmark(source, label).distance_to(landmark(fallen, label)))
	assert(jump < .002, "%d %s fall changed a displayed joint by %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0018, "%d %s fall has gap %.6f" % [body, source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	if body == 302:
		var wings := corpse.get_node("HopperWings") as MeshInstance3D
		assert(wings != null and wings.mesh.get_surface_count() == 2)
		var material := wings.get_active_material(1) as ShaderMaterial
		assert(material != null and material.shader.resource_path.get_file() == "SourceEnhancedHopperWing.gdshader"
			and material.get_shader_parameter("membrane"))
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}
