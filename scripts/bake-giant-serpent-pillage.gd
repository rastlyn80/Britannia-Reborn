extends SceneTree
## Recover the Giant Serpent motion already imported for the verified Silver rig.

const TARGET := "res://local-art/creatures/serpents_snake_giant-%s.gltf"
const DONOR := "res://local-art/creatures/serpents_snake_giant_silver-%s.gltf"
const OUTPUT := "res://local-art/creatures/giant-serpent-21-pillage-%s.scn"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for treatment in ["original", "rounded", "modern"]:
		if not bake(treatment):
			quit(1)
			return
	quit()

func bake(treatment: String) -> bool:
	var target := (load(TARGET % treatment) as PackedScene).instantiate()
	root.add_child(target)
	var donor := (load(DONOR % treatment) as PackedScene).instantiate()
	var source_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var target_rig := target.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var source_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var target_player := target.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := target_player.get_animation_library("")
	assert(not library.has_animation("Pillage"))
	var source := source_player.get_animation("Pillage")
	var motion := source.duplicate(true) as Animation
	var target_path := target_player.get_node(target_player.root_node).get_path_to(target_rig)
	var source_space := target_rig.get_parent() as Node3D
	for track in range(motion.get_track_count() - 1, -1, -1):
		var path := motion.track_get_path(track)
		if path.get_subname_count() == 0:
			# The Silver import's scene track compensates its own mesh.
			assert(motion.track_get_type(track) == Animation.TYPE_POSITION_3D)
			assert(source_player.get_node(source_player.root_node).get_node(path) == source_rig.get_parent())
			motion.remove_track(track)
			continue
		assert(path.get_subname_count() == 1)
		var joint := String(path.get_subname(0))
		var source_bone := source_rig.find_bone(joint)
		var target_bone := target_rig.find_bone(joint)
		assert(source_bone >= 0 and target_bone >= 0)
		assert(source_rig.get_bone_rest(source_bone).is_equal_approx(target_rig.get_bone_rest(target_bone)))
		assert(parent_name(source_rig, source_bone) == parent_name(target_rig, target_bone))
		motion.track_set_path(track, NodePath("%s:%s" % [target_path, joint]))
	assert(library.add_animation("Pillage", motion) == OK)
	var mesh := target.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, target_rig)
	var start_position := source_space.position
	var local_up := (source_space.get_parent() as Node3D).global_basis.inverse() * Vector3.UP
	var intervals := ceili(motion.length * 1920.0)
	var offsets := PackedFloat32Array()
	target_player.play("Pillage", 0.0)
	target_player.advance(0.0)
	for sample in intervals + 1:
		target_player.seek(motion.length * float(sample) / intervals, true)
		target_rig.force_update_all_bone_transforms()
		offsets.append(-Ground.minimum_plane_gap(skin, target_rig, target_rig.global_transform, Vector3.ZERO, Vector3.UP))
	target_player.stop()
	var floor := motion.add_track(Animation.TYPE_POSITION_3D)
	motion.track_set_path(floor, target_player.get_node(target_player.root_node).get_path_to(source_space))
	for sample in offsets.size():
		motion.position_track_insert_key(floor, motion.length * float(sample) / intervals,
			start_position + local_up * offsets[sample])
	var scene := PackedScene.new()
	var saved := scene.pack(target) == OK and ResourceSaver.save(scene, OUTPUT % treatment, ResourceSaver.FLAG_COMPRESS) == OK
	donor.free()
	target.free()
	print("GIANT SERPENT 21: ", treatment, ", ", motion.get_track_count() - 1,
		" recovered tracks on exact matching joints, ", offsets.size(), " target floor samples")
	return saved

func parent_name(rig: Skeleton3D, bone: int) -> String:
	var parent := rig.get_bone_parent(bone)
	return rig.get_bone_name(parent) if parent >= 0 else ""
