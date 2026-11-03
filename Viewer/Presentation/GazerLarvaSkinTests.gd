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

const INPUT := "res://local-art/creatures/gazer_larva/"
func run() -> void:
 var original: Node3D=(load(INPUT+"swarm-exact-source.scn") as PackedScene).instantiate()
 var refined: Node3D=(load(INPUT+"swarm-body-refined.scn") as PackedScene).instantiate()
 root.add_child(original);root.add_child(refined)
 var source_rig: Skeleton3D=original.find_children("*","Skeleton3D",true,false)[0]
 var target_rig: Skeleton3D=refined.find_children("*","Skeleton3D",true,false)[0]
 var source_player: AnimationPlayer=original.find_children("*","AnimationPlayer",true,false)[0]
 var target_player: AnimationPlayer=refined.find_children("*","AnimationPlayer",true,false)[0]
 var source: MeshInstance3D=original.find_children("*","MeshInstance3D",true,false)[0]
 var cards: MeshInstance3D=refined.find_child("OriginalCards",true,false)
 var body: MeshInstance3D
 for mesh: MeshInstance3D in refined.find_children("*","MeshInstance3D",true,false):
  if mesh!=cards:body=mesh
 var arrays:=source.mesh.surface_get_arrays(0)
 var indices:=PackedInt32Array()
 if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
 else:
  for index in arrays[Mesh.ARRAY_VERTEX].size():indices.append(index)
 var links: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/gazer-larva/owned-source/card-bindings.json"))
 var leaves: Dictionary={}
 for part: Dictionary in links.parts:leaves[source_rig.find_bone(str(part.name))]=true
 var card_indices:=PackedInt32Array();var body_indices:=PackedInt32Array()
 for offset in range(0,indices.size(),3):
  var triangle:=indices.slice(offset,offset+3)
  var card:=true;var leaf:=-1
  for corner in triangle.size():
   var vertex:=triangle[corner]
   var bind: int=arrays[Mesh.ARRAY_BONES][vertex*4]
   var joint:=source.skin.get_bind_bone(bind)
   if joint<0:joint=source_rig.find_bone(source.skin.get_bind_name(bind))
   if corner==0:leaf=joint
   if joint!=leaf or not leaves.has(joint) or not is_equal_approx(arrays[Mesh.ARRAY_WEIGHTS][vertex*4],1.):
    card=false;break
  if card:card_indices.append_array(triangle)
  else:body_indices.append_array(triangle)
 check(card_indices.size()==126 and body_indices.size()==2346,"Source triangles partition exactly")
 check(source_player.get_animation_list()==target_player.get_animation_list(),"All source clips retained")
 var refined_indices: PackedInt32Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
 var max_card:=0.;var max_body:=0.;var poses:=0
 var samples: Array=[]
 for clip: String in source_player.get_animation_list():
  for phase in [.1731,.4349,.8267]:
   for player in [source_player,target_player]:
    player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.pause()
   source_rig.force_update_all_bone_transforms();target_rig.force_update_all_bone_transforms()
   var source_points:=skinned(source,source_rig)
   var card_points:=skinned(cards,target_rig)
   var body_points:=skinned(body,target_rig)
   check(card_points.size()==126 and refined_indices.size()==9384,"All split corners present")
   var card_error:=0.;var body_error:=0.
   for corner in card_points.size():
    card_error=maxf(card_error,card_points[corner].distance_to(source_points[card_indices[corner]]))
   for corner in refined_indices.size():
    var index:=floori(corner/12.)*3
    body_error=maxf(body_error,triangle_distance(body_points[refined_indices[corner]],source_points[body_indices[index]],
     source_points[body_indices[index+1]],source_points[body_indices[index+2]]))
   check(card_error<.00005,clip+" card positions differ by "+str(card_error))
   check(body_error<.002,clip+" body surface differs by "+str(body_error))
   max_card=maxf(max_card,card_error);max_body=maxf(max_body,body_error);poses+=1
   samples.append({"clip":clip,"phase":phase,"card_error_m":card_error,"body_error_m":body_error})
 var proof: Dictionary={"checks":checks,"failures":failures,"poses":poses,"samples":samples,
  "max_card_m":max_card,"max_body_m":max_body,"source_sha256":FileAccess.get_sha256(INPUT+"swarm-exact-source.scn"),
  "refined_sha256":FileAccess.get_sha256(INPUT+"swarm-body-refined.scn")}
 FileAccess.open("res://../work/creatures/gazer-larva/owned-source/refined-motion.json",FileAccess.WRITE).store_string(JSON.stringify(proof,"\t"))
 print("GAZER REFINED MOTION: ",checks," checks / ",failures," failures / ",poses," poses; card ",max_card,"m, body ",max_body,"m")
 quit(1 if failures else 0)
