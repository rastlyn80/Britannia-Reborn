# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedFireBreathProjectilePresenter.gd"

const Gargoyle := preload("res://Presentation/SourceEnhancedArmoredGargoyleVisual.gd")
const Hatchet := 0x0f43
const Whirlwind := 0x3728

var handle_mesh: CylinderMesh
var blade_mesh: ArrayMesh


func present(effect: Dictionary) -> void:
	if scene != null and scene.game.phase == "world" and effect.kind == "fixed_mobile" \
			and int(effect.graphic) == Whirlwind and int(effect.speed) == 10 and int(effect.duration) == 15:
		var serial := int(effect.target if int(effect.target) else effect.source)
		var enforcer := gargoyle_actor(serial, 754)
		if enforcer != null:
			if not enforcer.dead:
				enforcer.start_turning_sweep()
				draw_whirlwind(enforcer, colour(effect))
				return
	super.present(effect)


func draw_whirlwind(actor: Gargoyle, tint: Color) -> void:
	var pivot := Node3D.new()
	pivot.name = "NativeEnforcerWhirlwind"
	actor.add_child(pivot)
	pivot.position.y = 1.0
	var band := TorusMesh.new()
	band.inner_radius = .58
	band.outer_radius = .67
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint.lightened(.58), .82)
	material.emission_enabled = true
	material.emission = tint.lightened(.58)
	material.emission_energy_multiplier = 1.25
	band.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = band
	ring.scale = Vector3(.66, .20, .66)
	ring.rotation.z = .16
	pivot.add_child(ring)
	var dust := sparks(tint, 32, .55, .43, 1.45)
	dust.one_shot = true
	dust.explosiveness = .75
	pivot.add_child(dust)
	dust.emitting = true
	var flare := pivot.create_tween().set_parallel(true)
	flare.tween_property(ring, "scale", Vector3(1.65, .05, 1.65), .35)
	flare.tween_property(ring, "rotation:y", TAU, .40)
	flare.tween_property(material, "albedo_color:a", 0.0, .38)
	flare.chain().tween_interval(1.12)
	flare.chain().tween_callback(pivot.queue_free)


func _bolt(effect: Dictionary, tint: Color) -> void:
	if int(effect.graphic) == Hatchet and int(effect.speed) == 10 and not effect.explodes:
		var destroyer := gargoyle_actor(int(effect.source), 755)
		if destroyer != null:
			var origin: Variant = destroyer.start_hatchet_counter()
			if origin is Vector3:
				fly_hatchet(origin, _point(int(effect.target), effect.to), float(effect.speed))
				return
	super._bolt(effect, tint)


func gargoyle_actor(serial: int, body: int) -> Gargoyle:
	var avatar := scene.avatars.get(serial) as Avatar
	if avatar == null or avatar.native_body != body:
		return null
	return avatar.horse_visual as Gargoyle


func fly_hatchet(origin: Vector3, destination: Vector3, speed: float) -> void:
	if handle_mesh == null:
		make_hatchet_meshes()
	var hatchet := Node3D.new()
	hatchet.name = "NativeDestroyerHatchet"
	var handle := MeshInstance3D.new()
	handle.mesh = handle_mesh
	hatchet.add_child(handle)
	var blade := MeshInstance3D.new()
	blade.mesh = blade_mesh
	hatchet.add_child(blade)
	add_child(hatchet)
	hatchet.global_position = origin
	var path := destination - origin
	var travel := clampf(path.length() / (6.0 + speed), .15, 1.6)
	var axis := Vector3.UP.cross(path).normalized()
	if axis.is_zero_approx():
		axis = Vector3.RIGHT
	var facing := Basis.looking_at(axis, Vector3.UP)
	var flight := create_tween()
	flight.tween_method(func(phase: float):
		hatchet.global_position = origin.lerp(destination, phase) + Vector3.UP * (.13 * sin(PI * phase))
		hatchet.global_basis = Basis(axis, TAU * phase * 1.1) * facing, 0.0, 1.0, travel)
	flight.tween_callback(hatchet.queue_free)


func make_hatchet_meshes() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(.20, .098, .044)
	wood.roughness = .81
	handle_mesh = CylinderMesh.new()
	handle_mesh.top_radius = .019
	handle_mesh.bottom_radius = .016
	handle_mesh.height = .39
	handle_mesh.radial_segments = 10
	handle_mesh.material = wood

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(.48, .50, .51)
	steel.roughness = .42
	steel.metallic = .82
	var outline := PackedVector2Array([Vector2(-.028, .12), Vector2(.046, .118), Vector2(.143, .080),
		Vector2(.170, .128), Vector2(.159, .192), Vector2(.127, .224), Vector2(.045, .184), Vector2(-.028, .178)])
	var face := Geometry2D.triangulate_polygon(outline)
	assert(not face.is_empty())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(steel)
	surface.set_smooth_group(-1)
	for index in range(0, face.size(), 3):
		for corner in [2, 1, 0]:
			add_blade_vertex(surface, outline[face[index + corner]], .014)
		for corner in [0, 1, 2]:
			add_blade_vertex(surface, outline[face[index + corner]], -.014)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		add_blade_vertex(surface, a, -.014)
		add_blade_vertex(surface, b, -.014)
		add_blade_vertex(surface, b, .014)
		add_blade_vertex(surface, a, -.014)
		add_blade_vertex(surface, b, .014)
		add_blade_vertex(surface, a, .014)
	surface.generate_normals()
	blade_mesh = surface.commit()


func add_blade_vertex(surface: SurfaceTool, point: Vector2, depth: float) -> void:
	surface.add_vertex(Vector3(point.x, point.y, depth))
