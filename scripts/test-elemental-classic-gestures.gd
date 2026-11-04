extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const SERIAL := 0x4100
const ACTIONS := {7: "ElementalOverhead", 8: "ElementalHeldReach"}

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in [13, 15]:
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		var actor := Registry.create(body)
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(body, 0x8035)
		for slot: int in ACTIONS:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(SERIAL, 4))
			packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
			assert(actor.current_clip == ACTIONS[slot] and actor.native_hue == 0x8035)
			if not sample(actor, slot):
				quit(1)
				return
			actor._process(actor.action_remaining + 0.001)
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == "Idle")
		actor.free()
	game.free()
	print("ELEMENTAL CLASSIC: four decoded routes and 404 sampled poses")
	quit()

func point(rig: Skeleton3D, label: String) -> Vector3:
	return rig.get_bone_global_pose(rig.find_bone(label)).origin

func sample(actor: Node3D, slot: int) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var clip: String = ACTIONS[slot]
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var initial_left := point(rig, "hand_l")
	var initial_right := point(rig, "hand_r")
	var initial_spine := point(rig, "spine_01")
	var spine_drift := 0.0
	var highest_right := -INF
	var left_extension := 0.0
	var held_samples := 0
	var root_pose := actor.global_transform
	for i in 101:
		player.seek(player.get_animation(clip).length * float(i) / 100.0, true)
		rig.force_update_all_bone_transforms()
		var left := point(rig, "hand_l")
		var right := point(rig, "hand_r")
		var head := point(rig, "Head")
		highest_right = maxf(highest_right, right.y - head.y)
		left_extension = maxf(left_extension, left.x - initial_left.x)
		spine_drift = maxf(spine_drift, point(rig, "spine_01").distance_to(initial_spine))
		if left.z - initial_left.z > 0.22 and right.z - initial_right.z > 0.28 and right.y > left.y + 0.10:
			held_samples += 1
		if not actor.global_transform.is_equal_approx(root_pose):
			return false
		if i == 100 and maxf(left.distance_to(initial_left), right.distance_to(initial_right)) > 0.002:
			return false
	print(actor.native_body, " ", clip, " overhead, extension, held samples, spine drift ",
		[highest_right, left_extension, held_samples, spine_drift])
	if spine_drift > 0.001:
		return false
	if slot == 7:
		return highest_right > 0.20 and left_extension > 0.15
	return held_samples >= 40 and highest_right < 0.05
