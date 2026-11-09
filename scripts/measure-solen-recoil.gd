extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CLIP := "SolenRecoil"
const RATE := 960.0

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for body in [806, 782]:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := "res://local-art/creatures/golem-juka-solen-%d-actions-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.deterministic = true
			var length := player.get_animation(CLIP).length
			var steps := ceili(length * RATE)
			var samples := []
			var residual := 0.0
			player.play(CLIP, 0.0)
			player.advance(0.0)
			for index in steps + 1:
				var time := length * float(index) / float(steps)
				player.seek(time, true)
				rig.force_update_all_bone_transforms()
				var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
				assert(is_finite(gap))
				residual = maxf(residual, absf(gap))
				samples.append([time, -gap])
			treatments[treatment] = {"asset_sha256": FileAccess.get_sha256(path), "clips": {CLIP: samples}}
			print(body, " ", treatment, " ", samples.size(), " recoil samples, peak absolute residual ", residual)
			model.free()
		var output := FileAccess.open("res://local-art/creatures/solen-recoil-%d-ground.json" % body, FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"sample_rate": int(RATE), "treatments": treatments}))
		output.close()
	quit()
