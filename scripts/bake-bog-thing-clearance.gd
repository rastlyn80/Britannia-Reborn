extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const BOG := 780
const SOURCE := "res://local-art/creatures/bog-thing-gestures.scn"
const OUTPUT := "res://local-art/creatures/bog-thing-actions.scn"
const CLIPS := {"Fidget": "BogFloorFidget", "BogBrace": "BogFloorBrace", "BogBranchReach": "BogFloorReach"}
const BRANCHES := ["l forearm", "r forearm", "r forearm b"]

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(BOG).duplicate(true)
	row.assets = {"original": SOURCE, "modern": SOURCE}
	row.presentation_script = "res://Presentation/SourceBogThingVisual.gd"
	Registry.entries[BOG] = row
	var actor := Registry.create(BOG)
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(rig.get_bone_count() == 116 and actor.footprint.size() == 103)
	var drivers: Array[int] = []
	for branch: String in BRANCHES:
		var driver := rig.get_bone_parent(rig.find_bone(branch))
		assert(rig.get_bone_name(driver).begins_with("__matrix_factor_"))
		drivers.append(driver)
	var arrays: Array = actor.base_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var controls := branch_controls(actor.base_mesh, rig, arrays, drivers)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for clip: String in CLIPS:
		var original := player.get_animation(clip)
		var fitted := original.duplicate(true) as Animation
		var tracks: Array[int] = []
		for driver in drivers:
			var path := NodePath("%s:%s" % [rig_path, rig.get_bone_name(driver)])
			var track := fitted.find_track(path, Animation.TYPE_POSITION_3D)
			assert(track >= 0, "Missing source branch position track")
			for key in range(fitted.track_get_key_count(track) - 1, -1, -1):
				fitted.track_remove_key(track, key)
			tracks.append(track)
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var samples := ceili(original.length * 360.0)
		var max_offset := 0.0
		for frame in samples + 1:
			var time := original.length * frame / float(samples)
			player.seek(time, true)
			rig.force_update_all_bone_transforms()
			var matrices: Array[Transform3D] = actor.skin_transforms(actor.base_mesh, rig.global_transform)
			var floor := INF
			for vertex: int in actor.footprint:
				var point: Vector3 = actor.weighted_point(arrays, matrices, vertex)
				floor = minf(floor, point.y)
			var offsets := [0.0, 0.0, 0.0]
			for vertex in vertices.size():
				var point: Vector3 = actor.weighted_point(arrays, matrices, vertex)
				var control := controls[vertex]
				if control.x < 0 or point.y >= floor + 0.004:
					continue
				var index := int(control.x)
				offsets[index] = maxf(offsets[index], (floor + 0.004 - point.y) / control.y)
			for index in drivers.size():
				var parent := rig.get_bone_parent(drivers[index])
				var parent_world := rig.global_basis * rig.get_bone_global_pose(parent).basis
				var offset: float = offsets[index]
				assert(offset <= 0.16, "Excessive stretch in %s at %s: %s" % [clip, frame, offset])
				max_offset = maxf(max_offset, offset)
				var position := rig.get_bone_pose_position(drivers[index]) + parent_world.inverse() * (Vector3.UP * offset)
				fitted.position_track_insert_key(tracks[index], time, position)
		assert(library.add_animation(CLIPS[clip], fitted) == OK)
		print(clip, " ", samples + 1, " samples, maximum distal displacement ", max_offset)
	Exact.check_earlier_keys(player, SOURCE)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(actor.model) == OK and ResourceSaver.save(scene, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	actor.free()
	quit()

func branch_controls(mesh: MeshInstance3D, rig: Skeleton3D, arrays: Array, drivers: Array[int]) -> PackedVector2Array:
	var owners := PackedInt32Array()
	for binding in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(binding)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(binding))
		while bone >= 0 and bone not in drivers:
			bone = rig.get_bone_parent(bone)
		owners.append(drivers.find(bone))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := weights.size() / vertices.size()
	var result := PackedVector2Array()
	for vertex in vertices.size():
		var strength := [0.0, 0.0, 0.0]
		for slot in stride:
			var index := vertex * stride + slot
			var branch := owners[bindings[index]]
			if branch >= 0:
				strength[branch] += weights[index]
		var dominant: float = strength.max()
		result.append(Vector2(strength.find(dominant), dominant) if dominant >= 0.30 else Vector2(-1.0, 0.0))
	return result
