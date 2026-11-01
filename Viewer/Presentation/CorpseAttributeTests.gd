extends SceneTree
## Synthetic, source-free preservation of float and byte custom UV channels.
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.2,0.,0.),Vector3(.2,0.,0.),Vector3(0.,.4,.1)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD]);arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP]);arrays[Mesh.ARRAY_TEX_UV2]=PackedVector2Array([Vector2(.1,.2),Vector2(.3,.4),Vector2(.5,.6)])
	arrays[Mesh.ARRAY_CUSTOM0]=PackedFloat32Array([.1,.2,.3,.4,.5,.6,.7,.8,.9,1.,.2,.3]);arrays[Mesh.ARRAY_CUSTOM1]=PackedFloat32Array([.1,.2,.3,.4,.5,.6]);arrays[Mesh.ARRAY_CUSTOM2]=PackedByteArray([0,30,60,255,90,120,150,255,180,210,240,255])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2])
	var flags: int=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RG_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA8_UNORM<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	var original:=ArrayMesh.new();original.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
	var actor:=Node3D.new();actor.set_meta("corpse_body",205);actor.set_meta("native_hue",53);actor.set_meta("death_clip","Synthetic source-free pose");root.add_child(actor)
	var part:=MeshInstance3D.new();part.mesh=original;actor.add_child(part);var result:=Corpses.freeze(actor);root.add_child(result)
	check(result!=null and result.get_child_count()==1,"Synthetic float/byte custom corpse surface exists")
	var frozen:=result.get_child(0) as MeshInstance3D;check(frozen.mesh.get_surface_count()==1,"Freezer creates an actual valid surface")
	if frozen.mesh.get_surface_count()==1:
		var before:=original.surface_get_arrays(0);var after:=frozen.mesh.surface_get_arrays(0)
		for channel in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_INDEX]:check(before[channel]==after[channel],"Original UV/custom/index payload preserved exactly:"+str(channel))
		for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT]:check(((original.surface_get_format(0)>>shift)&Mesh.ARRAY_FORMAT_CUSTOM_MASK)==((frozen.mesh.surface_get_format(0)>>shift)&Mesh.ARRAY_FORMAT_CUSTOM_MASK),"Source custom element format retained")
	check(result.get_meta("static_cadaver") and result.find_children("*","Skeleton3D",true,false).is_empty(),"Custom-data cadaver is static and rig-free")
	actor.free();result.free();print("CORPSE ATTRIBUTES: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
