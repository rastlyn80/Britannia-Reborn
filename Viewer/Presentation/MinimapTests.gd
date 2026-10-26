extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func _initialize() -> void:
 var radar:=preload("res://Presentation/RadarMap.gd").new()
 radar.palette.resize((0x4000+10)*2)
 radar.palette.encode_u16(1*2,0x03e0)
 radar.palette.encode_u16((0x4000+2)*2,0x7c00)
 radar.palette.encode_u16((0x4000+3)*2,0x001f)
 radar.metadata={"4":{"name":"nodraw invisible"},"5":{"flags":0x02000000}}
 var source:={"terrain":[{"x":1088,"y":1408,"z":-5,"id":1},{"x":1089,"y":1408,"z":0,"id":1}],"statics":[{"x":1088,"y":1408,"z":-6,"id":3},{"x":1088,"y":1408,"z":0,"id":2},{"x":1088,"y":1408,"z":20,"id":4},{"x":1088,"y":1408,"z":21,"id":5},{"x":1089,"y":1408,"z":-1,"id":3}]}
 var image:=radar.render(source,Vector2i(1088,1408),Vector2i(2,1))
 check(image.get_pixel(0,0).is_equal_approx(Color.RED),"Radar chooses highest drawable native static and excludes invisible records")
 check(image.get_pixel(1,0).is_equal_approx(Color.GREEN),"Below-ground statics preserve native land radar colour")
 check(not radar.drawable({"id":0x2198}),"Radar suppresses native invisible effect markers")
 radar.hues.resize(92);radar.hues.encode_u16(36,0x001f)
 check(radar.static_color({"id":2,"hue":1}).is_equal_approx(Color.BLUE),"Native hue group header and middle shade override static radar colour")
 check(radar.static_color({"id":2,"hue":999}).is_equal_approx(Color.RED),"Missing hue safely falls back to native static palette")
 var minimap:=preload("res://Presentation/Minimap.gd").new()
 var center:=Vector2(1602.5,1591.5)
 check(minimap.marker(center,center,1)==minimap.MAP.get_center(),"Native player marker remains centred independent of map origin")
 check(minimap.marker(center+Vector2(2,-3),center,2)==minimap.MAP.get_center()+Vector2(4,-6),"Minimap preserves east-right north-up and zoom scale")
 minimap.zoom(100)
 check(minimap.pixels_per_cell==4,"Minimap clamps close zoom")
 minimap.zoom(0.00001)
 check(minimap.pixels_per_cell==0.25,"Minimap clamps wide zoom to bounded texture window")
 check(ceil(minimap.MAP.size.x/minimap.pixels_per_cell/256.0+1)*ceil(minimap.MAP.size.y/minimap.pixels_per_cell/256.0+1)<=minimap.MAX_TEXTURES,"Widest view fits the fixed radar texture budget")
 minimap.free()
 print("MINIMAP TESTS: ",checks," checks / ",failures," failures")
 quit(1 if failures else 0)
