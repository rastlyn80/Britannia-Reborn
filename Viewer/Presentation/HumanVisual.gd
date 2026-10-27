extends Node3D
## Licensed male/female body and individual garments on one animated skeleton.
const Wardrobe = preload("res://Presentation/HumanWardrobe.gd")
var female := false
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var skin: ShaderMaterial
var parts: Array[MeshInstance3D] = []
var outfit_bits := -1
var appearance_key := ""
var unsupported_items: Array[int] = []
var skin_hue := 1002
var current_clip := "Idle"
var folder: String:
	get: return "res://local-art/free-equipment" + ("-female" if female else "")

static func available(is_female: bool) -> bool:
	return ResourceLoader.exists("res://local-art/free-equipment%s/runtime/body-mask-00.glb" % ("-female" if is_female else ""))

func _ready() -> void:
	model = load(folder+"/equipment-base.glb").instantiate()
	add_child(model)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	animator = model.find_children("*","AnimationPlayer",true,false)[0]
	skin = ShaderMaterial.new()
	skin.shader = preload("res://Presentation/FreeHumanSkin.gdshader")
	if get_viewport().transparent_bg:
		var portrait_shader := Shader.new()
		portrait_shader.code = "#define HUMAN_NO_SSS\n"+skin.shader.code
		skin.shader = portrait_shader
	skin.set_shader_parameter("skin_normal",load("res://local-art/free-equipment/Aksel_Skin_NRM.png"))
	skin.set_shader_parameter("skin_specular",load("res://local-art/free-equipment/Aksel_Skin_SPEC.png"))
	if female: skin.set_shader_parameter("normal_strength",.10)
	set_skin(1002)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name.begins_with("Eyelash"): mesh.visible = false
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null: continue
			if original.resource_name.begins_with("Skin"):
				mesh.material_override = skin
			elif original.resource_name in ["Eye","Iris","Cornea"]:
				var eye: StandardMaterial3D = original.duplicate()
				eye.roughness = .04 if original.resource_name == "Cornea" else .36
				eye.metallic_specular = .45 if original.resource_name == "Cornea" else .25
				if original.resource_name == "Iris": eye.albedo_color = Color("8d7857")
				if original.resource_name == "Cornea": eye.albedo_color.a = .035
				mesh.set_surface_override_material(surface,eye)
			elif original.resource_name.begins_with("Hair_") or mesh.name.begins_with("Eyebrow"):
				var mat: StandardMaterial3D = original.duplicate()
				mat.roughness = .78
				mat.metallic_specular = .22
				if mesh.name.begins_with("Eyebrow"):
					mat.albedo_color = Color("604632")
					mat.alpha_scissor_threshold = .38
					mat.metallic_specular = 0.
				mesh.set_surface_override_material(surface,mat)
	for clip in ["Idle","Walk","Run"]: animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play("Idle")
	set_equipment([])

func set_skin(hue: int) -> void:
	skin_hue = hue
	if skin == null: return
	# Three authored presets approximate native human hue groups deterministically.
	var shade := clampi(((hue&0x3fff)-1002)/19,0,2)
	var names := ["young_lightskinned_female_diffuse.png","young_lightskinned_female_diffuse3.png","young_darkskinned_female_diffuse.png"] if female else ["young_lightskinned_male_diffuse2.png","young_lightskinned_male_diffuse3.png","young_darkskinned_male_diffuse.png"]
	skin.set_shader_parameter("albedo_texture",load("res://local-art/free-equipment/"+names[shade]))

func _attach(path: String, prefix: String, body_part: bool = false) -> void:
	var source: Node3D = load(path).instantiate()
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		if not mesh.name.begins_with(prefix): continue
		var source_rig: Skeleton3D = mesh.get_node(mesh.skeleton)
		var bindings: Skin = mesh.skin.duplicate()
		for i in bindings.get_bind_count():
			var bone := bindings.get_bind_name(i)
			if bone.is_empty(): bone = source_rig.get_bone_name(bindings.get_bind_bone(i))
			assert(skeleton.find_bone(bone)>=0,"Incompatible human garment bone")
			bindings.set_bind_bone(i,-1)
			bindings.set_bind_name(i,bone)
		mesh.skin = bindings
		if body_part: mesh.material_override = skin
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
		mesh.transform = Transform3D.IDENTITY
		parts.append(mesh)
	source.free()

func set_equipment(worn: Array) -> void:
	if model == null: return
	var resolved := Wardrobe.resolve(worn)
	var key := JSON.stringify(resolved)
	if key == appearance_key: return
	appearance_key = key
	unsupported_items.assign(resolved.unsupported)
	for part in parts:
		part.visible = false
		part.get_parent().remove_child(part)
		part.queue_free()
	parts.clear()
	outfit_bits = int(resolved.bits)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name.begins_with("Body"): mesh.visible = outfit_bits == 0
		if mesh.name.begins_with("Hair_"): mesh.visible = bool(resolved.hair) and not (outfit_bits&16)
		if mesh.name.begins_with("Cloth_briefs"): mesh.visible = not (outfit_bits&3)
		if mesh.name.begins_with("Cloth_bra"): mesh.visible = not (outfit_bits&9)
	if outfit_bits:
		_attach(folder+"/runtime/body-mask-%02d.glb" % outfit_bits,"Body",true)
	for i in Wardrobe.SLOTS.size():
		if outfit_bits&(1<<i):
			var slot: String = Wardrobe.SLOTS[i]
			_attach(folder+"/runtime/part-"+slot+".glb","Free_")
			var garment := parts[-1]
			var hue := int(resolved.hues.get(slot,0))
			if hue&0x3fff:
				var tint: Color = preload("res://Network/Artwork.gd").color(hue,Color.WHITE)
				for surface in garment.mesh.get_surface_count():
					var material: StandardMaterial3D = garment.get_active_material(surface).duplicate()
					material.albedo_color = Color(lerpf(.35,1.,tint.r),lerpf(.35,1.,tint.g),lerpf(.35,1.,tint.b))
					garment.set_surface_override_material(surface,material)
	set_meta("wardrobe_bits",outfit_bits)
	set_meta("unsupported_wearables",unsupported_items)

func play(clip: String, blend: float = .15) -> void:
	if clip == current_clip and animator.current_animation == clip: return
	var previous := current_clip
	var phase := animator.current_animation_position/maxf(.001,animator.current_animation_length)
	current_clip = clip
	animator.play(clip,blend)
	if previous in ["Walk","Run"] and clip in ["Walk","Run"]: animator.seek(fmod(phase,1.)*animator.current_animation_length,true)
