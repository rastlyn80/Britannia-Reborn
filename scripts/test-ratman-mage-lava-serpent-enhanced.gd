# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Mage := preload("bake-ratman-mage-enhanced.gd")
const Lava := preload("bake-lava-serpent-enhanced.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const NativeHue := preload("res://Presentation/HumanHue.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Modes := {
	143: {"0": {
		"2": [Mage.Clips[15], Mage.Clips[15]], "5": [Mage.Clips[26], Mage.Clips[27]], "8": [Mage.Clips[28]],
		"11": [Mage.Clips[12], Mage.Clips[12], Mage.Clips[12]], "14": [Mage.Clips[11]], "15": [Mage.Clips[23]],
	}, "1": {"5": [Mage.Clips[26]]}},
	90: {"0": {"8": [Lava.Clips[28]], "11": [Lava.Clips[4], Lava.Clips[4], Lava.Clips[4]],
		"15": [Lava.Clips[23]]}, "1": {}},
}


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var base := {}
	for body: int in Modes:
		base[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var proof := {}
	for body: int in Modes:
		var row := Registry.entry(body) if installed else candidate_row(body, base[body])
		assert(row.enhanced_source_action_groups == Modes[body])
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var result := await review_body(game, body, row, base[body])
		assert(not result.is_empty())
		proof[str(body)] = result
		Registry.entries[body] = base[body]
	game.free()
	if not installed:
		var output := FileAccess.open(Mage.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": proof, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()


static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Mage.Destination + "%d-%s.scn" % [body, treatment]
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = (Mage.Clips if body == 143 else Lava.Clips).values()
	row.presentation_script = "res://Presentation/SourceEnhanced%sVisual.gd" % ("RatmanMage" if body == 143 else "LavaSerpent")
	return row


func create_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var path: String = row.presentation_script
	if not ResourceLoader.exists(path):
		path = Mage.Destination + path.get_file()
	var actor: Node3D = Registry.create(body) if Installed.enabled else load(path).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func review_body(game: Node, body: int, row: Dictionary, base: Dictionary) -> Dictionary:
	var proof := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "gap": INF,
		"jump": 0.0, "fall_gap": INF, "hashes": {}, "interrupted": 0, "retained": 0, "rise": 0.0,
		"breath_poses": 0, "breath_falls": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				proof.retained += check_retained(actor, base, treatment)
				var counts := check_routes(avatar, game, body, Modes[body])
				proof.routes += counts.x
				proof.classic += counts.y
				proof.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if treatment == "modern":
					check_hues(actor)
			for kind: String in Modes[body]["0"]:
				var clips: Array = Modes[body]["0"][kind]
				for variant in clips.size():
					var clip: String = clips[variant]
					if clips.find(clip) != variant:
						continue
					var packet := decode(game, body, int(kind), variant)
					start_fit(actor, avatar, packet, clip)
					var emerges := clip == Lava.Clips[23]
					var starting_top := 0.0
					var last_top := 0.0
					var surface := actor.model.find_child("Body", true, false) as MeshInstance3D
					for i in 31:
						var phase := i / 30.0
						move_to(actor, phase)
						var gap := skin_gap(actor, floor) + (Lava.emergence_depth(phase) if emerges else 0.0)
						assert(gap >= .0018, "%d %s phase %.3f plane gap %.7f" % [body, clip, phase, gap])
						proof.gap = minf(proof.gap, gap)
						proof.poses += 1
						if body == 143:
							assert(actor.crook.visible and not actor.sword.visible)
							assert(joint(actor, Mage.StaffBone).distance_to(joint(actor, "cp_grasp_rhand")) < .00001)
						if emerges and tilt == Vector3.ZERO and treatment == "modern" and i in [0, 30]:
							last_top = Geometry.deformed_bounds(surface, actor.skeleton).end.y
							if i == 0:
								starting_top = last_top
					if emerges and tilt == Vector3.ZERO and treatment == "modern":
						proof.rise = last_top - starting_top
						assert(proof.rise > .50)
					for phase: float in [.13, .56]:
						start_fit(actor, avatar, packet, clip)
						move_to(actor, phase)
						var fall := check_fall(actor, row, floor)
						proof.jump = maxf(proof.jump, fall.jump)
						proof.fall_gap = minf(proof.fall_gap, fall.gap)
						proof.falls += 1
					if kind == "15":
						check_interrupted(actor, avatar, floor, packet, clip)
						proof.interrupted += 1
			if body == 90:
				check_fire_breath(actor, avatar, row, floor, proof)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("RATMAN MAGE AND LAVA SERPENT RUNTIME ", body, " ", proof)
	return proof


func check_fire_breath(actor: Node3D, avatar: Avatar, row: Dictionary, floor: StaticBody3D, proof: Dictionary) -> void:
	var packet := {"protocol": "classic", "body": 90, "serial": 90, "action": 12,
		"frames": 5, "repeat_count": 1, "delay": 0, "repeat": false, "reverse": false}
	start_fit(actor, avatar, packet, Lava.Breath)
	for sample in 31:
		move_to(actor, sample / 30.0)
		assert(skin_gap(actor, floor) >= .0018)
		proof.breath_poses += 1
	for phase: float in [.21, 1.3 / Lava.BreathDuration]:
		start_fit(actor, avatar, packet, Lava.Breath)
		move_to(actor, phase)
		var fall := check_fall(actor, row, floor)
		proof.jump = maxf(proof.jump, fall.jump)
		proof.fall_gap = minf(proof.fall_gap, fall.gap)
		proof.breath_falls += 1


func check_retained(actor: Node3D, base: Dictionary, treatment: String) -> int:
	var source := (load(Registry.asset_path(base, treatment)) as PackedScene).instantiate()
	var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var checked := 0
	for name: String in player.get_animation_list():
		var old := player.get_animation(name)
		var fitted: Animation = actor.animator.get_animation(name)
		var added := 1 if actor.native_body == 143 and name == "Death" else 0
		assert(old.length == fitted.length and old.get_track_count() + added == fitted.get_track_count())
		for track in old.get_track_count():
			assert(old.track_get_path(track) == fitted.track_get_path(track))
			assert(old.get("tracks/%d/keys" % track) == fitted.get("tracks/%d/keys" % track))
		if added:
			assert(str(fitted.track_get_path(old.get_track_count())).ends_with(":" + Mage.StaffBone))
		checked += 1
	source.free()
	return checked


func check_hues(actor: Node3D) -> void:
	var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
	for hue: int in [0, 0x455, 0x8035]:
		actor.apply_identity(actor.native_body, hue)
		var surface := mesh.get_active_material(0) as ShaderMaterial
		assert(surface.get_shader_parameter("hue_palette") == NativeHue.palette(hue))
		assert(surface.get_shader_parameter("use_hue") == (hue != 0))
		if actor.native_body == 143:
			assert(actor.crook.get_active_material(0) == actor.crook.mesh.surface_get_material(0))


func start_fit(actor: Node3D, avatar: Avatar, request: Dictionary, clip: String) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.20)
	assert(Dispatch.dispatch(avatar, request, true, 64) and actor.current_clip == clip)
	actor.animator.advance(.16)


func move_to(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func check_interrupted(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary, clip: String) -> void:
	start_fit(actor, avatar, request, clip)
	move_to(actor, .17)
	var body: int = actor.native_body
	var action := {"protocol": "classic", "body": body, "serial": body, "action": 4,
		"frames": 5, "repeat_count": 1, "delay": 0}
	assert(Classic.dispatch(avatar, action))
	for step in 20:
		actor.animator.advance(1.0 / 60.0)
	if body == 143:
		assert(actor.sword.visible and not actor.crook.visible)
	else:
		assert(actor.animator.assigned_animation != clip)
		assert(skin_gap(actor, floor) > -.003)


func joint(actor: Node3D, name: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)


func skin_gap(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	return Ground.minimum_plane_gap(actor.fitted_fall.skin, rig, rig.global_transform, floor.position, floor.basis.y)


func check_fall(source: Node3D, row: Dictionary, floor: StaticBody3D) -> Dictionary:
	var body: int = source.native_body
	var fallen := create_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform
	fallen.rotate_y(.29)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(fallen.current_clip == "Death" and duration > 0.0)
	var labels := ["bip01 head", Mage.StaffBone, "cp_grasp_rhand"] if body == 143 else ["bip01 head", "bip01 neck2", "bip01 tail4"]
	var jump := 0.0
	for name: String in labels:
		jump = maxf(jump, joint(source, name).distance_to(joint(fallen, name)))
	assert(jump < .002, "%d %s moved a displayed joint by %.7fm" % [body, source.current_clip, jump])
	var min_gap := INF
	for i in 31:
		fallen.animator.seek(duration * i / 30.0, true)
		var helper: RefCounted = fallen.fitted_fall
		var progress := smoothstep(0.0, helper.blend_length, fallen.animator.current_animation_position)
		var gap: float = skin_gap(fallen, floor) + helper.initial_depth * (1.0 - progress)
		assert(gap >= .0018)
		min_gap = minf(min_gap, gap)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	if body == 143:
		assert(corpse.has_node("RatmanCrook") and not corpse.has_node("RatmanSword"))
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": min_gap}
