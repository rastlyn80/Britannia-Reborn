extends "res://Presentation/GiantSpiderActionsVisual.gd"
## Keep the attack flashes on the animated eyes and off the resting model.

const FLASH := preload("res://Presentation/GazerEyeFlash.gdshader")
const COLORS := {"Attack": Color("ffdb80"), "Attack2": Color("7affe0"), "EyeVolley": Color("ff865e")}
var sparks: Array[MeshInstance3D] = []

func _ready() -> void:
	super._ready()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.31, 0.31)
	for index in range(1, 5):
		var spark := MeshInstance3D.new()
		spark.mesh = quad
		spark.set_meta("source_death_flash", true)
		var material := ShaderMaterial.new()
		material.shader = FLASH
		spark.material_override = material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.hide()
		add_child(spark)
		sparks.append(spark)
	animator.mixer_applied.connect(update_eye_flashes)

func update_eye_flashes() -> void:
	var active := not dead and COLORS.has(current_clip) and animator.current_animation_length > 0.0
	var phase := animator.current_animation_position / animator.current_animation_length if active else 0.0
	for index in sparks.size():
		var start := 0.28 + float(index) * (0.08 if current_clip == "EyeVolley" else 0.022)
		var intensity := smoothstep(start, start + 0.12, phase) * (1.0 - smoothstep(start + 0.24, 0.96, phase))
		var spark := sparks[index]
		spark.visible = active and intensity > 0.002
		if spark.visible:
			var bone := skeleton.find_bone("gazers_gazer_eyebone%d" % (index + 1))
			spark.global_position = skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
			var material := spark.material_override as ShaderMaterial
			material.set_shader_parameter("tint", COLORS[current_clip])
			material.set_shader_parameter("strength", intensity)
