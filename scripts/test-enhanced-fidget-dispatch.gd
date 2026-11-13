# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-creature-wire-routes.gd"

const SourceAction := preload("res://Presentation/EnhancedCreatureActions.gd")
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Legacy := preload("res://Presentation/NativeMobileActions.gd")
const DIRECTORY := "res://../work/creatures/native-form-audit/enhanced-source-gaps/"
const CANDIDATE := {267: "troglodyte-fidgets", 753: "gargoyle-quiet-fidget"}

func run() -> void:
	Registry.load_index()
	var installed := "--installed" in OS.get_cmdline_user_args()
	var baseline := Registry.entries.duplicate()
	if installed:
		assert(Profile.enable() and Profile.enable())
	var selector: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "official-enhanced-action-selector.json"))
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "fidget-candidate-routing.json"))
	var tables := {}
	for row: Dictionary in selector.fidget_choices:
		var body := str(int(row.body))
		var mode := "0" if row.mode == "combat" else "1"
		var mapped: Dictionary = candidate.bodies[body].groups
		if not tables.has(body):
			tables[body] = {}
		tables[body][mode] = {"5": row.groups.map(func(group: float): return mapped[str(int(group))])}
	tables["267"]["0"]["8"] = ["TroglodyteOpenReach"]
	var tested := 0
	var preserved := 0
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for key: String in tables:
		var body := int(key)
		var base: Dictionary = baseline[body]
		var entry := Registry.entry(body)
		if installed:
			for mode_key: String in tables[key]:
				var actual: Dictionary = entry.enhanced_source_action_groups.get(mode_key, {})
				for action: String in tables[key][mode_key]:
					if actual.get(action) != tables[key][mode_key][action]:
						push_error("Unexpected Enhanced fidget routing: %s" % str([body, mode_key, action, actual.get(action)]))
						game.free()
						quit(1)
						return
		else:
			entry = base.duplicate(true)
			entry["enhanced_source_action_groups"] = tables[key]
			if CANDIDATE.has(body):
				for treatment: String in entry.assets:
					entry.assets[treatment] = DIRECTORY + "%s-%s.scn" % [CANDIDATE[body], treatment]
			Registry.entries[body] = entry
		for treatment: String in entry.assets:
			var avatar := FixtureAvatar.new()
			var visual := Registry.create(body)
			avatar.horse_visual = visual
			visual.treatment = treatment
			root.add_child(avatar)
			avatar.add_child(visual)
			visual.apply_identity(body, 0x8035)
			visual.set_process(false)
			visual.set_physics_process(false)
			for flags: int in [0, 0x40]:
				game.entities[body] = {"serial": body, "body": body, "hue": 0x8035, "flags": flags}
				var mode := "1" if flags == 0 else "0"
				for type: int in [5, 8] if body == 267 else [5]:
					var selected: Array = tables[key][mode].get(str(type), tables[key]["0"][str(type)])
					for variant: int in [0, 1, 2, 3, 127, 128, 255]:
						var bytes := packet(body, 0xe2, type, variant)
						game._handle(bytes)
						var request: Dictionary = game.last_mobile_actions[body]
						var original := dispatch_result(avatar, request, false, flags)
						assert(original == legacy_result(avatar, request))
						assert(original == dispatch_result(avatar, request, true, -1))
						preserved += 2
						if variant > 127:
							assert(original == dispatch_result(avatar, request, true, flags))
							preserved += 1
						else:
							assert(dispatch_result(avatar, request, true, flags) == selected[variant % selected.size()],
								str([body, treatment, flags, type, variant, visual.current_clip, selected]))
							assert(visual.get_meta("native_action") == request)
							tested += 1
						assert(visual.entry == entry)
			for group: int in [17, 18]:
				game._handle(packet(body, 0x6e, group, 0))
				var request: Dictionary = game.last_mobile_actions[body]
				assert(dispatch_result(avatar, request, true, 0) == legacy_result(avatar, request))
				preserved += 1
			if body == 831:
				game._handle(packet(body, 0xe2, 5, 1))
				assert(SourceAction.dispatch(avatar, game.last_mobile_actions[body], true, 0x04))
				assert(visual.current_clip == "Idle")
				tested += 1
			avatar.free()
		Registry.entries[body] = base
	game.free()
	print("ENHANCED DISPATCH TRIAL: ", tested, " actual visual selections and ", preserved, " preserving checks")
	quit()

func dispatch_result(avatar: Node3D, request: Dictionary, enhanced: bool, flags: int) -> String:
	avatar.horse_visual.animator.stop()
	avatar.horse_visual.action_remaining = 0.0
	return avatar.horse_visual.current_clip if SourceAction.dispatch(avatar, request, enhanced, flags) else ""

func legacy_result(avatar: Node3D, request: Dictionary) -> String:
	avatar.horse_visual.animator.stop()
	avatar.horse_visual.action_remaining = 0.0
	return avatar.horse_visual.current_clip if Legacy.dispatch(avatar, request) else ""
