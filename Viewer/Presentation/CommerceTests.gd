extends SceneTree
const Wire = preload("res://Network/LoginProtocol.gd")
const Protocol = preload("res://Network/CommerceProtocol.gd")
var checks := 0
var failures := 0
class Session extends "res://Network/GameSession.gd":
 var sent := []
 func send(bytes: PackedByteArray) -> void: sent.append(bytes)
func check(value: bool,text: String) -> void:
 checks += 1
 if value: print("PASS ",text)
 else:
  failures += 1
  push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var lift := Protocol.lift(0x40000123,7)
 check(lift.size()==7 and Wire.read_be(lift,1,4)==0x40000123 and Wire.read_be(lift,5,2)==7,"native lift serial and stack amount")
 check(Protocol.lift(0,1).is_empty() and Protocol.lift(1,65536).is_empty(),"invalid lift requests rejected")
 var drop := Protocol.drop(0x40000123,0,Vector3i(1603,1591,-20))
 check(drop.size()==15 and Wire.read_be(drop,5,2)==1603 and drop[9]==236 and Wire.read_be(drop,11,4)==0,"High Seas ground drop coordinates, signed Z, grid byte and destination")
 drop = Protocol.drop(0x40000123,0x40000009)
 check(Wire.read_be(drop,5,2)==65535 and Wire.read_be(drop,7,2)==65535 and Wire.read_be(drop,11,4)==0x40000009,"native automatic container placement")
 var equip := Protocol.equip(0x40000123,7)
 check(equip.size()==10 and equip[5]==0 and Wire.read_be(equip,6,4)==7,"native equip request lets server choose the actual layer")
 var buy := Protocol.buy(7,0x40000123,2)
 check(buy.size()==15 and buy[7]==2 and buy[8]==0x1a and Wire.read_be(buy,9,4)==0x40000123 and Wire.read_be(buy,13,2)==2,"native vendor purchase flag, layer, stock serial and quantity")
 check(Protocol.buy(7,8,0).is_empty(),"zero-quantity purchase rejected")
 var menu := PackedByteArray([0xbf,0,18,0,0x14,0,1,0,0,0,7,1,0,2,0x17,0xd7,0,0])
 var context := Protocol.context(menu)
 check(context.serial==7 and context.options[0].label==3006103 and context.options[0].index==2,"legacy native context-menu Buy entry")
 check(Protocol.context(menu.slice(0,17)).is_empty(),"truncated context entry rejected")
 var prices := PackedByteArray([0x74,0,15,0x40,0,0,9,1,0,0,0,7,2,65,0])
 check(Protocol.prices(prices).entries[0].price==7 and Protocol.prices(prices).entries[0].description=="A","native price-list length and description")
 check(Protocol.prices(prices.slice(0,14)).is_empty(),"truncated native price record rejected")
 var game := Session.new()
 root.add_child(game)
 game.set_process(false)
 game.phase = "world"
 game.player.serial = 1
 game.backpack = 0x40000001
 game.container_serial = game.backpack
 game.remember_item({"serial":0x40000002,"id":4007,"amount":1,"container":game.backpack})
 game.remember_item({"serial":0x40000003,"id":4081,"amount":1,"container":0x40000009})
 check(game.contents_of(game.backpack).size()==1 and game.contents_of(0x40000009).size()==1,"separate native container caches survive UI navigation")
 var outcomes := []
 game.transfer_result.connect(func(ok: bool,_text: String): outcomes.append(ok))
 check(game.move_item(0x40000002,0x40000009) and game.known_items[0x40000002].container==game.backpack and outcomes.is_empty(),"transfer stays pending without an optimistic item move")
 check(not game.move_item(0x40000003,game.backpack),"only one item transfer may be outstanding")
 game.remember_item({"serial":0x40000002,"id":4007,"amount":1,"container":game.backpack})
 check(outcomes.is_empty(),"an old source update before lifting does not falsely reject a queued move")
 game.feed(PackedByteArray([0x1d,0x40,0,0,2]))
 game.remember_item({"serial":0x40000002,"id":4007,"amount":1,"container":0x40000009})
 check(outcomes==[true] and game.pending_transfer.is_empty(),"destination update confirms transfer after native removal")
 game.next_item_action = 0
 game.move_item(0x40000002,game.backpack)
 game.feed(PackedByteArray([0x27,0]))
 check(outcomes==[true,false] and game.known_items[0x40000002].container==0x40000009,"native lift rejection retains the last confirmed location")
 game.container_serial = game.backpack
 game.feed(PackedByteArray([0x3c,0,5,0,0]))
 check(game.contents_of(0x40000009).size()==2,"empty contents only clears the active native container")
 game.context_menu = {"serial":7,"options":[{"index":2,"flags":1}]}
 check(not game.choose_context(2),"disabled native context action cannot be submitted")
 game.close()
 check(game.known_items.is_empty() and game.equipment.is_empty() and game.context_menu.is_empty(),"disconnect clears inventory, equipment and context state")
 game.free()
 var gump := preload("res://Network/GumpView.gd").new()
 check(gump.html_text("<b>Bold</b><br><u>Under</u>")=="[b]Bold[/b]\n[u]Under[/u]","safe native HTML formatting preserves emphasis and line breaks")
 check(gump.html_text("[url=bad]x[/url]").begins_with("[lb]url"),"native text cannot inject Godot URL controls")
 gump.free()
 for frame in 3: await process_frame
 print("COMMERCE CHECKS: %d passed / %d total" % [checks-failures,checks])
 quit(0 if failures==0 else 1)
