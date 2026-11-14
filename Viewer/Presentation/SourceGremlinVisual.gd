# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLaterFlyingVisual.gd"

const BowSource := preload("res://Presentation/SourceRatmanArcherVisual.gd")
const BowAim := preload("res://Presentation/SourceRatmanBowAim.gd")
const Hue := preload("res://Presentation/HumanHue.gd")
const FingerFit := preload("res://Presentation/LichGrip.gd")
const BowScale := .48

var bow: MeshInstance3D
var aim := BowAim.new()
var left_grasp: int
var right_grasp: int
var bow_hue := -1
var draw_offset := Vector3.ZERO
var thumb := Vector2i()
var fingers := Vector2i()


func _ready() -> void:
	super._ready()
	left_grasp = skeleton.find_bone("cp_grasp_lhand")
	right_grasp = skeleton.find_bone("cp_grasp_rhand")
	thumb = Vector2i(skeleton.find_bone("bip01 l finger0"), skeleton.find_bone("bip01 l finger01"))
	fingers = Vector2i(skeleton.find_bone("bip01 l finger1"), skeleton.find_bone("bip01 l finger11"))
	aim.reach_scale = .75
	aim.close_grip = close_bow_grip
	aim.bind(self)
	animator.mixer_applied.connect(sync_bow)


func set_equipment(worn: Array) -> void:
	for item: Dictionary in worn:
		if int(item.get("layer", 0)) == 2 and int(item.get("id", 0)) in [0x13b1, 0x13b2]:
			if not equip_bow(int(item.get("hue", 0))):
				return
			sync_bow()
			return
	if is_instance_valid(bow):
		bow.hide()


func equip_bow(hue: int) -> bool:
	if not is_instance_valid(bow):
		if not BowSource.prepare_bow():
			return false
		bow = MeshInstance3D.new()
		bow.name = "GremlinBow"
		bow.mesh = BowSource.rest_bow
		add_child(bow)
	if hue != bow_hue:
		bow_hue = hue
		var material := BowSource.rest_bow.surface_get_material(0) as StandardMaterial3D
		bow.set_surface_override_material(0, Hue.material(material, hue) if hue != 0 else material)
	bow.visible = not dead
	return true


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead and is_instance_valid(bow):
		bow.hide()
	return true


func bow_release_available() -> bool:
	return not dead and is_instance_valid(bow) and bow.is_visible_in_tree()


func begin_bow_release(destination: Vector3) -> float:
	if not bow_release_available():
		return -1.0
	aim.start(destination)
	return BowAim.ReleaseTime


func bow_arrow_origin() -> Vector3:
	return bow.to_global(BowSource.string_center + draw_offset + Vector3(0.0, .035, 0.0))


func sync_bow() -> void:
	if not bow_release_available():
		return
	var forward := global_basis.z.slide(Vector3.UP).normalized()
	var across := forward.cross(Vector3.UP)
	var upright := (Vector3.UP * .45 - forward * .89).normalized()
	place_bow(Basis(across, upright, across.cross(upright)), Vector3.ZERO)


func pose_bow_release(flight: Vector3, across: Vector3, weight: float, draw: float) -> void:
	var basis := bow.global_basis.orthonormalized().slerp(release_basis(flight, across), weight)
	var fit := basis.scaled_local(Vector3.ONE * BowScale)
	var origin := grasp(left_grasp) - fit * BowSource.Grip
	var draw_hand := Transform3D(fit, origin).affine_inverse() * grasp(right_grasp)
	place_bow(basis, (draw_hand - BowSource.string_center).limit_length(.59) * draw)


func bow_draw_target(flight: Vector3, across: Vector3, distance: float) -> Vector3:
	var shift := release_basis(flight, across) * ((BowSource.string_center - BowSource.Grip) * BowScale)
	return grasp(left_grasp) + shift - flight * distance


func release_basis(flight: Vector3, across: Vector3) -> Basis:
	var upright := flight.cross(across)
	return Basis(-across, upright, upright.cross(across))


func grasp(joint: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(joint).origin)


func close_bow_grip() -> void:
	var handle := skeleton.to_local(bow.to_global(BowSource.Grip))
	for chain: Vector2i in [thumb, fingers]:
		var base := skeleton.get_bone_global_pose(chain.x)
		var knuckle := skeleton.get_bone_global_pose(chain.y)
		var inward := (handle - base.origin).normalized()
		FingerFit.aim(skeleton, chain.x, knuckle.origin, knuckle.origin.lerp(base.origin + inward * .15, .58))
		knuckle = skeleton.get_bone_global_pose(chain.y)
		FingerFit.aim(skeleton, chain.y, knuckle * Vector3(.08, 0, 0), handle)


func place_bow(basis: Basis, offset: Vector3) -> void:
	var fit := basis.scaled_local(Vector3.ONE * BowScale)
	bow.global_transform = Transform3D(fit, grasp(left_grasp) - fit * BowSource.Grip)
	if offset.is_equal_approx(draw_offset):
		return
	draw_offset = offset
	if offset.is_zero_approx():
		bow.mesh = BowSource.rest_bow
		return
	var vertices: PackedVector3Array = BowSource.rest_arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in BowSource.string_vertices:
		vertices[index] += offset
	var arrays := BowSource.rest_arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var drawn := ArrayMesh.new()
	drawn.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	drawn.surface_set_material(0, BowSource.rest_bow.surface_get_material(0))
	bow.mesh = drawn
