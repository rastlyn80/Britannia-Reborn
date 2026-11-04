extends "res://../scripts/test-spider-mongbat-gestures.gd"

func forms() -> Dictionary:
	return {
		26: {"clip": "GhostSway", "support": [], "moving": "bip01 r hand",
			"minimum_travel": 0.008, "maximum_travel": 0.04, "native_hue": 0x4001,
			"alpha": "spirits_ghost-original-albedo.png",
			"presentation_script": "res://Presentation/SourceWraithVisual.gd"},
	}

func check_identity_material(actor: Node3D, treatment: String) -> void:
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	actor.apply_identity(26, 0x4001)
	assert(actor.native_hue == 0x4001)
	var material := mesh.get_surface_override_material(0) as ShaderMaterial
	assert(material.shader.resource_path.ends_with("WraithSpectralSurface.gdshader"))
	var atlas := material.get_shader_parameter("source_atlas") as Texture2D
	assert(atlas.resource_path.ends_with("spirits_ghost-original-albedo.png"))
	actor.apply_identity(26, 0x8035)
	check_source_alpha(actor, treatment, "spirits_ghost-original-albedo.png")
