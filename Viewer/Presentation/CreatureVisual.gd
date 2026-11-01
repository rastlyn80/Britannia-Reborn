extends "res://Presentation/OstardVisual.gd"
## Loose source-rig creatures. Native gameplay and world transforms stay outside.
var entry: Dictionary={}
var native_body:=0
var native_hue:=0
var native_mount_item:=0
var current_clip:="Idle"
var action_remaining:=0.
var dead:=false
var lean:=0.
var contact: SkeletonModifier3D
var source_model_basis:=Basis.IDENTITY
var action_profile:="monster"
var default_model_scale:=Vector3.ONE
var death_flashes: Array[MeshInstance3D]=[]
var water_phase:=0.
func _init() -> void:asset_folder="creatures"
func model_resource_path(folder: String,asset_kind: String) -> String:
	return str(entry.get("assets",{}).get(treatment,super.model_resource_path(folder,asset_kind)))
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null:return
	if treatment=="modern" and entry.get("surface_kind","")=="water_pbr":
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,preload("res://Presentation/WaterElementalMaterial.gd").build(value,water_phase))
	if treatment=="modern" and entry.get("surface_kind","")=="feather_pbr":
		var partial_mask: Texture2D=load(str(entry.partial_hue_mask)) if entry.has("partial_hue_mask") else null
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/CreatureFeatherMaterial.gd").build(source,value,detail,partial_mask))
	if treatment=="modern" and not entry.get("mineral_surface",{}).is_empty():
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():mesh.set_surface_override_material(surface,preload("res://Presentation/CreatureMineralMaterial.gd").build(entry.mineral_surface,value,detail))
	if treatment=="modern" and entry.get("surface_kind","")=="marine_pbr":
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/CreatureMarineMaterial.gd").build(source,value,detail))
	death_flashes.clear()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name!="RecoveredFlash":continue
		var flash:=ShaderMaterial.new();flash.shader=preload("res://Presentation/CreatureFlashSurface.gdshader")
		flash.set_shader_parameter("albedo_texture",load("res://local-art/creatures/"+str(entry.source_alpha_texture)))
		var rect: Array=entry.get("death_effect",{}).get("uv_rect",[0.,0.,1.,1.])
		flash.set_shader_parameter("uv_rect",Vector4(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])))
		var palette:=preload("res://Presentation/HumanHue.gd").palette(value)
		flash.set_shader_parameter("hue_palette",palette);flash.set_shader_parameter("use_hue",palette!=null)
		mesh.material_override=flash;mesh.visible=false;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.set_meta("source_death_flash",true);death_flashes.append(mesh)
	if treatment!="modern" or str(entry.get("source_alpha_texture","")).is_empty():return
	var opacity:=load("res://local-art/creatures/"+str(entry.source_alpha_texture)) as Texture2D
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("source_death_flash"):continue
		for surface in mesh.mesh.get_surface_count():
			var previous:=mesh.get_surface_override_material(surface) as ShaderMaterial
			if previous==null:continue
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			var dust:=kind=="spirits_blade_spirit" and source!=null and source.resource_name.contains("dust")
			var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureDustSurface.gdshader") if dust else preload("res://Presentation/CreatureCutoutSurface.gdshader")
			for parameter in ["albedo_texture","hue_palette","use_hue","partial_hue","detail_strength"]:
				material.set_shader_parameter(parameter,previous.get_shader_parameter(parameter))
			material.set_shader_parameter("source_alpha_texture",opacity)
			material.set_shader_parameter("metallic_strength",source.metallic if source!=null else 0.)
			if entry.get("movement_mode","")=="native_waterline":material.set_shader_parameter("wetness",.7)
			mesh.set_surface_override_material(surface,material)
func _ready() -> void:
	kind=str(entry.kind)
	action_profile=str(entry.get("profile","monster"))
	if str(entry.get("family","")) in ["rodents","walrus"]:feeding_neck_angle=.1;feeding_head_angle=.04
	super._ready()
	contact=preload("res://Presentation/BirdGroundSupport.gd").new() if entry.get("movement_mode","")=="ground_plane" else preload("res://Presentation/SourceMountContact.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true
	contact.iterations=1 if str(entry.get("family","")) in ["bruins","walrus"] else 3
	if kind in ["dragons_dragon_asian","dragons_wyvern"]:
		contact.align_skinned_soles=true;contact.iterations=5
	var quadruped:=str(entry.get("profile",""))=="animal" and str(entry.get("family",""))!="walrus" or str(entry.get("family","")) in ["rodents","lizards","dragons","centaurs"]
	# A floating actor can have real leg bones (efreet's crossed legs). They
	# remain animated limbs, not stance feet to drag down onto the terrain.
	if str(entry.get("movement_mode","")) not in ["source_hover","native_waterline"]:contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],quadruped)
	source_model_basis=model.basis.orthonormalized()
	default_model_scale=model.scale
	set_meta("source_creature",entry.duplicate(true))
	if entry.has("camera_height"):set_meta("camera_height",float(entry.camera_height))
	if entry.has("pick_bounds"):
		var record: Dictionary=entry.pick_bounds;var p: Array=record.position;var s: Array=record.size
		set_meta("pick_bounds",AABB(Vector3(float(p[0]),float(p[1]),float(p[2])),Vector3(float(s[0]),float(s[1]),float(s[2]))))
func apply_identity(body: int,value: int,item: int=0) -> void:
	native_body=body;native_hue=value;native_mount_item=item;set_hue(value)
	for identity: Dictionary in entry.get("bodies",[]):
		if int(identity.body)==body:
			action_profile=str(identity.get("native_profile",entry.get("profile","monster")))
			var base: Array=entry.bodies[0].scale;var target: Array=identity.scale
			model.scale=default_model_scale*Vector3(float(target[0])/float(base[0]),float(target[1])/float(base[1]),float(target[2])/float(base[2]))
			break
	set_meta("native_body",body);set_meta("native_hue",value)
func motion(_speed: float,_turn_rate: float,_delta: float) -> void:pass
func play_gait(moving: bool,speed: float) -> void:
	if current_clip=="LieDown" and moving:action_remaining=0.
	if dead or action_remaining>0.:return
	var clip:="Idle" if not moving else "Run" if speed>3.6 else "Walk"
	if current_clip=="LieDown" and not moving:return
	contact.enabled=true
	if current_clip!=clip:current_clip=clip;play(clip,.18)
	animator.speed_scale=clampf(speed/(5.5 if clip=="Run" else 1.8),.65,1.65) if moving else 1.
func _process(delta: float) -> void:
	update_death_effect()
	if entry.get("surface_kind","")=="water_pbr" and (not dead or action_remaining>0.):
		water_phase+=delta
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():mesh.get_active_material(surface).set_shader_parameter("water_time",water_phase)
	if entry.get("surface_kind","")=="feather_pbr" or entry.has("head_bone"):
		var head:=skeleton.find_bone(str(entry.get("head_bone","head")))
		if head>=0:set_meta("nameplate_height",to_local(skeleton.to_global(skeleton.get_bone_global_pose(head).origin)).y+.08)
	if action_remaining>0.:
		action_remaining=maxf(0.,action_remaining-delta)
		if action_remaining==0. and (dead or current_clip=="LieDown"):animator.seek(animator.current_animation_length,true);animator.pause()
func update_death_effect() -> void:
	if death_flashes.is_empty():return
	var showing:=animator.assigned_animation in ["Death","Death2"]
	var phase:=clampf(animator.current_animation_position/maxf(.001,animator.current_animation_length),0.,1.) if showing else 0.
	for mesh in death_flashes:
		mesh.visible=showing and phase>0. and phase<1.
		mesh.material_override.set_shader_parameter("gain",sin(PI*phase)*sin(PI*phase))
func _physics_process(delta: float) -> void:
	if contact==null:return
	if entry.get("movement_mode","")=="native_waterline":return
	contact.sample(get_world_3d().direct_space_state,global_position)
	if contact.enabled and not contact.contacts.is_empty():
		if not contact.stance_gaps.is_empty():
			var gap: float=contact.stance_gaps.max()
			if gap>.05 or model.position.y<-.001:
				var support_offset:=clampf(model.position.y+.025-gap,-.12,0.)
				model.position.y=lerpf(model.position.y,support_offset,1.-exp(-8.*delta))
		var normal:=Vector3.ZERO
		for hit: Dictionary in contact.contacts.values():normal+=hit.normal
		normal=(global_basis.inverse()*normal.normalized()).normalized()
		var slope:=Basis.from_euler(Vector3(clampf(atan2(normal.z,normal.y),-.2,.2),0.,clampf(-atan2(normal.x,normal.y),-.15,.15)))
		# Terrain tilt must preserve the native body's configured proportions.
		var current_scale:=model.scale
		model.basis=model.basis.orthonormalized().slerp(slope*source_model_basis,1.-exp(-8.*delta)).scaled_local(current_scale)
func receive_action(request: Dictionary) -> bool:
	var clip:=""
	if str(request.get("protocol",""))=="classic":
		var action:=int(request.get("action",-1))
		if action_profile=="animal":
			clip=str({0:"Walk",1:"Run",2:"Idle",3:"Eat",4:"Alert",5:"Attack",6:"Attack2",7:"Hit",8:"Death",9:"Fidget",10:"Fidget",11:"LieDown",12:"Death2"}.get(action,""))
		elif action_profile=="sea":
			clip=str({0:"Walk",1:"Run",2:"Idle",3:"Fidget",4:"Fidget2",5:"Attack",6:"Attack2",7:"Hit",8:"Death",12:"Attack"}.get(action,""))
		else:
			clip=str({0:"Walk",1:"Idle",2:"Death",3:"Death2",4:"Attack",5:"Attack2",6:"Attack3",7:"AttackBow",8:"AttackXBow",9:"AttackThrow",10:"Hit",11:"Pillage",12:"Cast",13:"Hit",14:"Cast3",15:"Hit",16:"Hit",17:"Fidget",18:"Fidget",19:"Fly",20:"Land",21:"Death"}.get(action,""))
		clip=str(entry.get("classic_action_categories",{}).get(str(action),clip))
	elif str(request.get("protocol",""))=="new":clip=str({0:"Attack",3:"Death",4:"Hit",11:"Cast"}.get(int(request.get("type",-1)),""))
	if str(request.get("protocol",""))=="new":clip=str(entry.get("new_action_categories",{}).get(str(int(request.get("type",-1))),clip))
	if action_profile=="sea" and str(request.get("protocol",""))=="new" and int(request.get("type",-1))==0 and (int(request.get("mode",0))&1)!=0:clip="Attack2"
	var replacement:={"Attack2":"Attack","Attack3":"Attack","Death2":"Death","Alert":"Fidget","Fidget2":"Fidget"}
	if not animator.has_animation(clip) and replacement.has(clip):clip=replacement[clip]
	if clip.is_empty() or not animator.has_animation(clip) or dead and clip not in ["Death","Death2"]:
		set_meta("unsupported_action",request.duplicate(true));return false
	current_clip=clip;dead=clip in ["Death","Death2"]
	contact.enabled=not dead and clip not in ["LieDown","Fly","HitInAir","TakeOff"]
	var duration:=preload("res://Presentation/HumanActions.gd").duration(request,animator.get_animation(clip).length)
	action_remaining=duration;animator.play(clip,.12,animator.get_animation(clip).length/duration)
	set_meta("native_action",request.duplicate(true));return true
