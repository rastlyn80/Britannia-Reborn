# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Pair := preload("bake-raptor-slith-enhanced.gd")
const Forms := [730, 734]
const Renderers := {730: "res://Presentation/SourceEnhancedRaptorVisual.gd",
	734: "res://Presentation/SourceEnhancedSlithVisual.gd"}


static func modes_for(body: int) -> Dictionary:
	var clips: Dictionary = Pair.Raptor if body == 730 else Pair.Slith
	return {"0": {"2": [clips[15], clips[15]], "5": [clips[26], clips[27]], "8": [clips[28]],
		"11": [clips[4], clips[4], clips[4]], "14": [clips[25]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = (Pair.Raptor if body == 730 else Pair.Slith).values()
	row.presentation_script = Renderers[body]
	for treatment: String in row.assets:
		row.assets[treatment] = Pair.Destination + "%d-%s.scn" % [body, treatment]
	return row


func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var result := {}
	for body: int in Forms:
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var row := row_for(body, Registry.entry(body))
		var modes: Dictionary = modes_for(body)
		var packets := {}
		for kind: String in modes["0"]:
			var options: Array = modes["0"][kind]
			for variation in options.size():
				if not packets.has(options[variation]):
					packets[options[variation]] = decode(game, body, int(kind), variation)
		assert(packets.size() == row.archive_grounded_gestures.size())
		var counts := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "gaits": 0,
			"breath_poses": 0, "gap": INF, "jump": 0.0}
		for slope: Vector3 in Slopes:
			var floor := await create_floor(slope)
			for treatment: String in row.assets:
				var actor := create_trial_actor(body, row, treatment)
				var avatar := Avatar.new()
				avatar.horse_visual = actor
				if slope == Vector3.ZERO:
					var selection := check_routes(avatar, game, body, modes)
					counts.routes += selection.x
					counts.classic += selection.y
					counts.gaits += check_native_gaits(actor)
				for clip: String in packets:
					start_action(avatar, packets[clip], clip)
					for sample in 31:
						seek(actor, sample / 30.0)
						var gap := minimum_gap(actor, floor, [actor.fall.skin if body == 730 else actor.skin])
						assert(gap >= .0018, "%d %s phase %d floor %.6f" % [body, clip, sample, gap])
						counts.gap = minf(counts.gap, gap)
						counts.poses += 1
					for phase: float in [.19, .67]:
						start_action(avatar, packets[clip], clip)
						seek(actor, phase)
						counts.jump = maxf(counts.jump, check_trial_fall(actor, floor, row))
						counts.falls += 1
				if body == 734:
					counts.breath_poses += check_breath(avatar, game, floor)
				avatar.free()
				actor.free()
			floor.free()
			await physics_frame
		assert(counts.poses == 3255 and counts.falls == 210 and counts.gaits == 18)
		assert(counts.breath_poses == (465 if body == 734 else 0))
		counts["hashes"] = {}
		for treatment: String in row.assets:
			counts.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
		result[str(body)] = counts
		print("RAPTOR AND SLITH RUNTIME ", body, " ", counts)
	game.free()
	var receipt := FileAccess.open(Pair.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(result, "\t"))
	receipt.close()
	quit()


func create_trial_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = load(row.presentation_script).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_native_gaits(actor: Node3D) -> int:
	var raptor: bool = actor.native_body == 730
	var clips := ["RaptorQuietWatch", "RaptorPeaceWalk"] if raptor else ["SlithQuietCoast", "SlithPeaceWalk"]
	actor.action_remaining = 0.0
	for flags: int in [0, 64]:
		actor.set_native_combat_flags(flags)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == (clips[0] if flags == 0 else "Idle"))
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == (clips[1] if flags == 0 else "Walk"))
		actor.play_gait(true, 7.0)
		assert(actor.current_clip == "Run")
	return 6


func check_breath(avatar: Avatar, game: Node, floor: StaticBody3D) -> int:
	var actor := avatar.horse_visual
	var serial: int = actor.native_body
	var wire := PackedByteArray([0x6e])
	wire.append_array(Wire.uint_be(serial, 4))
	wire.append_array(Wire.uint_be(12, 2))
	wire.append_array(Wire.uint_be(5, 2))
	wire.append_array(Wire.uint_be(1, 2))
	wire.append_array(PackedByteArray([0, 0, 0]))
	game._handle(wire)
	assert(Classic.dispatch(avatar, game.last_mobile_actions[serial]))
	assert(actor.current_clip == Pair.Breath and actor.action_remaining >= 1.6)
	actor.animator.advance(.16)
	assert(is_equal_approx(actor.animator.get_playing_speed(), 1.0))
	for sample in 31:
		seek(actor, sample / 30.0)
		assert(minimum_gap(actor, floor, [actor.skin]) >= .0018)
	seek(actor, 1.30 / actor.animator.current_animation_length)
	var muzzle: Vector3 = actor.fire_breath_origin()
	var offset := muzzle.distance_to(landmark(actor, "bip01 head"))
	assert(muzzle.is_finite() and offset > .05 and offset < .6)
	return 31


func check_trial_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> float:
	var body: int = source.native_body
	var fallen := create_trial_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var labels := ["Head", "Tail4", "BackFoot.L"] if body == 730 else ["bip01 head", "bip01 tail2", "bip01 r foot"]
	var jump := 0.0
	for label: String in labels:
		jump = maxf(jump, landmark(source, label).distance_to(landmark(fallen, label)))
	assert(jump < .002, "%d %s handoff moved %.6f m" % [body, source.current_clip, jump])
	for sample in 31:
		seek(fallen, sample / 30.0)
		assert(minimum_gap(fallen, floor, [fallen.fall.skin]) >= .0016)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return jump
