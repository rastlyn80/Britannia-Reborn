extends SceneTree

const Geometry := preload("res://../scripts/orc-captain-axe-clearance.gd")
const LABEL := "OrcCaptainAxe"
const OFFSETS := [-64, -48, -36, -28, -20, -14, -8, -4, 4, 8, 14, 20, 28, 36, 48, 64]
const AXES := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD]

func _initialize() -> void:
	create_timer(170.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for treatment: String in ["original", "rounded", "modern"]:
		var source := "res://local-art/creatures/orc-captain-axe-fitted-%s.scn" % treatment
		var scene := (load(source) as PackedScene).instantiate()
		root.add_child(scene)
		var rig := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var axe := scene.find_child(LABEL, true, false) as MeshInstance3D
		var points: PackedVector3Array = axe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var joint := rig.find_bone("orc captain axe")
		var grip := rig.find_bone("cp_grasp_rhand")
		assert(body != axe and rig.get_bone_parent(joint) == grip)
		var motion := player.get_animation("Attack2")
		var track_path := NodePath("%s:%s" % [player.get_node(player.root_node).get_path_to(rig), rig.get_bone_name(joint)])
		var track := motion.find_track(track_path, Animation.TYPE_ROTATION_3D)
		assert(track >= 0)
		var samples := ceili(motion.length * 360.0)
		var original: Array[Quaternion] = []
		player.play("Attack2", 0.0)
		player.advance(0.0)
		for frame in samples + 1:
			player.seek(motion.length * frame / float(samples), true)
			var pose := rig.global_transform * rig.get_bone_global_pose(joint)
			original.append(pose.basis.orthonormalized().get_rotation_quaternion())
		var geometry := Geometry.new(body, rig)
		var candidates: Array[Array] = []
		for frame in samples + 1:
			player.seek(motion.length * frame / float(samples), true)
			rig.force_update_all_bone_transforms()
			geometry.update_pose()
			var socket := rig.global_transform * rig.get_bone_global_pose(grip)
			var pose := rig.global_transform * rig.get_bone_global_pose(joint)
			var options: Array = [{"world": original[frame], "local": rig.get_bone_pose_rotation(joint), "error": 0.0}]
			assert(not geometry.crosses_prop(pose, LABEL))
			if frame > 0 and frame < samples:
				for offset: int in OFFSETS:
					var alternative := original[clampi(frame + offset, 0, samples)]
					append_candidate(options, geometry, socket, points, original[frame], alternative)
				for radius in [10, 20, 35]:
					var alternative := original[maxi(frame - radius, 0)].slerp(original[mini(frame + radius, samples)], 0.5)
					append_candidate(options, geometry, socket, points, original[frame], alternative)
				for axis: Vector3 in AXES:
					for degrees in [6.0, 12.0, 24.0]:
						var alternative := Quaternion(axis, deg_to_rad(degrees)) * original[frame]
						append_candidate(options, geometry, socket, points, original[frame], alternative)
			candidates.append(options)
		var knots: Array[Quaternion] = []
		for bound in [2.3, 2.8, 3.4, 4.0, 5.0, 6.8]:
			knots = choose_path(candidates, deg_to_rad(bound))
			if not knots.is_empty():
				print("ORC CAPTAIN ", treatment, " second strike: ", knots.size(), " samples; angular limit ", bound, " degrees")
				break
		assert(knots.size() == samples + 1, "No continuous route through safe headings")
		player.stop()
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		for frame in samples + 1:
			motion.rotation_track_insert_key(track, motion.length * frame / float(samples), knots[frame])
		var output := PackedScene.new()
		assert(output.pack(scene) == OK and ResourceSaver.save(output,
			"res://local-art/creatures/orc-captain-actions-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		scene.free()
	quit()

func append_candidate(options: Array, geometry: RefCounted, socket: Transform3D, points: PackedVector3Array,
		original: Quaternion, target: Quaternion) -> void:
	for option: Dictionary in options:
		if target.angle_to(option.world) < 0.008:
			return
	var measured: Dictionary = geometry.measure(socket, LABEL, Basis(target), points)
	if measured.floor < 0.008 or measured.crossed or geometry.crosses_prop(measured.pose, LABEL, 0.004):
		return
	var pose: Transform3D = measured.pose
	var world := pose.basis.orthonormalized().get_rotation_quaternion()
	options.append({"world": world, "local": measured.rotation, "error": world.angle_to(original)})

func choose_path(candidates: Array[Array], bound: float) -> Array[Quaternion]:
	var costs := PackedFloat64Array([0.0])
	var links: Array[PackedInt32Array] = [PackedInt32Array([-1])]
	var cosine := cos(bound * 0.5)
	for frame in range(1, candidates.size()):
		var next_costs := PackedFloat64Array()
		var back := PackedInt32Array()
		var reachable := false
		for item: Dictionary in candidates[frame]:
			var best := INF
			var best_index := -1
			for index in costs.size():
				if not is_finite(costs[index]):
					continue
				var dot := absf((item.world as Quaternion).dot(candidates[frame - 1][index].world))
				if dot < cosine:
					continue
				var error: float = item.error
				var cost := costs[index] + 8.0 * (1.0 - dot) + 0.08 * error * error
				if cost < best:
					best = cost
					best_index = index
			back.append(best_index)
			next_costs.append(best)
			reachable = reachable or best_index >= 0
		if not reachable:
			return []
		costs = next_costs
		links.append(back)
	var result: Array[Quaternion] = []
	var index := 0
	for frame in range(candidates.size() - 1, -1, -1):
		result.append(candidates[frame][index].local)
		index = links[frame][index]
	result.reverse()
	return result
