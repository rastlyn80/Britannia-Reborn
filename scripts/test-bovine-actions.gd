extends SceneTree
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const FORMS := ["bovine_cow_spotted", "bovine_cow_brown", "bovine_bull_brown", "bovine_bull_spotted"]
const CLIPS := ["Attack", "Attack2", "Fidget", "Fidget2", "Death", "Death2"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var poses := 0
	for kind: String in FORMS:
		for treatment: String in ["original", "rounded", "modern"]:
			poses += witness(kind, treatment)
	print("BOVINE ACTIONS: ", poses, " posed skins across 12 body and mesh combinations, old keys preserved")
	quit()

func witness(kind: String, treatment: String) -> int:
	var poses := 0
	var path := "res://local-art/animals/%s-%s-actions.scn" % [kind, treatment]
	var actor := (load(path) as PackedScene).instantiate()
	root.add_child(actor)
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var hip := rig.find_bone("bip01 pelvis")
	Exact.check_earlier_keys(player, "res://local-art/animals/%s-%s.gltf" % [kind, treatment])
	for clip: String in CLIPS:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var gap := INF
		for frame in 65:
			player.seek(player.current_animation_length * frame / 64.0, true)
			rig.force_update_all_bone_transforms()
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			poses += 1
		assert(is_finite(gap))
		if clip.ends_with("2"):
			assert(gap > -0.006, "%s %s %f" % [kind, clip, gap])
		if clip.begins_with("Death"):
			var height := rig.to_global(rig.get_bone_global_pose(hip).origin).y
			print(kind, " ", treatment, " ", clip, " floor/hip ", gap, " / ", height)
			if clip == "Death2":
				assert(height < 0.80)
	actor.free()
	return poses
