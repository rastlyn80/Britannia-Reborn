extends "res://../scripts/test-gargoyle-kitsune-larva-actions.gd"

const BATCH := "swamp_widow_juka_actions"
const NEXT_BODIES := [794, 799, 157, 765]
const NewPacket := preload("res://../scripts/test-efreet-actions.gd")
const SWAMP := {4: "RaiseHead", 9: "ForwardNeckCheck", 10: "TailBalance", 11: "QuietChuff"}
const WIDOW := {2: "Death", 3: "Death", 4: "Attack", 5: "Attack", 6: "Attack",
	10: "Hit", 11: "Fidget", 15: "LowBrace", 16: "LowBrace", 17: "Fidget", 18: "AbdomenSignal"}
const JUKA := {6: "AdvancingPalm", 15: "HighRecoil", 16: "LowRecoil", 18: "JukaGlance"}
const JUKA_MARKERS := {6: ["bip01 l hand", "bip01 l upperarm"], 15: ["bip01 head", "bip01 spine1"],
	16: ["bip01 head", "bip01 spine1"], 18: ["bip01 head", "bip01 head"]}

var ground_count := 0
var rider_count := 0
var min_gap := INF
var max_seat := 0.0
var max_foot := 0.0
var max_mouth := {}
var max_tail := {}
var max_chuff_jaw := 0.0

var gesture_samples := 0
var packet_checks := 0
var widow_gap := INF
var widow_travel := {}
var widow_rotation := {}
var max_body_lowering := 0.0

var juka_samples := 0
var juka_gap := INF
var displacements := {}
var rotations := {}

var session: Node
var route_count := 0
var newer_count := 0
var corpse_count := 0

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var pin := FileAccess.get_sha256(index)
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var path := "res://../work/creatures/swamp_widow_juka_actions/prepared-client.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == NEXT_BODIES.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	session = Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in NEXT_BODIES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == BATCH)
		session.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for treatment: String in TREATMENTS:
			verify_routes(body, treatment)
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
			corpse.free()
			corpse_count += 1
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body in [794, 799]:
			for treatment: String in TREATMENTS:
				sample_swamp_ground(plane, body, treatment)
			for gender in [400, 401]:
				await sample_rider(plane, body, gender)
		for treatment: String in TREATMENTS:
			sample_widow(plane, treatment)
			sample_juka(plane, treatment)
		plane.free()
		await physics_frame
	assert(FileAccess.get_sha256(index) == pin and ground_count == 2232 and rider_count == 432)
	assert(gesture_samples == 738 and packet_checks == 99 and widow_gap >= 0.002)
	assert(juka_samples == 1476 and juka_gap >= 0.0015)
	assert(route_count == 156 and newer_count == 15 and corpse_count == 12)
	for slot in [4, 9, 10]:
		assert(max_mouth[slot] > 0.065, str(max_mouth))
	assert(max_chuff_jaw > 0.30 and max_tail[10] > 0.10, str([max_chuff_jaw, max_tail]))
	assert(widow_rotation[15] > 0.33 and widow_rotation[18] > 0.36 and widow_travel[18] > 0.05
		and max_body_lowering > 0.035, str([widow_rotation, widow_travel, max_body_lowering]))
	assert(displacements[6] > 0.14 and rotations[15] > 0.32 and rotations[16] > 0.28 and rotations[18] > 0.21,
		str([displacements, rotations]))
	print("SWAMP, WIDOW AND JUKA: ", ground_count + gesture_samples + juka_samples, " terrain poses, ", rider_count,
		" ridden poses, ", route_count, " Classic and ", newer_count, " newer selections, ", corpse_count, " corpse hues. Ground gaps ",
		[min_gap, widow_gap, juka_gap], ", maximum seat / stirrup errors ", [max_seat, max_foot])
	quit()

func verify_routes(body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(int(actor.entry.bodies[0].body), 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.apply_identity(body, 0x8035)
	assert(actor.native_body == body and actor.native_hue == 0x8035)
	var player: AnimationPlayer = actor.animator
	Earlier.check_earlier_keys(player, actor.entry.classic_gesture_base_assets[treatment])
	for slot: String in actor.entry.classic_motion_references:
		actor.dead = false
		player.stop()
		var request := decode(session, body, int(slot))
		assert(request.body == body and actor.receive_action(request))
		assert(actor.current_clip == actor.entry.classic_action_categories[slot] and actor.get_meta("native_action") == request)
		route_count += 1
	if body == 765:
		for example: Array in [[0, 0, 0, "Attack"], [0, 0, 1, "Attack2"], [0, 2, 1, "Attack"],
				[3, 0, 1, "Death2"], [11, 0, 0, "Cast"]]:
			actor.dead = false
			player.stop()
			var request := NewPacket.decode_new(session, body, example[0], example[1], example[2])
			assert(actor.receive_action(request) and actor.current_clip == example[3] and actor.get_meta("native_action") == request)
			newer_count += 1
	actor.free()

func sample_swamp_ground(plane: StaticBody3D, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(int(actor.entry.bodies[0].body), 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var anchor: Transform3D = actor.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.visible and mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	assert(not skins.is_empty())
	var normal := plane.global_basis.y.normalized()
	for slot: int in SWAMP:
		var request := decode(session, actor.native_body, slot)
		player.stop()
		assert(actor.receive_action(request) and actor.current_clip == SWAMP[slot])
		player.advance(0.15)
		var start_mouth: Vector3
		var start_tail: Vector3
		var start_jaw: Quaternion
		var jaw_joint := rig.find_bone("bone_jaw1")
		for phase in 31:
			player.seek(player.current_animation_length * phase / 30.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			for skin: Dictionary in skins:
				var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
				assert(is_finite(gap) and actor.global_transform == anchor and gap >= -0.0015,
					"Terrain crossing %s" % str([body, treatment, slot, phase, gap]))
				min_gap = minf(min_gap, gap)
			if normal.is_equal_approx(Vector3.UP):
				var mouth: Vector3 = actor.socket("mouth").origin
				var tail := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 tail4")).origin)
				if phase == 0:
					start_mouth = mouth
					start_tail = tail
					start_jaw = rig.get_bone_pose_rotation(jaw_joint)
				if slot == 11:
					max_chuff_jaw = maxf(max_chuff_jaw, start_jaw.angle_to(rig.get_bone_pose_rotation(jaw_joint)))
				max_mouth[slot] = maxf(float(max_mouth.get(slot, 0.0)), mouth.distance_to(start_mouth))
				max_tail[slot] = maxf(float(max_tail.get(slot, 0.0)), tail.distance_to(start_tail))
			ground_count += 1
	actor.free()

func sample_rider(plane: StaticBody3D, body: int, gender: int) -> void:
	var rider := Avatar.new()
	rider.initial_body = gender
	root.add_child(rider)
	rider.set_physics_process(false)
	var item := int(Registry.entry(body).mount_item)
	rider.apply_server_appearance({"body": gender, "hue": 1002},
		[{"id": 0x1f03}, {"id": 0x170b}, {"id": item, "layer": 25, "hue": 53}])
	var mount: Node3D = rider.horse_visual
	assert(mount != null and mount.native_body == body and mount.native_mount_item == item)
	rider.rider_contact.begin_mount(false)
	rider.human_visual.set_process(false)
	mount.set_physics_process(false)
	mount.contact.active = false
	rider.human_visual.play("Rider_Idle", 0.0)
	var anchor := rider.global_transform
	for slot: int in SWAMP:
		mount.animator.stop()
		assert(mount.receive_action(decode(session, body, slot)))
		for phase in 9:
			mount.animator.seek(mount.animator.current_animation_length * phase / 8.0, true)
			mount.animator.pause()
			mount._physics_process(1.0 / 60.0)
			mount.contact._process_modification_with_delta(1.0 / 60.0)
			mount.skeleton.force_update_all_bone_transforms()
			mount.contact.modification_processed.emit()
			assert(not mount.contact.contacts.is_empty())
			var ground: Dictionary = mount.contact.contacts.values()[0]
			assert(ground.normal.dot(plane.global_basis.y.normalized()) > 0.999)
			for frame in 4:
				await process_frame
			var contact: SkeletonModifier3D = rider.rider_contact
			var feet: Array = contact.stirrup_errors
			assert(rider.global_transform == anchor and contact.seat_error < 0.002 and feet.size() == 2 and feet[0] < 0.025 and feet[1] < 0.025,
				str([body, gender, slot, phase, contact.seat_error, feet]))
			assert(rider.human_visual.grip.reins_holding and rider.human_visual.grip.left_reins_holding)
			max_seat = maxf(max_seat, contact.seat_error)
			max_foot = maxf(max_foot, feet.max())
			rider_count += 1
	rider.free()

func sample_widow(plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(157)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(int(actor.entry.bodies[0].body), 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var normal := plane.global_basis.y.normalized()
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for slot: int in WIDOW:
		actor.dead = false
		player.stop()
		var request := decode(session, actor.native_body, slot)
		assert(actor.receive_action(request) and actor.current_clip == WIDOW[slot])
		packet_checks += 1
		if slot not in [15, 18]:
			continue
		player.advance(0.15)
		var landmark := rig.find_bone("bone26" if slot == 15 else "bone02")
		var start := Vector3.ZERO
		var joint := rig.find_bone("bone24" if slot == 15 else "bone02")
		var torso := rig.find_bone("bone01")
		var start_rotation := Quaternion.IDENTITY
		var start_height := 0.0
		var anchor := actor.global_transform
		for frame in 41:
			player.seek(player.current_animation_length * frame / 40.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			actor.support_gesture()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and actor.global_transform == anchor)
			widow_gap = minf(widow_gap, gap)
			var point := rig.get_bone_global_pose(landmark).origin
			if frame == 0:
				start = point
				start_rotation = rig.get_bone_pose_rotation(joint)
				start_height = rig.to_global(rig.get_bone_global_pose(torso).origin).dot(normal)
			if slot == 15:
				max_body_lowering = maxf(max_body_lowering, start_height - rig.to_global(rig.get_bone_global_pose(torso).origin).dot(normal))
			widow_rotation[slot] = maxf(float(widow_rotation.get(slot, 0.0)), start_rotation.angle_to(rig.get_bone_pose_rotation(joint)))
			widow_travel[slot] = maxf(float(widow_travel.get(slot, 0.0)), point.distance_to(start))
			gesture_samples += 1
	actor.free()

func sample_juka(plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(765)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(int(actor.entry.bodies[0].body), 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var normal := plane.global_basis.y.normalized()
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var anchor := actor.global_transform
	for slot: int in JUKA:
		player.stop()
		var request := decode(session, actor.native_body, slot)
		assert(actor.receive_action(request) and actor.current_clip == JUKA[slot])
		player.advance(0.16)
		var landmark := rig.find_bone(JUKA_MARKERS[slot][0])
		var joint := rig.find_bone(JUKA_MARKERS[slot][1])
		var start := Vector3.ZERO
		var start_rotation := Quaternion.IDENTITY
		for frame in 41:
			actor.blend_remaining = 0.0 if frame > 9 else 0.16 - frame / 60.0
			player.seek(player.current_animation_length * frame / 40.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and actor.global_transform == anchor)
			juka_gap = minf(juka_gap, gap)
			var point := rig.get_bone_global_pose(landmark).origin
			if frame == 0:
				start = point
				start_rotation = rig.get_bone_pose_rotation(joint)
			displacements[slot] = maxf(float(displacements.get(slot, 0.0)), point.distance_to(start))
			rotations[slot] = maxf(float(rotations.get(slot, 0.0)), start_rotation.angle_to(rig.get_bone_pose_rotation(joint)))
			juka_samples += 1
	actor.free()
