extends SceneTree
const Support=preload("res://Presentation/SupportPlan.gd")
const Reviews=preload("res://Presentation/ReviewedCatalog.gd")
const Geometry=preload("res://Presentation/GeometryLibrary.gd")
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
 # Bridge context: stone pier towers/parapets, never plaster house walls.
 var names:={"1994":{"name":"wooden bridge","height":1,"flags":0x200},"1872":{"name":"stone","height":10,"flags":0x600},"94":{"name":"window","height":20,"flags":0x1050},"99":{"name":"stone wall","height":5,"flags":0x50},"310":{"name":"plaster wall","height":20,"flags":0x50},"6039":{"name":"water","height":0,"flags":0x80},"87":{"name":"stone wall","height":20,"flags":0x50},"2567":{"name":"wall torch","height":15,"flags":0x4}}
 for origin in [Vector2i(500,500),Vector2i(1381,1743)]:
  var bridge_world:={"elevationScale":.2,"originX":origin.x,"originY":origin.y,"terrain":[],"statics":[],"staticData":names,"landData":{}}
  for x in 4:
   bridge_world.terrain.append({"x":origin.x+x,"y":origin.y+1,"z":-15,"id":2})
   bridge_world.terrain.append({"x":origin.x+x,"y":origin.y,"z":-15,"id":2})
   bridge_world.statics.append({"x":origin.x+x,"y":origin.y+1,"z":-5,"id":6039})
   bridge_world.statics.append({"x":origin.x+x,"y":origin.y+1,"z":0,"id":1994})
   bridge_world.statics.append({"x":origin.x+x,"y":origin.y,"z":-5,"id":6039})
  for z in [-15,-10]:bridge_world.statics.append({"x":origin.x+1,"y":origin.y,"z":z,"id":1872})
  bridge_world.statics.append({"x":origin.x+1,"y":origin.y,"z":-5,"id":94})
  bridge_world.statics.append({"x":origin.x+2,"y":origin.y,"z":0,"id":99})
  bridge_world.statics.append({"x":origin.x+3,"y":origin.y,"z":0,"id":310})
  bridge_world.statics.append({"x":origin.x+20,"y":origin.y,"z":0,"id":94})
  var unchanged:=JSON.stringify(bridge_world)
  var bridge_recon:=preload("res://Presentation/Reconstruction.gd").new()
  bridge_recon.index(bridge_world)
  var plan: Dictionary=bridge_recon.bridges.parapets
  var pier_window: int=bridge_world.statics.size()-4
  check(bridge_recon.bridges.decks.size()==4,"Plank deck over a water riverbed is recognized as bridge deck: "+str(origin))
  check(plan.get(pier_window,{}).get("reason","")=="stands on bridge pier" and plan[pier_window].family=="stone" and plan[pier_window].opening=="slit","Window art on a bridge pier becomes a stone tower with a slit opening: "+str(origin))
  check(plan.get(pier_window+1,{}).get("reason","")=="parapet along bridge deck edge","Low stone wall beside the deck is a bridge parapet: "+str(origin))
  check(not plan.has(pier_window+2),"Explicit plaster construction beside a bridge keeps its building treatment")
  check(not plan.has(pier_window+3),"Same window graphic away from a bridge is not reinterpreted as a parapet")
  var tower: Node3D=bridge_recon.build(bridge_world.statics[pier_window],bridge_world,pier_window)
  var iron:=0
  var frames:=0
  for mesh in tower.find_children("*","MeshInstance3D",true,false):
   if mesh.material_override==bridge_recon.facade.iron_material:iron+=1
  for node in tower.find_children("*","Node3D",true,false):
   if node.scene_file_path.contains("Window_Wide"):frames+=1
  check(iron==3 and frames==0,"Pier slit keeps its barred opening without a timber casement")
  tower.free()
  check(JSON.stringify(bridge_world)==unchanged,"Bridge planning leaves canonical source records untouched")
 for id in [93,94,202,203]:check(Reviews.entry(id).get("facadeFamily","")=="stone" and Reviews.entry(id).get("opening","")=="slit","Generic window name keeps its inspected stone slit art: "+str(id))
 check(Reviews.entry(59).get("facadeFamily","")=="brick" and Reviews.entry(141).get("opening","")=="arched","Brick and ashlar arched windows keep their inspected material")
 # Wall-hung torches attach to the adjacent source wall face.
 var mount_world:={"elevationScale":.2,"originX":600,"originY":600,"terrain":[],"statics":[{"x":600,"y":599,"z":20,"id":87},{"x":600,"y":600,"z":20,"id":87},{"x":600,"y":601,"z":20,"id":87},{"x":601,"y":600,"z":32,"id":2567},{"x":610,"y":610,"z":32,"id":2567}],"staticData":names,"landData":{}}
 var mount_recon:=preload("res://Presentation/Reconstruction.gd").new()
 mount_recon.index(mount_world)
 check(preload("res://Presentation/RegionalRules.gd").resolve(6428,{"name":"bar","height":8}).get("kind","")=="counter","Legacy bar art is a serving counter, not a fence")
 check(mount_recon.rule_for(2567).get("kind","")=="prop" and mount_recon.rule_for(2567).get("model","")=="wall_light","Wall torch name is an attachment, not a plaster wall")
 var hung: Dictionary=mount_recon.presentation_adjustments.get(3,{})
 check(hung.get("offset",Vector3.ZERO).is_equal_approx(Vector3(-.91,0,0)) and is_equal_approx(float(hung.get("yaw",0)),-PI/2),"Torch hangs on the west wall face and faces east")
 check(not mount_recon.presentation_adjustments.get(4,{}).has("offset"),"Torch without a source wall is not moved")
 # Source-backed contact on unreviewed procedural tables, rugs and stacks.
 var contact:=Support.new()
 contact.catalog={"2947":{"kind":"table"},"22224":{"kind":"carpet"}}
 var plate:={"id":2519,"x":700,"y":700,"z":6}
 var stacked:={"id":4014,"x":701,"y":700,"z":6}
 var bed:={"id":2681,"x":702,"y":700,"z":22}
 var stray:={"id":2681,"x":703,"y":700,"z":40}
 contact.index({"elevationScale":.2,"terrain":[{"x":700,"y":700,"z":0},{"x":701,"y":700,"z":0},{"x":702,"y":700,"z":0},{"x":703,"y":700,"z":0}],"statics":[{"id":2947,"x":700,"y":700,"z":0},{"id":4014,"x":701,"y":700,"z":0},{"id":1309,"x":702,"y":700,"z":20},{"id":22224,"x":702,"y":700,"z":20},plate,stacked,bed,stray],"staticData":{"2947":{"height":6,"flags":0x200},"4014":{"height":3,"flags":0},"1309":{"height":0,"flags":0x200},"22224":{"height":1,"flags":0}}})
 check(is_equal_approx(contact.placement(plate).offset.y,Geometry.furniture_height("table")-1.2),"Item on an unreviewed table rests on the procedural table top")
 check(is_equal_approx(contact.placement(stacked).offset.y,float(Reviews.entry(4014).dimensions[1])-1.2),"Stacked barrel rests on the reviewed barrel below")
 check(is_equal_approx(contact.placement(bed).offset.y,4.0+Geometry.CARPET_LIFT-4.4),"Bed on a legacy rug rests on the rug surface")
 check(contact.placement(stray).status=="unsupported-candidate","Bed with no source support remains an unresolved candidate")
 print("ART FIDELITY TESTS: ",checks," checks / ",failures," failures")
 quit(1 if failures else 0)
