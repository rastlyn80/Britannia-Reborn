# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Iron := preload("bake-golem-enhanced.gd")
const Sand := preload("bake-sand-vortex-enhanced.gd")
const IronVisual := preload("res://Presentation/SourceEnhancedIronGolemVisual.gd")
const SandVisual := preload("res://Presentation/SourceEnhancedSandVortexVisual.gd")
const Forms := [752, 790]
const Modes := {
	752: {"0": {"5": [Iron.Clips[26], Iron.Clips[27]], "8": [Iron.Clips[28]],
		"11": [Iron.Clips[12], Iron.Clips[12], Iron.Clips[12]], "15": [Iron.Clips[23]]}, "1": {"5": [Iron.Clips[26]]}},
	790: {"0": {"2": [Sand.SandClips[15], Sand.SandClips[15]], "5": [Sand.SandClips[26], Sand.SandClips[27]],
		"8": [Sand.SandClips[28]], "11": [Sand.SandClips[4], Sand.SandClips[4], Sand.SandClips[4]],
		"14": [Sand.SandClips[25]], "15": [Sand.SandClips[23]]}, "1": {"5": [Sand.SandClips[26]]}},
}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = (Iron.Clips if body == 752 else Sand.SandClips).values()
	for treatment: String in row.assets:
		row.assets[treatment] = Iron.Destination + "%d-%s.scn" % [body, treatment if body == 752 else "modern"]
	return row


func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var result := {}
	for body: int in Forms:
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var row := row_for(body, Registry.entry(body))
		var modes: Dictionary = Modes[body]
		var packets := {}
		for kind: String in modes["0"]:
			var options: Array = modes["0"][kind]
			for variation in options.size():
				if not packets.has(options[variation]):
					packets[options[variation]] = decode(game, body, int(kind), variation)
		assert(packets.size() == row.archive_grounded_gestures.size())
		var counts := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "interruptions": 0, "gap": INF, "jump": 0.0}
		for slope: Vector3 in Slopes:
			var floor := await create_floor(slope)
			for treatment: String in row.assets if body == 752 else ["modern"]:
				var actor := create_trial_actor(body, row, treatment)
				var avatar := Avatar.new()
				avatar.horse_visual = actor
				if slope == Vector3.ZERO:
					var selection := check_routes(avatar, game, body, modes)
					counts.routes += selection.x
					counts.classic += selection.y
				for clip: String in packets:
					start_action(avatar, packets[clip], clip)
					for sample in 31:
						seek(actor, sample / 30.0)
						var gap := minimum_gap(actor, floor, [actor.fall.skin])
						assert(gap >= .0018, "%d %s phase %d floor %.6f" % [body, clip, sample, gap])
						counts.gap = minf(counts.gap, gap)
						counts.poses += 1
					for phase: float in [.19, .67]:
						start_action(avatar, packets[clip], clip)
						seek(actor, phase)
						counts.jump = maxf(counts.jump, check_trial_fall(actor, floor, row))
						counts.falls += 1
					if clip == SandVisual.Rise:
						check_formation_interrupt(avatar, packets[clip])
						counts.interruptions += 1
				avatar.free()
				actor.free()
			floor.free()
			await physics_frame
		assert(counts.poses == (2325 if body == 752 else 1085) and counts.falls == (150 if body == 752 else 70))
		counts["hashes"] = {}
		for treatment: String in row.assets:
			counts.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
		result[str(body)] = counts
		print("GOLEM AND SAND VORTEX RUNTIME ", body, " ", counts)
	game.free()
	var receipt := FileAccess.open(Iron.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(result, "\t"))
	receipt.close()
	quit()


func create_trial_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = IronVisual.new() if body == 752 else SandVisual.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_formation_interrupt(avatar: Avatar, packet: Dictionary) -> void:
	var actor := avatar.horse_visual as SandVisual
	var joint := actor.skeleton.find_bone("root")
	start_action(avatar, packet, SandVisual.Rise)
	seek(actor, .32)
	var before := actor.skeleton.get_bone_pose_scale(joint)
	assert(before.y < .65 and before.y > .04)
	assert(Classic.dispatch(avatar, {"protocol": "classic", "body": 790, "action": 4}))
	actor.animator.advance(.13)
	assert(actor.current_clip == "Attack" and actor.forming)
	for _frame in 21:
		actor.animator.advance(1.0 / 60.0)
		var scale := actor.skeleton.get_bone_pose_scale(joint)
		assert(scale.y >= before.y - .001 and scale.y <= 1.001)
		before = scale
	assert(not actor.forming and before.is_equal_approx(Vector3.ONE))


func check_trial_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> float:
	var body: int = source.native_body
	var fallen := create_trial_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var labels := ["bone_head", "bip01 l hand", "bip01 r foot"] if body == 752 else ["Head", "hand_l", "hand_r"]
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
