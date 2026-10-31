extends Node3D
## Licensed horse art; server body/mount identities remain authoritative.
const PATH := "res://local-art/horses/warhorse.glb"
const REGIONS_PATH := "res://local-art/horses/warhorse-regions.glb"
const Equines = preload("res://Presentation/EquineRegistry.gd")
# Original four-coat API retained for existing reviews and regression fixtures.
const BODIES := {0xc8:0x3e9f,0xe2:0x3ea0,0xe4:0x3ea1,0xcc:0x3ea2}
# Matched to private original stand frames, not inferred from array order.
const COATS := {0xc8:["golden tan",Color("b6a07b")],0xe2:["dapple grey",Color("9c9f9f")],0xe4:["dun",Color("96846a")],0xcc:["dark brown",Color("5e4130")]}
var model: Node3D
var visual_path:=""
var skeleton: Skeleton3D
var animator: AnimationPlayer
var current_clip := "idle"
var native_body := 0xc8
var native_hue := 0
var native_mount_item := 0
var identity_key := ""
var accessory_style := ""
var reins: MeshInstance3D
var rein_mesh := ImmediateMesh.new()
var contact: SkeletonModifier3D
var target_rate:=1.
var lean:=0.
var acceleration:=0.
var last_speed:=0.
var action_remaining:=0.
var dead:=false
static func available() -> bool:return ResourceLoader.exists(PATH)
static func supports_body(body: int) -> bool:return Equines.supports_body(body)
static func mount_item(worn: Array) -> Dictionary:
	for item: Dictionary in worn:
		if int(item.get("layer",0))==25:return item.duplicate(true)
	return {}
static func horse_body(item: int) -> int:
	return Equines.body_for_mount(item)
static func step_seconds(worn: Array, running: bool) -> float:
	return (.10 if running else .20) if not mount_item(worn).is_empty() else (.20 if running else .40)
func _ready() -> void:
	model=load(visual_path if not visual_path.is_empty() else REGIONS_PATH if ResourceLoader.exists(REGIONS_PATH) else PATH).instantiate();add_child(model)
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	animator=model.find_children("*","AnimationPlayer",true,false)[0]
	var library:=animator.get_animation_library("").duplicate(true)
	animator.remove_animation_library("");animator.add_animation_library("",library)
	preload("res://Presentation/HorseMotion.gd").install(animator,skeleton)
	preload("res://Presentation/AnimalPoseLibrary.gd").install(animator,skeleton,"idle","death","eat","lie_down")
	for clip in ["idle","walk","canter","gallop"]:animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	animator.play("idle")
	contact=preload("res://Presentation/HorseContact.gd").new();skeleton.add_child(contact)
	reins=MeshInstance3D.new();reins.name="RiderReins";reins.mesh=rein_mesh;add_child(reins)
	var leather:=StandardMaterial3D.new();leather.albedo_color=Color("30251d");leather.roughness=.85;reins.material_override=leather
	apply_identity(native_body,native_hue,native_mount_item)
	if not visual_path.is_empty():set_meta("rider_ground_drop",(skeleton.global_transform*skeleton.get_bone_global_rest(skeleton.find_bone("saddle_socket"))).origin.y-global_position.y-.09)
func apply_identity(body: int,hue: int,mount_id: int=0) -> void:
	var key:=str(body)+"|"+str(hue)+"|"+str(mount_id)
	if key==identity_key and model!=null:return
	native_body=body;native_hue=hue;native_mount_item=mount_id
	set_meta("native_body",body);set_meta("native_hue",hue)
	var profile:=Equines.profile(body,mount_id)
	if body==0x319 and not visual_path.is_empty():profile={"name":"Skeletal mount / HellSteed","style":"skeleton","colour":Color.WHITE,"change":0.}
	set_meta("coat_name",COATS[body][0] if COATS.has(body) and not bool(profile.get("ethereal",false)) else str(profile.get("name","Unsupported equine")))
	set_meta("equine_profile",profile)
	set_meta("native_mount_item",mount_id)
	if model==null:return
	identity_key=key
	# A legacy client's fallback colour is an artwork default, never a rewrite
	# of the authoritative raw hue retained above and in received packets.
	var effective_hue:=hue if hue!=0 else int(profile.get("default_hue",0))
	model.scale=profile.get("scale",Vector3.ONE)
	contact.hoof_height=.17*model.scale.y
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original==null:continue
			var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/HorseEthereal.gdshader") if bool(profile.get("ethereal",false)) else preload("res://Presentation/HorseSurface.gdshader")
			material.set_shader_parameter("albedo_texture",original.albedo_texture)
			material.set_shader_parameter("normal_texture",original.normal_texture)
			material.set_shader_parameter("orm_texture",original.roughness_texture)
			var dye: Texture2D=null if effective_hue==0x4001 and bool(profile.get("ethereal",false)) else preload("res://Presentation/HumanHue.gd").palette(effective_hue)
			material.set_shader_parameter("hue_palette",dye)
			material.set_shader_parameter("use_hue",dye!=null)
			material.set_shader_parameter("partial_hue",(effective_hue&0x8000)!=0)
			material.set_shader_parameter("coat_colour",profile.get("colour",Color.WHITE))
			material.set_shader_parameter("coat_change",float(profile.get("change",1.)))
			material.set_shader_parameter("grey_coat",bool(profile.get("grey",false)))
			material.set_shader_parameter("magic_glow",float(profile.get("glow",0.)))
			material.set_shader_parameter("magic_colour",profile.get("magic",Color.BLACK))
			material.set_shader_parameter("use_vertex_regions",visual_path.is_empty() and ResourceLoader.exists(REGIONS_PATH))
			mesh.set_surface_override_material(surface,material)
	if accessory_style!=str(profile.get("style","")):
		preload("res://Presentation/EquineAccessories.gd").rebuild(self,profile)
		accessory_style=str(profile.get("style",""))
	preload("res://Presentation/EquineAccessories.gd").tint_spectral_horn(self,profile,effective_hue)
func socket(name: String, rotation_delta: bool = false) -> Transform3D:
	var index:=skeleton.find_bone(name)
	var pose:=skeleton.get_bone_global_pose(index)
	var basis:=pose.basis*skeleton.get_bone_global_rest(index).basis.inverse() if rotation_delta else Basis.IDENTITY
	return skeleton.global_transform*Transform3D(basis.orthonormalized(),pose.origin)
func seat() -> Transform3D:return socket("saddle_socket",true)
func stirrup(left: bool) -> Vector3:
	return socket("stirrup_L" if left else "stirrup_R").origin+seat().basis*Vector3(.025 if left else -.025,-.245,0)
func play_gait(moving: bool,speed: float) -> void:
	var fast:=speed>(2.9 if current_clip in ["canter","gallop"] else 3.6)
	var galloping:=speed>(6.0 if current_clip=="gallop" else 6.8)
	var clip:="idle" if not moving else "gallop" if galloping else "canter" if fast else "walk"
	if current_clip=="lie_down" and not moving:return
	if current_clip=="lie_down" and moving:action_remaining=0.
	if dead or action_remaining>0. or (current_clip=="rear" and animator.is_playing()):return
	contact.enabled=true
	if current_clip!=clip:
		var phase:=animator.current_animation_position/maxf(.001,animator.current_animation_length)
		var travelling:=current_clip in ["walk","canter","gallop"] and clip in ["walk","canter","gallop"]
		current_clip=clip;animator.play(clip,.28 if clip=="idle" else .24)
		if travelling:animator.seek(fmod(phase,1.)*animator.get_animation(clip).length,true)
	target_rate=1. if not moving else clampf(speed/(8.5 if clip=="gallop" else 5. if clip=="canter" else 1.8),.65,1.65)
func motion(speed: float,turn_rate: float,delta: float) -> void:
	lean=lerpf(lean,clampf(turn_rate*minf(speed,6.)*.009,-.065,.065),1.-exp(-6.*delta))
	acceleration=lerpf(acceleration,clampf((speed-last_speed)/maxf(delta,.001)*.0015,-.035,.035),1.-exp(-7.*delta));last_speed=speed
func _process(delta: float) -> void:
	if action_remaining>0.:
		action_remaining=maxf(0.,action_remaining-delta)
		if action_remaining==0. and (dead or current_clip=="lie_down"):animator.seek(animator.current_animation_length,true);animator.pause()
	elif current_clip!="rear" and not dead:animator.speed_scale=lerpf(animator.speed_scale,target_rate,1.-exp(-8.*delta))
	if contact!=null:
		model.rotation.x=lerp_angle(model.rotation.x,-contact.support_tilt.x+acceleration,1.-exp(-7.*delta))
		model.rotation.z=lerp_angle(model.rotation.z,contact.support_tilt.y+lean,1.-exp(-7.*delta))
	if current_clip=="lie_down" or not visual_path.is_empty() and current_clip in ["rear","hit","death"]:fit_action_floor()
	elif not is_zero_approx(model.position.y):model.position.y=lerpf(model.position.y,0.,1.-exp(-12.*delta))
func fit_action_floor() -> void:
	if visual_path.is_empty() and current_clip!="lie_down":return
	var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
	var bounds:=preload("res://Presentation/SkinGeometry.gd").deformed_bounds(mesh,skeleton)
	# Preserve airborne gallop clearance. Reactions and the held corpse must
	# rest on the actor's actual support level instead of cutting into it.
	if bounds.position.is_finite():model.position.y+=global_position.y-bounds.position.y
func _physics_process(_delta: float) -> void:
	if contact!=null:contact.sample(get_world_3d().direct_space_state,global_position)
func rear() -> void:
	if dead:return
	current_clip="rear";animator.speed_scale=1.;animator.play("rear",.15)
func receive_action(request: Dictionary) -> bool:
	var clip:=""
	if str(request.get("protocol",""))=="classic":clip=str({0:"walk",1:"gallop",2:"idle",3:"eat",5:"rear",6:"rear",7:"rear",8:"death",9:"idle",10:"idle",11:"lie_down",12:"death"}.get(int(request.get("action",-1)),""))
	elif str(request.get("protocol",""))=="new":clip=str({0:"rear",3:"death",4:"hit"}.get(int(request.get("type",-1)),""))
	if clip.is_empty():set_meta("unsupported_action",request.duplicate(true));return false
	if dead and clip!="death":return false
	current_clip=clip;dead=clip=="death";contact.enabled=not dead and clip!="lie_down"
	var duration:=preload("res://Presentation/HumanActions.gd").duration(request,animator.get_animation(clip).length)
	action_remaining=duration;animator.speed_scale=1.;animator.play(clip,.12,animator.get_animation(clip).length/duration)
	set_meta("native_action",request.duplicate(true));return true
func set_reins(left: Vector3,right: Vector3) -> void:
	rein_mesh.clear_surfaces()
	var mouth:=socket("mouth_socket").origin
	rein_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		var a:=to_local(mouth+global_basis.x*side*.095);var b:=to_local(left if side>0 else right)
		for step in 12:
			var t:=float(step)/12.;var u:=float(step+1)/12.
			var p:=a.lerp(b,t)+Vector3.DOWN*.10*sin(PI*t);var q:=a.lerp(b,u)+Vector3.DOWN*.10*sin(PI*u)
			var axis:=(q-p).normalized();var across:=axis.cross(Vector3.UP).normalized()*.004;var vertical:=axis.cross(across).normalized()*.004
			for i in 6:
				var angle:=TAU*i/6.;var next:=TAU*(i+1)/6.;var x:=across*cos(angle)+vertical*sin(angle);var y:=across*cos(next)+vertical*sin(next)
				for point in [p+x,q+x,q+y,p+x,q+y,p+y]:rein_mesh.surface_add_vertex(point)
	rein_mesh.surface_end()
