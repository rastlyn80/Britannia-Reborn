extends SceneTree

const Actions := preload("res://Presentation/DesertOstardActions.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Mounts := preload("res://Presentation/MountVisual.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const SLOPES := [Vector3.ZERO, Vector3(0.12, 0.0, -0.09), Vector3(-0.09, 0.0, 0.10)]
var game: Node
var poses := 0
var ridden := 0

func _initialize() -> void:
	create_timer(115.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Actions.trial = "--candidate" in OS.get_cmdline_user_args()
	assert(Actions.available())
	game = Game.new()
	root.add_child(game)
	game.set_process(false)
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in Actions.TREATMENTS:
			var mount := Mounts.create(210)
			mount.treatment = treatment
			root.add_child(mount)
			check_actions(mount, plane)
			mount.free()
		for female: bool in [false, true]:
			await check_rider(female)
		plane.free()
		await physics_frame
	var ethereal := Mounts.create(210, 0x3eac)
	root.add_child(ethereal)
	assert(ethereal.desert_actions == null)
	assert(not ethereal.receive_action({"protocol":"classic", "action":4}))
	ethereal.free()
	print("DESERT OSTARD ACTION ROUTES: ", poses, " terrain poses, ", ridden, " ridden phases")
	quit()

func check_actions(mount: Node3D, plane: StaticBody3D) -> void:
	mount.apply_identity(210, 0x8035)
	mount.set_process(false)
	mount.set_physics_process(false)
	var player: AnimationPlayer = mount.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var model: Node3D = mount.model
	var rig: Skeleton3D = mount.skeleton
	var basis := model.basis
	var origin := mount.global_transform
	assert(mount.desert_actions != null and mount.native_hue == 0x8035 and rig.get_bone_count() == 24)
	for group: int in Actions.CLIPS:
		mount.dead = false
		mount.action_remaining = 0.0
		model.basis = plane.basis * basis
		player.speed_scale = 1.6
		assert(mount.receive_action(decode_action(game, 210, group)))
		assert(mount.current_clip == Actions.CLIPS[group] and mount.dead == (group == 12))
		assert(is_equal_approx(player.speed_scale, 1.0))
		player.advance(0.15)
		var lowest := INF
		for sample in 41:
			player.seek(player.current_animation_length * sample / 40.0, true)
			var gap := Ground.minimum_plane_gap(mount.desert_actions.fall.skin, rig, rig.global_transform,
				plane.global_position, plane.global_basis.y.normalized())
			lowest = minf(lowest, gap)
			assert(mount.global_transform == origin and is_finite(gap) and gap >= 0.0015,
				"Group %d, %s, sample %d ground gap %s" % [group, mount.treatment, sample, gap])
			poses += 1
		assert(lowest < 0.015)
		if group == 11:
			assert(not mount.dead and not mount.contact.enabled)
			mount.play_gait(true, 1.8)
			assert(mount.current_clip == "Walk" and mount.contact.enabled)
			player.advance(0.0)
			assert(mount.desert_actions.live_shift.is_zero_approx())

func check_rider(female: bool) -> void:
	var actor := Avatar.new()
	actor.initial_body = 401 if female else 400
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.apply_server_appearance({"body": actor.initial_body, "hue": 1002}, [
		{"id":0x3ea3, "layer":25, "hue":0x8035}, {"id":0x1f03}, {"id":0x170b}])
	actor.rider_contact.begin_mount(false)
	actor.human_visual.set_process(false)
	var mount: Node3D = actor.horse_visual
	assert(mount.desert_actions != null and mount.native_mount_item == 0x3ea3 and mount.native_hue == 0x8035)
	for clip: String in ["Idle", "Walk", "Run", "Alert", "Peck", "CrestDip", "CrestTwitch"]:
		var group: int = {"Idle":2, "Walk":0, "Run":1, "Alert":4, "Peck":6, "CrestDip":9, "CrestTwitch":10}[clip]
		mount.set_process(false)
		assert(mount.receive_action(decode_action(game, 210, group)))
		actor.human_visual.play("Rider_%s" % clip if group < 3 else "Rider_Idle", 0.0)
		mount.animator.play(clip, 0.0)
		for phase: float in [0.0, 0.20, 0.45, 0.67, 0.87]:
			mount.animator.seek(phase * mount.animator.current_animation_length, true)
			mount.animator.pause()
			actor.animator.seek(phase * actor.animator.current_animation_length, true)
			actor.animator.pause()
			for frame in 3:
				await process_frame
			assert(actor.rider_contact.seat_error < 0.003)
			assert(actor.rider_contact.stirrup_errors.size() == 2)
			assert(actor.rider_contact.stirrup_errors.all(func(gap: float) -> bool: return gap < 0.03))
			assert(mount.rein_mesh.get_surface_count() == 1 and actor.human_visual.grip.reins_holding
				and actor.human_visual.grip.left_reins_holding and actor.transform == Transform3D.IDENTITY)
			ridden += 1
	actor.free()

static func decode_action(session: Node, serial: int, group: int) -> Dictionary:
	var action := PackedByteArray([0x6e])
	action.append_array(Wire.uint_be(serial, 4))
	action.append_array(PackedByteArray([0, group, 0, 6, 0, 1, 1, 0, 0]))
	session._handle(action)
	return session.last_mobile_actions[serial]

func support(tilt: Vector3) -> StaticBody3D:
	var ground := StaticBody3D.new()
	root.add_child(ground)
	ground.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.10, 8.0)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -0.05
	ground.add_child(collider)
	await physics_frame
	await physics_frame
	return ground
