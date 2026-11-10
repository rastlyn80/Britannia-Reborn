# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-blood-elemental-mountain-goat-enhanced.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")


static func modes_for(body: int) -> Dictionary:
	if body == 159:
		return {"0": {"8": [Batch.BloodClips[28]], "15": [Batch.BloodClips[23]]}, "1": {}}
	var quiet: String = Batch.MountainClips[25]
	var dip: String = Batch.MountainClips[26]
	return {"0": {"0": [quiet, quiet, quiet, quiet, quiet, quiet], "2": [quiet, quiet],
		"5": [dip, quiet], "8": [quiet], "11": [quiet, quiet, quiet], "14": [quiet], "15": [quiet]}, "1": {"5": [dip]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	for treatment: String in row.assets:
		row.assets[treatment] = Batch.Destination + "%d-%s.scn" % [body, treatment]
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = Batch.BloodClips.values() if body == 159 else Batch.MountainClips.values()
	return row


func actor_for(body: int, row: Dictionary, treatment: String) -> Node3D:
	if Installed.enabled:
		return super.actor_for(body, row, treatment)
	var path := "SourceEnhancedBloodElementalVisual.gd" if body == 159 else "SourceEnhancedMountainGoatVisual.gd"
	var renderer := load(Batch.Destination + path) as GDScript
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
	for body: int in [159, 88]:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var results := {}
	for body: int in [159, 88]:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else row_for(body, base)
		assert(row.enhanced_source_action_groups == modes_for(body))
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var result := await inspect_body(game, body, base, row)
		assert(result.poses == 930 and result.falls == 60)
		assert(result.routes == (48 if body == 159 else 168) and result.classic == (36 if body == 159 else 126))
		results[str(body)] = result
		print("BLOOD ELEMENTAL AND MOUNTAIN GOAT RUNTIME ", body, " ", result)
	game.free()
	if not installed:
		var file := FileAccess.open(Batch.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": results, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


func inspect_body(game: Node, body: int, base: Dictionary, row: Dictionary) -> Dictionary:
	var result := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0,
		"routes": 0, "classic": 0, "growth_resets": 0, "visible_motion": {}, "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := actor_for(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
			var crest := actor.model.find_child("BloodSurgeCrest", true, false) as MeshInstance3D
			var pool := actor.get_node_or_null("BloodRisePool") as MeshInstance3D
			if tilt == Vector3.ZERO:
				Giants.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, row.enhanced_source_action_groups)
				result.routes += counts.x
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			var types := [15, 8] if body == 159 else [2, 5]
			for kind: int in types:
				var request := decode(game, body, kind, 0)
				var clip: String = row.enhanced_source_action_groups["0"][str(kind)][0]
				start_action(avatar, request, clip)
				var first := 0.0
				var low := INF
				var high := -INF
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%d %s %s support gap %.6f" % [body, treatment, clip, gap])
					result.gap = minf(result.gap, gap)
					var height := landmark(actor, "bip01 head").y
					if body == 159:
						assert(crest != null and pool != null)
						var body_bounds := Geometry.deformed_bounds(mesh, actor.skeleton)
						height = body_bounds.merge(Geometry.deformed_bounds(crest, actor.skeleton)).size.y
						assert(pool.visible == (kind == 15 and sample / 30.0 < .59))
						if pool.visible:
							var plane_normal := floor.basis.y
							assert(is_equal_approx(plane_normal.dot(pool.global_position - floor.position), .005))
					first = height if sample == 0 else first
					low = minf(low, height)
					high = maxf(high, height)
					result.poses += 1
				if tilt == Vector3.ZERO and treatment == "modern":
					result.visible_motion[clip] = {"first": first, "low": low, "high": high}
				for phase: float in [.11, .63]:
					start_action(avatar, request, clip)
					seek(actor, phase)
					var witness := inspect_fall(actor, floor, body, row)
					result.falls += 1
					result.jump = maxf(result.jump, witness.jump)
					result.fall_gap = minf(result.fall_gap, witness.gap)
			if body == 159:
				for attack: bool in [true, false]:
					start_action(avatar, decode(game, body, 15, 0), Batch.BloodClips[23])
					seek(actor, .11)
					var joint: int = actor.skeleton.find_bone("__root")
					assert(actor.skeleton.get_bone_pose_scale(joint).length() < .6)
					if attack:
						assert(Dispatch.dispatch(avatar, {"body": body, "protocol": "classic", "action": 4, "frames": 7}, true, 64))
					else:
						actor.action_remaining = 0.0
						actor.play_gait(true, 1.8)
					for frame in 22:
						actor.animator.advance(1.0 / 60.0)
					assert(actor.skeleton.get_bone_pose_scale(joint).is_equal_approx(Vector3.ONE))
					result.growth_resets += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	return result


func inspect_fall(source: Node3D, floor: StaticBody3D, body: int, row: Dictionary) -> Dictionary:
	var fallen := actor_for(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	for label: String in ["bip01 head", "bip01 r hand", "bip01 l foot"]:
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
	if body == 159:
		assert(corpse.has_node("BloodSurgeCrest") and not corpse.has_node("BloodRisePool"))
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}
