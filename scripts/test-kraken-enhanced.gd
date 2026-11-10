# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-kraken-fidgets.gd"

const Profile := preload("res://Presentation/EnhancedCreatureActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Compact := preload("res://../scripts/bake-kraken-enhanced.gd")
const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/"
const SERIAL := 0x5678
const Modes := {
	"0": {"5": ["KrakenScan", "KrakenFinThrust"], "8": ["KrakenAlert"], "14": ["KrakenPoise"], "15": ["KrakenSurface"]},
	"1": {"5": ["KrakenScan"]},
}

func run() -> void:
	var base := Registry.entry(BODY)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var trial := Registry.entry(BODY).duplicate(true) if installed else base.duplicate(true)
	if not installed:
		trial.enhanced_source_action_groups = Modes
		for treatment: String in trial.assets:
			trial.assets[treatment] = Folder + "kraken-compact-%s.scn" % treatment
	assert(trial.enhanced_source_action_groups == Modes)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x481}
	var plane := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(35.0, .10, 35.0)
	shape.shape = box
	plane.add_child(shape)
	root.add_child(plane)
	var trials := 0
	var retaining := 0
	var poses := 0
	var hashes := {}
	var measures := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var candidate: String = trial.assets[treatment]
		var selected := trial.duplicate(true)
		selected.assets.modern = candidate
		hashes[treatment] = FileAccess.get_sha256(candidate)
		assert(not hashes[treatment].is_empty())
		Registry.entries[BODY] = selected
		var avatar := HumanAvatar.new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x481)
		assert(actor.native_body == BODY and actor.native_hue == 0x481 and actor.contact.feet.is_empty())
		check_retarget(actor, Registry.asset_path(base, treatment), treatment == "modern")
		for flags: int in [0, 0x40]:
			for type: int in [5, 8, 14, 15]:
				var choices: Array = Modes["1" if flags == 0 else "0"].get(str(type), Modes["0"][str(type)])
				for variation: int in [0, 1, 2, 127]:
					var packet := decode(game, type, variation)
					assert(Profile.dispatch(avatar, packet, true, flags))
					assert(actor.current_clip == choices[variation % choices.size()] and actor.entry == selected)
					trials += 1
				for variation: int in [0, 128, 255]:
					var packet := decode(game, type, variation)
					var accepted := Classic.dispatch(avatar, packet)
					var clip: String = actor.current_clip
					assert(Profile.dispatch(avatar, packet, variation > 0, flags) == accepted and actor.current_clip == clip)
					retaining += 1
		for height: float in [-4.0, .35]:
			plane.position.y = height
			plane.rotation.x = .09
			await physics_frame
			await physics_frame
			for form: Array in [[15, 0], [14, 0], [5, 0], [5, 1], [8, 0]]:
				var expected: String = Modes["0"][str(form[0])][form[1]]
				var motion := sample_compact(avatar, decode(game, form[0], form[1]), expected)
				poses += 31
				if height < 0.0:
					measures["%s:%s" % [treatment, expected]] = motion
				else:
					assert(measures["%s:%s" % [treatment, expected]] == motion)
		avatar.free()
	Registry.entries[BODY] = trial
	for hue: int in [0, 0x481, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		assert(corpse.find_children("*", "MeshInstance3D", true, false)[0].mesh.get_surface_count() == 8)
		corpse.free()
	Registry.entries[BODY] = base
	plane.free()
	game.free()
	assert(trials == 96 and retaining == 72 and poses == 930)
	var surface: Array = measures["modern:KrakenSurface"]
	assert(surface[4] >= .30 and surface[4] <= .40 and surface[3] > 1.50)
	assert(measures["modern:KrakenPoise"][2] < .20)
	assert(measures["modern:KrakenAlert"][2] > .75)
	assert(measures["modern:KrakenFinThrust"][2] > 1.40)
	if not installed:
		var file := FileAccess.open(Folder + "kraken-compact-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"routes": trials, "classic_comparisons": retaining, "waterline_poses": poses,
			"corpse_hues": 4, "actions": measures, "scene_sha256": hashes,
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	print("KRAKEN ENHANCED: ", trials, " selections, ", retaining, " Classic comparisons, ",
		poses, " waterline poses and four native corpse hues")
	print(measures)
	quit()

func decode(game: Node, type: int, variation: int) -> Dictionary:
	var packet := PackedByteArray([0xe2])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, type, 0, 0, variation]))
	game._handle(packet)
	return game.last_mobile_actions[SERIAL]

func check_retarget(actor: Node3D, source: String, retargeted: bool) -> void:
	var model := (load(source) as PackedScene).instantiate()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var prior := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var rig: Skeleton3D = actor.skeleton
	var recipe := Compact.new()
	for bone in prior.get_bone_count():
		var name := prior.get_bone_name(bone)
		assert(rig.get_bone_name(bone) == name and rig.get_bone_parent(bone) == prior.get_bone_parent(bone))
		var rest := prior.get_bone_rest(bone)
		if retargeted:
			rest.origin = recipe.compact_position(name, rest.origin)
		assert(rig.get_bone_rest(bone).is_equal_approx(rest))
	for name in player.get_animation_list():
		var before := player.get_animation(name)
		var after: Animation = actor.animator.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.track_get_key_count(track) == after.track_get_key_count(track))
			if before.track_get_type(track) != Animation.TYPE_POSITION_3D or not retargeted:
				assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
				continue
			var bone := str(before.track_get_path(track).get_subname(0))
			for key in before.track_get_key_count(track):
				assert(before.track_get_key_time(track, key) == after.track_get_key_time(track, key))
				var point := recipe.compact_position(bone, before.track_get_key_value(track, key))
				assert(after.track_get_key_value(track, key) == point)
	recipe.free()
	model.free()

func sample_compact(avatar: Node3D, packet: Dictionary, expected: String) -> Array:
	var actor: Node3D = avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var model_basis: Basis = actor.model.basis
	var anchor: Vector3 = avatar.global_position
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Profile.dispatch(avatar, packet, true, 0x40) and actor.current_clip == expected)
	# Complete the normal crossfade before seeking to the exact fitted poses.
	player.advance(.13)
	var bounds: Array[AABB] = []
	var tips := PackedVector2Array()
	for frame in 31:
		player.seek(player.current_animation_length * float(frame) / 30.0, true)
		avatar._physics_process(.01)
		actor._physics_process(.01)
		rig.force_update_all_bone_transforms()
		var box := Geometry.deformed_bounds(mesh, rig)
		assert(box.position.is_finite() and box.size.is_finite() and box.size.length() < 22.0)
		assert(avatar.global_position.is_equal_approx(anchor) and is_zero_approx(avatar.ground_offset))
		assert(actor.contact.contacts.is_empty() and actor.model.basis.is_equal_approx(model_basis))
		bounds.append(box)
		tips.append(Vector2(tip(rig, "l"), tip(rig, "r")))
	actor._process(actor.action_remaining + .001)
	avatar.animate(false, 0.0, .016, 0.0)
	assert(actor.current_clip == "Idle")
	return [bounds[0].size.x, bounds[-1].size.x, lift(tips),
		bounds[-1].end.y - bounds[0].end.y, float(bounds[0].size.x / bounds[-1].size.x)]
