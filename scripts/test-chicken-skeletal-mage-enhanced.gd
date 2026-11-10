# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/chicken-skeletal-mage/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Families := {208: "Chicken", 148: "SkeletalMage"}
const Modes := {
	208: {"0": {"8": ["ChickenLowAlert"], "11": ["ChickenQuickPeck", "ChickenQuickPeck", "ChickenQuickPeck"],
		"15": ["ChickenSettledWatch"]}, "1": {}},
	148: {"0": {"5": ["SkeletalMageWatch", "SkeletalMageStaffLift"], "8": ["SkeletalMageStaffWard"],
		"11": ["SkeletalMageStaffThrust", "SkeletalMageStaffThrust", "SkeletalMageStaffThrust"],
		"15": ["SkeletalMageGroundRise"]}, "1": {"5": ["SkeletalMageWatch"]}},
}
const Staff := "SkeletonMageStaff"


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Families:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Families:
		var row := Registry.entry(body) if installed else candidate_row(body, bases[body])
		assert(row.enhanced_source_action_groups == Modes[body])
		Registry.entries[body] = row
		evidence[str(body)] = await review(game, body, bases[body], row, installed)
		assert(not evidence[str(body)].is_empty())
		Registry.entries[body] = bases[body]
	game.free()
	if not installed:
		var output := FileAccess.open(Stage + "terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": evidence, "script_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()

static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = motion_packets(body).keys()
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
	return row

static func motion_packets(body: int) -> Dictionary:
	var clips := {}
	for kind: String in Modes[body]["0"]:
		var names: Array = Modes[body]["0"][kind]
		for variant in names.size():
			if not clips.has(names[variant]):
				clips[names[variant]] = [int(kind), variant]
	return clips

func review(game: Node, body: int, base: Dictionary, row: Dictionary, installed: bool) -> Dictionary:
	game.entities[body] = {"body": body, "serial": body, "hue": 0x8035}
	var clips := motion_packets(body)
	var result := {"decoded": 0, "classic": 0, "poses": 0, "terrain": {}, "hashes": {},
		"falls": 0, "maximum_death_jump": 0.0, "hues": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_fit(body, treatment, installed)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				verify_retained(actor, base)
				var counts := check_routes(avatar, game, body, Modes[body])
				result.decoded += counts.x
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in clips:
				var selection: Array = clips[clip]
				var request := decode(game, body, selection[0], selection[1])
				var measurements := review_clip(actor, avatar, floor, request, clip)
				assert(not measurements.is_empty())
				result.poses += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					result.terrain[clip] = measurements
				for phase: float in [.10, .58]:
					var fall := review_fall(actor, avatar, floor, request, phase, installed)
					assert(fall.has("jump"))
					result.falls += 1
					result.maximum_death_jump = maxf(result.maximum_death_jump, fall.jump)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	assert(result.decoded == (24 if body == 208 else 96) and result.classic == (18 if body == 208 else 72)
		and result.falls == clips.size() * 10 * row.assets.size())
	for hue: int in [0, 0x8035, 0x455]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		result.hues += 1
	print("CHICKEN AND SKELETAL MAGE ", body, ": ", result)
	return result

func verify_retained(actor: Node3D, base: Dictionary) -> void:
	var body: int = actor.native_body
	var active := Registry.entry(body)
	Registry.entries[body] = base
	var reference := Registry.create(body)
	Registry.entries[body] = active
	reference.treatment = actor.treatment
	root.add_child(reference)
	reference.apply_identity(body, actor.native_hue)
	for name: String in reference.animator.get_animation_list():
		assert(actor.animator.has_animation(name), name)
		var before: Animation = reference.animator.get_animation(name)
		var after: Animation = actor.animator.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count(), name)
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track), name)
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track),
				"%d/%s %s %s" % [body, actor.treatment, name, before.track_get_path(track)])
	reference.free()

func create_fit(body: int, treatment: String, installed: bool) -> Node3D:
	var renderer := Stage + "SourceEnhanced%sVisual.gd" % Families[body]
	var actor: Node3D = Registry.create(body) if installed else load(renderer).new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func start_fit(actor: Node3D, avatar: Avatar, request: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	assert(Dispatch.dispatch(avatar, request, true, 0x40))
	actor.animator.advance(.14)

func move_to(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()

static func bone(actor: Node3D, label: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)

static func labels(body: int) -> Array[String]:
	if body == 208:
		return ["Head", "Finger3_L.002", "Finger3_R.002"]
	return ["bip01 head", "skeletal mage staff", "bip01 r hand"]


static func skin_gap(actor: Node3D, floor: StaticBody3D) -> float:
	var space: Transform3D = actor.skeleton.global_transform
	if actor.native_body == 208:
		return actor.skin_gap(space, floor.position, floor.basis.y)
	return Ground.minimum_plane_gap(actor.gesture_skin, actor.skeleton, space, floor.position, floor.basis.y)


func review_clip(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary, clip: String) -> Dictionary:
	start_fit(actor, avatar, request)
	assert(actor.current_clip == clip)
	var lowest := INF
	var highest := -INF
	var gap := INF
	var staff_low := Vector3(INF, INF, INF)
	var staff_high := Vector3(-INF, -INF, -INF)
	var joints := labels(actor.native_body)
	var staff := actor.model.find_child(Staff, true, false) as MeshInstance3D
	assert((staff != null) == (actor.native_body == 148))
	for i in 31:
		move_to(actor, i / 30.0)
		gap = minf(gap, skin_gap(actor, floor))
		var height := bone(actor, joints[0]).y
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
		if staff != null:
			var hand := bone(actor, joints[2])
			var held := bone(actor, joints[1])
			assert(hand.distance_to(held) < .19, "%s lost grip at %.3f" % [clip, i / 30.0])
			staff_low = staff_low.min(held)
			staff_high = staff_high.max(held)
	var clearance := .0024 if actor.native_body == 208 else .0019
	assert(gap >= clearance, "%s slope %s gap %.6f" % [clip, floor.rotation, gap])
	# Terrain pitch changes the vertical projection of both arcs.
	var flat := floor.rotation == Vector3.ZERO
	var required: float = {"ChickenQuickPeck": .030 if flat else .016, "ChickenSettledWatch": .0015,
		"ChickenLowAlert": .014, "SkeletalMageGroundRise": .75 if flat else .65}.get(clip, 0.0)
	assert(highest - lowest >= required, "%s slope %s head travel %.5f" % [clip, floor.rotation, highest - lowest])
	var staff_excursion := staff_high.distance_to(staff_low) if staff != null else 0.0
	var required_staff: float = {"SkeletalMageWatch": .04, "SkeletalMageStaffLift": .80,
		"SkeletalMageStaffWard": .48, "SkeletalMageStaffThrust": .85, "SkeletalMageGroundRise": .60}.get(clip, 0.0)
	assert(staff_excursion >= required_staff, "%s slope %s staff travel %.5f" % [clip, floor.rotation, staff_excursion])
	return {"gap": gap, "head_minimum": lowest, "head_maximum": highest, "staff_excursion": staff_excursion}


func review_fall(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary,
		phase: float, installed: bool) -> Dictionary:
	start_fit(actor, avatar, request)
	move_to(actor, phase)
	var joints := labels(actor.native_body)
	var prior: Array[Vector3] = []
	for label: String in joints:
		prior.append(bone(actor, label))
	var fall := create_fit(actor.native_body, actor.treatment, installed)
	fall.global_transform = actor.global_transform
	fall.model.transform = actor.model.transform
	fall.dead = true
	fall.contact.enabled = false
	var duration: float = fall.begin_death_from(actor)
	var jump := 0.0
	for i in joints.size():
		jump = maxf(jump, prior[i].distance_to(bone(fall, joints[i])))
	assert(duration > 0.0 and jump < .002, "%s %.2f %s %.6f" % [actor.current_clip, phase, floor.rotation, jump])
	var clearance := .0024 if actor.native_body == 208 else .0019
	for i in 31:
		fall.animator.seek(duration * i / 30.0, true)
		var gap := skin_gap(fall, floor)
		assert(gap >= clearance, "%s death %.3f slope %s gap %.6f" % [actor.current_clip, i / 30.0, floor.rotation, gap])
	var snapshot := Snapshot.capture(fall, fall.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	if actor.native_body == 148:
		assert(corpse.find_child(Staff, true, false) != null)
	corpse.free()
	fall.free()
	return {"jump": jump}
