extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,text:String)->void:
 checks+=1
 if ok:print("PASS ",text)
 else:failures+=1;push_error(text)
class Fixture extends RefCounted:
 var manifest:Dictionary
 var sources:Dictionary={}
 func _init()->void:
  manifest={"originX":0,"originY":0,"width":128,"height":64,"chunks":[{"x":0,"y":0},{"x":64,"y":0}],"landData":{"0":{"name":"grass","flags":64}},"staticData":{"60000":{"name":"stone wall","height":20},"60001":{"name":"thatch roof","height":3},"60002":{"name":"wooden boards","height":0},"60003":{"name":"bench","height":1}}}
  for at in [Vector2i(0,0),Vector2i(64,0)]:
   var source:Dictionary={"terrain":[],"statics":[]}
   for y in 64:
    for x in 64:source.terrain.append({"x":at.x+x,"y":y,"z":30 if at.x+x==64 and y==20 else 0,"id":0})
   for x in range(60,69):
    if x<at.x or x>=at.x+64:continue
    for entry in [[60000,4,0],[60001,5,20],[60002,5,0]]:source.statics.append({"x":x,"y":entry[1],"z":entry[2],"id":entry[0],"hue":0})
   for x in [63,64]:
    if x>=at.x and x<at.x+64:source.statics.append({"x":x,"y":8,"z":0,"id":60003,"hue":0})
   sources[at]=source
 func chunk(at:Vector2i)->Dictionary:return sources.get(at,{"terrain":[],"statics":[]})
func _initialize()->void:call_deferred("run")
func boundary(mesh:ArrayMesh,x:float)->Dictionary:
 var arrays:=mesh.surface_get_arrays(0)
 var result:Dictionary={}
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for i in vertices.size():
  if absf(vertices[i].x-x)<0.00001:result[roundi(vertices[i].z*4)]={"height":vertices[i].y,"normal":normals[i]}
 return result
func run()->void:
 var data:=Fixture.new()
 var plan:=preload("res://Presentation/RegionalContext.gd").new()
 plan.prepare(data)
 var roof_left:=-1
 var roof_right:=-1
 var bench_owner:=-1
 var bench_members:=0
 for i in plan.world.statics.size():
  var source:Dictionary=plan.world.statics[i]
  if source.id==60001 and source.x==63:roof_left=i
  if source.id==60001 and source.x==64:roof_right=i
  if source.id==60003:
   bench_members+=1
   if bench_owner<0:bench_owner=int(plan.reconstruction.groups[i].owner)
   check(int(plan.reconstruction.groups[i].owner)==bench_owner,"cross-chunk furniture uses one stable group owner")
 check(bench_members==2,"both source furniture records retained")
 var a:Dictionary=plan.reconstruction.roofs.tiles[roof_left]
 var b:Dictionary=plan.reconstruction.roofs.tiles[roof_right]
 check(a.component==b.component and not a.exposed[1] and not b.exposed[3],"a roof crossing x=64 has no internal eaves or duplicate closure")
 check(is_equal_approx(a.heights[2],b.heights[0]) and is_equal_approx(a.heights[5],b.heights[3]) and is_equal_approx(a.heights[8],b.heights[6]),"all roof corner/midpoint heights agree on the chunk boundary")
 check(a.normals[2].is_equal_approx(b.normals[0]) and a.normals[5].is_equal_approx(b.normals[3]) and a.normals[8].is_equal_approx(b.normals[6]),"roof lighting normals agree across chunk boundaries")
 var left:=plan.surface.build(Rect2i(0,0,64,64))
 var right:=plan.surface.build(Rect2i(64,0,64,64))
 var left_edge:=boundary(left,64)
 var right_edge:=boundary(right,64)
 check(left_edge.size()>60 and left_edge.size()==right_edge.size(),"adjacent terrain chunks both include the same boundary samples")
 var same:=true
 for key in left_edge:
  if not right_edge.has(key) or absf(left_edge[key].height-right_edge[key].height)>0.00001 or not left_edge[key].normal.is_equal_approx(right_edge[key].normal):same=false
 plan.surface.heights.clear()
 var reloaded:=plan.surface.build(Rect2i(0,0,64,64))
 check(reloaded.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==left.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"terrain eviction/rebuild reproduces identical geometry")
 check(same,"terrain positions and lighting normals match exactly across chunks")
 check(plan.surface.samples[Vector2i(64,20)].z==30 and plan.surface.peak_repairs.has(Vector2i(64,20)),"boundary spike repair leaves native elevation unchanged")
 var floor_left:=-1
 var floor_right:=-1
 for i in plan.world.statics.size():
  var source:Dictionary=plan.world.statics[i]
  if source.id==60002 and source.x==63:floor_left=i
  if source.id==60002 and source.x==64:floor_right=i
 var slab_a:Node3D=plan.reconstruction.build(plan.world.statics[floor_left],plan.world,floor_left)
 var slab_b:Node3D=plan.reconstruction.build(plan.world.statics[floor_right],plan.world,floor_right)
 check(is_equal_approx(slab_a.position.y,slab_b.position.y),"cross-chunk floor slabs retain one native storey height")
 slab_a.free();slab_b.free()
 var shapes:=preload("res://Presentation/RegionalRules.gd")
 check(shapes.resolve(61000,{"name":"stone pavers","height":0}).surface=="stone","paving receives stone material rather than wooden floor material")
 check(shapes.resolve(61001,{"name":"no draw","height":0}).kind=="invisible","native invisible markers are explicitly accounted without fake props")
 check(preload("res://Presentation/GeometryLibrary.gd").roof_height(0.5,0.5,{"profile":"flat"})==0.0,"flat castle roofs do not acquire a per-tile ridge")
 var fixture_corner:Dictionary={"staticData":{"61010":{"name":"stone wall","height":20},"61011":{"name":"stone wall","height":20}},"statics":[{"id":61010,"x":10,"y":10,"z":0},{"id":61011,"x":11,"y":10,"z":0},{"id":61011,"x":10,"y":11,"z":0}]}
 var corner_rules:Dictionary={}
 shapes.extend(fixture_corner,corner_rules)
 check(corner_rules["61010"].kind=="corner","new stone corner IDs are sealed from perpendicular source adjacency")
 var owned_mesh:=preload("res://Presentation/SourceOwnership.gd").mesh(BoxMesh.new(),0,{"x":64,"y":32})
 var batch:=SurfaceTool.new();batch.begin(Mesh.PRIMITIVE_TRIANGLES)
 batch.append_from(owned_mesh,0,Transform3D(Basis.IDENTITY,Vector3(63,0,0)))
 var batched:=batch.commit()
 var owners:PackedVector2Array=batched.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
 var all_owned:=not owners.is_empty()
 for value in owners:
  if value!=Vector2(64,0):all_owned=false
 check(all_owned,"batched roof overhang retains its source chunk instead of switching at the visible edge")
 check(shapes.resolve(61090,{"name":"mysterious residue","height":4}).is_empty(),"future unsupported graphic families remain visible diagnostics rather than falsely completed mappings")
 var no_metadata:Dictionary={}
 shapes.extend({"staticData":null,"statics":[]},no_metadata)
 check(no_metadata.is_empty(),"synthetic IR without tiledata remains supported without inventing mappings")
 var movement:=preload("res://Presentation/MovementSurface.gd").new()
 movement.index({"landData":null,"staticData":null,"terrain":[],"statics":[]})
 check(movement.land_data.is_empty() and movement.static_data.is_empty(),"fixture movement indexing accepts explicitly null metadata without a script error")
 var uv_origin:Vector2=preload("res://Presentation/SurfaceLibrary.gd").source_origin
 check(uv_origin==Vector2.ZERO,"global-coordinate chunks share texture/water phase with no second origin offset")
 print("REGIONAL SEAMS: %d/%d" % [checks-failures,checks])
 quit(0 if failures==0 else 1)
