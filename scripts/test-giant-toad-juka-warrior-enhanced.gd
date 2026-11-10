# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Fit := preload("bake-giant-toad-juka-warrior-enhanced.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const NativeHue := preload("res://Presentation/HumanHue.gd")
const SourceModes := {
	80: {"0": {"2": ["GiantToadQuietBreath", "GiantToadQuietBreath"],
		"5": ["GiantToadTongueSnap", "GiantToadQuietBreath"], "8": ["GiantToadQuietBreath"],
		"11": ["GiantToadQuietBreath", "GiantToadQuietBreath", "GiantToadQuietBreath"],
		"14": ["GiantToadQuietBreath"], "15": ["GiantToadQuietBreath"]}, "1": {"5": ["GiantToadTongueSnap"]}},
	764: {"0": {"8": ["JukaWarriorGuardKick"], "15": ["JukaWarriorCrouchedRise"]}, "1": {}},
}


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var base := {}
	for body: int in SourceModes:
		base[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var proof := {}
	for body: int in SourceModes:
		var row := Registry.entry(body) if installed else candidate_row(body, base[body])
		assert(row.enhanced_source_action_groups == SourceModes[body])
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var result := await review_body(game, body, row)
		assert(result.has("routes"))
		proof[str(body)] = result
		Registry.entries[body] = base[body]
	game.free()
	if not installed:
		var report := FileAccess.open(Fit.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(report != null)
		report.store_string(JSON.stringify({"bodies": proof, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		report.close()
	quit()


static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [body, treatment]
	row.enhanced_source_action_groups = SourceModes[body]
	row.archive_grounded_gestures = (Fit.ToadClips if body == 80 else Fit.JukaClips).values()
	row.presentation_script = "res://Presentation/" + (
		"SourceEnhancedGiantToadVisual.gd" if body == 80 else "SourceEnhancedJukaWarriorVisual.gd"
	)
	return row


func create_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = Registry.create(body) if Installed.enabled else load(Fit.Destination + row.presentation_script.get_file()).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func review_body(game: Node, body: int, row: Dictionary) -> Dictionary:
	var proof := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "gap": INF, "jump": 0.0, "hashes": {}, "shape": {}}
	var routes := {}
	for kind: String in SourceModes[body]["0"]:
		var choices: Array = SourceModes[body]["0"][kind]
		for variation in choices.size():
			if not routes.has(choices[variation]):
				routes[choices[variation]] = Vector2i(int(kind), variation)
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				var counts := check_routes(avatar, game, body, SourceModes[body])
				proof.routes += counts.x
				proof.classic += counts.y
				proof.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if treatment == "modern":
					check_dyes(actor)
			for clip: String in routes:
				var route: Vector2i = routes[clip]
				var packet := decode(game, body, route.x, route.y)
				if tilt == Vector3.ZERO and treatment == "modern":
					start_action(actor, avatar, packet, clip)
					proof.shape[clip] = check_shape(actor, clip)
				start_action(actor, avatar, packet, clip)
				for index in 31:
					sample_pose(actor, index / 30.0)
					var gap := gap_to_plane(actor, floor)
					assert(gap >= .0018, "%d %s phase %.3f gap %.7f" % [body, clip, index / 30.0, gap])
					proof.gap = minf(proof.gap, gap)
					proof.poses += 1
				for phase: float in [.18, .49]:
					start_action(actor, avatar, packet, clip)
					sample_pose(actor, phase)
					proof.jump = maxf(proof.jump, check_handoff(actor, row, floor))
					proof.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("GIANT TOAD AND JUKA WARRIOR RUNTIME ", body, " ", proof)
	return proof


func check_dyes(actor: Node3D) -> void:
	var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
	for hue: int in [0, 0x455, 0x8035]:
		actor.apply_identity(actor.native_body, hue)
		var shell := mesh.get_active_material(0) as ShaderMaterial
		assert(shell.get_shader_parameter("hue_palette") == NativeHue.palette(hue))
		assert(shell.get_shader_parameter("use_hue") == (hue != 0))
		assert(shell.get_shader_parameter("partial_hue") == ((hue & 0x8000) != 0))


func start_action(actor: Node3D, avatar: Avatar, packet: Dictionary, clip: String) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.20)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and actor.current_clip == clip)
	actor.animator.advance(.15)


func sample_pose(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact._process_modification_with_delta(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func joint_position(actor: Node3D, joint: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint)).origin)


func gap_to_plane(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	return Ground.minimum_plane_gap(actor.fitted_fall.skin, rig, rig.global_transform, floor.position, floor.basis.y)


func check_shape(actor: Node3D, clip: String) -> float:
	sample_pose(actor, 0.0)
	match clip:
		"GiantToadTongueSnap":
			var closed := joint_position(actor, Fit.Tongue[-1]).z - joint_position(actor, "bip01 head").z
			sample_pose(actor, .28)
			var extension := joint_position(actor, Fit.Tongue[-1]).z - joint_position(actor, "bip01 head").z - closed
			assert(extension >= .50)
			return extension
		"JukaWarriorGuardKick":
			var start := joint_position(actor, "bip01 l foot").z
			sample_pose(actor, .90)
			var reach := joint_position(actor, "bip01 l foot").z - start
			assert(reach >= .48 and joint_position(actor, "bip01 l foot").y > joint_position(actor, "bip01 r foot").y + .16)
			return reach
		"JukaWarriorCrouchedRise":
			var crouched := joint_position(actor, "bip01 head").y
			sample_pose(actor, .96)
			var rise := joint_position(actor, "bip01 head").y - crouched
			assert(rise > .35)
			return rise
		_:
			var rest := joint_position(actor, "bip01 spine1").y
			sample_pose(actor, .25)
			return absf(joint_position(actor, "bip01 spine1").y - rest)


func check_handoff(source: Node3D, row: Dictionary, floor: StaticBody3D) -> float:
	var body: int = source.native_body
	var fallen := create_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform
	fallen.rotate_y(.29)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	var joints := ["bip01 head", Fit.Tongue[-1], "bip01 r hand"] if body == 80 else ["bip01 head", "bip01 r hand", "bip01 l foot"]
	var jump := 0.0
	for joint: String in joints:
		jump = maxf(jump, joint_position(source, joint).distance_to(joint_position(fallen, joint)))
	assert(duration > 0 and jump < .002, "%d %s displayed fall jump %.7f" % [body, source.current_clip, jump])
	for index in 31:
		fallen.animator.seek(duration * index / 30.0, true)
		assert(gap_to_plane(fallen, floor) >= .0018)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return jump
