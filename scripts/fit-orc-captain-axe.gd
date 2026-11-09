extends "res://../scripts/bake-skeleton-actions.gd"

const Geometry := preload("res://../scripts/orc-captain-axe-clearance.gd")
const CLIPS := ["Idle", "Walk", "Run", "Attack", "Attack2", "Attack3", "Hit", "Death", "Fidget", "Cast", "Pillage",
	"Death2", "CaptainHighGuard", "CaptainLowGuard", "CaptainAxeSignal", "CaptainAxeCheck"]
const TREATMENTS := ["original", "rounded", "modern"]

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for treatment in TREATMENTS:
		var input := "res://local-art/creatures/orc-captain-motion-actions-%s.scn" % treatment
		var output := "res://local-art/creatures/orc-captain-axe-fitted-%s.scn" % treatment
		var model := (load(input) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var axe := model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
		var points: PackedVector3Array = axe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var joint := rig.find_bone("orc captain axe")
		var grip := rig.find_bone("cp_grasp_rhand")
		var hand := rig.find_bone("bip01 r hand")
		var arm := [rig.find_bone("bip01 r upperarm"), rig.find_bone("bip01 r forearm")]
		assert(body != axe and rig.get_bone_parent(joint) == grip)
		var solver := Geometry.new(body, rig)
		var path := NodePath("%s:%s" % [player.get_node(player.root_node).get_path_to(rig), rig.get_bone_name(joint)])
		for clip: String in CLIPS:
			var motion := player.get_animation(clip)
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var knots: Array[Quaternion] = []
			var before := Basis.IDENTITY
			var samples := ceili(motion.length * 160.0)
			var failures := 0
			var worst_floor := INF
			var maximum_step := 0.0
			var arm_samples: Array[Array] = [[], []]
			var refit := clip in ["Attack", "Attack2", "Attack3", "CaptainHighGuard"]
			for frame in samples + 1:
				var phase := float(frame) / samples
				player.seek(motion.length * phase, true)
				rig.force_update_all_bone_transforms()
				if refit:
					var amount := arm_amount(clip, phase)
					if amount > 0.0:
						var offset := Vector3(-0.23, -0.015, 0.16) * amount
						fit_arm(rig, "r", rig.to_global(rig.get_bone_global_pose(hand).origin) + offset)
					for side in arm.size():
						arm_samples[side].append(rig.get_bone_pose_rotation(arm[side]))
				solver.update_pose()
				var socket := rig.global_transform * rig.get_bone_global_pose(grip)
				var target := directed_pose(clip, phase)
				if frame == 0:
					before = target
				var fitted := solver.solve_continuous(socket, target, before, points, 0.008)
				var rotation: Quaternion = fitted.rotation
				if not knots.is_empty():
					maximum_step = maxf(maximum_step, rad_to_deg(knots[-1].angle_to(rotation)))
				knots.append(rotation)
				before = fitted.heading
				worst_floor = minf(worst_floor, fitted.floor)
				failures += int(not solver.is_safe(fitted, 0.008))
			var index := motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(index, path)
			for frame in knots.size():
				motion.rotation_track_insert_key(index, motion.length * float(frame) / samples, knots[frame])
			if refit:
				for side in arm.size():
					var arm_path := NodePath("%s:%s" % [player.get_node(player.root_node).get_path_to(rig), rig.get_bone_name(arm[side])])
					var track := motion.find_track(arm_path, Animation.TYPE_ROTATION_3D)
					assert(track >= 0, str(arm_path))
					for key in range(motion.track_get_key_count(track) - 1, -1, -1):
						motion.track_remove_key(track, key)
					for frame in knots.size():
						motion.rotation_track_insert_key(track, motion.length * float(frame) / samples, arm_samples[side][frame])
			print(treatment, " ", clip, " clearance misses ", failures, " / ", samples + 1,
				" floor ", worst_floor, " largest local step ", maximum_step)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
	quit()

func arm_amount(clip: String, phase: float) -> float:
	if clip == "Attack2":
		return smoothstep(0.00, 0.04, phase) * (1.0 - smoothstep(0.25, 0.64, phase))
	return smoothstep(0.35, 0.58, phase) * (1.0 - smoothstep(0.95, 1.0, phase))

func directed_pose(clip: String, phase: float) -> Basis:
	var neutral := Vector3(-0.28, 0.40, 0.87).normalized()
	var pulse := smoothstep(0.05, 0.40, phase) * (1.0 - smoothstep(0.63, 0.99, phase))
	var windup := smoothstep(0.02, 0.25, phase) * (1.0 - smoothstep(0.27, 0.50, phase))
	var strike := smoothstep(0.27, 0.53, phase) * (1.0 - smoothstep(0.64, 1.0, phase))
	var shaft := neutral
	if clip in ["Death", "Death2"]:
		var settle := smoothstep(0.05, 0.26, phase)
		var rest := Vector3(-0.95, 0.075, 0.32).normalized()
		return Basis(hold(neutral, Vector3.RIGHT).get_rotation_quaternion().slerp(
			hold(rest, Vector3.UP).get_rotation_quaternion(), settle))
	if clip in ["Attack", "Attack2", "Attack3"]:
		var wind := Vector3(-0.41, 0.88, -0.20) if clip != "Attack3" else Vector3(-0.86, 0.34, -0.38)
		if clip == "Attack2":
			wind = Vector3(-0.67, 0.63, 0.39)
		shaft = neutral.slerp(wind.normalized(), windup)
		shaft = shaft.slerp(Vector3(-0.62, 0.25, 0.74).normalized(), strike)
	else:
		var target: Vector3 = {"Hit": Vector3(-0.73, 0.45, 0.51),
			"CaptainHighGuard": Vector3(-0.55, 0.82, 0.15),
			"CaptainLowGuard": Vector3(-0.84, 0.15, 0.52),
			"CaptainAxeSignal": Vector3(-0.23, 0.96, 0.15),
			"CaptainAxeCheck": Vector3(-0.77, 0.45, 0.45)}.get(clip, neutral)
		shaft = neutral.slerp(target.normalized(), pulse)
	return hold(shaft, Vector3.RIGHT)

func hold(shaft: Vector3, reference: Vector3) -> Basis:
	var x := reference.slide(shaft).normalized()
	return Basis(x, shaft, x.cross(shaft))
