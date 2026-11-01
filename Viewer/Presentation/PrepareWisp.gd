extends SceneTree
## Independent authored analytic model/rig/motions, still uninstalled and unaccepted.
var model: Node3D
var rig: Skeleton3D
var vertex_count:=0
var triangles:=0
func _initialize() -> void:call_deferred("run")
func attach(source: Mesh,bone: int,label: String,core: bool,density: float=1.) -> void:
	var arrays:=source.surface_get_arrays(0).duplicate(true)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var rest:=rig.get_bone_global_rest(bone)
	var bones:=PackedInt32Array();var weights:=PackedFloat32Array();bones.resize(vertices.size()*4);weights.resize(vertices.size()*4)
	for i in vertices.size():
		vertices[i]=rest*vertices[i];normals[i]=(rest.basis*normals[i]).normalized();bones[i*4]=bone;weights[i*4]=1.
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=null;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	vertex_count+=vertices.size();triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else vertices.size())/3
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code=FileAccess.get_file_as_string("res://Presentation/WispSurface.gdshader");material.shader=shader;material.set_shader_parameter("core",core);material.set_shader_parameter("density",density)
	mesh.surface_set_material(0,material)
	var visual:=MeshInstance3D.new();visual.name=label;visual.mesh=mesh;visual.skin=Skin.new()
	for index in rig.get_bone_count():visual.skin.add_bind(index,rig.get_bone_global_rest(index).affine_inverse())
	visual.skeleton=NodePath("../Rig");visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;model.add_child(visual);visual.owner=model
func ray_mesh(length: float,width: float) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in 16:
		for side in 12:
			for corner in [[0,0],[1,0],[1,1],[0,0],[1,1],[0,1]]:
				var t:=float(section+corner[1])/16.;var a:=TAU*float(side+corner[0])/12.;var radius:=width*pow(1.-t,1.65)*(1.+.06*sin(t*20.))
				st.set_uv(Vector2(a/TAU,t));st.add_vertex(Vector3(cos(a)*radius,t*length,sin(a)*radius))
	st.generate_normals();return st.commit()
func track(animation: Animation,type: Animation.TrackType,path: String) -> int:
	var index:=animation.add_track(type);animation.track_set_path(index,NodePath(path));return index
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://local-art/wisp"))
	model=Node3D.new();model.name="AuthoredWisp";root.add_child(model)
	rig=Skeleton3D.new();rig.name="Rig";model.add_child(rig);rig.owner=model;rig.add_bone("EnergyRoot");rig.set_bone_rest(0,Transform3D(Basis.IDENTITY,Vector3(0,.95,0)))
	for index in 6:
		rig.add_bone("Ray"+str(index));rig.set_bone_parent(index+1,0)
		var direction: Vector3=[Vector3.UP,Vector3.DOWN,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK][index]
		rig.set_bone_rest(index+1,Transform3D(Basis(Quaternion(Vector3.UP,direction)),Vector3.ZERO))
	rig.reset_bone_poses()
	for radius in [.085,.14]:
		var orb:=SphereMesh.new();orb.radius=radius;orb.height=2.*radius;orb.radial_segments=32;orb.rings=16;attach(orb,0,"Core" if radius<.1 else "Halo",true,1. if radius<.1 else .2)
	for index in 6:attach(ray_mesh(.4 if index<2 else .32,.105),index+1,"EnergyRay"+str(index),false)
	var animator:=AnimationPlayer.new();animator.name="AnimationPlayer";model.add_child(animator);animator.owner=model
	var library:=AnimationLibrary.new();var clips: Dictionary={}
	var definitions:={"Idle":[2.,true,.0],"Walk":[1.2,true,.04],"Run":[.8,true,.08],"Attack":[.7,false,.18],"Attack2":[.85,false,.12],"Attack3":[1.,false,.22],"Hit":[.5,false,-.07],"Death":[1.5,false,0.],"Death2":[1.8,false,0.],"Fidget":[1.6,false,.05],"Fidget2":[1.8,false,.06],"Cast":[1.5,false,.15],"Eat":[1.8,false,-.05],"Pillage":[1.4,false,.05],"Alert":[1.,false,.07],"LieDown":[1.4,false,0.]}
	for category: String in definitions:
		var definition: Array=definitions[category];var animation:=Animation.new();animation.length=float(definition[0]);animation.loop_mode=Animation.LOOP_LINEAR if bool(definition[1]) else Animation.LOOP_NONE
		var position:=track(animation,Animation.TYPE_POSITION_3D,"Rig:EnergyRoot");var rotation:=track(animation,Animation.TYPE_ROTATION_3D,"Rig:EnergyRoot");var size:=track(animation,Animation.TYPE_SCALE_3D,"Rig:EnergyRoot")
		var ray_tracks: Array[int]=[]
		for bone in 6:ray_tracks.append(track(animation,Animation.TYPE_SCALE_3D,"Rig:Ray"+str(bone)))
		for sample in 61:
			var t:=float(sample)/60.;var pulse:=sin(TAU*t);var envelope:=pow(sin(PI*t),2.);var ending:=category in ["Death","Death2","LieDown"]
			var scale:=lerpf(1.,.34,t*t*(3.-2.*t)) if ending else 1.+(.07 if category=="Cast" else .025)*pulse
			var offset:=Vector3(0,-.78*t*t*(3.-2.*t) if ending else .025*pulse+float(definition[2])*envelope,0)
			animation.position_track_insert_key(position,t*animation.length,Vector3(0,.95,0)+offset)
			animation.rotation_track_insert_key(rotation,t*animation.length,Quaternion(Vector3.UP,TAU*t if bool(definition[1]) else envelope*(.8 if category=="Hit" else 1.4)))
			animation.scale_track_insert_key(size,t*animation.length,Vector3.ONE*scale)
			for bone in 6:
				var ray_scale:=1.+(.1+.035*float(bone%2))*sin(TAU*t+float(bone)*PI/3.)
				animation.scale_track_insert_key(ray_tracks[bone],t*animation.length,Vector3(1.,ray_scale,1.))
		library.add_animation(category,animation);clips[category]={"duration":animation.length,"loop":bool(definition[1]),"origin":"Explicitly authored analytic energy-root/ray animation; not recovered source choreography"}
	animator.add_animation_library("",library)
	var scene:=PackedScene.new();if scene.pack(model)!=OK:push_error("Cannot pack authored Wisp trial");quit(1);return
	if ResourceSaver.save(scene,"res://local-art/wisp/wisp-modern.scn")!=OK:push_error("Cannot save authored Wisp trial");quit(1);return
	var report:=FileAccess.open("res://local-art/wisp/preparation.json",FileAccess.WRITE);report.store_string(JSON.stringify({"status":"Unaccepted trial, no installed route or added coverage","license":"GPL-3.0-or-later original analytic geometry/rig/motions/shader; no third-party or UO art","bones":7,"vertices":vertex_count,"triangles":triangles,"clips":clips,"missing":["Actual complete-skin/key interpolation and loop checks","Runtime hue bindings and deterministic shader freeze","Terrain-relative hover/picking/camera/nameplate","Native constructor/actions/hues/death/corpse","Clean public distribution and full regression"]},"\t"));report.close();print("WISP TRIAL: ",vertex_count," vertices / ",triangles," triangles / 7 bones / ",clips.size()," authored categories; uninstalled");quit()
