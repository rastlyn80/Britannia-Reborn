# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const DIRECTORY := "res://../work/creatures/native-form-audit/enhanced-source-gaps/"
const GARGOYLE := 753
const GARGOYLE_FIDGET := "UopGargoyleQuietFidget"
const MAPPING := {
	267: {26: "TroglodyteSettleFidget", 27: "TroglodyteRaisedFidget"},
	692: {1: "UopHalberdHover", 25: "UopHalberdReadyHover"},
	705: {26: "StonePeaceGesture", 27: "StoneWarGesture"},
	753: {26: GARGOYLE_FIDGET, 27: "UopGargoyleLunge"},
	831: {25: "Idle", 26: "UopParrotWingTuck"},
	1246: {1: "Idle", 26: "DormantShuffle"},
	1247: {1: "Idle", 25: "Dormant"},
}
const CANDIDATES := {267: "troglodyte-fidgets", 753: "gargoyle-quiet-fidget"}

func run() -> void:
	var selector: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "official-enhanced-action-selector.json"))
	var proofs := {}
	var checked_clips := 0
	for body: int in MAPPING:
		var base := Registry.entry(body)
		var row := base.duplicate(true)
		if CANDIDATES.has(body):
			for treatment: String in row.assets:
				row.assets[treatment] = DIRECTORY + "%s-%s.scn" % [CANDIDATES[body], treatment]
		Registry.entries[body] = row
		var groups := {}
		for selection: Dictionary in selector.fidget_choices:
			if int(selection.body) != body:
				continue
			assert(int(selection.subaction) == -1)
			for group: int in selection.groups:
				assert(MAPPING[body].has(group))
				groups[group] = MAPPING[body][group]
		assert(groups == MAPPING[body])
		var assets := {}
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			if CANDIDATES.has(body):
				Exact.check_earlier_keys(actor.animator, base.assets[treatment])
			for clip: String in groups.values():
				assert(actor.animator.has_animation(clip) and actor.animator.get_animation(clip).length > 0.0,
					str([body, treatment, clip]))
				checked_clips += 1
			if body == GARGOYLE:
				check_wrist(actor)
			assets[treatment] = FileAccess.get_sha256(row.assets[treatment])
			actor.free()
		proofs[body] = {"groups": groups, "assets": assets, "prepared": CANDIDATES.has(body)}
	var row := Registry.entry(GARGOYLE)
	row.archive_grounded_gestures = [GARGOYLE_FIDGET]
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in row.assets:
			sample_ranked_ground(plane, GARGOYLE, treatment)
		plane.free()
		await physics_frame
	assert(ground_poses == 31 * SLOPES.size() * row.assets.size() and lowest >= .0019)
	var file := FileAccess.open(DIRECTORY + "fidget-candidate-routing.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"mapped_variants": selector.fidget_choices.size(), "loaded_clips": checked_clips,
		"gargoyle_ground_poses": ground_poses, "minimum_gap": lowest, "bodies": proofs}, "\t"))
	file.close()
	print("ENHANCED FIDGET CANDIDATES: ", checked_clips, " clip checks across ", proofs.size(),
		" bodies, ", ground_poses, " Gargoyle ground poses")
	quit()

func check_wrist(actor: Node3D) -> void:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var wrist := rig.find_bone("bip01 l hand")
	player.play(GARGOYLE_FIDGET, 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var start := rig.to_global(rig.get_bone_global_pose(wrist).origin)
	player.seek(.50, true)
	rig.force_update_all_bone_transforms()
	var peak := rig.to_global(rig.get_bone_global_pose(wrist).origin)
	assert(peak.y > start.y + .08, str([actor.treatment, start, peak]))
