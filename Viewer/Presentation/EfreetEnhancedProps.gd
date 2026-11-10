# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

const CarpetShader := preload("efreet-carpet.gdshader")
const SmokeShader := preload("efreet-smoke.gdshader")
var carpet := MeshInstance3D.new()
var lamp := Node3D.new()
var fabric := ShaderMaterial.new()
var wisps: Array[MeshInstance3D] = []


func _ready() -> void:
	var rug := PlaneMesh.new()
	rug.size = Vector2(1.52, 1.10)
	rug.subdivide_width = 24
	rug.subdivide_depth = 16
	carpet.name = "EfreetFlyingCarpet"
	carpet.mesh = rug
	carpet.custom_aabb = AABB(Vector3(-.82, -.05, -.91), Vector3(1.64, .65, 1.52))
	fabric.shader = CarpetShader
	carpet.material_override = fabric
	carpet.visible = false
	add_child(carpet)
	lamp.name = "EfreetArrivalLamp"
	lamp.visible = false
	add_child(lamp)
	make_lamp()
	var vapour := ShaderMaterial.new()
	vapour.shader = SmokeShader
	var quad := QuadMesh.new()
	quad.size = Vector2(.46, .46)
	for index in 4:
		var wisp := MeshInstance3D.new()
		wisp.name = "ArrivalWisp%d" % index
		wisp.mesh = quad
		wisp.material_override = vapour
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.visible = false
		wisps.append(wisp)
		add_child(wisp)


func apply_phase(group: int, phase: float, body_bottom: float) -> void:
	var arrival := group == 23
	var spread := smoothstep(.35, .78, phase) if arrival else 1.0
	carpet.visible = group in [23, 26, 27, 28] and spread > .015
	carpet.position = Vector3(0.0, body_bottom - .036, .15)
	carpet.rotation = Vector3(.025 * sin(TAU * phase), 0.0, .040 * sin(TAU * phase))
	carpet.scale = Vector3.ONE * lerpf(.45, 1.0, spread)
	fabric.set_shader_parameter("roll", 1.0 - spread)
	fabric.set_shader_parameter("wave_phase", phase * TAU)
	lamp.visible = arrival and phase < .59
	lamp.position = Vector3(-.10 * phase, .055 + .09 * sin(phase * PI), .30)
	lamp.rotation = Vector3(0.0, -.47 + phase * 1.2, .14 * sin(TAU * phase))
	lamp.scale = Vector3.ONE * (1.0 - .80 * smoothstep(.38, .60, phase))
	for index in wisps.size():
		var wisp := wisps[index]
		var age := (phase - .028 * index) / .53
		wisp.visible = arrival and age > 0.0 and age < 1.0
		if not wisp.visible:
			continue
		var curl := age * 4.4 + index * 1.23
		wisp.position = Vector3(.14 + .14 * age * cos(curl), .14 + .54 * age, .30 + .14 * age * sin(curl))
		wisp.scale = Vector3.ONE * lerpf(.52, 1.38, age)
		var density := smoothstep(0.0, .17, age) * (1.0 - smoothstep(.51, 1.0, age))
		wisp.set_instance_shader_parameter("density", density)
		wisp.set_instance_shader_parameter("drift", age)


func make_lamp() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("#ad7027")
	brass.metallic = .75
	brass.roughness = .38
	var belly := SphereMesh.new()
	belly.radius = .12
	belly.height = .24
	add_lamp_piece(belly, Vector3.ZERO, Vector3(1.0, .48, .65), brass)
	add_lamp_piece(belly, Vector3(0, .055, 0), Vector3(.54, .24, .46), brass)
	add_lamp_piece(belly, Vector3(0, .086, 0), Vector3(.21, .20, .21), brass)
	var loop := TorusMesh.new()
	loop.inner_radius = .041
	loop.outer_radius = .061
	var handle := add_lamp_piece(loop, Vector3(-.139, .027, 0), Vector3(1.0, 1.0, 1.0), brass)
	handle.rotation.x = PI * .5
	var a := Vector3(.079, .005, 0)
	var b := Vector3(.166, .021, 0)
	var c := Vector3(.231, .086, 0)
	add_spout(a, b, .035, .024, brass)
	add_spout(b, c, .024, .012, brass)


func add_spout(a: Vector3, b: Vector3, bottom: float, top: float, material: Material) -> void:
	var part := CylinderMesh.new()
	part.bottom_radius = bottom
	part.top_radius = top
	part.height = a.distance_to(b) + .006
	var instance := add_lamp_piece(part, a.lerp(b, .5), Vector3.ONE, material)
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


func add_lamp_piece(mesh: Mesh, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = at
	piece.scale = size
	lamp.add_child(piece)
	return piece
