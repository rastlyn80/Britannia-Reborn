extends SceneTree

const INPUT := "res://../work/creatures/late-client-inputs/troll-action-trial/"
const FORMS := {
	53: ["trolls_troll", "Axe"],
	55: ["trolls_troll_frost", "FrostClub"],
}
const JOINT := "troll weapon"

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func vertex(builder: SurfaceTool, position: Vector3, normal: Vector3, uv: Vector2) -> void:
	builder.set_normal(normal)
	builder.set_uv(uv)
	builder.set_bones(PackedInt32Array([0, 0, 0, 0]))
	builder.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	builder.add_vertex(position)

func spikes(mesh: ArrayMesh) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = 0.0
	shape.bottom_radius = 0.066
	shape.height = 0.25
	shape.radial_segments = 5
	shape.rings = 0
	var data := shape.get_mesh_arrays()
	var positions: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9ba8ab")
	material.metallic = 0.63
	material.roughness = 0.52
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for i in 4:
		var angle := PI * (float(i) + 0.5) / 2.0
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var axis := (radial + Vector3.UP * 0.18).normalized()
		var basis := Basis(Quaternion(Vector3.UP, axis))
		var center := Vector3(0.01, 0.84, -0.02) + radial * 0.17 + axis * 0.125
		for index in indices:
			vertex(builder, center + basis * positions[index], basis * normals[index], Vector2.ZERO)
	builder.commit(mesh)

func run() -> void:
	var shapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT + "weapon-sources.json"))
	var atlas := Image.load_from_file(INPUT + "weapon-atlas.png")
	assert(atlas != null and not atlas.is_empty())
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = 0.84
	for body in FORMS:
		bake(body, shapes, material)
	quit()

func bake(body: int, shapes: Dictionary, material: Material) -> void:
	var form: Array = FORMS[body]
	var path := "res://local-art/creatures/%s-slot11-trial.scn" % form[0]
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(grip >= 0)
	var joint := rig.add_bone(JOINT)
	rig.set_bone_parent(joint, grip)
	# The source socket is inside the palm. Seat the shaft at that anchor.
	var fit := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0))
	rig.set_bone_rest(joint, fit)
	rig.reset_bone_pose(joint)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in shapes[form[1]]:
		vertex(builder, Vector3(row[0], row[1], row[2]), Vector3(row[3], row[4], row[5]), Vector2(row[6], row[7]))
	var weapon := MeshInstance3D.new()
	weapon.name = form[1]
	var mesh := builder.commit()
	if body == 55:
		spikes(mesh)
	weapon.mesh = mesh
	var skin := Skin.new()
	skin.add_bind(joint, Transform3D.IDENTITY)
	weapon.skin = skin
	weapon.skeleton = NodePath("..")
	rig.add_child(weapon)
	weapon.owner = model

	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, "res://local-art/creatures/troll-%d-armed-trial.scn" % body,
		ResourceSaver.FLAG_COMPRESS) == OK)
	print("Troll ", body, " uses source grip socket and ", mesh.get_surface_count(), " weapon surfaces")
	model.free()
