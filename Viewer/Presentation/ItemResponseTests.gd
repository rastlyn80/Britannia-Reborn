extends SceneTree
const Wire = preload("res://Network/LoginProtocol.gd")
const Responses = preload("res://Network/ItemResponses.gd")
const Appearance = preload("res://Presentation/ItemAppearance.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if ok: print("PASS ",label)
 else:
  failures += 1
  push_error(label)
func packet(id: int, payload: PackedByteArray) -> PackedByteArray:
 var result := PackedByteArray([id])
 result.append_array(Wire.uint_be(payload.size()+3,2))
 result.append_array(payload)
 return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var cover := Wire.uint_be(0x40000123,4)
 cover.append_array(PackedByteArray([1,0,0,1,0,5]))
 cover.append_array("Test".to_utf8_buffer())
 cover.append_array(PackedByteArray([0,0,4]))
 cover.append_array("Ada".to_utf8_buffer())
 cover.append(0)
 var header := packet(0xd4,cover)
 var decoded := Responses.decode(header)
 check(decoded.get("title","") == "Test" and decoded.get("author","") == "Ada" and decoded.page_count == 1,"native D4 title, author, writability and page count")
 var pages := Wire.uint_be(0x40000123,4)
 pages.append_array(PackedByteArray([0,1,0,1,0,2]))
 pages.append_array("First line".to_utf8_buffer())
 pages.append(0)
 pages.append_array("Second line".to_utf8_buffer())
 pages.append(0)
 var content := packet(0x66,pages)
 check(Responses.decode(content).pages[1] == "First line\nSecond line","native book page numbers and NUL terminated UTF8 lines")
 for original in [header,content]:
  var rejected := true
  for length in original.size():
   var truncated: PackedByteArray = original.slice(0,length)
   if truncated.size() >= 3:
    truncated[1] = length>>8
    truncated[2] = length&255
   if not Responses.decode(truncated).is_empty(): rejected = false
  check(rejected,"every truncated book payload rejected without partial state")
 var board := PackedByteArray([0])
 board.append_array(Wire.uint_be(0x40000009,4))
 board.append_array("Town notices".to_utf8_buffer())
 board.resize(35)
 check(Responses.decode(packet(0x71,board)).title == "Town notices","native bulletin board display name")
 var post := PackedByteArray([2])
 post.append_array(Wire.uint_be(0x40000009,4))
 post.append_array(Wire.uint_be(0x40000010,4))
 for value in ["Ada","Hello","Today"]:
  post.append(value.length()+1)
  post.append_array(value.to_utf8_buffer())
  post.append(0)
 post.append_array(PackedByteArray([0,0,0,0,0,1,7]))
 post.append_array("Notice".to_utf8_buffer())
 post.append_array(PackedByteArray([0,0]))
 # Native BB body text includes a second zero for the classic client workaround.
 post[post.size()-9] = 8
 var message := Responses.decode(packet(0x71,post))
 check(message.get("lines",[]) == ["Notice"] and message.author == "Ada","native bulletin message UTF8 strings and padded body lines")
 var kinds := {}
 for pair in [[2503,"BeverageBottle"],[2504,"Jug"],[4007,"Dices"],[4030,"Static"],[4032,"Static"],[3603,"Static"],[3608,"Static"],[3610,"Static"],[5453,"Static"],[4766,"LocalizedSign"],[7775,"BulletinBoard"]]:
  var kind := Appearance.variant(pair[0],{"type":pair[1]})
  kinds[kind] = true
 check(kinds.size() == 11,"eleven native graphics select distinct object variants rather than a shared cup")
 var request := PackedByteArray([0x6c,0,0,0,0,55,0])
 request.resize(19)
 var target := preload("res://Network/GameSession.gd").target_packet(request,{"serial":123,"x":1600,"y":1590,"z":-20,"id":2503})
 check(target.size() == 19 and Wire.read_be(target,2,4) == 55 and Wire.read_be(target,7,4) == 123 and target[16] == 236,"native target echoes request ID, object serial and signed elevation")
 var cancel := preload("res://Network/GameSession.gd").target_packet(request)
 check(Wire.read_be(cancel,7,4) == 0 and Wire.read_be(cancel,11,2) == 65535 and Wire.read_be(cancel,13,2) == 65535,"native target cancellation uses invalid coordinates and zero serial")
 check(preload("res://Network/GameSession.gd").target_packet(PackedByteArray([0x6c])).is_empty(),"malformed target request cannot generate a response")
 var g := preload("res://Presentation/GeometryLibrary.gd").new()
 var node := Node3D.new()
 root.add_child(node)
 var signatures := {}
 for kind in ["book","bottle","jug","mug","dice","ink","cards","checkers","chessmen"]:
  var item := Node3D.new()
  node.add_child(item)
  var size := Appearance.small(item,g,kind,4007)
  signatures[str(size)+str(item.get_child_count())] = true
  check(size.y > 0 and item.get_child_count() > 0 and item.get_meta("appearance") == kind,"shared world/inventory geometry for "+kind)
 check(signatures.size() >= 8,"model silhouettes and dimensions differ across object graphics")
 node.free()
 for frame in 3: await process_frame
 print("ITEM RESPONSE CHECKS: %d passed / %d total" % [checks-failures,checks])
 quit(0 if failures == 0 else 1)
