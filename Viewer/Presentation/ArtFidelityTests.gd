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
 # Sea land renders as a lowered bed under one water surface; river water
 # objects are not doubled; floors at ground height never z-fight terrain.
 var Terrain:=preload("res://Presentation/TerrainSurface.gd")
 var sea_world:={"elevationScale":.2,"originX":800,"originY":800,"width":4,"height":2,"terrain":[],"statics":[{"x":801,"y":800,"z":-5,"id":6039},{"x":803,"y":801,"z":0,"id":1993}],"landData":{"168":{"name":"water"},"3":{"name":"grass"}},"staticData":{"6039":{"name":"water","height":0},"1993":{"name":"wooden plank","height":1,"flags":0x200}}}
 for y in 2:
  for x in 4:sea_world.terrain.append({"x":800+x,"y":800+y,"z":-5 if x<2 else 0,"id":168 if x<2 else 3})
 var sea:=Terrain.new();sea.index(sea_world)
 check(is_equal_approx(sea.z(Vector2i(800,800)),-1.0-Terrain.SEABED_DEPTH) and is_equal_approx(sea.raw_z(Vector2i(800,800)),-1.0),"Sea land is presented as a bed below its canonical source surface")
 var water_mesh: ArrayMesh=sea.sea_mesh(Rect2i(800,800,4,2))
 check(water_mesh!=null and water_mesh.surface_get_array_len(0)==18,"One sea quad per open-water cell, none where a river water object already exists")
 check(sea.z(Vector2i(803,801))<0.0 and is_equal_approx(sea.raw_z(Vector2i(803,801)),0.0),"Terrain under a ground-level plank floor drops below the deck")
 # Stone wall tops are masonry, never the plaster/timber kit model.
 var merlon_world:={"elevationScale":.2,"originX":900,"originY":900,"terrain":[],"statics":[{"x":900,"y":900,"z":40,"id":99}],"staticData":{"99":{"name":"stone wall","height":5,"flags":0x50}},"landData":{}}
 var merlon_recon:=preload("res://Presentation/Reconstruction.gd").new()
 merlon_recon.index(merlon_world)
 var merlon: Node3D=merlon_recon.build(merlon_world.statics[0],merlon_world,0)
 var kit:=0
 for node in merlon.find_children("*","Node3D",true,false):
  if node.scene_file_path.contains("Village/"):kit+=1
 check(kit==0 and merlon.find_children("*","MeshInstance3D",true,false).size()==2,"Stone merlon is solid masonry with a coping, not a kit wall")
 merlon.free()
 # Close studding never crosses a source window opening.
 var tudor:=preload("res://Presentation/Facade.gd").new()
 var window_panel:=tudor.panel(4.0,true,{"offset":1,"length":3,"run":1},"plaster")
 var sill:=minf(1.05,4.0*0.28);var top_of_opening:=sill+minf(1.4,4.0*0.46)
 var crossing:=false
 var studs:=0
 for mesh in window_panel.find_children("*","MeshInstance3D",true,false):
  var box: Vector3=mesh.mesh.size if mesh.mesh is BoxMesh else Vector3.ZERO
  var oak: bool=mesh.material_override==tudor.material("oak") or mesh.material_override==tudor.capless_materials.get("oak")
  if oak:studs+=int(absf(box.x-0.11)<0.001)
  if oak and absf(box.x-0.11)<0.001 and mesh.position.y-box.y/2<top_of_opening-0.01 and mesh.position.y+box.y/2>sill+0.01:crossing=true
 check(studs==4 and not crossing,"Tudor studs stop at the sill and head of a window opening")
 window_panel.free()
 # Stair facing comes from tiledata flags, not an ambiguous neighbour guess.
 var stair_floor:=preload("res://Presentation/FloorPlan.gd").new()
 var stair_world:={"elevationScale":.2,"statics":[],"staticData":{}}
 var expected:=[Vector2(0,-1),Vector2(1,0),Vector2(-1,0),Vector2(0,1)]
 for k in 4:
  stair_world.statics.append({"x":1000+k*5,"y":1000,"z":0,"id":7000+k})
  stair_world.staticData[str(7000+k)]={"name":"stone stairs","height":5,"flags":0x2600|(0x40000000 if k in [1,3] else 0)|(0x80000000 if k in [2,3] else 0)}
 stair_floor.index(stair_world,{"7000":{"kind":"stairs"},"7001":{"kind":"stairs"},"7002":{"kind":"stairs"},"7003":{"kind":"stairs"}})
 check(range(4).all(func(k): return stair_floor.stair_rise.get(k,Vector2.ZERO)==expected[k]),"Isolated stair tiles rise north/east/west/south from their tiledata facing flags")
 # Roof ends take the material of the walls under the roof, not plaster.
 var roof_world:={"elevationScale":.2,"originX":1100,"originY":1100,"width":12,"height":12,"terrain":[],"statics":[{"x":1100,"y":1100,"z":0,"id":53},{"x":1101,"y":1100,"z":0,"id":53},{"x":1100,"y":1100,"z":25,"id":1441},{"x":1110,"y":1110,"z":0,"id":310},{"x":1110,"y":1110,"z":25,"id":1441}],"staticData":{"53":{"name":"brick wall","height":20},"310":{"name":"plaster wall","height":20},"1441":{"name":"slate roof","height":3,"flags":0x10000000}},"landData":{}}
 var roof_recon:=preload("res://Presentation/Reconstruction.gd").new()
 roof_recon.index(roof_world)
 check(roof_recon.roof_families.get(2,"")=="brick" and roof_recon.roof_families.get(4,"")=="plaster","Roof gable ends follow the brick or plaster walls beneath each roof")
 # Vegetation roots on planters and on the rendered (interpolated) terrain.
 check(preload("res://Presentation/RegionalRules.gd").resolve(2,{"name":"FlowerBed Corner NOR","height":5}).get("kind","")=="planter","Flower bed pieces are planters, not flower tufts")
 var veg_world:={"elevationScale":.2,"originX":1200,"originY":1200,"width":4,"height":4,"terrain":[],"statics":[{"x":1200,"y":1200,"z":0,"id":9001},{"x":1200,"y":1200,"z":5,"id":9002},{"x":1202,"y":1201,"z":10,"id":9003},{"x":1203,"y":1203,"z":60,"id":9002}],"staticData":{"9001":{"name":"FlowerBed Middle EAS","height":5},"9002":{"name":"red poppies","height":0},"9003":{"name":"oak tree","height":20}},"landData":{"3":{"name":"grass"}}}
 for y in 4:
  for x in 4:veg_world.terrain.append({"x":1200+x,"y":1200+y,"z":x*5,"id":3})
 var veg_recon:=preload("res://Presentation/Reconstruction.gd").new()
 veg_recon.index(veg_world)
 var veg_terrain:=preload("res://Presentation/TerrainSurface.gd").new();veg_terrain.index(veg_world)
 veg_recon.terrain_surface=veg_terrain
 check(is_equal_approx(veg_recon.vegetation_ground(veg_world.statics[1],veg_world),1.0),"Flower on a raised bed roots on the bed top")
 check(is_equal_approx(veg_recon.vegetation_ground(veg_world.statics[2],veg_world),veg_terrain.height_at(Vector2(1202.5,1201.5))),"Tree on a slope roots on the rendered terrain at its tile centre")
 check(is_nan(veg_recon.vegetation_ground(veg_world.statics[3],veg_world)),"Vegetation far above any ground keeps its source height")
 # Owner-licensed trees are optional: absent -> CC0 fallback; present ->
 # uniformly scaled, bottom-centred and deterministic per source cell.
 var LocalTrees:=preload("res://Presentation/LocalTrees.gd")
 if not LocalTrees.available():
  check(LocalTrees.build("oak tree",1500,1600)==null,"Without local licensed trees the CC0 library trees remain in use")
 else:
  var first: Node3D=LocalTrees.build("oak tree",1500,1600)
  var again: Node3D=LocalTrees.build("oak tree",1500,1600)
  var model: MeshInstance3D=first.get_child(0)
  var bottom:=(model.transform*model.mesh.get_aabb()).position.y
  var scale_axes:=model.transform.basis.get_scale()
  check(first.get_meta("local_tree")==again.get_meta("local_tree") and absf(bottom)<0.01 and is_equal_approx(scale_axes.x,scale_axes.y) and is_equal_approx(scale_axes.y,scale_axes.z),"Local licensed trees are deterministic, uniformly scaled and rooted at their source cell")
  first.free();again.free()
 # Chimney sprite tiles become one stack rooted in the roof beneath them.
 var chimney_world:={"elevationScale":.2,"originX":1300,"originY":1300,"width":8,"height":8,"terrain":[],"statics":[{"x":1301,"y":1301,"z":40,"id":1488},{"x":1302,"y":1301,"z":40,"id":1488},{"x":1301,"y":1301,"z":46,"id":2268},{"x":1302,"y":1301,"z":46,"id":2269},{"x":1301,"y":1301,"z":56,"id":2268}],"staticData":{"1488":{"name":"wooden shingles","height":3},"2268":{"name":"chimney","height":16},"2269":{"name":"chimney","height":16}},"landData":{}}
 var chimney_recon:=preload("res://Presentation/Reconstruction.gd").new()
 chimney_recon.index(chimney_world)
 var chimney_group: Dictionary=chimney_recon.groups.get(2,{})
 check(chimney_group.get("kind","")=="chimney" and chimney_group.indices.size()==3 and chimney_recon.chimney_bases.get(int(chimney_group.owner),0)==40,"Stacked/adjacent chimney tiles form one stack based on the roof below")
 var stack: Node3D=chimney_recon.chimney_stack(chimney_world.statics[int(chimney_group.owner)],chimney_group,chimney_world)
 var stack_boxes: Array=[];chimney_recon._collect_bounds(stack,Transform3D.IDENTITY,stack_boxes)
 var stack_box: AABB=stack_boxes[0]
 for other in stack_boxes: stack_box=stack_box.merge(other)
 check(absf(stack_box.position.y-(40-int(chimney_world.statics[int(chimney_group.owner)].z))*.2)<0.01 and stack_box.size.x>1.5,"Chimney stack spans its two-tile footprint from the roof up")
 stack.free()
 # Bridge edge parapets record the deck side so they sit flush on its edge.
 var bridge_world:={"elevationScale":.2,"statics":[{"x":10,"y":10,"z":40,"id":120},{"x":10,"y":11,"z":40,"id":1997}],"staticData":{"120":{"name":"stone wall","height":5},"1997":{"name":"wooden plank","height":0,"flags":0x200}},"terrain":[{"x":10,"y":11,"z":-5,"id":168},{"x":10,"y":10,"z":-5,"id":168}],"landData":{"168":{"name":"water"}}}
 var bridge_plan:=preload("res://Presentation/BridgePlan.gd").new()
 bridge_plan.index(bridge_world,{"120":{"kind":"trim","axis":"x"},"1997":{"kind":"floor"}})
 check(bridge_plan.parapets.get(0,{}).get("toward",Vector2i.ZERO)==Vector2i(0,1),"An edge parapet shifts toward its bridge deck, not into the water gap")
 # Wedge records in wood/brick assemble as gables like the plaster ones.
 for id in ["24","25","193","194","85","86"]:
  if roof_recon.catalog.get(id,{}).get("kind","")!="gable":check(false,"Wedge "+id+" is a gable")
 check(roof_recon.catalog.get("194",{}).get("kind","")=="gable","Stacked timber/brick gable wedges assemble instead of poking through the roof")
 check(preload("res://Presentation/RegionalRules.gd").resolve(1477,{"name":"wooden shingles","height":3}).get("material","")=="shingle","Wooden shingle hip/corner pieces use the shingle material, not slate")
 # Hip steps close in roof material; true gable ends keep wall infill.
 var hip_world:={"elevationScale":.2,"statics":[{"x":0,"y":0,"z":30,"id":1476},{"x":1,"y":0,"z":30,"id":1476},{"x":1,"y":1,"z":30,"id":1476}]}
 var hip_plan:=preload("res://Presentation/RoofPlan.gd").new()
 hip_plan.index(hip_world,{"1476":{"kind":"roof","material":"shingle","rise":[1,0],"ridgeAxis":"x","anchorOffset":[-1,-1]}})
 check(hip_plan.tiles[0].hip_edges[2] and hip_plan.tiles[2].hip_edges[3] and hip_plan.tiles[1].gable_edges[1] and not hip_plan.tiles[1].hip_edges[1],"Stepped hip edges are told apart from open gable ends")
 # Sign kinds and furniture facings from upstream placements.
 var appearance:=preload("res://Presentation/ItemAppearance.gd")
 check(appearance.variant(4764,{"family":"sign"})=="street_sign" and appearance.variant(7977,{"family":"sign"})=="plaque" and appearance.variant(2996,{"family":"sign"})=="sign","Street signs and wall plaques are not drawn as bracket-hung shop signs")
 check(int(preload("res://Presentation/ReviewedCatalog.gd").entry(2713).get("yawDegrees",0))==90 and int(preload("res://Presentation/ReviewedCatalog.gd").entry(2711).get("yawDegrees",0))==0,"Bookcases placed in north-south runs face east")
 print("ART FIDELITY TESTS: ",checks," checks / ",failures," failures")
 quit(1 if failures else 0)
