extends Node3D
## Licensed horse art; server body/mount identities remain authoritative.
const PATH := "res://local-art/horses/warhorse.glb"
const BODIES := {0xc8:0x3e9f,0xe2:0x3ea0,0xe4:0x3ea1,0xcc:0x3ea2}
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var current_clip := "idle"
var native_body := 0xc8
var native_hue := 0
var identity_key := ""
var reins: MeshInstance3D
var rein_mesh := ImmediateMesh.new()
static func available() -> bool:return ResourceLoader.exists(PATH)
static func mount_item(worn: Array) -> Dictionary:
	for item: Dictionary in worn:
		if int(item.get("layer",0))==25:return item.duplicate(true)
	return {}
static func horse_body(item: int) -> int:
	for body: int in BODIES:
		if BODIES[body]==item:return body
	return 0
static func step_seconds(worn: Array, running: bool) -> float:
	return (.10 if running else .20) if not mount_item(worn).is_empty() else (.20 if running else .40)
func _ready() -> void:
	model=load(PATH).instantiate();add_child(model)
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	animator=model.find_children("*","AnimationPlayer",true,false)[0]
	var library:=animator.get_animation_library("").duplicate(true)
	animator.remove_animation_library("");animator.add_animation_library("",library)
	for clip in ["idle","walk","canter"]:animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	animator.play("idle")
	reins=MeshInstance3D.new();reins.name="RiderReins";reins.mesh=rein_mesh;add_child(reins)
	var leather:=StandardMaterial3D.new();leather.albedo_color=Color("30251d");leather.roughness=.85;reins.material_override=leather
	apply_identity(native_body,native_hue)
func apply_identity(body: int,hue: int) -> void:
	var key:=str(body)+"|"+str(hue)
	if key==identity_key and model!=null:return
	native_body=body;native_hue=hue
	set_meta("native_body",body);set_meta("native_hue",hue)
	if model==null:return
	identity_key=key
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original==null:continue
			var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/HorseSurface.gdshader")
			material.set_shader_parameter("albedo_texture",original.albedo_texture)
			material.set_shader_parameter("normal_texture",original.normal_texture)
			material.set_shader_parameter("orm_texture",original.roughness_texture)
			material.set_shader_parameter("hue_palette",preload("res://Presentation/HumanHue.gd").palette(hue))
			material.set_shader_parameter("use_hue",preload("res://Presentation/HumanHue.gd").palette(hue)!=null)
			material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
			mesh.set_surface_override_material(surface,material)
func socket(name: String, rotation_delta: bool = false) -> Transform3D:
	var index:=skeleton.find_bone(name)
	var pose:=skeleton.get_bone_global_pose(index)
	var basis:=pose.basis*skeleton.get_bone_global_rest(index).basis.inverse() if rotation_delta else Basis.IDENTITY
	return skeleton.global_transform*Transform3D(basis.orthonormalized(),pose.origin)
func seat() -> Transform3D:return socket("saddle_socket",true)
func stirrup(left: bool) -> Vector3:
	return socket("stirrup_L" if left else "stirrup_R").origin+seat().basis*Vector3(.025 if left else -.025,-.245,0)
func play_gait(moving: bool,speed: float) -> void:
	var clip:="idle" if not moving else "canter" if speed>3.2 else "walk"
	if current_clip=="rear" and animator.is_playing():return
	if current_clip!=clip:
		current_clip=clip;animator.play(clip,.18)
	animator.speed_scale=1. if not moving else clampf(speed/(5. if clip=="canter" else 1.8),.65,1.65)
func rear() -> void:
	current_clip="rear";animator.speed_scale=1.;animator.play("rear",.15)
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
