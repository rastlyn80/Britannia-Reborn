# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-skeletal-knight-enhanced.gd"

const New := preload("bake-skeletal-knight-remaining.gd")
const ExactModes := {
	"0": {
		"2": [New.Flinch, New.Flinch], "5": [New.Check, New.Stagger], "8": [Fit.Alert],
		"11": [New.Sweep, New.Sweep, New.Sweep], "14": [New.Brace], "15": [Fit.Rise],
	},
	"1": {"5": [New.Check]},
}
const Cases := [
	[2, 0, New.Flinch], [5, 0, New.Check], [5, 1, New.Stagger], [8, 0, Fit.Alert],
	[11, 0, New.Sweep], [14, 0, New.Brace], [15, 0, Fit.Rise],
]


func run() -> void:
	var base := Registry.entry(Body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	else:
		Registry.entries[Body] = candidate_row(base)
	var row := Registry.entry(Body)
	assert(row.enhanced_source_action_groups == ExactModes)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x8035}
	var proof := {"terrain": 0, "falls": 0, "routes": 0, "classic": 0,
		"minimum_gap": INF, "prop_gap": INF, "maximum_jump": 0.0, "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				var counts := check_routes(avatar, game, Body, ExactModes)
				proof.routes += counts.x
				proof.classic += counts.y
				proof.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			var prop_skins: Array[Dictionary] = []
			for name: String in Props:
				prop_skins.append(Ground.skin_points(actor.model.find_child(name, true, false), actor.skeleton))
			for action: Array in Cases:
				var packet := decode(game, Body, action[0], action[1])
				start_fit(actor, avatar, packet)
				assert(actor.current_clip == action[2])
				for i in 31:
					move_to(actor, i / 30.0)
					var gap := minimum_gap(actor, floor)
					assert(gap >= .0019)
					proof.minimum_gap = minf(proof.minimum_gap, gap)
					for prop_skin: Dictionary in prop_skins:
						var rig: Skeleton3D = actor.skeleton
						var prop_gap := Ground.minimum_plane_gap(prop_skin, rig, rig.global_transform, floor.position, floor.basis.y)
						assert(prop_gap >= .0019)
						proof.prop_gap = minf(proof.prop_gap, prop_gap)
					for item: String in Props:
						assert(world_joint(actor, item.to_lower()).distance_to(world_joint(actor, Props[item])) < .00001)
					proof.terrain += 1
				for phase: float in [.16, .47, .73]:
					start_fit(actor, avatar, packet)
					move_to(actor, phase)
					proof.maximum_jump = maxf(proof.maximum_jump, check_fall(actor, floor))
					proof.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	Registry.entries[Body] = base
	game.free()
	print("SKELETAL KNIGHT REMAINING RUNTIME ", proof)
	if not installed:
		var file := FileAccess.open(New.Output + "fitted-runtime-receipt.json", FileAccess.WRITE)
		assert(file != null)
		proof.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
		file.store_string(JSON.stringify(proof, "\t"))
		file.close()
	quit()


static func candidate_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = New.Output + "147-%s.scn" % treatment
	row.presentation_script = "res://Presentation/SourceEnhancedSkeletalMageVisual.gd"
	row.enhanced_source_action_groups = ExactModes
	row.archive_grounded_gestures = [Fit.Rise, Fit.Alert] + New.Durations.keys()
	return row
