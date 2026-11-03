extends SceneTree
## Bake the authored effect without proprietary images or models.

const Surface = preload("res://Presentation/EnergyVortexSurface.gdshader")
const OUTPUT := "res://local-art/creatures/energy_vortex/"
const CLIPS := {
	"Idle": [1.8, Vector3.ONE, Vector3.ONE],
	"Walk": [1.1, Vector3(0.94, 1.06, 0.94), Vector3.ONE],
	"Run": [0.75, Vector3(0.82, 1.18, 0.82), Vector3.ONE],
	"Attack": [0.8, Vector3(1.28, 0.95, 1.28), Vector3.ONE],
	"Hit": [0.5, Vector3(0.8, 0.86, 0.8), Vector3.ONE],
	"Fidget": [1.1, Vector3(1.11, 1.12, 1.11), Vector3.ONE],
	"Death": [0.8, Vector3(1.24, 0.66, 1.24), Vector3(0.45, 0.14, 0.45)],
}


func _initialize() -> void:
	var model := Node3D.new()
	var rig := Skeleton3D.new()
	rig.name = "Rig"
	rig.add_bone("Anchor")
	model.add_child(rig)
	rig.owner = model
	var ribbons := Node3D.new()
	ribbons.name = "Ribbons"
	model.add_child(ribbons)
	ribbons.owner = model
	for layer in 3:
		var shell := CylinderMesh.new()
		shell.height = 1.65 - layer * 0.20
		shell.top_radius = 0.73 - layer * 0.15
		shell.bottom_radius = 0.24 + layer * 0.025
		shell.radial_segments = 64
		shell.rings = 8
		shell.cap_top = false
		shell.cap_bottom = false
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("twist", float(layer) * 1.7)
		shell.material = material
		var visual := MeshInstance3D.new()
		visual.name = "Ribbon%d" % layer
		visual.mesh = shell
		visual.position.y = 0.95
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbons.add_child(visual)
		visual.owner = model
	var player := AnimationPlayer.new()
	model.add_child(player)
	player.owner = model
	var library := AnimationLibrary.new()
	for clip: String in CLIPS:
		var motion := Animation.new()
		var values: Array = CLIPS[clip]
		motion.length = values[0]
		var track := motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(track, ^"Ribbons")
		motion.scale_track_insert_key(track, 0.0, Vector3.ONE)
		motion.scale_track_insert_key(track, motion.length * 0.45, values[1])
		motion.scale_track_insert_key(track, motion.length, values[2])
		library.add_animation(clip, motion)
	player.add_animation_library("", library)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene := PackedScene.new()
	var packed := scene.pack(model) == OK
	model.free()
	if not packed or ResourceSaver.save(scene, OUTPUT + "vortex.scn") != OK:
		quit(1)
		return
	print("ENERGY VORTEX BAKE: three shells, seven authored clips")
	quit()
