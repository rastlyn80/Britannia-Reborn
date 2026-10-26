extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var directory:=ProjectSettings.globalize_path("res://../outputs/britain")
 var owned:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--dataset="):directory=arg.substr(10)
  if arg.begins_with("--data="):owned=arg.substr(7)
 var palette_path:=owned.path_join("radarcol.mul")
 if not FileAccess.file_exists(palette_path):push_error("Minimap requires local radarcol.mul; install owned UO data and run scripts/prepare-minimap.ps1 -DataDir <folder>.");quit(1);return
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open(directory.path_join("atlas.json")):quit(1);return
 var output:=directory.path_join("minimap")
 DirAccess.make_dir_recursive_absolute(output)
 var signature:=(FileAccess.get_sha256(directory.path_join("atlas.json"))+FileAccess.get_sha256(palette_path)+FileAccess.get_sha256(owned.path_join("hues.mul"))+FileAccess.get_sha256("res://Presentation/RadarMap.gd")+FileAccess.get_sha256("res://Presentation/BakeMinimap.gd")).sha256_text()
 var index_path:=output.path_join("index.json")
 var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(index_path)) if FileAccess.file_exists(index_path) else null
 if previous is Dictionary and previous.get("signature","")==signature:
  var complete:=true
  for at in previous.tiles:
   if not FileAccess.file_exists(output.path_join("%d_%d.png" % [at[0],at[1]])):complete=false
  if complete:print("MINIMAP BAKE: current");quit();return
 if FileAccess.file_exists(index_path):DirAccess.remove_absolute(index_path)
 var radar:=preload("res://Presentation/RadarMap.gd").new()
 radar.palette=FileAccess.get_file_as_bytes(palette_path)
 radar.hues=FileAccess.get_file_as_bytes(owned.path_join("hues.mul"))
 radar.metadata=data.manifest.staticData
 var bounds:=Rect2i(data.manifest.originX,data.manifest.originY,data.manifest.width,data.manifest.height)
 var tiles: Array=[]
 for y in range(bounds.position.y,bounds.end.y,256):
  for x in range(bounds.position.x,bounds.end.x,256):
   var at:=Vector2i(x,y)
   var size:=Vector2i(mini(256,bounds.end.x-x),mini(256,bounds.end.y-y))
   var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGB8)
   for cy in range(y,y+size.y,64):
    for cx in range(x,x+size.x,64):
     var cell:=Vector2i(cx,cy)
     var source:=data.chunk(cell)
     assert(not source.is_empty(),"Missing minimap source chunk")
     var chunk:=radar.render(source,cell,Vector2i(64,64))
     image.blit_rect(chunk,Rect2i(0,0,64,64),cell-at)
   var path:=output.path_join("%d_%d.png" % [x,y])
   assert(image.save_png(path)==OK)
   tiles.append([x,y])
   await process_frame
 var index:={"schema":1,"signature":signature,"originX":bounds.position.x,"originY":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y,"facet":1,"tileSize":256,"tiles":tiles,"source":"Native land + highest drawable static base Z; radarcol.mul and hues.mul. Static radar reconstruction; dynamic multis excluded."}
 var file:=FileAccess.open(index_path+".pending",FileAccess.WRITE)
 file.store_string(JSON.stringify(index));file.close()
 assert(DirAccess.rename_absolute(index_path+".pending",index_path)==OK)
 print("MINIMAP BAKE PASS: ",tiles.size()," bounded radar tiles / ",bounds.size.x*bounds.size.y," native cells")
 quit()
