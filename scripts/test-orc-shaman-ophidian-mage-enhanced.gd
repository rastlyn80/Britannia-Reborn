# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/orc-shaman-ophidian-mage/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Modes := {
	140: {"0": {"8": ["OrcShamanStaffBrace"], "15": ["OrcShamanStaffRise"]}, "1": {}},
	85: {"0": {"5": ["OphidianMageStaffWatch", "OphidianMageHighWard"],
		"8": ["OphidianMageTailSignal"], "15": ["OphidianMageCoilUnwind"]},
		"1": {"5": ["OphidianMageStaffWatch"]}},
}
const StaffNames := {140: "OrcShamanStaff", 85: "OphidianMageStaff"}
const StaffBones := {140: "orc shaman staff", 85: "ophidian mage staff"}


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Modes:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Modes:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else candidate_row(body, base)
		assert(row.enhanced_source_action_groups == Modes[body])
		var routes := {}
		for kind: String in Modes[body]["0"]:
			var clips: Array = Modes[body]["0"][kind]
			for i in clips.size():
				routes[clips[i]] = [int(kind), i]
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		evidence[str(body)] = await review_staff(game, body, routes, base, installed)
		assert(not evidence[str(body)].is_empty())
		Registry.entries[body] = base
	game.free()
	if not installed:
		var receipt := FileAccess.open(Stage + "terrain-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify({"bodies": evidence, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		receipt.close()
	quit()


static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = []
	for choices: Array in Modes[body]["0"].values():
		row.archive_grounded_gestures.append_array(choices)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
	if body == 140:
		row.presentation_script = "res://Presentation/SourceEnhancedSkeletalMageVisual.gd"
	else:
		row.presentation_script = "res://Presentation/SourceEnhancedOphidianMageVisual.gd"
		row.grounded_gestures = row.grounded_gestures + row.archive_grounded_gestures
	return row


func actor_for(body: int, treatment: String, installed: bool) -> Node3D:
	var actor: Node3D = Registry.create(body) if (body == 140 or installed) else load(Stage + "SourceEnhancedOphidianMageVisual.gd").new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func select_fit(actor: Node3D, avatar: Avatar, request: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.2)
	assert(Dispatch.dispatch(avatar, request, true, 0x40))
	actor.animator.advance(.17)


func review_staff(game: Node, body: int, routes: Dictionary, base: Dictionary, installed: bool) -> Dictionary:
	var receipt := {"poses": 0, "falls": 0, "hues": 0, "routes": 0, "classic": 0, "hashes": {},
		"minimum": INF, "fall_minimum": INF, "maximum_jump": 0.0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in Registry.entry(body).assets:
			var actor := actor_for(body, treatment, installed)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := actor_skins(actor)
			if tilt == Vector3.ZERO:
				check_retained(actor, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, Modes[body])
				receipt.routes += counts.x
				receipt.classic += counts.y
				receipt.hashes[treatment] = FileAccess.get_sha256(Registry.asset_path(Registry.entry(body), treatment))
			for clip: String in routes:
				var choice: Array = routes[clip]
				var request := decode(game, body, choice[0], choice[1])
				select_fit(actor, avatar, request)
				assert(actor.current_clip == clip)
				for i in 31:
					seek(actor, i / 30.0)
					var gap := skin_gap(actor, skins, floor)
					assert(gap >= .0019, "%d %s %s %s gap %.8f" % [body, treatment, clip, tilt, gap])
					assert(bone(actor, StaffBones[body]).distance_to(bone(actor, "cp_grasp_rhand")) < .00001)
					receipt.minimum = minf(receipt.minimum, gap)
					receipt.poses += 1
				for phase: float in [.10, .58]:
					select_fit(actor, avatar, request)
					seek(actor, phase)
					var death := check_fall(actor, floor, installed)
					assert(not death.is_empty(), "%d %s %s %s fall" % [body, treatment, clip, tilt])
					receipt.maximum_jump = maxf(receipt.maximum_jump, death.jump)
					receipt.fall_minimum = minf(receipt.fall_minimum, death.gap)
					receipt.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 0x8035, 0x455]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_child(StaffNames[body], true, false) != null)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		receipt.hues += 1
	print("ARMED MAGES ", body, " ", receipt)
	return receipt


func check_retained(actor: Node3D, source: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for label: String in player.get_animation_list():
		var before := player.get_animation(label)
		var after: Animation = actor.animator.get_animation(label)
		assert(after != null and before.length == after.length)
		assert(after.get_track_count() == before.get_track_count() + (1 if actor.native_body == 140 else 0))
		for track in before.get_track_count():
			var path := before.track_get_path(track)
			assert(path == after.track_get_path(track))
			if actor.native_body == 140 and label in ["Death", "Fidget"] and path.get_concatenated_subnames() == "bip01 r upperarm":
				continue
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track), label)
	model.free()


func actor_skins(actor: Node3D) -> Array[Dictionary]:
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, actor.skeleton))
	assert(skins.size() == 2)
	return skins


func seek(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func bone(actor: Node3D, label: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)


func skin_gap(actor: Node3D, skins: Array[Dictionary], floor: StaticBody3D) -> float:
	var result := INF
	for skin: Dictionary in skins:
		result = minf(result, Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform,
			floor.position, floor.basis.y))
	return result


func check_fall(actor: Node3D, floor: StaticBody3D, installed: bool) -> Dictionary:
	var body: int = actor.native_body
	var label: String = StaffBones[body]
	var head := bone(actor, "bip01 head")
	var hand := bone(actor, label)
	var fallen := actor_for(body, actor.treatment, installed)
	fallen.global_transform = actor.global_transform
	fallen.model.transform = actor.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(actor)
	var jump := maxf(bone(fallen, "bip01 head").distance_to(head), bone(fallen, label).distance_to(hand))
	assert(duration > 0.0 and jump < .002, "%s fall pose jump %.7f" % [actor.current_clip, jump])
	var skins := actor_skins(fallen)
	var gap := INF
	for i in 31:
		fallen.animator.seek(duration * i / 30.0, true)
		fallen.skeleton.force_update_all_bone_transforms()
		gap = minf(gap, skin_gap(fallen, skins, floor))
	assert(gap >= .0018, "%s fall on %s gap %.8f" % [actor.current_clip, floor.rotation, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_child(StaffNames[body], true, false) != null)
	assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}
