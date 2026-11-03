extends SceneTree
func _initialize() -> void:
 create_timer(240.).timeout.connect(func():push_error("Affine source bake deadline");quit(1))
 call_deferred("run")
func run() -> void:
 var bog:="--bog-thing" in OS.get_cmdline_user_args()
 var folder:="res://../work/creatures/"+("bog-thing" if bog else "gazer-larva")+"/owned-source/"
 var stem:="bog-thing" if bog else "swarm"
 var input:=folder+"prepared/"+stem+("-full-affine-dense.gltf" if bog else "-full-affine.gltf")
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 if doc.append_from_file(ProjectSettings.globalize_path(input),state)!=OK:push_error("Source factor import failed");quit(1);return
 var model:=doc.generate_scene(state);root.add_child(model);var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var installer=load("res://Presentation/SourceGazerExactClocks.gd").new();var recipe: Dictionary=installer.install(input,player,rig)
 if recipe.get("clips",[]).size()!=9:push_error("Exact-key source install incomplete");quit(1);return
 var assets:="res://local-art/creatures/"+("bog_thing" if bog else "gazer_larva")+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(assets))
 var path:=assets+stem+"-exact-clocks.res";var library: AnimationLibrary=player.get_animation_library("")
 if ResourceSaver.save(library,path,ResourceSaver.FLAG_COMPRESS)!=OK:push_error("Exact animation save failed");quit(1);return
 var saved:=ResourceLoader.load(path,"AnimationLibrary",ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
 var tracks:=0;var keys:=0;var failures:=0
 if saved==null:push_error("Exact animation reload failed");quit(1);return
 for name: String in library.get_animation_list():
  var a:=library.get_animation(name);var b:=saved.get_animation(name)
  if b==null or a.length!=b.length or a.get_track_count()!=b.get_track_count():failures+=1;continue
  for track in a.get_track_count():
   if a.track_get_path(track)!=b.track_get_path(track) or a.track_get_type(track)!=b.track_get_type(track) or a.get("tracks/"+str(track)+"/keys")!=b.get("tracks/"+str(track)+"/keys"):failures+=1
   tracks+=1;keys+=a.track_get_key_count(track)
 player.remove_animation_library("");player.add_animation_library("",saved)
 var packed:=PackedScene.new();var scene_path:=assets+stem+"-exact-source.scn"
 if packed.pack(model)!=OK or ResourceSaver.save(packed,scene_path,ResourceSaver.FLAG_COMPRESS)!=OK:failures+=1
 var resource:=load(scene_path) as PackedScene;var reloaded:=resource.instantiate() if resource!=null else null
 if reloaded==null:failures+=1
 else:
  root.add_child(reloaded);var p: AnimationPlayer=reloaded.find_children("*","AnimationPlayer",true,false)[0];var r: Skeleton3D=reloaded.find_children("*","Skeleton3D",true,false)[0]
  if r.get_bone_count()!=(116 if bog else 126) or p.get_animation_library("").get_instance_id()!=load(path).get_instance_id():failures+=1
 var report:={"failures":failures,"tracks":tracks,"keys":keys,"clips":recipe.clips,"gltf_sha256":FileAccess.get_sha256(input),"library_sha256":FileAccess.get_sha256(path),"scene_sha256":FileAccess.get_sha256(scene_path),"installer_sha256":FileAccess.get_sha256("res://Presentation/SourceGazerExactClocks.gd"),"scope":"Actual binary save/reload preserves every serialized key array and channel/path exactly; packed scene shares one saved exact-key library across instances. No source interpolation, cached mesh/material fidelity, runtime/native/route acceptance."}
 FileAccess.open(folder+"saved-clock-library.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SAVED SOURCE CLOCKS: ",tracks," tracks / ",keys," keys / ",failures," failures");quit(1 if failures else 0)
