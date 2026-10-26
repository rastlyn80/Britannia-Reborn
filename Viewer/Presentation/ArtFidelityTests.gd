extends SceneTree
const Support=preload("res://Presentation/SupportPlan.gd")
const Reviews=preload("res://Presentation/ReviewedCatalog.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func _initialize() -> void:
 var support:=Support.new()
 var counter:={"id":2880,"x":1301,"y":1401,"z":20}
 var jug:={"id":2504,"x":1301,"y":1401,"z":26}
 var barrel1:={"id":3703,"x":1302,"y":1401,"z":20}
 var barrel2:={"id":3703,"x":1302,"y":1401,"z":25}
 var world:={"elevationScale":.2,"terrain":[{"x":1301,"y":1401,"z":20},{"x":1302,"y":1401,"z":20}],"statics":[counter,barrel1,barrel2],"staticData":{"2880":{"height":6,"flags":0x200},"3703":{"height":5,"flags":0x40}}}
 support.index(world)
 var original:=jug.duplicate(true)
 check(is_equal_approx(support.placement(jug).offset.y,-.2),"Native counter-contact elevation follows the reviewed one-metre surface")
 check(jug==original,"Contact correction preserves source ID and authoritative XYZ")
 check(is_equal_approx(support.placement(barrel2).offset.y,-.05),"Stacked barrels rest on the actual replacement barrel height")
 var unsupported:=jug.merged({"x":1350},true)
 check(support.placement(unsupported).status=="unsupported-candidate" and support.placement(unsupported).offset==Vector3.ZERO,"Uncertain support is reported instead of speculative snapping")
 var upstairs:=jug.merged({"z":46},true)
 check(support.placement(upstairs).status=="unsupported-candidate","Support search cannot snap an upper-storey object to furniture below")
 world.statics.append({"id":500,"x":1301,"y":1401,"z":46})
 world.staticData["500"]={"flags":0x200,"height":0}
 support.index(world)
 check(support.placement(upstairs).status=="supported" and support.placement(upstairs).offset==Vector3.ZERO,"A legitimate same-Z upper-storey floor supports its own objects")
 var table:={"id":2931,"x":1301,"y":1401,"z":20}
 world.statics=[table];world.staticData={"2931":{"height":6,"flags":0x200},"4006":{"height":1,"flags":0x200}}
 support.index(world)
 var board:={"id":4006,"x":1301,"y":1401,"z":24}
 var pieces:={"id":3603,"x":1301,"y":1401,"z":24}
 support.dynamic={1:board,2:pieces}
 check(is_equal_approx(support.placement(board).offset.y,.02),"Native four-unit table placements use bounded legacy contact tolerance")
 check(is_equal_approx(support.placement(pieces).offset.y,.068),"Same-native-Z chess pieces sit above their reviewed board without a support cycle")
 var moved:=world.duplicate(true)
 for tile in moved.terrain:tile.x+=73;tile.y-=52
 for tile in moved.statics:tile.x+=73;tile.y-=52
 support.dynamic.clear();support.index(moved)
 var translated:=board.merged({"x":1374,"y":1349},true)
 check(is_equal_approx(support.placement(translated).offset.y,.02),"Support relationships survive coordinate translation")
 var r:=Reviews.entry(2902);var east:=Vector3.BACK.rotated(Vector3.UP,deg_to_rad(r.yawDegrees))
 check(east.is_equal_approx(Vector3.RIGHT),"Reviewed west-side chair faces east into its native table")
 check(Vector3.BACK.rotated(Vector3.UP,deg_to_rad(Reviews.entry(2904).yawDegrees)).is_equal_approx(Vector3.LEFT),"Opposite chair graphic faces west rather than duplicating the first orientation")
 var recon:=preload("res://Presentation/Reconstruction.gd").new()
 for id in [2931,2911,2653,2902,2718,3650]:
  var node: Node3D=Reviews.build(recon,id)
  var boxes: Array=[];recon._collect_bounds(node,Transform3D.IDENTITY,boxes)
  var bounds: AABB=boxes[0]
  for box in boxes:bounds=bounds.merge(box)
  check(absf(bounds.position.y)<.001,"Imported reviewed model bottom aligns with support plane: "+str(id))
  node.free()
 var book: Node3D=Reviews.build(recon,4030)
 var boxes: Array=[];recon._collect_bounds(book,Transform3D.IDENTITY,boxes)
 check(boxes[0].size.y<.071,"Standing publisher book is oriented flat before bound normalization")
 book.free()
 var bottle: Node3D=Reviews.build(recon,2503)
 var colored:=false
 var cork:=false
 var vertex_material:=false
 for mesh in bottle.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   vertex_material=vertex_material or mesh.get_active_material(surface).vertex_color_use_as_albedo
   for color in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
    colored=colored or color.g>color.r*2
    cork=cork or color.r>color.g
 check(vertex_material,"Publisher vertex colours are enabled instead of rendering every prop as pale ceramic")
 check(colored and cork,"Reviewed wine pigment preserves a green body and a separate brown cork")
 bottle.free()
 var ale: Node3D=Reviews.build(recon,2459)
 var green:=false
 for mesh in ale.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   for color in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:green=green or color.g>color.r*2
 check(not green,"Wine palette customization cannot mutate the shared downloaded ale mesh")
 ale.free()
 check(Reviews.dimensions(Reviews.entry(2931),{"size":Vector2(2,5)}).is_equal_approx(Vector3(5,.82,2)),"Multi-piece table retains its complete native footprint and reviewed top height")
 print("ART FIDELITY TESTS: ",checks," checks / ",failures," failures")
 quit(1 if failures else 0)
