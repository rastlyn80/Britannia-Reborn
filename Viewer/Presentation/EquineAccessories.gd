extends RefCounted
## Original procedural fittings; positions in the unchanged horse's bind space.
## Bone attachments follow the same rig as its skin and animated rider sockets.
static func material(colour: Color,metallic: float=0.,glow: float=0.) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new();mat.albedo_color=colour;mat.roughness=.8 if metallic==0. else .42;mat.metallic=metallic
	if glow>0.:mat.emission_enabled=true;mat.emission=colour;mat.emission_energy_multiplier=glow
	return mat
static func attach(horse: Node3D,bone: String,node: Node3D,point: Vector3) -> void:
	var socket:=BoneAttachment3D.new();socket.name=bone+"_Fitting";socket.bone_name=bone;horse.skeleton.add_child(socket)
	socket.set_meta("equine_fitting",true);socket.set_meta("bind_point",point)
	var index: int=horse.skeleton.find_bone(bone)
	var rest: Transform3D=horse.skeleton.global_transform*horse.skeleton.get_bone_global_rest(index)
	node.transform=rest.affine_inverse()*horse.model.global_transform*Transform3D(Basis.IDENTITY,point)
	socket.add_child(node)
static func horn() -> MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=28;var sides:=24;var length:=.43
	for ring in rings:
		for side in sides:
			var corners: Array[Vector3]=[]
			for pair in [[ring,side],[ring+1,side],[ring+1,side+1],[ring,side+1]]:
				var t:=float(pair[0])/rings;var a:=TAU*float(pair[1])/sides
				var radius:=.043*pow(1.-t,.85)*(1.+.12*sin(a+t*TAU*7.))
				corners.append(Vector3(radius*cos(a),length*t,radius*sin(a)))
			for i in [0,1,2,0,2,3]:surface.add_vertex(corners[i])
	surface.generate_normals();var mesh:=MeshInstance3D.new();mesh.name="SpiralHorn";mesh.mesh=surface.commit();mesh.material_override=material(Color("dfd0a2"),.32)
	mesh.quaternion=Quaternion(Vector3.UP,Vector3(0,.86,.51).normalized());return mesh
static func bag() -> MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Eight-corner leather pannier, with chamfered sides rather than a cube.
	var outline: Array[Vector2]=[Vector2(-.10,-.30),Vector2(.10,-.30),Vector2(.15,-.25),Vector2(.15,.25),Vector2(.10,.30),Vector2(-.10,.30),Vector2(-.15,.25),Vector2(-.15,-.25)]
	for i in 8:
		var a:=outline[i];var b:=outline[(i+1)%8]
		for point in [Vector3(a.x,-.23,a.y),Vector3(b.x,-.23,b.y),Vector3(b.x,.23,b.y),Vector3(a.x,-.23,a.y),Vector3(b.x,.23,b.y),Vector3(a.x,.23,a.y)]:surface.add_vertex(point)
		for top in [false,true]:
			var y:=.23 if top else -.23
			for point in ([Vector3(0,y,0),Vector3(a.x,y,a.y),Vector3(b.x,y,b.y)] if top else [Vector3(0,y,0),Vector3(b.x,y,b.y),Vector3(a.x,y,a.y)]):surface.add_vertex(point)
	surface.generate_normals();var result:=MeshInstance3D.new();result.name="LeatherPannier";result.mesh=surface.commit();result.material_override=material(Color("624631"));return result
static func rebuild(horse: Node3D,profile: Dictionary) -> void:
	for child in horse.skeleton.get_children():
		if child.has_meta("equine_fitting"):child.free()
	if bool(profile.get("horn",false)):
		var mount:=Node3D.new();mount.name="UnicornHorn";mount.add_child(horn())
		if bool(profile.get("ethereal",false)):
			var ghost:=material(profile.colour,0.,.35);ghost.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ghost.albedo_color.a=.65
			mount.get_child(0).material_override=ghost
		attach(horse,"head",mount,Vector3(0,1.94,1.11))
	if profile.has("eyes"):
		for side in [-1.,1.]:
			var eye:=MeshInstance3D.new();eye.name="EmberEye";var sphere:=SphereMesh.new();sphere.radius=.018;sphere.height=.026;eye.mesh=sphere;eye.material_override=material(profile.eyes,0.,1.4)
			attach(horse,"head",eye,Vector3(side*.115,1.837,1.107))
	if bool(profile.get("bags",false)):
		for side in [-1.,1.]:
			var pack:=Node3D.new();pack.name="PackPannier";pack.add_child(bag())
			for z in [-.18,.18]:
				var strap:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=Vector3(.31,.47,.034);strap.mesh=cube;strap.position.z=z;strap.material_override=material(Color("32271f"));pack.add_child(strap)
				var buckle:=MeshInstance3D.new();var loop:=TorusMesh.new();loop.inner_radius=.019;loop.outer_radius=.026;loop.rings=12;loop.ring_segments=8;buckle.mesh=loop;buckle.rotation.z=PI/2.;buckle.position=Vector3(side*.158,.08,z);buckle.material_override=material(Color("b69a50"),.7);pack.add_child(buckle)
			attach(horse,"spine_01",pack,Vector3(side*.445,1.16,-.64))
	if bool(profile.get("embers",false)):
		var sparks:=GPUParticles3D.new();sparks.name="FireSteedEmbers";sparks.amount=24;sparks.lifetime=1.3;sparks.visibility_aabb=AABB(Vector3(-1,-1,-1),Vector3(2,3,3))
		var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(.02,.18,.18);process.direction=Vector3.UP;process.spread=25.;process.initial_velocity_min=.22;process.initial_velocity_max=.5;process.gravity=Vector3(0,.1,0);process.scale_min=.005;process.scale_max=.016;sparks.process_material=process
		var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;sphere.radial_segments=6;sphere.rings=3;sphere.material=material(Color("ff751d"),0.,2.);sparks.draw_pass_1=sphere
		attach(horse,"neck_03",sparks,Vector3(0,1.86,.72))
static func tint_spectral_horn(horse: Node3D,profile: Dictionary,hue: int) -> void:
	if not bool(profile.get("ethereal",false)) or not bool(profile.get("horn",false)):return
	var colour: Color=profile.colour
	var palette: Texture2D=null if hue==0x4001 else preload("res://Presentation/HumanHue.gd").palette(hue)
	if palette!=null and (hue&0x8000)==0:colour=palette.get_image().get_pixel(20,0)
	for mesh: MeshInstance3D in horse.skeleton.find_children("SpiralHorn","MeshInstance3D",true,false):
		var mat:=mesh.material_override as StandardMaterial3D
		mat.albedo_color=Color(colour,.65);mat.emission=colour
