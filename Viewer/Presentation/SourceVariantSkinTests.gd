extends SceneTree
## Saved variant geometry/rig/animation must equal its declared imported donor.
var checks:=0
var failures:=0
const PREPARATION="res://local-art/creatures/source_variants/preparation.json"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<15:push_error(label)
func run() -> void:
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREPARATION))
	var receipts: Array=[]
	for row: Dictionary in preparation.models:
		var image:=Image.load_from_file(ProjectSettings.globalize_path("res://local-art/creatures/"+str(row.source_atlas_texture)))
		image.convert(Image.FORMAT_RGBA8);image.clear_mipmaps()
		for treatment: String in row.assets:
			var asset:=str(row.assets[treatment]);var donor:="res://"+str(row.donor_assets[treatment].path).trim_prefix("Viewer/")
			check(FileAccess.get_sha256(asset)==row.saved_scenes[treatment].asset_sha256,"Exact saved candidate scene")
			check(FileAccess.get_sha256(donor)==row.donor_assets[treatment].sha256 and FileAccess.get_sha256(donor+".import")==row.donor_imports[treatment].sha256,"Exact imported donor input")
			var a:=load(donor).instantiate() as Node3D;var b:=load(asset).instantiate() as Node3D
			check(a.transform==b.transform,"Exact model root transform")
			for node: Node3D in a.find_children("*","Node3D",true,false):
				var twin:=b.get_node_or_null(a.get_path_to(node)) as Node3D
				check(twin!=null and twin.transform==node.transform,"Every model-space ancestor/node transform survives packing")
			var ma: Array=a.find_children("*","MeshInstance3D",true,false);var mb: Array=b.find_children("*","MeshInstance3D",true,false)
			check(ma.size()==mb.size() and ma.size()>0,"All donor mesh parts survive packing")
			for part in ma.size():
				var x:=ma[part] as MeshInstance3D;var y:=mb[part] as MeshInstance3D
				check(x.transform==y.transform and x.skeleton==y.skeleton,"Exact mesh transform and rig path")
				check(x.mesh.get_surface_count()==y.mesh.get_surface_count(),"Exact source material ranges")
				for surface in x.mesh.get_surface_count():
					var xa:=x.mesh.surface_get_arrays(surface);var ya:=y.mesh.surface_get_arrays(surface)
					for slot in Mesh.ARRAY_MAX:check(xa[slot]==ya[slot],"Every uploaded position/normal/UV/tangent/index/weight/binding array remains exact")
					check(x.mesh.surface_get_format(surface)==y.mesh.surface_get_format(surface),"Uploaded array flags retained")
					var material:=y.mesh.surface_get_material(surface) as StandardMaterial3D
					var pixels:=material.albedo_texture.get_image();pixels.convert(Image.FORMAT_RGBA8);pixels.clear_mipmaps()
					check(pixels.get_size()==image.get_size() and pixels.get_data()==image.get_data(),"Actual saved material contains its own original RGBA, not the donor pixels")
				check(x.skin.get_bind_count()==y.skin.get_bind_count(),"Exact inverse-bind count")
				for bind in x.skin.get_bind_count():check(x.skin.get_bind_bone(bind)==y.skin.get_bind_bone(bind) and x.skin.get_bind_name(bind)==y.skin.get_bind_name(bind) and x.skin.get_bind_pose(bind)==y.skin.get_bind_pose(bind),"Every inverse bind/name/bone remains exact")
			var ra: Skeleton3D=a.find_children("*","Skeleton3D",true,false)[0];var rb: Skeleton3D=b.find_children("*","Skeleton3D",true,false)[0]
			check(ra.get_bone_count()==rb.get_bone_count(),"Complete donor rig retained")
			for bone in ra.get_bone_count():check(ra.get_bone_name(bone)==rb.get_bone_name(bone) and ra.get_bone_parent(bone)==rb.get_bone_parent(bone) and ra.get_bone_rest(bone)==rb.get_bone_rest(bone) and ra.get_bone_pose(bone)==rb.get_bone_pose(bone),"Exact rest hierarchy and initial channels, including declared inactive donor label")
			var pa: AnimationPlayer=a.find_children("*","AnimationPlayer",true,false)[0];var pb: AnimationPlayer=b.find_children("*","AnimationPlayer",true,false)[0]
			check(pa.root_node==pb.root_node and pa.root_motion_track==pb.root_motion_track and pa.get_animation_list()==pb.get_animation_list(),"Same animation target, root-motion policy and complete category list")
			var tracks:=0;var keys:=0
			for clip: String in pa.get_animation_list():
				var source:=pa.get_animation(clip);var saved:=pb.get_animation(clip)
				check(source.length==saved.length and source.loop_mode==saved.loop_mode and source.get_track_count()==saved.get_track_count(),"Exact clip length/loop/channels")
				for track in source.get_track_count():
					check(source.track_get_path(track)==saved.track_get_path(track) and source.track_get_type(track)==saved.track_get_type(track) and source.track_is_enabled(track)==saved.track_is_enabled(track) and source.track_get_interpolation_type(track)==saved.track_get_interpolation_type(track) and source.get("tracks/"+str(track)+"/keys")==saved.get("tracks/"+str(track)+"/keys"),"All saved source/alias track paths, enabled state, interpolation and serialized key arrays remain exact")
					tracks+=1;keys+=source.track_get_key_count(track)
			for dependency in ResourceLoader.get_dependencies(asset):check(not dependency.contains(".godot/imported"),"Variant scene is independent of transient donor import cache")
			receipts.append({"kind":row.kind,"treatment":treatment,"bones":ra.get_bone_count(),"tracks":tracks,"keys":keys,"asset_sha256":FileAccess.get_sha256(asset),"donor_sha256":FileAccess.get_sha256(donor)})
			a.free();b.free()
		var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
		var body:=int(row.bodies[0].body);var previous: Variant=registry.entries.get(body,null);registry.entries[body]=row
		for hue: int in [0,53,0x8035]:
			var corpse: Node3D=preload("res://Presentation/CorpseModels.gd").build(body,hue)
			check(corpse!=null,"Actual candidate factory creates its native static corpse")
			if corpse==null:continue
			check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==body and corpse.get_meta("native_hue")==hue,"Native corpse graphic/body/raw hue survive")
			check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Cadaver is genuinely static")
			var bounds: AABB=corpse.get_meta("corpse_bounds")
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.1 and absf(bounds.position.y)<.00001,"Complete finite cadaver settles on its deformed underside")
			corpse.free()
		if previous==null:registry.entries.erase(body)
		else:registry.entries[body]=previous
	var folder:="res://../work/creatures/source-variants"
	FileAccess.open(folder+"/skin-proof.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scenes":receipts,"preparation_sha256":FileAccess.get_sha256(PREPARATION),"test_sha256":FileAccess.get_sha256("res://Presentation/SourceVariantSkinTests.gd"),"scope":"Actual saved variant arrays/inverse binds/rest hierarchy and complete serialized animation tracks equal declared donors, while exact own RGBA pixels replace donor maps. This proves compiled deformation reuse; current avatar/body/hue/terrain/death/native behaviour and original raw GRN fidelity remain separate."},"\t"))
	print("SOURCE VARIANT SKINS: ",checks," checks / ",failures," failures / ",receipts.size()," saved scenes")
	quit(1 if failures else 0)
