extends "res://Presentation/OstardVisual.gd"
## Runtime adapter around the separately prepared source-rig creature.
var native_body:=0xd2
var native_hue:=0
var native_mount_item:=0
var current_clip:="Idle"
var lean:=0.
var dead:=false
var action_remaining:=0.
var reins: MeshInstance3D
var rein_mesh:=ImmediateMesh.new()
var seat_offset:=Vector3.ZERO
var seat_bone:=-1
var mouth_offset:=Vector3.ZERO
var mouth_bone:=-1
var pack_fitting: Node3D
var contact: SkeletonModifier3D
var source_model_basis:=Basis.IDENTITY
func _ready() -> void:
	super._ready()
	seat_bone=find_source_bone("spine1");mouth_bone=find_source_bone("head")
	# Calibrate local bone offsets against the imported bind geometry, not a
	# moving idle frame. World-facing seat basis is independent of source Z-up.
	var saddle:=Vector3(0,1.24,-.05)
	var mouth:=Vector3(0,1.85,.70)
	if kind=="kirin":saddle=Vector3(0,1.30,-.03);mouth=Vector3(.04,1.46,1.55)
	elif kind.begins_with("llama"):saddle=Vector3(0,1.22,.35);mouth=Vector3(0,1.51,1.54)
	set_meta("rider_ground_drop",saddle.y-.09)
	seat_offset=skeleton.get_bone_global_rest(seat_bone).affine_inverse()*(skeleton.global_transform.affine_inverse()*(global_transform*saddle))
	mouth_offset=skeleton.get_bone_global_rest(mouth_bone).affine_inverse()*(skeleton.global_transform.affine_inverse()*(global_transform*mouth))
	reins=MeshInstance3D.new();reins.mesh=rein_mesh;reins.name="OstardReins";add_child(reins)
	var leather:=StandardMaterial3D.new();leather.albedo_color=Color("30251d");leather.roughness=.9;reins.material_override=leather
	if kind=="kirin" or kind.begins_with("llama"):build_eyes()
	contact=preload("res://Presentation/SourceMountContact.gd").new();skeleton.add_child(contact)
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],kind=="kirin" or kind.begins_with("llama"))
	source_model_basis=model.basis
func _physics_process(_delta: float) -> void:
	if contact!=null:
		contact.sample(get_world_3d().direct_space_state,global_position)
		if contact.enabled and not contact.contacts.is_empty():
			var normal:=Vector3.ZERO
			for hit: Dictionary in contact.contacts.values():normal+=hit.normal
			normal=(global_basis.inverse()*normal.normalized()).normalized()
			var slope:=Basis.from_euler(Vector3(clampf(atan2(normal.z,normal.y),-.2,.2),0.,clampf(-atan2(normal.x,normal.y),-.15,.15)))
			model.basis=model.basis.slerp(slope*source_model_basis,1.-exp(-8.*_delta))
func build_eyes() -> void:
	var attachment:=BoneAttachment3D.new();attachment.bone_name=skeleton.get_bone_name(mouth_bone);skeleton.add_child(attachment)
	var rest:=skeleton.global_transform*skeleton.get_bone_global_rest(mouth_bone)
	for side in [-1.,1.]:
		var point:=Vector3(side*.105,1.63,1.26)
		if kind=="kirin":point=Vector3(.038+side*.096,1.72,1.28)
		var mesh:=MeshInstance3D.new();mesh.name="AuthoredEye";var sphere:=SphereMesh.new();sphere.radius=.023;sphere.height=.046;sphere.radial_segments=16;sphere.rings=8;mesh.mesh=sphere
		var material:=StandardMaterial3D.new();material.albedo_color=Color("24180c") if kind=="kirin" else Color("140f0b");material.roughness=.21;material.metallic_specular=.65;mesh.material_override=material
		attachment.add_child(mesh);mesh.transform=rest.affine_inverse()*Transform3D(global_basis.scaled(Vector3(.45,1.,1.)),global_transform*point)
func find_source_bone(suffix: String) -> int:
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).replace("_","")=="bip01 "+suffix:return i
	return -1
func apply_identity(body: int,value: int,item: int=0) -> void:
	native_body=body;native_hue=value;native_mount_item=item;set_hue(value)
	set_meta("native_body",body);set_meta("native_hue",value);set_meta("native_mount_item",item)
	set_meta("equine_profile",{"style":kind,"ethereal":kind in ["ethereal","llama_ethereal"]})
	if body==0x124 and pack_fitting==null:build_pack()
	elif body!=0x124 and pack_fitting!=null:pack_fitting.free();pack_fitting=null
func build_pack() -> void:
	var attachment:=BoneAttachment3D.new();attachment.bone_name=skeleton.get_bone_name(seat_bone);skeleton.add_child(attachment);pack_fitting=attachment
	var rest:=skeleton.global_transform*skeleton.get_bone_global_rest(seat_bone)
	var leather:=StandardMaterial3D.new();leather.albedo_color=Color("5b3e27");leather.roughness=.88
	var brass:=StandardMaterial3D.new();brass.albedo_color=Color("82724d");brass.metallic=.7;brass.roughness=.55
	for side in [-1.,1.]:
		for piece in [[Vector3(.30,.48,.65),Vector3(side*.43,.94,.35),leather],[Vector3(.34,.10,.69),Vector3(side*.43,1.19,.35),leather],[Vector3(.02,.28,.06),Vector3(side*.59,1.05,.35),brass]]:
			var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=piece[0];mesh.mesh=box;mesh.material_override=piece[2];attachment.add_child(mesh)
			mesh.transform=rest.affine_inverse()*Transform3D(global_basis,global_transform*Vector3(piece[1]))
func anchor(bone: int,offset: Vector3) -> Transform3D:
	var pose:=skeleton.get_bone_global_pose(bone)
	var delta:=skeleton.global_basis*pose.basis*skeleton.get_bone_global_rest(bone).basis.inverse()*skeleton.global_basis.inverse()
	var facing:=global_basis*(model.basis*source_model_basis.inverse()).orthonormalized()
	return Transform3D(delta.orthonormalized()*facing,skeleton.to_global(pose*offset))
func seat() -> Transform3D:return anchor(seat_bone,seat_offset)
func stirrup(left: bool) -> Vector3:return seat()*Vector3(.29 if left else -.29,-.62,.12)
func socket(_name: String,_rotation_delta: bool=false) -> Transform3D:return anchor(mouth_bone,mouth_offset)
func motion(speed: float,turn_rate: float,delta: float) -> void:
	lean=lerpf(lean,clampf(turn_rate*minf(speed,6.)*.009,-.065,.065),1.-exp(-6.*delta))
func play_gait(moving: bool,speed: float) -> void:
	if dead or action_remaining>0.:return
	var clip:="Idle" if not moving else "Run" if speed>3.6 else "Walk"
	if current_clip!=clip:current_clip=clip;play(clip,.18)
	animator.speed_scale=clampf(speed/(5.5 if clip=="Run" else 1.8),.65,1.65) if moving else 1.
func _process(delta: float) -> void:
	if action_remaining>0.:
		action_remaining=maxf(0.,action_remaining-delta)
		if action_remaining==0. and dead:animator.seek(animator.current_animation_length,true);animator.pause()
func receive_action(request: Dictionary) -> bool:
	var clip:=""
	# ClassicUO LowAnimationGroup: 9/10 are fidgets, never hit reactions.
	if str(request.get("protocol",""))=="classic":clip=str({0:"Walk",1:"Run",2:"Idle",5:"Attack",6:"Attack",7:"Attack",8:"Death",9:"Fidget",10:"Fidget",12:"Death"}.get(int(request.get("action",-1)),""))
	elif str(request.get("protocol",""))=="new":clip=str({0:"Attack",3:"Death",4:"Hit"}.get(int(request.get("type",-1)),""))
	if clip.is_empty() or dead and clip!="Death":set_meta("unsupported_action",request.duplicate(true));return false
	current_clip=clip;dead=clip=="Death"
	contact.enabled=not dead
	var duration:=preload("res://Presentation/HumanActions.gd").duration(request,animator.get_animation(clip).length)
	action_remaining=duration;animator.play(clip,.12,animator.get_animation(clip).length/duration)
	set_meta("native_action",request.duplicate(true));return true
func set_reins(left: Vector3,right: Vector3) -> void:
	rein_mesh.clear_surfaces();rein_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		var a:=to_local(socket("mouth").origin+global_basis.x*side*.075);var b:=to_local(left if side>0 else right)
		for step in 12:
			var t:=float(step)/12.;var u:=float(step+1)/12.
			var p:=a.lerp(b,t)+Vector3.DOWN*.08*sin(PI*t);var q:=a.lerp(b,u)+Vector3.DOWN*.08*sin(PI*u)
			var across:=(q-p).cross(Vector3.UP).normalized()*.004
			for point in [p-across,q-across,q+across,p-across,q+across,p+across]:rein_mesh.surface_add_vertex(point)
	rein_mesh.surface_end()
