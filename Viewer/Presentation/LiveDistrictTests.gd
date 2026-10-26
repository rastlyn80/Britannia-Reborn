extends SceneTree
const Game = preload("res://Network/GameSession.gd")
const Districts = preload("res://Presentation/LiveDistricts.gd")
var failures := 0
var checks := 0
class Session extends Game:
 var sent: Array = []
 func send(bytes: PackedByteArray) -> void: sent.append(bytes)
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(label)
 else: print("PASS ",label)
func _initialize() -> void:
 var stream := Districts.new()
 stream.bounds = Rect2i(1088,1408,704,512)
 check(not stream.destination_ready(Vector2i(1600,1591)),"Missing physics district blocks movement")
 stream.loaded[Vector2i(1600,1536)] = true
 check(stream.destination_ready(Vector2i(1600,1591)),"Native coordinate identifies installed district")
 check(not stream.destination_ready(Vector2i(1599,1591)),"Unloaded neighboring district remains blocked")
 check(not stream.destination_ready(Vector2i(1792,1591)),"Outer city edge remains blocked")
 var game := Session.new()
 game.phase = "world"
 game.player = {"x":1599,"y":1591,"z":0,"direction":2,"facet":1}
 game.preview_bounds = stream.bounds
 game.destination_ready = stream.destination_ready
 stream.loaded.clear()
 check(not game.walk(2) and game.sent.is_empty() and game.outstanding == -1,"Unloaded destination sends no native packet or optimistic move")
 stream.loaded[Vector2i(1600,1536)] = true
 check(game.walk(2) and game.sent.size()==1 and game.outstanding==0,"Loaded boundary sends original native walk protocol")
 check(game.player.x==1599,"Streaming never mutates authoritative player position")
 stream.loaded.clear()
 game.outstanding = -1
 game.next_walk = 0
 check(game.walk(0),"Native turn remains available during district loading")
 var district := Node3D.new()
 var model := Node3D.new()
 model.position = Vector3(10,2,20)
 district.add_child(model)
 var material := StandardMaterial3D.new()
 var originals: Array = []
 for x in [0,2]:
  var mesh := MeshInstance3D.new()
  mesh.mesh = BoxMesh.new()
  mesh.material_override = material
  mesh.position.x = x
  model.add_child(mesh)
  originals.append(mesh)
 var sign := Node3D.new()
 sign.set_meta("kind","sign")
 district.add_child(sign)
 var sign_mesh := MeshInstance3D.new()
 sign_mesh.mesh = BoxMesh.new()
 sign.add_child(sign_mesh)
 var body := StaticBody3D.new()
 district.add_child(body)
 preload("res://Presentation/DistrictBatch.gd").new().apply(district)
 check(district.get_meta("draw_batches")==1,"Opaque equal-material surfaces merge into one draw batch")
 check(originals[0].mesh==null and originals[1].mesh==null,"Merged originals no longer render duplicate surfaces")
 check(sign_mesh.mesh!=null,"Native sign renderer remains individually suppressible")
 check(body.get_parent()==district,"Physical collision survives batching")
 var batch: MeshInstance3D = district.get_child(district.get_child_count()-1)
 check(batch.mesh.get_aabb().position.is_equal_approx(Vector3(9.5,1.5,19.5)),"Batched vertices retain complete source model transform")
 check(batch.mesh.get_aabb().size.is_equal_approx(Vector3(3,1,1)),"Batch retains geometry extent and separate placements")
 stream.horizon=Node3D.new();stream.add_child(stream.horizon)
 var macro:=Node3D.new();stream.horizon.add_child(macro)
 var coarse:=MeshInstance3D.new();macro.add_child(coarse)
 coarse.material_override=ShaderMaterial.new()
 coarse.material_override.shader=preload("res://Presentation/AtlasGround.gdshader")
 stream.macro_nodes[Vector2i.ZERO]=macro
 stream.activating[Vector2i(1536,1536)]=true
 stream.activating[Vector2i(1600,1536)]=true
 stream.update_horizon()
 check(coarse.material_override.get_shader_parameter("detail_count")==2,"First installed terrain masks coarse overlap while duplicate active ownership stays unique")
 check(not stream.destination_ready(Vector2i(1599,1591)),"Partially activated visual district never unlocks native movement before collision completes")
 district.free()
 game.free()
 stream.free()
 print("LIVE DISTRICT TESTS: ",checks," checks / ",failures," failures")
 quit(1 if failures else 0)
