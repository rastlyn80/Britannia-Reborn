extends SceneTree

const Geometry := preload("res://../scripts/orc-captain-axe-clearance.gd")
const CLIPS := ["Idle", "Walk", "Run", "Attack", "Attack2", "Attack3", "Hit", "Death", "Fidget", "Cast", "Pillage",
	"Death2", "CaptainHighGuard", "CaptainLowGuard", "CaptainAxeSignal", "CaptainAxeCheck"]
func _initialize() -> void:
	create_timer(145.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var hz := 720.0 if "--dense" in OS.get_cmdline_user_args() else 360.0
	var total_samples := 0
	var total_crossings := 0
	for treatment: String in ["original", "rounded", "modern"]:
		var path := "res://local-art/creatures/orc-captain-actions-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var axe := model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
		var points: PackedVector3Array = axe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var joint := rig.find_bone("orc captain axe")
		var grip := rig.find_bone("cp_grasp_rhand")
		assert(body != axe and rig.get_bone_parent(joint) == grip and axe.mesh.get_faces().size() == 246)
		var solver := Geometry.new(body, rig)
		for clip: String in CLIPS:
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var crossed := 0
			var lowest := INF
			var samples := ceili(player.current_animation_length * hz)
			var previous := Quaternion.IDENTITY
			var max_step := 0.0
			for frame in samples + 1:
				player.seek(player.current_animation_length * frame / float(samples), true)
				rig.force_update_all_bone_transforms()
				var pose := rig.global_transform * rig.get_bone_global_pose(joint)
				assert(pose.origin.distance_to(rig.to_global(rig.get_bone_global_pose(grip).origin)) < 0.000001)
				var rotation := pose.basis.orthonormalized().get_rotation_quaternion()
				if frame > 0:
					var step := rad_to_deg(previous.angle_to(rotation))
					max_step = maxf(max_step, step)
				previous = rotation
				for point: Vector3 in points:
					lowest = minf(lowest, (pose * point).y)
				solver.update_pose()
				if solver.crosses_prop(pose, "OrcCaptainAxe", 0.0):
					crossed += 1
			total_samples += samples + 1
			total_crossings += crossed
			print(treatment, " ", clip, " crossings ", crossed, "/", samples + 1, ", min floor ", lowest, " max world step ", max_step)
		model.free()
	print("ORC CAPTAIN AXE: ", total_samples, " samples at ", hz, " Hz, ", total_crossings, " crossings")
	quit(int(total_crossings > 0 or total_samples < 17847))
