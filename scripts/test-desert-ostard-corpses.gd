extends "res://../scripts/test-desert-ostard-actions.gd"

const Deaths := preload("res://Presentation/CreatureDeathsWithOstard.gd")
const Items := preload("res://Presentation/WorldItems.gd")

class Arena extends Node3D:
	var avatars: Dictionary = {}

func run() -> void:
	Actions.trial = "--candidate" in OS.get_cmdline_user_args()
	assert(Actions.available())
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for phase: float in [0.0, 0.06, 0.40, 0.78]:
			witness(plane, phase)
		plane.free()
		await physics_frame
	print("DESERT OSTARD CORPSES: 12 decoded handoffs across ", poses, " terrain poses")
	quit()

func witness(plane: StaticBody3D, phase: float) -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var session := Game.new()
	arena.add_child(session)
	session.set_process(false)
	var items := Items.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = session
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, session, items)
	deaths.set_process(false)
	var avatar := Avatar.new()
	avatar.initial_body = 210
	arena.add_child(avatar)
	avatar.set_physics_process(false)
	var mobile := 0x100d2
	var corpse := 0x400100d2
	var entity := {"serial":mobile, "body":210, "hue":0x8035, "direction":4}
	avatar.apply_server_appearance(entity, [])
	session.entities[mobile] = entity
	arena.avatars[mobile] = avatar
	var source: Node3D = avatar.horse_visual
	assert(source.desert_actions != null)
	source.set_process(false)
	source.set_physics_process(false)
	source.model.basis = plane.basis * source.model.basis
	var previous: AnimationPlayer = source.animator
	previous.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var time := 0.0
	var speed := 1.0
	if phase > 0.0:
		assert(avatar.receive_native_action(decode_action(session, mobile, 12)))
		previous.advance(0.10 if phase > 0.1 else 0.027)
		time = previous.current_animation_length * phase
		previous.seek(time, true)
		speed = previous.get_playing_speed()
	else:
		assert(avatar.receive_native_action(decode_action(session, mobile, 9)))
		previous.advance(0.32)
		previous.seek(previous.current_animation_length * 0.4, true)
	var initial := world_joints(source.skeleton)
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[corpse] = holder
	assert(items._equine_corpse(holder, {"id":0x2006, "amount":210, "hue":0x8035, "direction":4}, corpse))
	var death_packet := PackedByteArray([0xaf])
	death_packet.append_array(Wire.uint_be(mobile, 4))
	death_packet.append_array(Wire.uint_be(corpse, 4))
	death_packet.append_array(Wire.uint_be(0, 4))
	session._handle(death_packet)
	assert(deaths.active.has(mobile) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[mobile].visual
	visual.set_process(false)
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = visual.skeleton
	var clip := "Death2" if phase > 0.0 else "Death"
	assert(visual.current_clip == clip and visual.global_transform == source.global_transform)
	assert(is_equal_approx(player.current_animation_position, time) and is_equal_approx(player.get_playing_speed(), speed))
	var jump := max_joint_gap(initial, world_joints(rig))
	assert(jump < 0.003, "Death pose entry moved by %s m at %s" % [jump, phase])
	var skin: Dictionary = visual.desert_actions.fall.skin
	for frame in 41:
		player.seek(lerpf(time, player.current_animation_length, frame / 40.0), true)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, plane.global_basis.y.normalized())
		assert(gap >= 0.0015)
		poses += 1
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(mobile, 4))
	session._handle(removal)
	assert(not session.entities.has(mobile))
	deaths._process(10.0)
	assert(not deaths.active.has(mobile) and items.corpse_snapshots.has(corpse) and holder.visible)
	var static_body := holder.get_node("CorpseVisual") as Node3D
	assert(static_body.get_meta("death_clip") == clip and static_body.get_meta("native_hue") == 0x8035
		and static_body.get_meta("static_cadaver") and static_body.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(not holder.get_node("PickBody/PickShape").shape.size.is_zero_approx())
	arena.free()

func world_joints(rig: Skeleton3D) -> Array[Vector3]:
	rig.force_update_all_bone_transforms()
	var joints: Array[Vector3] = []
	for bone in rig.get_bone_count():
		joints.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return joints

func max_joint_gap(before: Array[Vector3], after: Array[Vector3]) -> float:
	var gap := 0.0
	for index in before.size():
		gap = maxf(gap, before[index].distance_to(after[index]))
	return gap
