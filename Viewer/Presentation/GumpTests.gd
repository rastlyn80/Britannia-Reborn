extends SceneTree
const Protocol = preload("res://Network/GumpProtocol.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks += 1
 if ok: print("PASS ",label)
 else:
  failures += 1
  push_error(label)
func packed(raw: PackedByteArray) -> PackedByteArray:
 if raw.is_empty(): return Wire.uint_be(0,4)
 var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
 var result := Wire.uint_be(compressed.size()+4,4)
 result.append_array(Wire.uint_be(raw.size(),4))
 result.append_array(compressed)
 return result
func packet(id: int, body: PackedByteArray) -> PackedByteArray:
 var result := PackedByteArray([id])
 result.append_array(Wire.uint_be(body.size()+3,2))
 result.append_array(body)
 return result
class Connection extends Node:
 var labels := preload("res://Network/ItemLabels.gd").new()
 var replies := []
 func respond_gump(value: Dictionary,button: int,switches: Array,entries: Dictionary) -> bool:
  replies.append([value,button,switches,entries])
  return true
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var layout := "{ page 0 }{ resizepic 0 0 2600 420 300 }{ page 1 }{ text 20 20 0 0 }{ button 20 60 5540 5541 0 2 0 }{ page 2 }{ checkbox 20 40 210 211 1 7 }{ textentry 20 80 200 30 0 4 1 }{ button 20 120 5540 5541 1 0 9 }{ xmfhtmltok 20 160 100 30 1 0 1042971 0 @argument with spaces@ }"
 var header := Wire.uint_be(123,4)
 for value in [456,20,30]: header.append_array(Wire.uint_be(value,4))
 var strings := PackedByteArray()
 for value in ["Title","Åda 🌿"]:
  var bytes := Protocol.unicode_bytes(value)
  strings.append_array(Wire.uint_be(bytes.size()/2,2))
  strings.append_array(bytes)
 var body := header.duplicate()
 body.append_array(packed(layout.to_utf8_buffer()))
 body.append_array(Wire.uint_be(2,4))
 body.append_array(packed(strings))
 var compressed := packet(0xdd,body)
 var decoded := Protocol.decode(compressed)
 check(decoded.get("serial",0) == 123 and decoded.get("type",0) == 456 and decoded.x == 20,"compressed native gump identity and screen position")
 check(decoded.texts == ["Title","Åda 🌿"],"gump UTF16BE handles accented characters and surrogate pairs")
 check(decoded.commands[-1][-1] == "@argument with spaces@","layout tokenizer preserves localized argument blocks")
 body = header.duplicate()
 body.append_array(Wire.uint_be(layout.length(),2))
 body.append_array(layout.to_utf8_buffer())
 body.append_array(Wire.uint_be(2,2))
 body.append_array(strings)
 var legacy := packet(0xb0,body)
 check(Protocol.decode(legacy) == decoded,"legacy and compressed layouts produce equivalent controls")
 for original in [compressed,legacy]:
  var rejected := true
  for length in original.size():
   var truncated: PackedByteArray = original.slice(0,length)
   if truncated.size() >= 3:
    truncated[1] = length>>8
    truncated[2] = length&255
   if not Protocol.decode(truncated).is_empty(): rejected = false
  check(rejected,"every truncated native gump rejected")
 var corrupt := compressed.duplicate()
 for i in range(23,27): corrupt[i] = 255
 check(Protocol.decode(corrupt).is_empty(),"expanded gump size limit enforced before decompression")
 var response := Protocol.response(decoded,9,[7],{4:"Åda 🌿"})
 check(response[0] == 0xb1 and Wire.read_be(response,1,2) == response.size() and Wire.read_be(response,11,4) == 9,"native B1 response identity and button")
 check(Wire.read_be(response,15,4) == 1 and Wire.read_be(response,19,4) == 7 and Wire.read_be(response,23,4) == 1,"native checked-switch and text counts")
 check(Protocol.unicode_be(response.slice(31)) == "Åda 🌿","native response text encoded UTF16BE")
 check(Protocol.response(decoded,9,[],{4:"x".repeat(240)}).is_empty(),"server text-entry limit prevents invalid responses")
 check(Protocol.art_ids(decoded).has(2608) and Protocol.art_ids(decoded).has(5541),"collect nine background slices and both native button graphic IDs")
 var connection := Connection.new()
 root.add_child(connection)
 var view := preload("res://Network/GumpView.gd").new()
 root.add_child(view)
 view.configure(connection,decoded)
 check(view.unsupported.is_empty() and view.page == 1,"supported native controls build without a fallback warning")
 view.show_page(2)
 check(view.switches[7].button_pressed and view.entries[4].text == "Åda 🌿","page transitions preserve switch and text-entry state")
 view.reply(9)
 check(connection.replies.size() == 1 and connection.replies[0][2] == [7],"rendered controls relay actual state to server callback")
 # A right-click over a gump's art (not only its panels) closes it.
 var shut := preload("res://Network/GumpView.gd").new()
 root.add_child(shut)
 shut.configure(connection,decoded)
 await process_frame
 var over: Vector2 = (shut.get_global_transform()*shut.content_bounds).get_center()
 var hover := InputEventMouseMotion.new(); hover.position = over; hover.global_position = over
 root.push_input(hover)
 await process_frame
 var right := InputEventMouseButton.new(); right.button_index = MOUSE_BUTTON_RIGHT; right.pressed = true; right.position = over; right.global_position = over
 root.push_input(right)
 await process_frame
 check(connection.replies.size() == 2 and connection.replies[1][1] == 0,"right-clicking a closable gump closes it with button 0")
 if connection.replies.size() == 2: connection.replies.pop_back()
 var unsupported := preload("res://Network/GumpView.gd").new()
 root.add_child(unsupported)
 var unknown := decoded.duplicate(true)
 unknown.commands.append(["futurewidget","0","0"])
 unsupported.configure(connection,unknown)
 unsupported.reply(9)
 check(unsupported.reply_buttons[0].disabled and connection.replies.size() == 1,"unknown control disables action responses instead of guessing")
 unsupported.reply(0)
 check(connection.replies.size() == 2,"unsupported gump still permits a native close response")
 check(preload("res://Network/GumpView.gd").plain_html("<center>A</center><br>B &amp; C") == "A\nB & C","HTML is displayed as inert text with line breaks, never executed")
 unsupported.free()
 connection.free()
 for frame in 4: await process_frame
 print("GUMP CHECKS: %d passed / %d total" % [checks-failures,checks])
 quit(0 if failures == 0 else 1)
