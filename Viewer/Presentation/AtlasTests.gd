extends SceneTree
var failed := 0
var count := 0
func check(ok: bool,message: String) -> void:
 count+=1
 if ok: print("PASS ",message)
 else: failed+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var folder := "user://atlas-test"
 DirAccess.make_dir_recursive_absolute(folder)
 var file := FileAccess.open(folder+"/128_192.brw",FileAccess.WRITE)
 file.store_32(0x31575242)
 for value in [128,192,64,64,1]: file.store_32(value)
 for y in 64:
  for x in 64:
   file.store_16(100+x)
   file.store_8((x-y)&255)
 file.store_16(900)
 file.store_8(3);file.store_8(4);file.store_8((-20)&255);file.store_16(77)
 file.close()
 var manifest := {"format":"BRW1","schema":1,"chunkSize":64,"landData":{},"staticData":{}}
 var json := FileAccess.open(folder+"/atlas.json",FileAccess.WRITE)
 json.store_string(JSON.stringify(manifest));json.close()
 var data := preload("res://Presentation/AtlasData.gd").new()
 check(data.open(folder+"/atlas.json"),"versioned binary atlas manifest opens")
 var chunk := data.chunk(Vector2i(128,192))
 check(chunk.terrain.size()==4096,"chunk decodes all native terrain samples")
 check(chunk.terrain[64].x==128 and chunk.terrain[64].y==193 and chunk.terrain[64].z==-1,"row-major chunk coordinates and negative elevation")
 check(chunk.statics[0]=={"id":900,"x":131,"y":196,"z":-20,"hue":77},"static graphic XYZ and hue survive binary IR")
 var world := data.world(Vector2i(128,192))
 check(world.originX==128 and world.width==64 and world.statics.size()==1,"chunk adapts to existing engine-independent world schema")
 check(data.cache.size()==1,"missing neighbors never become fabricated geography")
 var bad := FileAccess.open(folder+"/192_192.brw",FileAccess.WRITE)
 bad.store_32(0x31575242)
 for value in [192,192,64,64,1]: bad.store_32(value)
 bad.close()
 check(data.chunk(Vector2i(192,192)).is_empty(),"truncated chunk rejected before sample allocation")
 print("ATLAS CHECKS: %d/%d" % [count-failed,count])
 quit(0 if failed==0 else 1)
