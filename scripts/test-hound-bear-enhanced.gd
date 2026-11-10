extends "res://../scripts/test-field-enhanced.gd"

const Baker := preload("res://../scripts/bake-hound-bear-enhanced.gd")
const HoundModes := {"0": {
	"2": ["HoundRearBark", "HoundRearBark"], "5": ["HoundScentCheck", "HoundTailCheck"], "8": ["HoundAlert"],
	"11": ["HoundBowSnap", "HoundBowSnap", "HoundBowSnap"], "14": ["HoundQuietStand"], "15": ["HoundQuietStand"],
}, "1": {"5": ["HoundScentCheck"]}}
const BearModes := {"0": {
	"2": ["BlackBearUprightWarning"], "5": ["BlackBearScentTurn", "BlackBearRaisedGuard"], "8": ["BlackBearRearAlert"],
	"11": ["BlackBearHighSwipe"], "14": ["BlackBearQuietStand"], "15": ["BlackBearWakeAndRise"],
}, "1": {"5": ["BlackBearScentTurn"]}}
var installed := false

func run() -> void:
	var bases := {217: Registry.entry(217), 211: Registry.entry(211)}
	installed = "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in [217, 211]:
		var record := await review(game, body, bases[body], HoundModes if body == 217 else BearModes)
		assert(record.has("routes"))
		evidence[str(body)] = record
	game.free()
	if not installed:
		var file := FileAccess.open(Baker.Folder + "hound-bear-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": evidence, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func review(game: Node, body: int, base: Dictionary, modes: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if installed else base.duplicate(true)
	var clips := {}
	for kind: String in modes["0"]:
		var options: Array = modes["0"][kind]
		for variation in options.size():
			if not clips.has(options[variation]):
				clips[options[variation]] = [int(kind), variation]
	if not installed:
		row.enhanced_source_action_groups = modes
		row.archive_grounded_gestures = clips.keys()
		for treatment: String in row.assets:
			row.assets[treatment] = Baker.Folder + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	assert(row.enhanced_source_action_groups == modes)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var counts := Vector2i.ZERO
	var poses := 0
	var gaps := {}
	var geometry := {}
	var hashes := {}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor: Node3D = Registry.create(body) if installed else FieldVisual.new()
			actor.entry = row
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				counts += check_routes(avatar, game, body, modes)
				hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if treatment == "modern":
					geometry = measure_rear(actor, body)
			for clip: String in clips:
				var selection: Array = clips[clip]
				var packet := decode(game, body, selection[0], selection[1])
				var gap := sample(avatar, floor, packet, clip)
				assert(gap > .001, "%s dips into %s on the %s skin: %f" % [clip, tilt, treatment, gap])
				gaps[clip] = minf(gap, gaps.get(clip, INF))
				poses += 31
			avatar.free()
			root.remove_child(actor)
			for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					mesh.set_surface_override_material(surface, null)
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		corpse.free()
	Registry.entries[body] = base
	assert(counts == Vector2i(144, 108) and poses == clips.size() * 465)
	print("HOUND/BEAR ENHANCED ", body, ": ", counts, " ", poses, " slope poses, ", geometry, " ", gaps)
	return {"routes": counts.x, "classic_comparisons": counts.y, "terrain_poses": poses,
		"gaps": gaps, "geometry": geometry, "corpse_hues": 3, "scene_sha256": hashes}

func measure_rear(actor: Node3D, body: int) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("HoundRearBark" if body == 217 else "BlackBearRaisedGuard", 0.0)
	player.advance(0.0)
	var probe := Baker.new()
	var anchor := probe.hind_midpoint(rig)
	var result := {"paw_height": 0.0, "head_height": 0.0, "hind_drift": 0.0, "paw_span": 0.0}
	for index in 81:
		player.seek(player.current_animation_length * index / 80.0, true)
		rig.force_update_all_bone_transforms()
		var left := probe.joint_world(rig, "bip01 l hand")
		var right := probe.joint_world(rig, "bip01 r hand")
		result.paw_height = maxf(result.paw_height, (left.y + right.y) * .5)
		result.head_height = maxf(result.head_height, probe.joint_world(rig, "bip01 head").y)
		result.hind_drift = maxf(result.hind_drift, (probe.hind_midpoint(rig) - anchor).slide(Vector3.UP).length())
		result.paw_span = maxf(result.paw_span, left.distance_to(right))
	if body == 217:
		player.play("Idle", 0.0)
		player.advance(0.0)
		var standing := probe.joint_world(rig, "bip01 neck").y
		player.play("HoundBowSnap", 0.0)
		player.advance(0.0)
		result["bow_chest_drop"] = standing - probe.joint_world(rig, "bip01 neck").y
	probe.free()
	assert(result.hind_drift < .004)
	assert(result.paw_height > (.27 if body == 217 else 1.15))
	if body == 217:
		assert(result.bow_chest_drop > .025)
	return result
