# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const OUTPUT := "res://local-art/creatures/jack-o-lanterns"
const FLAME := preload("res://Presentation/JackOLanternFlame.gdshader")
const CLIPS := {
	"Idle": [1.70, true], "Walk": [1.70, true], "Run": [1.12, true],
	"Attack": [1.70, false], "Hit": [1.60, false], "Fidget": [1.70, true],
	"Death": [2.20, false], "Dormant": [.30, false], "Ignite": [1.60, false],
}

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): quit(2))
	call_deferred("bake")

func bake() -> void:
	var trial := OS.get_environment("BR_FORM_TEST_DIR")
	assert(not trial.is_empty(), "Bake in the isolated viewer")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scan := load("res://Art/Objaverse/pumpkin/pumpkin.glb") as PackedScene
	assert(scan != null)
	for body: int in [1246, 1247]:
		var model := Node3D.new()
		model.name = "JackOLantern"
		root.add_child(model)
		var anchor := Skeleton3D.new()
		anchor.name = "RigidRig"
		anchor.add_bone("Root")
		model.add_child(anchor)
		var gourd := Node3D.new()
		gourd.name = "Gourd"
		model.add_child(gourd)
		add_gourd(gourd, scan)
		var spirit := Node3D.new()
		spirit.name = "Spirit"
		model.add_child(spirit)
		add_spirit(spirit, body == 1247)
		var player := AnimationPlayer.new()
		player.name = "Actions"
		model.add_child(player)
		var library := AnimationLibrary.new()
		var clips := CLIPS.duplicate(true)
		if body == 1247:
			clips.Death[0] = 2.10
			clips.Cast = [2.10, false]
		else:
			clips.DormantShuffle = [.30, false]
		for clip: String in clips:
			assert(library.add_animation(clip, bake_clip(clip, float(clips[clip][0]), clips[clip][1], body)) == OK)
		player.add_animation_library("", library)
		for node: Node in model.find_children("*", "Node", true, false):
			if node.owner == null:
				node.owner = model
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, OUTPUT.path_join("%d.scn" % body), ResourceSaver.FLAG_COMPRESS) == OK)
		print("JACK O' LANTERN ", body, " / ", clips.size(), " baked actions")
		model.free()
	quit()

func add_gourd(gourd: Node3D, scan: PackedScene) -> void:
	var pumpkin := scan.instantiate() as Node3D
	pumpkin.name = "LicensedPumpkin"
	gourd.add_child(pumpkin)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in pumpkin.find_children("*", "MeshInstance3D", true, false):
		var box := pumpkin.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	assert(not first and bounds.size.x > 0.0)
	var scale := .57 / maxf(bounds.size.x, bounds.size.z)
	pumpkin.scale = Vector3.ONE * scale
	pumpkin.position = -scale * Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var surface_points := PackedVector3Array()
	for mesh: MeshInstance3D in pumpkin.find_children("*", "MeshInstance3D", true, false):
		var local := gourd.global_transform.affine_inverse() * mesh.global_transform
		for vertex: Vector3 in mesh.mesh.get_faces():
			surface_points.append(local * vertex)
	var cuts := SurfaceTool.new()
	cuts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := PackedVector3Array([
		Vector3(-.165, .24, .207), Vector3(-.094, .296, .245), Vector3(-.052, .235, .261),
		Vector3(.052, .235, .261), Vector3(.094, .296, .245), Vector3(.165, .24, .207),
		Vector3(-.145, .14, .205), Vector3(-.080, .116, .246), Vector3(-.063, .153, .266),
		Vector3(-.035, .120, .268), Vector3(.044, .121, .268), Vector3(.069, .155, .258),
		Vector3(.091, .124, .242), Vector3(.141, .147, .211),
	])
	var faces := [0, 1, 2, 3, 4, 5, 6, 7, 8, 6, 8, 9, 6, 9, 10, 6, 10, 13, 10, 11, 13, 11, 12, 13]
	for index in range(0, faces.size(), 3):
		project_cut(cuts, surface_points, outline[faces[index]], outline[faces[index + 1]], outline[faces[index + 2]], 3)
	cuts.generate_normals()
	var carved := MeshInstance3D.new()
	carved.name = "Cutouts"
	carved.mesh = cuts.commit()
	var dark := material(Color("#331205"), .92)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	carved.material_override = dark
	gourd.add_child(carved)

func project_cut(cuts: SurfaceTool, surface: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, depth: int) -> void:
	if depth > 0:
		var ab := (a + b) * .5
		var bc := (b + c) * .5
		var ca := (c + a) * .5
		project_cut(cuts, surface, a, ab, ca, depth - 1)
		project_cut(cuts, surface, ab, b, bc, depth - 1)
		project_cut(cuts, surface, ca, bc, c, depth - 1)
		project_cut(cuts, surface, ab, bc, ca, depth - 1)
		return
	var outline := PackedVector3Array()
	for point: Vector3 in [a, b, c]:
		var front := Vector3(point.x, point.y, .65)
		var nearest := -INF
		for face in range(0, surface.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(front, Vector3.FORWARD,
				surface[face], surface[face + 1], surface[face + 2])
			if hit != null:
				nearest = maxf(nearest, hit.z)
		if not is_finite(nearest):
			return
		outline.append(Vector3(point.x, point.y, nearest + .0025))
	for point: Vector3 in outline:
		cuts.add_vertex(point)

func add_spirit(spirit: Node3D, blue: bool) -> void:
	var layers: Array[Vector3] = [Vector3(1.41, 1.48, 1.24), Vector3(1.11, 1.18, 1.02), Vector3(.88, .98, .91)]
	for layer in layers.size():
		var flame := ShaderMaterial.new()
		flame.shader = FLAME
		flame.set_shader_parameter("dark_tint", Color("#120d69") if blue else Color("#a52805"))
		flame.set_shader_parameter("bright_tint", Color("#3bc6ff") if blue else Color("#ffda39"))
		flame.set_shader_parameter("offset", 3.6 * layer)
		flame.set_shader_parameter("density", [.69, .61, .51][layer])
		var shell := ellipsoid(spirit, Vector3(.03, .05, -.19), layers[layer], flame)
		shell.name = "Flame%d" % layer
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.extra_cull_margin = .14
		shell.set_meta("ephemeral_flame", true)
	var face := Node3D.new()
	face.name = "Mask"
	face.position = Vector3(0., -.03, .40)
	spirit.add_child(face)
	var bone := material(Color("#8797ab") if blue else Color("#89734e"), .74)
	var shadow := material(Color("#190e17"), .95)
	var eye := material(Color("#fa651d") if blue else Color("#ffc94a"), .48, .53)
	ellipsoid(face, Vector3(0, .025, -.01), Vector3(.45, .54, .31), bone)
	var jaw := Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0., -.15, .06)
	face.add_child(jaw)
	ellipsoid(jaw, Vector3(0, -.065, .016), Vector3(.245, .24, .21), bone)
	ellipsoid(jaw, Vector3(0, -.025, .116), Vector3(.207, .098, .054), shadow)
	for side: float in [-1.0, 1.0]:
		var orbit := ellipsoid(face, Vector3(.100 * side, .037, .136), Vector3(.145, .103, .065), shadow)
		orbit.rotation.z = side * .23
		ellipsoid(face, Vector3(.105 * side, .030, .172), Vector3(.043, .052, .041), eye)
		var ridge := ellipsoid(face, Vector3(.096 * side, .095, .139), Vector3(.163, .058, .099), bone)
		ridge.rotation.z = side * .25
		var cheek := ellipsoid(face, Vector3(.141 * side, -.048, .114), Vector3(.111, .095, .134), bone)
		cheek.rotation.z = side * -.38
		if blue:
			var paint := material(Color("#18557a"), .79)
			var accent := ellipsoid(face, Vector3(.121 * side, .133, .114), Vector3(.104, .087, .092), paint)
			accent.rotation.z = side * -.48
		else:
			var horn: Array[Vector3] = [Vector3(.156 * side, .109, .027),
				Vector3(.265 * side, .126, .067), Vector3(.317 * side, .235, .071),
				Vector3(.296 * side, .323, .144)]
			for segment in horn.size() - 1:
				add_horn(face, horn[segment], horn[segment + 1], .061 - .019 * segment, .044 - .018 * segment, bone)
	var nose := material(Color("#b73b37"), .58) if blue else bone
	ellipsoid(face, Vector3(0, -.023, .187), Vector3(.116, .092, .120) if blue else Vector3(.059, .089, .064), nose)
	for tooth in range(-2, 3):
		var width := .029 - .003 * absf(tooth)
		ellipsoid(jaw, Vector3(.035 * tooth, -.026 + .006 * absf(tooth), .142), Vector3(width, .042, .031), bone)

func ellipsoid(parent: Node3D, at: Vector3, dimensions: Vector3, surface: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 30 if surface is ShaderMaterial else 16
	sphere.rings = 16 if surface is ShaderMaterial else 9
	instance.mesh = sphere
	instance.position = at
	instance.scale = dimensions
	instance.material_override = surface
	parent.add_child(instance)
	return instance

func add_horn(parent: Node3D, start: Vector3, end: Vector3, base: float, tip: float, surface: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = tip
	mesh.bottom_radius = base
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.transform = Transform3D(Basis(Quaternion(Vector3.UP, (end - start).normalized())), start.lerp(end, .5))
	instance.material_override = surface
	parent.add_child(instance)

func material(colour: Color, roughness: float, emission := 0.) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = roughness
	result.emission_enabled = emission > 0.
	result.emission = colour * emission
	return result

func bake_clip(name: String, length: float, looped: bool, body: int) -> Animation:
	var clip := Animation.new()
	clip.length = length
	clip.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	var gourd := track(clip, Animation.TYPE_ROTATION_3D, "Gourd")
	var drift := track(clip, Animation.TYPE_POSITION_3D, "Spirit")
	var angle := track(clip, Animation.TYPE_ROTATION_3D, "Spirit")
	var spread := track(clip, Animation.TYPE_SCALE_3D, "Spirit")
	var jaw := track(clip, Animation.TYPE_ROTATION_3D, "Spirit/Mask/Jaw")
	var visible := track(clip, Animation.TYPE_VALUE, "Spirit:visible")
	clip.value_track_set_update_mode(visible, Animation.UPDATE_DISCRETE)
	var previous_visible := true
	for frame in 49:
		var phase := frame / 48.0
		var state := sample(name, phase, body == 1247)
		var time := phase * length
		clip.rotation_track_insert_key(gourd, time, Quaternion.from_euler(state[0]))
		clip.position_track_insert_key(drift, time, state[1])
		clip.rotation_track_insert_key(angle, time, Quaternion.from_euler(state[2]))
		clip.scale_track_insert_key(spread, time, state[3])
		clip.rotation_track_insert_key(jaw, time, Quaternion(Vector3.RIGHT, state[4]))
		if frame == 0 or state[5] != previous_visible:
			clip.track_insert_key(visible, time, state[5])
			previous_visible = state[5]
	return clip

func track(clip: Animation, type: int, path: String) -> int:
	var index := clip.add_track(type)
	clip.track_set_path(index, NodePath(path))
	return index

func wave(t: float, peak: float) -> float:
	return smoothstep(0., peak, t) * (1.0 - smoothstep(peak, 1.0, t))

func sample(name: String, t: float, blue: bool) -> Array:
	var phase := TAU * t
	var gourd := Vector3.ZERO
	var shift := Vector3(.035 * sin(phase), 1.02 + .060 * cos(phase), -.06 + .03 * cos(phase))
	var turn := Vector3(.06 * cos(phase), .21 * sin(phase), .075 * sin(phase))
	var scale := Vector3.ONE + Vector3(-.06, .105, -.05) * cos(phase)
	var jaw := .15 + .09 * sin(phase)
	var spirit_visible := true
	match name:
		"Walk", "Run":
			var pace := 1.34 if name == "Run" else 1.
			gourd = Vector3(.13 * pace * sin(phase), phase, .14 * pace * sin(phase + .7))
			shift += Vector3(.12 * sin(phase), .08 * pace * sin(phase), -.14 * pace * cos(phase))
			turn.y += .25 * pace * sin(phase)
		"Attack":
			var push := wave(t, .54)
			var pull := wave(t, .22)
			gourd.z = .08 * push
			shift += Vector3(.13 * push * (-1. if blue else 1.), .29 * pull - .22 * push, .69 * push - .24 * pull)
			turn += Vector3(-.43 * pull + .56 * push, .34 * push, -.31 * pull)
			scale *= Vector3(1.0 - .27 * push, 1.0 - .28 * push, 1.0 + .93 * push)
			jaw += .48 * push
		"Cast":
			var rise := wave(t, .28)
			var spill := wave(t, .64)
			shift += Vector3(.38 * spill, .36 * rise - .17 * spill, .41 * spill)
			turn += Vector3(-.34 * rise, -.38 * spill, .51 * spill)
			scale *= Vector3(1. + .64 * spill, 1. - .29 * spill, 1. + .47 * spill)
			jaw += .31 * spill
		"Hit":
			var recoil := wave(t, .34)
			shift += Vector3(-.17, .25, -.33) * recoil
			turn += Vector3(-.35, -.42, .29) * recoil
			scale *= Vector3(1. + .16 * recoil, 1. - .14 * recoil, 1. + .13 * recoil)
			jaw += .23 * recoil
		"Fidget":
			var circle := wave(t, .54)
			shift += Vector3(.09 * sin(phase), .17 * sin(phase), -.12 * circle)
			turn.y += .42 * circle * (-1. if blue else 1.)
		"Death":
			var lift := wave(t, .68)
			var fade := smoothstep(.65, .97, t)
			shift += Vector3(.10 * sin(phase), .64 * lift, -.10 * lift)
			scale *= Vector3(1. - .87 * fade, (1. + .35 * lift) * (1. - .87 * fade), 1. - .87 * fade)
			turn += Vector3(-.48 * lift, .78 * lift, .37 * lift)
			gourd.z = .13 * wave(t, .78)
			spirit_visible = t < .94
		"Dormant", "DormantShuffle":
			gourd.z = .065 * sin(phase) if name == "DormantShuffle" else 0.
			spirit_visible = false
		"Ignite":
			var rise := smoothstep(.13, .78, t)
			shift.y *= .29 + .71 * rise
			scale *= Vector3.ONE * (.08 + .92 * rise)
			jaw += .22 * wave(t, .68)
			spirit_visible = t >= .12
	return [gourd, shift, turn, scale, jaw, spirit_visible]
