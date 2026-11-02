extends RefCounted
## Authored reinterpretation of original white paint/black spirals on modern skin.
## Float rest coordinates stay attached to skin vertices through posing/freezing.
static var painted_meshes: Dictionary={}
static func _lods(source: ArrayMesh,surface: int) -> Dictionary:
	# ArrayMesh has no public LOD getter; the rendering surface retains the
	# original packed indices. Decode their actual base-surface index width.
	var data:=RenderingServer.mesh_get_surface(source.get_rid(),surface)
	var result: Dictionary={}
	var raw: PackedByteArray=data.get("index_data",PackedByteArray())
	var count:=int(data.get("index_count",0))
	var stride:=raw.size()/count if count>0 else 0
	for lod: Dictionary in data.get("lods",[]):
		assert(stride in [2,4],"Unsupported source LOD index width")
		var packed: PackedByteArray=lod.index_data
		assert(packed.size()%stride==0,"Invalid source LOD index buffer")
		var indices:=PackedInt32Array();indices.resize(packed.size()/stride)
		for index in indices.size():indices[index]=packed.decode_u16(index*stride) if stride==2 else packed.decode_u32(index*stride)
		result[float(lod.edge_length)]=indices
	return result
static func painted(source: ArrayMesh,female: bool) -> ArrayMesh:
	var key:=str(source.get_instance_id())+"/"+str(female)
	if painted_meshes.has(key):return painted_meshes[key].mesh
	assert(source.get_blend_shape_count()==0,"Savage paint needs explicit rest-coordinate support for morph targets")
	var result:=ArrayMesh.new();var scale:=1.8/(1.72 if female else 1.8)
	for surface in source.get_surface_count():
		var arrays:=source.surface_get_arrays(surface).duplicate(true)
		assert(arrays[Mesh.ARRAY_CUSTOM0]==null,"Human source already uses the reserved paint-coordinate channel")
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var coordinates:=PackedFloat32Array();coordinates.resize(points.size()*3)
		for index in points.size():
			var p:=points[index]*scale;coordinates[index*3]=p.x;coordinates[index*3+1]=p.y;coordinates[index*3+2]=p.z
		arrays[Mesh.ARRAY_CUSTOM0]=coordinates
		var format:=source.surface_get_format(surface);var flags:=format&(Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS|Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:flags|=format&(Mesh.ARRAY_FORMAT_CUSTOM_MASK<<shift)
		flags|=Mesh.ARRAY_CUSTOM_RGB_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays,[],_lods(source,surface),flags)
		# Re-encoding octahedral normals/tangents can change the last bit. Paint
		# occupies the separate attribute buffer; retain the exact vertex buffer.
		var original:=RenderingServer.mesh_get_surface(source.get_rid(),surface)
		var rebuilt:=RenderingServer.mesh_get_surface(result.get_rid(),surface)
		assert(original.vertex_data.size()==rebuilt.vertex_data.size(),"Paint changed the source vertex-buffer layout")
		result.surface_update_vertex_region(surface,0,original.vertex_data)
		result.surface_set_material(surface,source.surface_get_material(surface))
	# Retain the source resource too: an orphaned instance ID can be reused.
	painted_meshes[key]={"source":source,"mesh":result}
	return result
static func apply(human: Node3D,hue: int=0) -> void:
	var skin: ShaderMaterial=human.skin
	if not skin.has_meta("base_human_shader"):skin.set_meta("base_human_shader",skin.shader)
	if not skin.has_meta("base_human_snapshot"):skin.set_meta("base_human_snapshot",skin.get_meta("snapshot_uniforms",false))
	if not skin.has_meta("savage_shader"):
		var shader: Shader=preload("res://Presentation/SavageSkin.gdshader")
		if human.get_viewport().transparent_bg:
			var portrait:=Shader.new();portrait.code="#define HUMAN_NO_SSS\n"+shader.code;shader=portrait
		skin.set_meta("savage_shader",shader)
	skin.shader=skin.get_meta("savage_shader")
	skin.set_meta("snapshot_uniforms",true)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	skin.set_shader_parameter("hue_palette",palette);skin.set_shader_parameter("use_hue",palette!=null);skin.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	for mesh: MeshInstance3D in human.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override!=skin:continue
		if not mesh.has_meta("unpainted_mesh"):mesh.set_meta("unpainted_mesh",mesh.mesh)
		mesh.mesh=painted(mesh.get_meta("unpainted_mesh"),bool(human.female))
static func restore(human: Node3D) -> void:
	var skin: ShaderMaterial=human.skin
	if skin.has_meta("base_human_shader"):skin.shader=skin.get_meta("base_human_shader")
	if skin.has_meta("base_human_snapshot"):skin.set_meta("snapshot_uniforms",skin.get_meta("base_human_snapshot"))
	for mesh: MeshInstance3D in human.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("unpainted_mesh"):mesh.mesh=mesh.get_meta("unpainted_mesh")
