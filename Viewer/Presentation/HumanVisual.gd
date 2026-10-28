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
var missing_art: Array[int] = []
var native_cosmetics := {}
var grip: SkeletonModifier3D
var use_modern_motion := true
var motion_profile := {}
var war_mode := false
var native_action := {}
var action_clip := ""
var action_elapsed := 0.
var action_duration := 0.
var action_cycles := 0
var action_reverse := false
var action_holding := false
var action_rate := 1.
var folder: String:
	get: return "res://local-art/free-equipment" + ("-female" if female else "")

static func available(is_female: bool) -> bool:
	return ResourceLoader.exists("res://local-art/free-equipment%s/runtime/body-mask-00.glb" % ("-female" if is_female else ""))

func _ready() -> void:
	model = load(folder+"/equipment-base.glb").instantiate()
	add_child(model)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	animator = model.find_children("*","AnimationPlayer",true,false)[0]
	grip = preload("res://Presentation/WeaponGrip.gd").new()
	skeleton.add_child(grip)
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
	if use_modern_motion: motion_profile=preload("res://Presentation/HumanMotion.gd").install(self)
	if not motion_profile.is_empty():grip.use_prepared_clip(animator.get_animation("Sword_Idle"))
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
	server_equipment=worn.duplicate(true)
	var resolved := Wardrobe.resolve(worn)
	var key := JSON.stringify(resolved)
	if key == appearance_key: return
	appearance_key = key
	unsupported_items.assign(resolved.unsupported)
	missing_art.clear()
	native_cosmetics = {"hair_id":resolved.hair_id,"hair_hue":resolved.hair_hue,"beard_id":resolved.beard_id,"beard_hue":resolved.beard_hue,"hair_family_mapped":resolved.hair_exact_family,"beard_family_mapped":resolved.beard_exact_family}
	for part in parts:
		part.visible = false
		part.get_parent().remove_child(part)
		part.queue_free()
	parts.clear()
	outfit_bits = int(resolved.bits)
	var extra_parts: Dictionary = resolved.pieces.duplicate(true)
	for slot in extra_parts.keys():
		if not ResourceLoader.exists(folder+"/expansion/"+str(extra_parts[slot].asset)+".glb"):
			missing_art.append(int(extra_parts[slot].id))
			extra_parts.erase(slot)
	var gloves: bool = extra_parts.has("hands") and ResourceLoader.exists(folder+"/expansion/body-mask-%02d-gloves.glb" % outfit_bits)
	var masked := outfit_bits!=0 or gloves
	var hide_hair := (outfit_bits&16)!=0 or extra_parts.has("head")
	var hide_beard: bool = extra_parts.has("head") and str(extra_parts.head.asset)=="closed_helmet"
	grip.holding = extra_parts.has("weapon")
	grip.active = true
	var hair_style := str(resolved.hair_style)
	var extra_hair := hair_style not in ["","short"] and ResourceLoader.exists(folder+"/expansion/hair_"+hair_style+".glb")
	if hair_style not in ["","short"] and not extra_hair: missing_art.append(int(resolved.hair_id))
	if not bool(resolved.hair_exact_family): missing_art.append(int(resolved.hair_id))
	if not bool(resolved.beard_exact_family): missing_art.append(int(resolved.beard_id))
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name.begins_with("Body"): mesh.visible = not masked
		if mesh.name.begins_with("Hair_"):
			mesh.visible = bool(resolved.hair) and not hide_hair and not extra_hair
			_shade(mesh,int(resolved.hair_hue),true)
		if mesh.name.begins_with("Cloth_briefs"): mesh.visible = not (outfit_bits&3) and not extra_parts.has("outer_legs")
		if mesh.name.begins_with("Cloth_bra"): mesh.visible = not (outfit_bits&9) and not extra_parts.has("shirt")
	if masked:
		var mask_path := folder+"/expansion/body-mask-%02d-gloves.glb" % outfit_bits if gloves else folder+"/runtime/body-mask-%02d.glb" % outfit_bits
		_attach(mask_path,"Body",true)
	for i in Wardrobe.SLOTS.size():
		if outfit_bits&(1<<i):
			var slot: String = Wardrobe.SLOTS[i]
			_attach(folder+"/runtime/part-"+slot+".glb","Free_")
			var garment := parts[-1]
			var hue := int(resolved.hues.get(slot,0))
			_shade(garment,hue)
	for slot in extra_parts:
		var item: Dictionary = extra_parts[slot]
		_attach(folder+"/expansion/"+str(item.asset)+".glb","Extra_")
		_shade(parts[-1],int(item.hue))
	if extra_hair and not hide_hair:
		_attach(folder+"/expansion/hair_"+hair_style+".glb","Extra_")
		_shade(parts[-1],int(resolved.hair_hue),true)
	for style: String in resolved.beard_styles:
		if hide_beard: continue
		var path := folder+"/expansion/beard_"+style+".glb"
		if ResourceLoader.exists(path):
			_attach(path,"Extra_")
			_shade(parts[-1],int(resolved.beard_hue),true)
		else: missing_art.append(int(resolved.beard_id))
	set_meta("wardrobe_bits",outfit_bits)
	set_meta("unsupported_wearables",unsupported_items)
	set_meta("missing_art",missing_art)
	set_meta("native_cosmetics",native_cosmetics)
	if not action_clip.is_empty():
		var replacement:=clothing_clip(action_clip)
		if replacement!=action_clip:
			var phase:=animator.current_animation_position
			action_clip=replacement
			animator.play(replacement,.1,-action_rate if action_reverse else action_rate,action_reverse);animator.seek(phase,true)
	elif not motion_profile.is_empty() and not current_clip.is_empty():
		var replacement:=clothing_clip(current_clip)
		if replacement!=current_clip:
			var was_playing:=animator.is_playing()
			play(replacement)
			if not was_playing:animator.pause()

func _shade(mesh: MeshInstance3D, hue: int, cosmetic: bool = false) -> void:
	for surface in mesh.mesh.get_surface_count():
		var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if original==null: continue
		mesh.set_surface_override_material(surface,preload("res://Presentation/HumanHue.gd").material(original,hue,cosmetic) if (hue&0x3fff)!=0 or cosmetic else null)

func play(clip: String, blend: float = .15) -> void:
	if not action_clip.is_empty(): return
	clip=clothing_clip(clip)
	if clip == current_clip and animator.current_animation == clip: return
	var previous := current_clip
	var phase := animator.current_animation_position/maxf(.001,animator.current_animation_length)
	current_clip = clip
	animator.play(clip,blend)
	if preload("res://Presentation/HumanActions.gd").locomotion(previous) and preload("res://Presentation/HumanActions.gd").locomotion(clip): animator.seek(fmod(phase,1.)*animator.current_animation_length,true)

func stance_clip(base: String) -> String:
	if motion_profile.is_empty(): return base
	var resolved:=Wardrobe.resolve(server_equipment)
	var prefix: String="Sword_" if resolved.pieces.has("weapon") and (war_mode or base!="Idle") else ("Unarmed_" if war_mode else "")
	var name:=prefix+base
	return clothing_clip(name if animator.has_animation(name) else base)

func clothing_clip(name: String) -> String:
	if motion_profile.is_empty():return name
	var resolved:=Wardrobe.resolve(server_equipment)
	if not ((int(resolved.bits)&8)!=0 or resolved.pieces.has("outer_legs")):return name
	if animator.has_animation(name+"_Cloth"):return name+"_Cloth"
	if name.ends_with("Run") or name.ends_with("Sprint"):
		var prefix: String="Sword_" if name.begins_with("Sword_") else ("Unarmed_" if name.begins_with("Unarmed_") else "")
		return prefix+"Jog"
	return name

var server_equipment: Array=[]
func request_action(request: Dictionary) -> bool:
	native_action=request.duplicate(true)
	set_meta("native_action",native_action)
	var clip:=preload("res://Presentation/HumanActions.gd").resolve(request)
	clip=clothing_clip(clip)
	if motion_profile.is_empty() or clip.is_empty() or not animator.has_animation(clip):
		set_meta("unsupported_action",request.duplicate(true));return false
	if has_meta("unsupported_action"):remove_meta("unsupported_action")
	action_clip=clip;action_elapsed=0.;action_holding=false
	var animation:=animator.get_animation(clip)
	action_duration=preload("res://Presentation/HumanActions.gd").duration(request,animation.length)
	action_reverse=bool(request.get("reverse",false))
	action_rate=animation.length/action_duration
	action_cycles=0 if bool(request.get("repeat",false)) else int(request.get("repeat_count",1))
	animator.speed_scale=1.
	animator.stop(true)
	animator.play(clip,.1,-action_rate if action_reverse else action_rate,action_reverse)
	animator.seek(animation.length if action_reverse else 0.,true)
	return true

func cancel_action() -> void:
	action_clip="";action_holding=false;action_elapsed=0.;animator.speed_scale=1.;current_clip=""

func _process(delta: float) -> void:
	if action_clip.is_empty() or action_holding:return
	action_elapsed+=delta
	if action_elapsed<action_duration:return
	action_elapsed=fmod(action_elapsed,action_duration)
	if action_cycles==1:
		if action_clip=="Death" and not action_reverse:
			animator.seek(animator.get_animation(action_clip).length,true);animator.pause();action_holding=true
		else:cancel_action()
		return
	if action_cycles>1:action_cycles-=1
	animator.stop(true)
	animator.play(action_clip,0.,-action_rate if action_reverse else action_rate,action_reverse)
