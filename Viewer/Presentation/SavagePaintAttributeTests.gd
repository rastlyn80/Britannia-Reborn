extends SceneTree
## Source-free 16/32-bit LOD, eight-weight and static-paint preservation.
const Paint=preload("res://Presentation/SavageBodyPaint.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(60.).timeout.connect(func():push_error("Paint attribute test deadline");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	for vertex_count in [3,65537]:
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		var points:=PackedVector3Array();points.resize(vertex_count)
		var bones:=PackedInt32Array();bones.resize(vertex_count*8)
		var weights:=PackedFloat32Array();weights.resize(vertex_count*8)
		for index in vertex_count:
			points[index]=Vector3(float(index%3)*.1,float(index%7)*.03,.02)
			weights[index*8]=1.
		arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,vertex_count-1,vertex_count-1,1,0])
		arrays[Mesh.ARRAY_CUSTOM1]=PackedFloat32Array();arrays[Mesh.ARRAY_CUSTOM1].resize(vertex_count*2)
		var source:=ArrayMesh.new()
		var flags: int=Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS|(Mesh.ARRAY_CUSTOM_RG_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{.03:PackedInt32Array([vertex_count-1,1,0])},flags)
		var original:=source.surface_get_arrays(0)
		for female in [false,true]:
			var mesh:=Paint.painted(source,female);var after:=mesh.surface_get_arrays(0)
			for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX,Mesh.ARRAY_CUSTOM1]:check(original[channel]==after[channel],"Original geometry/skin/index/custom data retained: %d/%s/%d"%[vertex_count,female,channel])
			check(RenderingServer.mesh_get_surface(source.get_rid(),0).lods==RenderingServer.mesh_get_surface(mesh.get_rid(),0).lods,"Exact 16/32-bit source LOD thresholds and indices retained")
			var coordinates: PackedFloat32Array=after[Mesh.ARRAY_CUSTOM0]
			check(coordinates.size()==vertex_count*3,"Float rest coordinates have three components per vertex")
			var scale:=1.8/(1.72 if female else 1.8)
			check(Vector3(coordinates[3],coordinates[4],coordinates[5]).distance_to(points[1]*scale)<.000001,"Paint coordinates retain normalized original rest position")
			check(Paint.painted(source,female)==mesh,"Repeated appearance updates reuse the same painted mesh")
			var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/SavageSkin.gdshader");material.set_meta("snapshot_uniforms",true);material.set_shader_parameter("skin_tint",Color(.8,.7,.6))
			var actor:=Node3D.new();root.add_child(actor);actor.set_meta("corpse_body",184 if female else 183);actor.set_meta("native_hue",53);actor.set_meta("death_clip","Synthetic")
			var rig:=Skeleton3D.new();actor.add_child(rig);rig.add_bone("Synthetic")
			var skin:=Skin.new();skin.add_bind(0,Transform3D.IDENTITY)
			var part:=MeshInstance3D.new();part.mesh=mesh;part.skin=skin;part.skeleton=NodePath("..");part.material_override=material;rig.add_child(part)
			var corpse:=Corpses.freeze(actor)
			check(corpse!=null,"Painted surface freezes without a live rig")
			if corpse!=null:
				var frozen:=corpse.get_child(0) as MeshInstance3D;var frozen_arrays:=frozen.mesh.surface_get_arrays(0)
				check(frozen_arrays[Mesh.ARRAY_CUSTOM0]==coordinates and frozen_arrays[Mesh.ARRAY_CUSTOM1]==after[Mesh.ARRAY_CUSTOM1],"Static corpse retains exact float paint/other custom channels")
				var snapshot:=frozen.mesh.surface_get_material(0) as ShaderMaterial
				material.set_shader_parameter("skin_tint",Color.RED)
				check(snapshot!=material and snapshot.get_shader_parameter("skin_tint")==Color(.8,.7,.6),"Living identity changes cannot recolour the frozen paint snapshot")
				check(corpse.get_meta("corpse_body")== (184 if female else 183) and corpse.get_meta("graphic_id")==0x2006,"Static corpse retains native graphic/body identity")
				corpse.free()
			actor.free()
	print("SAVAGE PAINT ATTRIBUTES: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
