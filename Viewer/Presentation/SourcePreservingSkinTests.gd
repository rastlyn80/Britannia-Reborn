extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
 create_timer(180.).timeout.connect(func():push_error("Preserving skin deadline");quit(1));call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  if failures<8:push_error(message)
func skinned(mesh: MeshInstance3D,rig: Skeleton3D) -> PackedVector3Array:
 var transforms: Array[Transform3D]=[]
 for bind in mesh.skin.get_bind_count():
  var bone:=mesh.skin.get_bind_bone(bind)
  if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
  transforms.append(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
 var a:=mesh.mesh.surface_get_arrays(0);var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var b: PackedInt32Array=a[Mesh.ARRAY_BONES];var w: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=b.size()/p.size();var result:=PackedVector3Array()
 for vertex in p.size():
  var point:=Vector3.ZERO
  for slot in stride:point+=(transforms[b[vertex*stride+slot]]*p[vertex])*w[vertex*stride+slot]
  result.append(point)
 return result
func edge_distance(p: Vector3,a: Vector3,b: Vector3) -> float:
 var d:=b-a;return p.distance_to(a+d*clampf((p-a).dot(d)/maxf(d.length_squared(),1e-20),0.,1.))
func triangle_distance(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> float:
 var u:=b-a;var v:=c-a;var n:=u.cross(v);var nn:=n.length_squared()
 if nn>1e-20:
  var projected:=p-n*((p-a).dot(n)/nn);var q:=projected-a;var uu:=u.dot(u);var vv:=v.dot(v);var uv:=u.dot(v);var den:=uu*vv-uv*uv
  if den>1e-20:
   var s:=(q.dot(u)*vv-q.dot(v)*uv)/den;var t:=(q.dot(v)*uu-q.dot(u)*uv)/den
   if s>=0. and t>=0. and s+t<=1.:return p.distance_to(projected)
 return minf(edge_distance(p,a,b),minf(edge_distance(p,b,c),edge_distance(p,c,a)))
func run() -> void:
 check(is_equal_approx(triangle_distance(Vector3(.2,.2,.1),Vector3.ZERO,Vector3.RIGHT,Vector3.UP),.1),"Interior projection analytic distance")
 check(is_equal_approx(triangle_distance(Vector3(2.,0.,0.),Vector3.ZERO,Vector3.RIGHT,Vector3.UP),1.),"Outside triangle analytic distance")
 var prepared_path:="res://local-art/creatures/source_preserving/preparation.json"
 var prepared: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prepared_path))
 check(prepared.manifest_sha256==FileAccess.get_sha256("res://../scripts/source-preserving-inputs.json"),"Pinned source manifest unchanged")
 check(prepared.preparer_sha256==FileAccess.get_sha256("res://../scripts/prepare-source-preserving.py"),"Pinned source preparer unchanged")
 check(prepared.baker_sha256==FileAccess.get_sha256("res://Presentation/BakeSourcePreserving.gd"),"Pinned scene baker unchanged")
 check(prepared.subdivision_sha256==FileAccess.get_sha256("res://Presentation/SourcePoseSubdivision.gd"),"Pinned conditional-bind implementation unchanged")
 var rows: Array=[]
 for record: Dictionary in prepared.models:
  var kind:=str(record.kind)
  for treatment: String in record.assets:check(FileAccess.get_sha256(str(record.assets[treatment]))==record.saved_scenes[treatment].scene_sha256,"Actual saved source/dense scene matches receipt")
  var coarse: Node3D=load(str(record.assets.original)).instantiate();var dense: Node3D=load(str(record.assets.rounded)).instantiate();root.add_child(coarse);root.add_child(dense)
  var rigs: Array=[coarse.find_children("*","Skeleton3D",true,false)[0],dense.find_children("*","Skeleton3D",true,false)[0]];var players: Array=[coarse.find_children("*","AnimationPlayer",true,false)[0],dense.find_children("*","AnimationPlayer",true,false)[0]];var meshes: Array=[coarse.find_children("*","MeshInstance3D",true,false)[0],dense.find_children("*","MeshInstance3D",true,false)[0]]
  var source: PackedInt32Array=meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX];var refined: PackedInt32Array=meshes[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
  check(refined.size()==source.size()*16,"Actual source triangles subdivided sixteen-fold")
  check(rigs[0].get_bone_count()==rigs[1].get_bone_count(),"Original source bone count retained")
  for player: AnimationPlayer in players:player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var poses:=0;var maximum:=0.;var clips: Array=[]
  for name: String in players[0].get_animation_list():
   if name=="RESET":continue
   clips.append(name)
   for phase: float in [.173,.479,.817]:
    for i in 2:
     players[i].play(name,0.);players[i].seek(players[i].get_animation(name).length*phase,true);players[i].advance(0.);players[i].pause();rigs[i].force_update_all_bone_transforms()
    var a:=skinned(meshes[0],rigs[0]);var b:=skinned(meshes[1],rigs[1]);var error:=0.
    for triangle in source.size()/3:
     var x: Vector3=a[source[triangle*3]];var y: Vector3=a[source[triangle*3+1]];var z: Vector3=a[source[triangle*3+2]]
     for corner in 48:error=maxf(error,triangle_distance(b[refined[triangle*48+corner]],x,y,z))
    maximum=maxf(maximum,error);poses+=1;check(error<.002,"Complete refined source skin stays within2mm of its parent posed triangles: "+kind+"/"+name)
  # Temporary in-memory routing exercises the same creature/corpse factory
  # without accepting a new body or changing the persistent index.
  var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
  for identity: Dictionary in record.bodies:
   var body:=int(identity.body);var old: Variant=registry.entries.get(body,null);registry.entries[body]=record
   for hue: int in [0,0x515,0x8515]:
    var corpse: Node3D=preload("res://Presentation/CorpseModels.gd").build(body,hue)
    check(corpse!=null,"Native static corpse factory supports candidate body/hue")
    if corpse!=null:
     check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","AnimationPlayer",true,false).is_empty(),"Static candidate corpse has no live rig/player")
     check(not corpse.find_children("*","MeshInstance3D",true,false).is_empty(),"Static candidate corpse retains posed geometry")
     check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==body and corpse.get_meta("native_hue")==hue,"Native corpse graphic/body/raw hue are preserved")
     check(int(corpse.get_meta("vertices"))==int(record.saved_scenes.modern.vertices),"Invisible source control surface is excluded from the cadaver")
     corpse.free()
   if old==null:registry.entries.erase(body)
   else:registry.entries[body]=old
  rows.append({"kind":kind,"poses":poses,"clips":clips,"maximum_source_triangle_distance_m":maximum,"source_bones":rigs[0].get_bone_count(),"source_triangles":source.size()/3,"dense_triangles":refined.size()/3})
  print("PRESERVING SKIN ",kind," / ",poses," poses / max ",maximum,"m");coarse.free();dense.free()
 FileAccess.open("res://../work/creatures/source-preserving/skin-proof.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"models":rows,"preparation_sha256":FileAccess.get_sha256(prepared_path),"test_sha256":FileAccess.get_sha256("res://Presentation/SourcePreservingSkinTests.gd"),"helper_sha256":FileAccess.get_sha256("res://Presentation/SourcePoseSubdivision.gd"),"scope":"Actual saved scene complete weighted skins and temporary candidate corpse factory against geometric distance to each corresponding original posed triangle; three declared off-grid phases/all available baked clips,2mm bound including1.5mm normal offset. Original GRN affine/interpolation, raw GRN-to-scene precision, terrain/native/route acceptance remain separate."},"\t"))
 print("PRESERVING SKIN: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
