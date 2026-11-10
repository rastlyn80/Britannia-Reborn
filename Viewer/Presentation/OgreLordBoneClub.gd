# SPDX-License-Identifier: GPL-3.0-or-later
extends MeshInstance3D

const RingSides := 16
const Profile := [
	Vector3(-.20, .069, .042), Vector3(-.16, .088, .062), Vector3(-.10, .067, .053),
	Vector3(-.06, .046, .039), Vector3(.08, .043, .037), Vector3(.24, .050, .042),
	Vector3(.40, .061, .043), Vector3(.53, .079, .056), Vector3(.60, .105, .067),
	Vector3(.67, .112, .076), Vector3(.72, .096, .061), Vector3(.75, .065, .037),
]


func _init() -> void:
	name = "OgreLordBoneClub"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in Profile.size():
		var profile: Vector3 = Profile[ring]
		var center_x := .04 * sin((profile.x + .2) * 3.0)
		for side in RingSides:
			var angle := TAU * side / RingSides
			var ripple := 1.0 + .06 * sin(3.0 * angle + ring * .62)
			var x := cos(angle)
			var z := sin(angle)
			var y := profile.x + .015 * cos(2.0 * angle) * smoothstep(.45, .75, profile.x)
			var point := Vector3(center_x + profile.y * x * ripple, y, profile.z * z * ripple)
			var bevel := -.48 if ring <= 1 else .46 if ring >= Profile.size() - 2 else 0.0
			var normal := Vector3(x / profile.y, bevel / profile.y, z / profile.z).normalized()
			var grain := .50 + .20 * sin(3.0 * angle + ring * .41) + .09 * cos(5.0 * angle + ring * 1.8)
			var color := Color("c1a57c").lerp(Color("ede2c6"), grain)
			add_vertex(surface, point, normal, color)
	for ring in Profile.size() - 1:
		for side in RingSides:
			var next := (side + 1) % RingSides
			var a := ring * RingSides + side
			var b := (ring + 1) * RingSides + side
			var c := ring * RingSides + next
			var d := (ring + 1) * RingSides + next
			for index in [a, c, b, c, d, b]:
				surface.add_index(index)
	var start_cap := Profile.size() * RingSides
	var end_cap := start_cap + 1
	add_vertex(surface, Vector3(0, -.225, 0), Vector3.DOWN, Color("dac7a1"))
	add_vertex(surface, Vector3(.015, .78, 0), Vector3.UP, Color("e4d6b7"))
	for side in RingSides:
		var next := (side + 1) % RingSides
		var last := (Profile.size() - 1) * RingSides
		for index in [start_cap, next, side, end_cap, last + side, last + next]:
			surface.add_index(index)
	mesh = surface.commit()
	var ivory := StandardMaterial3D.new()
	ivory.vertex_color_use_as_albedo = true
	ivory.roughness = .82
	ivory.metallic_specular = .28
	material_override = ivory


func add_vertex(surface: SurfaceTool, point: Vector3, normal: Vector3, color: Color) -> void:
	surface.set_normal(normal)
	surface.set_color(color)
	surface.add_vertex(point)

