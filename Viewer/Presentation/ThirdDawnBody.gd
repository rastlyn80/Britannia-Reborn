extends Node3D
## Optional local-only body adapter. Same animate contract as Avatar.gd;
## server position, collision and the default licensed avatar stay independent.

var body := "human"
var animator: AnimationPlayer
var model: Node3D
var current_clip := "Idle"
var treatment := "original"
var wardrobe := "base"
var skeleton: Skeleton3D
var equipment: Array[MeshInstance3D] = []
var refined := false
var localized := false
var anatomy := false
var skin_texture := "young_lightskinned_male_diffuse2.png"
var hair_style := "short02"
var extra_hair: Array[MeshInstance3D] = []

func _ready() -> void:
	var suffix := "-" + wardrobe if body == "human" and wardrobe != "base" else ""
	var path := "res://local-art/third-dawn/%s%s%s.gltf" % [body, "-anatomy" if anatomy else ("-rounded" if localized else ("-smooth" if refined else "")), suffix]
	if body == "free-human":
		path = "res://local-art/free-human/free-human%s.glb" % ("" if wardrobe == "base" else "-" + wardrobe)
	if body == "free-equipment": path = "res://local-art/free-equipment/equipment-%s.glb" % wardrobe
	if not ResourceLoader.exists(path):
		push_error("Run scripts/import-third-dawn.py with your local archive first")
		return
	model = load(path).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	if body in ["free-human", "free-equipment"]:
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if body == "free-equipment":
				if mesh.name.begins_with("Free_"): equipment.append(mesh)
				if mesh.name.begins_with("Eyelash"): mesh.visible = false
				for surface in mesh.mesh.get_surface_count():
					var source: StandardMaterial3D = mesh.get_active_material(surface)
					if source.resource_name.begins_with("Skin"):
						var skin := ShaderMaterial.new()
						skin.shader = preload("res://Presentation/FreeHumanSkinPrevious.gdshader") if treatment == "previous" else preload("res://Presentation/FreeHumanSkin.gdshader")
						skin.set_shader_parameter("albedo_texture", load("res://local-art/free-equipment/" + ("Aksel_Skin_diffuse.png" if treatment == "previous" else skin_texture)))
						skin.set_shader_parameter("skin_normal", load("res://local-art/free-equipment/Aksel_Skin_NRM.png"))
						skin.set_shader_parameter("skin_specular", load("res://local-art/free-equipment/Aksel_Skin_SPEC.png"))
						mesh.material_override = skin
					elif source.resource_name in ["Eye", "Iris", "Cornea"]:
						var eye: StandardMaterial3D = source.duplicate()
						eye.roughness = .04 if source.resource_name == "Cornea" else .36
						eye.metallic_specular = .45 if source.resource_name == "Cornea" else .25
						if source.resource_name == "Cornea": eye.albedo_color.a = .035
						if treatment != "previous" and source.resource_name == "Iris": eye.albedo_color = Color("8d7857")
						mesh.set_surface_override_material(surface, eye)
					elif source.resource_name.begins_with("Hair_"):
						var hair: StandardMaterial3D = source.duplicate()
						hair.anisotropy_enabled = true
						hair.anisotropy = .25
						hair.roughness = .78 if treatment != "previous" else .66
						hair.metallic_specular = .22
						mesh.set_surface_override_material(surface, hair)
			if mesh.name.begins_with("Eyebrow") or mesh.name.begins_with("Eyelash"):
				for surface in mesh.mesh.get_surface_count():
					var brow: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
					brow.roughness = 1.0
					brow.metallic_specular = 0.0
					brow.albedo_color = Color("604632") if mesh.name.begins_with("Eyebrow") and body == "free-equipment" and treatment != "previous" else (Color("24160e") if mesh.name.begins_with("Eyebrow") else Color("140e0a"))
					brow.alpha_scissor_threshold = .38 if body == "free-equipment" and treatment != "previous" else .15
					mesh.set_surface_override_material(surface, brow)
			if mesh.name.begins_with("UO_"):
				equipment.append(mesh)
				for surface in mesh.mesh.get_surface_count():
					var material: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
					material.roughness = .65 if wardrobe == "shirt" else .92
					material.metallic = .35 if wardrobe == "shirt" else 0.
					if wardrobe == "robe": material.albedo_color = Color("7b8caa")
					mesh.set_surface_override_material(surface, material)
	if treatment in ["modern", "skin_v2"] and body == "human":
		var material := ShaderMaterial.new()
		if treatment == "skin_v2":
			material.shader = preload("res://Presentation/ThirdDawnSkin.gdshader")
			material.set_shader_parameter("albedo_texture", load("res://local-art/third-dawn/human-modern-albedo.png"))
			material.set_shader_parameter("skin_normal", load("res://local-art/third-dawn/human-normal-v2.png"))
		else:
			material.shader = preload("res://Presentation/ThirdDawnSkinLegacy.gdshader")
			material.set_shader_parameter("albedo_texture", load("res://local-art/third-dawn/human-modern-albedo.png"))
		for mesh in model.find_children("*", "MeshInstance3D", true, false): mesh.material_override = material
	if wardrobe != "base" and body == "human": attach_garment()
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Walk", "Run"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play("Idle")
	if body == "free-equipment" and treatment != "previous": set_hair(hair_style)

func set_natural_skin(filename: String) -> void:
	if body != "free-equipment" or treatment == "previous": return
	skin_texture = filename
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override is ShaderMaterial:
			mesh.material_override.set_shader_parameter("albedo_texture",load("res://local-art/free-equipment/" + filename))

func set_hair(style: String) -> void:
	if body != "free-equipment" or treatment == "previous": return
	if style not in ["bald","short02","ponytail01"]: return
	hair_style = style
	for mesh in extra_hair: mesh.free()
	extra_hair.clear()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.begins_with("Hair_"): mesh.visible = style == "short02" and wardrobe not in ["hood","monk"]
	if style in ["bald","short02"] or wardrobe in ["hood","monk"]: return
	var source: Node3D = load("res://local-art/free-equipment/hair_%s.glb" % style).instantiate()
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		var original: Skeleton3D = mesh.get_node(mesh.skeleton)
		var bindings: Skin = mesh.skin.duplicate()
		for i in bindings.get_bind_count():
			var name := bindings.get_bind_name(i)
			if name.is_empty(): name = original.get_bone_name(bindings.get_bind_bone(i))
			assert(skeleton.find_bone(name)>=0)
			bindings.set_bind_bone(i,-1)
			bindings.set_bind_name(i,name)
		mesh.skin = bindings
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		mesh.skeleton = NodePath("..")
		for surface in mesh.mesh.get_surface_count():
			var mat: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
			mat.roughness = .78
			mat.metallic_specular = .22
			mat.anisotropy_enabled = true
			mat.anisotropy = .25
			mat.alpha_scissor_threshold = .08
			mesh.set_surface_override_material(surface,mat)
		extra_hair.append(mesh)
	source.free()

func attach_garment() -> void:
	var garment: Node3D = load("res://local-art/third-dawn/gear-%s%s.gltf" % ["smooth-" if refined else "", wardrobe]).instantiate()
	# Named Skin bindings preserve each garment's own inverse bind transforms.
	# The human Skeleton3D supplies all runtime poses; no duplicate animator.
	for mesh: MeshInstance3D in garment.find_children("*", "MeshInstance3D", true, false):
		var source_rig: Skeleton3D = mesh.get_node(mesh.skeleton)
		var bindings: Skin = mesh.skin.duplicate()
		var arrays := mesh.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var used := {}
		for i in indices.size():
			if weights[i] > 0.0: used[indices[i]] = true
		for i in bindings.get_bind_count():
			var bone_name := bindings.get_bind_name(i)
			if bone_name.is_empty(): bone_name = source_rig.get_bone_name(bindings.get_bind_bone(i))
			if skeleton.find_bone(bone_name) < 0:
				assert(not used.has(i), "Unmatched weighted garment bone: " + bone_name)
				bone_name = "__root"
			bindings.set_bind_bone(i, -1)
			bindings.set_bind_name(i, bone_name)
		mesh.skin = bindings
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		mesh.skeleton = NodePath("..")
		mesh.name = "Equipment_" + wardrobe
		var material: StandardMaterial3D = mesh.get_active_material(0).duplicate()
		material.metallic = 0.55 if wardrobe == "shirt" else 0.0
		material.roughness = 0.58 if wardrobe == "shirt" else 0.92
		if wardrobe == "robe": material.albedo_color = Color("7b8caa")
		mesh.material_override = material
		equipment.append(mesh)
	garment.free()

func animate(moving: bool, direction: float, delta: float, speed: float = 2.44) -> void:
	rotation.y = lerp_angle(rotation.y, direction, 1.0 - exp(-10.0 * delta))
	set_clip(("Run" if speed > 3.35 else "Walk") if moving else "Idle")

func set_clip(clip: String) -> void:
	if animator and (current_clip != clip or animator.current_animation != clip):
		current_clip = clip
		animator.play(clip, 0.15)

func reset_presentation() -> void:
	set_clip("Idle")
