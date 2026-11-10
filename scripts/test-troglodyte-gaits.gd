# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-troglodyte-enhanced.gd"

const Modes := preload("res://Presentation/TroglodyteModesVisual.gd")
const VISUAL_PATH := "res://Presentation/TroglodyteModesVisual.gd"
const GAITS := ["ReadyStance", "TroglodytePeaceWalk", "TroglodyteSprint"]
const PATH := "res://../work/creatures/native-form-audit/enhanced-source-gaps/"
const SAMPLE_COUNT := 61
var greatest_gap := 0.0
var largest_seam := 0.0
var greatest_gap_by_clip := {}
var flat_idle_sole_gap := 0.0

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var row := Registry.entry(BODY).duplicate(true)
	if "--retained" in args:
		Registry.entries[BODY] = row.troglodyte_gaits.base
		await super.run()
		return
	var active := "--active" in args
	assert(active == row.has("troglodyte_gaits"))
	var base: Dictionary = row.troglodyte_gaits.base if active else row.duplicate(true)
	if not active:
		row.archive_grounded_gestures.append_array(GAITS)
		row.presentation_script = VISUAL_PATH
		for treatment: String in row.assets:
			row.assets[treatment] = PATH + "troglodyte-gaits-%s.scn" % treatment
	Registry.entries[BODY] = row
	var metrics := {}
	for treatment: String in row.assets:
		var actor := new_actor(treatment)
		Exact.check_earlier_keys(actor.animator, base.assets[treatment])
		verify_modes(actor)
		metrics[treatment] = motion(actor)
		actor.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in row.assets:
			sample_gait_ground(new_actor(treatment), plane)
		plane.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("static_cadaver") and corpse.get_meta("death_clip") == "Death")
		assert(corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
		corpse.free()
		static_corpses += 1
	assert(ground_poses == SAMPLE_COUNT * GAITS.size() * row.assets.size() * SLOPES.size())
	var hashes := {}
	for treatment: String in row.assets:
		hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
	if active:
		assert(hashes == row.asset_sha256)
	else:
		var file := FileAccess.open(PATH + "troglodyte-gaits-evidence.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"sha256": hashes, "metrics": metrics, "minimum_gap": lowest,
			"maximum_gap": greatest_gap, "largest_loop_seam": largest_seam, "terrain_poses": ground_poses,
			"maximum_gap_by_clip": greatest_gap_by_clip, "flat_idle_sole_gap": flat_idle_sole_gap,
			"static_corpses": static_corpses, "test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"renderer_sha256": FileAccess.get_sha256(VISUAL_PATH)}, "	"))
		file.close()
	print("TROGLODYTE GAITS: ", ground_poses, " support poses; ", static_corpses, " corpse hues; gap ",
		lowest, " to ", greatest_gap, " m; largest loop seam ", largest_seam, " m")
	quit()

func new_actor(treatment: String) -> Node3D:
	var actor := Registry.create(BODY)
	assert(actor is Modes)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(BODY, 1109)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func verify_modes(actor: Node3D) -> void:
	actor.set_native_combat_flags(0x40)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "Idle" and actor.action_remaining == 0.0)
	actor.set_native_combat_flags(0)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "ReadyStance")
	actor.play_gait(true, 1.8)
	assert(actor.current_clip == "TroglodytePeaceWalk" and is_equal_approx(actor.animator.speed_scale, 1.0))
	actor.play_gait(true, 7.0)
	assert(actor.current_clip == "TroglodyteSprint" and actor.animator.speed_scale > 1.0)
	actor.set_native_combat_flags(0x40)
	assert(actor.current_clip == "TroglodyteOpenReach" and actor.action_remaining > 0.0)
	actor.set_native_combat_flags(0x41)
	assert(actor.current_clip == "TroglodyteOpenReach")
	assert(actor.receive_action({"body": BODY, "protocol": "classic", "action": 6}))
	actor.set_native_combat_flags(0)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "Attack3" and actor.action_remaining > 0.0)
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "ReadyStance")
	actor.set_native_combat_flags(0x40)
	actor.set_native_combat_flags(0)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "ReadyStance" and actor.action_remaining == 0.0)
	actor.set_native_combat_flags(0x40)
	actor.action_remaining = 0.0
	actor.play_gait(true, 2.0)
	assert(actor.current_clip == "Walk")
	assert(actor.receive_action({"body": BODY, "protocol": "classic", "action": 11}))
	assert(actor.current_clip == "Pillage")
	assert(actor.receive_action({"body": BODY, "protocol": "classic", "action": 2}))
	actor.set_native_combat_flags(0)
	actor.set_native_combat_flags(0x40)
	actor.play_gait(true, 7.0)
	assert(actor.dead and actor.current_clip == "Death")
	actor.dead = false
	actor.action_remaining = 0.0

func motion(actor: Node3D) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var metrics := {}
	for clip: String in ["Walk", "Idle"] + GAITS:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var gait_duration := player.get_animation("TroglodytePeaceWalk").length
		var start := 412.0 / 120.0 if clip == "Walk" else 0.0
		var duration := gait_duration if clip == "Walk" else player.current_animation_length
		var first: Array[Transform3D] = []
		var wrist_sum := 0.0
		var head_sum := 0.0
		var stride := 0.0
		for frame in SAMPLE_COUNT:
			var elapsed := duration * float(frame) / (SAMPLE_COUNT - 1)
			player.seek(start + minf(elapsed, duration - .00001), true)
			rig.force_update_all_bone_transforms()
			var hips := point(rig, "bip01 pelvis")
			wrist_sum += .5 * (point(rig, "bip01 l hand").y + point(rig, "bip01 r hand").y) - hips.y
			head_sum += point(rig, "bip01 head").y
			stride = maxf(stride, absf(point(rig, "bip01 l foot").z - point(rig, "bip01 r foot").z))
			if clip in GAITS and (frame == 0 or frame == SAMPLE_COUNT - 1):
				for bone in rig.get_bone_count():
					var pose := rig.global_transform * rig.get_bone_global_pose(bone)
					if frame == 0:
						first.append(pose)
					else:
						var seam := first[bone].origin.distance_to(pose.origin)
						assert(seam < .001, str([clip, bone, seam]))
						largest_seam = maxf(largest_seam, seam)
		metrics[clip] = {"wrist_height": wrist_sum / SAMPLE_COUNT, "head_height": head_sum / SAMPLE_COUNT,
			"stride": stride}
	assert(metrics.TroglodytePeaceWalk.wrist_height < metrics.Walk.wrist_height - .16)
	assert(metrics.ReadyStance.head_height < metrics.Idle.head_height - .30)
	assert(metrics.TroglodyteSprint.head_height < metrics.Walk.head_height - .20)
	assert(metrics.TroglodyteSprint.stride > metrics.Walk.stride * 1.15)
	return metrics

func sample_gait_ground(actor: Node3D, plane: StaticBody3D) -> void:
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var anchor: Transform3D = actor.global_transform
	var normal := plane.global_basis.y.normalized()
	for clip: String in GAITS:
		actor.animator.stop()
		actor.current_clip = clip
		actor.animator.play(clip, 0.0)
		actor.animator.advance(0.0)
		for frame in SAMPLE_COUNT:
			actor.animator.seek(actor.animator.current_animation_length * frame / (SAMPLE_COUNT - 1), true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and gap > .0004 and gap < .02 and actor.global_transform == anchor, str([clip, frame, gap]))
			lowest = minf(lowest, gap)
			greatest_gap = maxf(greatest_gap, gap)
			greatest_gap_by_clip[clip] = maxf(greatest_gap_by_clip.get(clip, 0.0), gap)
			if clip == "ReadyStance" and normal.is_equal_approx(Vector3.UP):
				for foot: Dictionary in actor.contact.feet:
					var sole_gap := absf(actor.contact.sole(foot).y - plane.global_position.y)
					assert(sole_gap < .02, str([actor.treatment, frame, sole_gap]))
					flat_idle_sole_gap = maxf(flat_idle_sole_gap, sole_gap)
			ground_poses += 1
	actor.free()

func point(rig: Skeleton3D, name: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
