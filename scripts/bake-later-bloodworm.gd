# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-later-rotworm.gd"

## Body 287 has paired ivory spines, a scarlet back and a pale segmented belly.
## Reuse the existing worm skeleton and fit a separate silhouette and motions.


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	super.run()
	for style in ["original", "rounded", "modern"]:
		var generated := folder.path_join("732-%s.scn" % style)
		var matched := folder.path_join("287-%s.scn" % style)
		assert(DirAccess.rename_absolute(generated, matched) == OK)
		print("BLOODWORM BAKE: ", style, " ", FileAccess.get_sha256(matched))


func geometry(points: PackedVector3Array, style: String) -> ArrayMesh:
	var adjusted := points.duplicate()
	for segment in Segments + 1:
		var index := 1 + segment
		var progress := segment / float(Segments)
		adjusted[index].y += .065 * sin(progress * PI)
	for arm in 4:
		for joint in 5:
			var index := Segments + 2 + arm * 5 + joint
			var progress := joint / 4.0
			adjusted[index].z -= .10 * progress
			adjusted[index].x *= 1.0 + .55 * progress
			adjusted[index].y += .045 * sin(progress * PI)
	var meshed := super.geometry(adjusted, style)
	var spines := SurfaceTool.new()
	spines.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ivory := StandardMaterial3D.new()
	ivory.albedo_color = Color("#d8b788")
	ivory.roughness = .69
	spines.set_material(ivory)
	for segment in 9:
		var progress := segment / 9.0
		var bone := segment + 2
		for side in [-1.0, 1.0]:
			var base := adjusted[bone] + Vector3(side * lerpf(.095, .03, progress),
				lerpf(.125, .033, progress), 0)
			var direction := Vector3(.34 * side, .9, .36).normalized()
			add_spine(spines, base, direction, lerpf(.133, .043, progress),
				lerpf(.036, .014, progress), bone)
	spines.index()
	spines.commit(meshed)
	return meshed


func add_spine(surface: SurfaceTool, base: Vector3, direction: Vector3, length: float,
		width: float, bone: int) -> void:
	var right := direction.cross(Vector3.BACK).normalized()
	var tangent := right.cross(direction).normalized()
	for side in 8:
		var a := float(side) * TAU / 8.0
		var b := float(side + 1) * TAU / 8.0
		var left := right * cos(a) + tangent * sin(a)
		var next := right * cos(b) + tangent * sin(b)
		var tip := base + direction * length + Vector3.BACK * length * .13
		vertex(surface, tip, ((left + next) * .5 + direction * .28).normalized(), Vector2(.5, 0), bone)
		vertex(surface, base + left * width, (left + direction * .28).normalized(), Vector2(0, 1), bone)
		vertex(surface, base + next * width, (next + direction * .28).normalized(), Vector2(1, 1), bone)


func material(flesh: bool, style: String) -> StandardMaterial3D:
	var texture := Image.create_empty(256, 256, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 287
	noise.frequency = .13
	for y in texture.get_height():
		for x in texture.get_width():
			var angle := x * TAU / texture.get_width()
			var belly := smoothstep(-.08, .75, -sin(angle))
			var tint := Color("#9a382b").lerp(Color("#c4ab87"), belly)
			if flesh:
				tint = Color("#803728").lerp(Color("#ce8d70"), .65 + .25 * cos(angle))
			var band := .86 + .14 * cos(y * TAU * 21.0 / texture.get_height())
			var mottling := noise.get_noise_3d(cos(angle) * 27.0, sin(angle) * 27.0, y)
			var amplitude := .25 if style == "modern" else .15
			var multiplier := band * (1.0 + mottling * amplitude)
			texture.set_pixel(x, y, Color(tint.r * multiplier, tint.g * multiplier, tint.b * multiplier))
	texture.generate_mipmaps()
	var result := StandardMaterial3D.new()
	result.roughness = .70 if flesh else .82
	result.albedo_texture = ImageTexture.create_from_image(texture)
	return result


func pose(clip: String, bone: int, phase: float) -> Dictionary:
	var posture := super.pose(clip, bone, phase)
	var rotation: Vector3 = posture.rotation
	var drive := smoothstep(.08, .39, phase) * (1.0 - smoothstep(.55, .91, phase))
	if clip in ["Attack", "Attack2"]:
		if bone in [1, 2, 3]:
			rotation.x -= .13 * drive
		elif bone >= Segments + 2:
			rotation.y += .24 * drive * (-1.0 if clip == "Attack" else 1.0)
	elif clip in ["Death", "Death2"] and bone == 0:
		var settle := smoothstep(.16, .82, phase)
		rotation.z = 2.92 * settle if clip == "Death" else -2.70 * settle
	posture.rotation = rotation
	return posture
