extends SceneTree
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CLIPS := ["Death2", "CoilSnap", "LongStrike", "NeckDrawback", "LowNeckRecoil", "TailRipple"]
func _initialize() -> void:
	create_timer(75.0).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	var all_curves := {}
	for treatment: String in ["original", "rounded", "modern"]:
		all_curves[treatment] = measure(treatment)
	var output := FileAccess.open("res://local-art/creatures/lava-serpent-actions-curves.json", FileAccess.WRITE)
	assert(output != null)
	var scenes := {}
	for treatment: String in all_curves:
		scenes[treatment] = FileAccess.get_sha256("res://local-art/creatures/lava-serpent-actions-%s.scn" % treatment)
	output.store_string(JSON.stringify({"sample_rate": 960, "scenes": scenes, "curves": all_curves,
		"recipe": FileAccess.get_sha256(get_script().resource_path)}))
	output.close()
	quit()

func measure(treatment: String) -> Dictionary:
	var scene := load("res://local-art/creatures/lava-serpent-actions-%s.scn" % treatment) as PackedScene
	var model := scene.instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh,rig)
	var curves := {}
	var total := 0
	for clip: String in CLIPS:
		player.stop()
		player.play(clip,0.0)
		player.advance(0.0)
		var intervals := ceili(player.current_animation_length * 960.0)
		var samples: Array = []
		for frame in intervals + 1:
			var time := player.current_animation_length * float(frame) / intervals
			player.seek(time,true)
			rig.force_update_all_bone_transforms()
			var value := Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
			assert(is_finite(value))
			samples.append([time,-value])
			total += 1
		curves[clip] = samples
	model.free()
	print("LAVA SERPENT ", treatment, ": ", total, " full-skin samples at 960 Hz")
	return curves
