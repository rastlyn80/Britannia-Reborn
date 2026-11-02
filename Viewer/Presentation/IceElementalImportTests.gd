extends SceneTree
## Direct source versus actual saved imports. Never accept altered source motion.
const FOLDER="res://local-art/creatures/"
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Ice161 import fidelity deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(label)
func bone_id(mesh: MeshInstance3D,rig: Skeleton3D,bind: int) -> int:
	var bone:=mesh.skin.get_bind_bone(bind)
	return rig.find_bone(mesh.skin.get_bind_name(bind)) if bone<0 else bone
func corner(a: Array,mesh: MeshInstance3D,rig: Skeleton3D,vertex: int) -> Array:
	var weights:=PackedFloat32Array();weights.resize(rig.get_bone_count());var stride: int=a[Mesh.ARRAY_BONES].size()/a[Mesh.ARRAY_VERTEX].size()
	for slot in stride:
		var offset:=vertex*stride+slot;weights[bone_id(mesh,rig,a[Mesh.ARRAY_BONES][offset])]+=a[Mesh.ARRAY_WEIGHTS][offset]
	return [a[Mesh.ARRAY_VERTEX][vertex],a[Mesh.ARRAY_NORMAL][vertex],a[Mesh.ARRAY_TEX_UV][vertex],weights]
func triangles(a: Array,ids: Array) -> Dictionary:
	var indices: Variant=a[Mesh.ARRAY_INDEX];var result: Dictionary={};var size_: int=indices.size() if indices!=null and not indices.is_empty() else ids.size()
	assert(size_%3==0)
	for step in range(0,size_,3):
		var v: Array=[]
		for k in 3:v.append(ids[indices[step+k]] if indices!=null and not indices.is_empty() else ids[step+k])
		var first:=0
		if v[1]<v[first]:first=1
		if v[2]<v[first]:first=2
		var triangle:=Vector3i(v[first],v[(first+1)%3],v[(first+2)%3]);result[triangle]=int(result.get(triangle,0))+1
	return result
func rgba(image: Image) -> Dictionary:
	assert(image!=null)
	if image.is_compressed():assert(image.decompress()==OK)
	image.convert(Image.FORMAT_RGBA8);image.clear_mipmaps();var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
	return {"width":image.get_width(),"height":image.get_height(),"rgba_sha256":digest.finish().hex_encode()}
func pixels(mesh: MeshInstance3D) -> Dictionary:
	var material:=mesh.mesh.surface_get_material(0) as StandardMaterial3D;assert(material!=null and material.albedo_texture!=null)
	return rgba(material.albedo_texture.get_image())
func bind_poses(mesh: MeshInstance3D,rig: Skeleton3D) -> Dictionary:
	var result: Dictionary={}
	for bind in mesh.skin.get_bind_count():result[bone_id(mesh,rig,bind)]=mesh.skin.get_bind_pose(bind)
	return result
func run() -> void:
	var prep_path:=FOLDER+"ice_elementals/candidate.json";var prep_pin:=FileAccess.get_sha256(prep_path);var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	var pins: Dictionary={};var runtime: Dictionary={};var records: Array=[];var meshes: Array=[];var maximum_position:=0.;var maximum_basis:=0.;var maximum_scale:=0.;var maximum_skin_bound:=0.
	for name in ["IceElementalImportTests.gd","ConfigureIceElementalImport.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var configuration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/ice-elemental/import-settings.json"))
	check(configuration.preparation_sha256==prep_pin and configuration.recipe_sha256==runtime["ConfigureIceElementalImport.gd"] and configuration.textures.size()==4,"Exact narrow motion/texture import recipe matches preparation")
	for texture: Dictionary in configuration.textures:
		var path:=str(texture.asset);var config:=ConfigFile.new();assert(config.load(path+".import")==OK)
		for option: String in preload("res://Presentation/ConfigureIceElementalImport.gd").TEXTURE_OPTIONS:check(config.get_value("params",option,null)==preload("res://Presentation/ConfigureIceElementalImport.gd").TEXTURE_OPTIONS[option],"Small original atlas has explicit lossless base-pixel settings")
		check(FileAccess.get_sha256(path)==texture.asset_sha256 and FileAccess.get_sha256(path+".import")==texture.import_settings_sha256,"Texture/config unchanged since import preparation")
		for input: String in [path,path+".import",str(config.get_value("remap","path",""))]:pins[input]=FileAccess.get_sha256(input)
	for row: Dictionary in prep.models:
		for treatment: String in ["original","rounded","modern"]:
			var path:=FOLDER+str(row.kind)+"-"+treatment+".gltf";var config:=ConfigFile.new();assert(config.load(path+".import")==OK)
			var settings: Dictionary=config.get_value("params","_subresources",{}).get("nodes",{}).get("PATH:AnimationPlayer",{})
			check(settings.get("optimizer/enabled",true)==false and settings.get("compression/enabled",true)==false,"Only precise Ice161 motion is imported")
			var cache_path:=str(config.get_value("remap","path",""));assert(cache_path.begins_with("res://.godot/imported/") and cache_path.ends_with(".scn"))
			for input: String in [path,path+".import",cache_path]:pins[input]=FileAccess.get_sha256(input)
			var document:=GLTFDocument.new();var state:=GLTFState.new();assert(document.append_from_file(ProjectSettings.globalize_path(path),state)==OK);var raw:=document.generate_scene(state);var cached: Node3D=load(path).instantiate();root.add_child(raw);root.add_child(cached)
			var ar: Skeleton3D=raw.find_children("*","Skeleton3D",true,false)[0];var br: Skeleton3D=cached.find_children("*","Skeleton3D",true,false)[0];var ap: AnimationPlayer=raw.find_children("*","AnimationPlayer",true,false)[0];var bp: AnimationPlayer=cached.find_children("*","AnimationPlayer",true,false)[0]
			ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;bp.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;ap.deterministic=true;bp.deterministic=true
			check(ar.get_bone_count()==34 and br.get_bone_count()==34,"All original source rig joints survive saved import")
			for bone in ar.get_bone_count():check(ar.get_bone_name(bone)==br.get_bone_name(bone) and ar.get_bone_parent(bone)==br.get_bone_parent(bone),"Every bone name/parent remains identical")
			var am: MeshInstance3D=raw.find_children("*","MeshInstance3D",true,false)[0];var bm: MeshInstance3D=cached.find_children("*","MeshInstance3D",true,false)[0];var a:=am.mesh.surface_get_arrays(0);var b:=bm.mesh.surface_get_arrays(0);var table: Dictionary={};var ai: Array=[];var bi: Array=[];var missing:=0;var boxes: Dictionary={};var maximum_weight:=0.
			check(am.mesh.get_surface_count()==1 and bm.mesh.get_surface_count()==1 and am.mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES and bm.mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES,"Source and cache retain one triangle skin")
			for vertex in a[Mesh.ARRAY_VERTEX].size():
				var key:=corner(a,am,ar,vertex)
				if not table.has(key):table[key]=table.size()
				ai.append(table[key]);var weights: PackedFloat32Array=key[3];var total:=0.
				for bone in weights.size():
					assert(weights[bone]>=0. and is_finite(weights[bone]));total+=weights[bone]
					if weights[bone]>0.:boxes[bone]=(boxes[bone] as AABB).expand(key[0]) if boxes.has(bone) else AABB(key[0],Vector3.ZERO)
				maximum_weight=maxf(maximum_weight,total)
			for vertex in b[Mesh.ARRAY_VERTEX].size():
				var key:=corner(b,bm,br,vertex)
				if not table.has(key):missing+=1
				bi.append(table.get(key,-1))
			var topology:=triangles(a,ai)==triangles(b,bi);check(missing==0 and topology and maximum_weight<=1.0001,"Exact position/normal/UV/semantic weights and winding-aware topology survive cache reordering")
			var image:=pixels(am);check(image==pixels(bm) and int(image.width)==128 and int(image.height)==128,"Every original atlas RGBA pixel survives saved import")
			if treatment=="original":check(image==rgba((load(FOLDER+str(row.source_atlas_texture)) as Texture2D).get_image()),"The shader's separate original atlas retains every base RGBA pixel too")
			var ab:=bind_poses(am,ar);var bb:=bind_poses(bm,br);check(ab==bb,"All semantic inverse-bind transforms are identical")
			meshes.append({"kind":row.kind,"treatment":treatment,"source_vertices":ai.size(),"cached_vertices":bi.size(),"missing_exact_corners":missing,"same_winding_topology":topology,"atlas":image,"maximum_weight_sum":maximum_weight})
			check(ap.get_animation_list().size()==13 and bp.get_animation_list().size()==13,"All13 source/explicit-alias categories survive")
			for clip: String in ap.get_animation_list():
				if clip=="RESET":continue
				check(bp.has_animation(clip) and absf(ap.get_animation(clip).length-bp.get_animation(clip).length)<.000001,"Original source category and duration preserved")
				ap.get_animation(clip).loop_mode=Animation.LOOP_NONE;bp.get_animation(clip).loop_mode=Animation.LOOP_NONE
				for step in 13:
					var phase:=0. if step==0 else 1. if step==12 else (float(step)-.317)/12.;ap.play(clip,0.);bp.play(clip,0.);ap.seek(ap.get_animation(clip).length*phase,true);bp.seek(bp.get_animation(clip).length*phase,true);ap.advance(0.);bp.advance(0.);ap.pause();bp.pause();ar.force_update_all_bone_transforms();br.force_update_all_bone_transforms();var pe:=0.;var be:=0.;var se:=0.;var skin_bound:=0.
					for bone in ar.get_bone_count():
						var x:=ar.global_transform*ar.get_bone_global_pose(bone);var y:=br.global_transform*br.get_bone_global_pose(bone);pe=maxf(pe,x.origin.distance_to(y.origin));se=maxf(se,x.basis.get_scale().distance_to(y.basis.get_scale()));var xb:=x.basis.orthonormalized();var yb:=y.basis.orthonormalized();be=maxf(be,maxf(xb.x.distance_to(yb.x),maxf(xb.y.distance_to(yb.y),xb.z.distance_to(yb.z))))
						if boxes.has(bone):
							var box: AABB=boxes[bone];var sa: Transform3D=x*ab[bone];var sb: Transform3D=y*bb[bone]
							for c in 8:
								var point:=box.position+box.size*Vector3(float(c&1),float((c>>1)&1),float((c>>2)&1));skin_bound=maxf(skin_bound,(sa*point).distance_to(sb*point))
					# Positive normalized weights form a convex blend. Affine
					# displacement over each influence box is bounded by its eight
					# corners;100um is an additional origin-local numeric margin.
					skin_bound=skin_bound*maximum_weight+.0001;maximum_position=maxf(maximum_position,pe);maximum_basis=maxf(maximum_basis,be);maximum_scale=maxf(maximum_scale,se);maximum_skin_bound=maxf(maximum_skin_bound,skin_bound)
					check(pe<.001 and be<.001 and se<.00001 and skin_bound<.001,"Saved import retains source rig and complete weighted skin within declared1mm/.001axis bounds")
					records.append({"kind":row.kind,"treatment":treatment,"clip":clip,"phase":phase,"maximum_world_joint_error_m":pe,"maximum_basis_axis_error":be,"maximum_scale_error":se,"conservative_skin_error_bound_m":skin_bound})
			raw.free();cached.free()
	for input: String in pins:check(pins[input]==FileAccess.get_sha256(input),"Exact GLTF/config/saved-scene input unchanged")
	for name: String in runtime:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Import fidelity recipe unchanged")
	check(prep_pin==FileAccess.get_sha256(prep_path),"Exact preparation unchanged")
	var report:={"checks":checks,"failures":failures,"records":records,"meshes":meshes,"maximum_position_error_m":maximum_position,"maximum_basis_error":maximum_basis,"maximum_scale_error":maximum_scale,"maximum_skin_error_bound_m":maximum_skin_bound,"assets_sha256":pins,"runtime_sha256":runtime,"preparation_sha256":prep_pin,"godot_version":Engine.get_version_info().string,"scope":"Actual direct versus saved three original/refined Ice161 imports:34bone names/parents, 13 source/explicit-alias categories/durations,13off-grid phases each; exact semantic position/normal/UV/four-slot weights/inverse binds/winding topology and128RGBA atlases. Joint1mm/.001axis/.00001scale bounds; conservative origin-local complete-skin1mm bound including100um numerical margin. No generated tangent/LOD fidelity, GPU/material pixels/native/terrain/family acceptance."}
	FileAccess.open("res://../work/creatures/ice-elemental/import-fidelity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("ICE161 SAVED IMPORT:",checks,"checks/",failures,"failures/",records.size(),"pairs; joint",maximum_position," skin bound",maximum_skin_bound);quit(1 if failures else 0)
