extends SceneTree
const Artwork = preload("res://Network/Artwork.gd")
class Session extends "res://Network/GameSession.gd":
 var sent := []
 func send(p: PackedByteArray) -> void: sent.append(p)
var checks := 0
var failed := 0
func check(ok: bool,text: String) -> void:
 checks += 1
 if ok: print("PASS ",text)
 else:
  failed += 1
  push_error(text)
func _initialize() -> void: call_deferred("run")
func capture(name_text: String) -> void:
 if "--visual" not in OS.get_cmdline_user_args(): return
 for frame in 8: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/ui-fixture-"+name_text+".png"))
 print("OFFLINE UI FIXTURE CAPTURE: ",name_text)
func run() -> void:
 root.size = Vector2i(1280,800)
 var notice := Label.new()
 notice.text = "OFFLINE PRESENTATION TEST · fixture items, no live transaction"
 notice.position = Vector2(24,24)
 root.add_child(notice)
 var game := Session.new()
 root.add_child(game)
 game.set_process(false)
 game.phase = "world"
 game.player = {"serial":1,"x":1602,"y":1591,"z":20,"facet":1,"direction":0}
 game.backpack = 0x4f000001
 game.container_serial = game.backpack
 var dice := {"serial":0x4f000002,"id":4007,"amount":1,"container":game.backpack,"hue":0}
 var boots := {"serial":0x4f000003,"id":5903,"amount":1,"container":1,"layer":3,"hue":0}
 game.remember_item(dice)
 game.remember_item(boots)
 game.equipment[3] = boots
 var browser := preload("res://Network/ItemBrowser.gd").new()
 root.add_child(browser)
 browser.configure(game)
 game.container_opened.emit(game.backpack)
 game.inventory_received.emit([dice])
 for frame in 3: await process_frame
 check(browser.rows.get_child_count()==1,"production item browser displays server-confirmed entries")
 var row: Button = browser.rows.get_child(0)
 row.pressed.emit()
 check(browser.selected==int(dice.serial) and browser.preview.get_parent().visible,"selecting an item shows its matching 3D preview")
 check(game.sent.is_empty(),"selecting an item does not accidentally double-click or move it")
 await capture("inventory")
 browser.show_equipment()
 check(browser.rows.get_child_count()==1 and browser.mode=="equipment","production equipment view follows native worn layers")
 check(browser.panel.get_global_rect().end.y <= 800,"inventory actions and Close fit an 800px-high window")
 browser.panel.hide()
 var shop := preload("res://Network/ShopPanel.gd").new()
 root.add_child(shop)
 shop.configure(game)
 game.entity_names[4] = "Fixture shopkeeper"
 game.vendor_received.emit(4,[dice.merged({"price":2,"description":"dice"})])
 for frame in 3: await process_frame
 check(shop.rows.get_child_count()==1 and "native stock" in shop.title.text,"production shop UI uses native stock and price records")
 var sent_before := game.sent.size()
 shop.rows.get_child(0).get_child(2).pressed.emit()
 check(game.sent.size()==sent_before,"UI cannot purchase stock absent from the session's authoritative catalogue")
 await capture("shop")
 shop.panel.hide()
 var gump := preload("res://Network/GumpView.gd").new()
 root.add_child(gump)
 gump.configure(game,{"serial":44,"type":55,"texts":["<b>Bold</b><br>Body"],"commands":[["resizepic","30","40","2600","420","300"],["tilepichue","80","90","4007","0"],["htmlgump","100","100","200","70","0","0","0"],["button","100","230","5540","5541","1","0","0"]]})
 check(gump.elements[0].control.mouse_filter==Control.MOUSE_FILTER_STOP,"gump background prevents clicks leaking into the 3D world")
 check(gump.unsupported.is_empty(),"native item pictures and safe formatted HTML are supported")
 var drags := []
 for child in gump.get_children():
  if child.get_script()==preload("res://Network/WindowDrag.gd"): drags.append(child)
 check(drags.size()==1 and drags[0].position==Vector2(30,40),"gump drag handle follows actual frame bounds")
 var click := InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 drags[0]._gui_input(click)
 var motion := InputEventMouseMotion.new()
 motion.relative=Vector2(50,20)
 drags[0]._gui_input(motion)
 check(gump.position.is_equal_approx(Vector2(50,20)),"dragging moves the production window without changing server control IDs")
 for frame in 2: await process_frame
 var frame_bounds: Control=gump.elements[0].control
 var inside := true
 for tile in frame_bounds.get_children():
  if tile is Control and (tile.position+tile.size).x>frame_bounds.size.x+0.1 or tile is Control and (tile.position+tile.size).y>frame_bounds.size.y+0.1: inside=false
 check(inside,"all nine classic frame patches stay inside native resize bounds")
 await capture("gump")
 gump.free()
 var fixed := preload("res://Network/GumpView.gd").new()
 root.add_child(fixed)
 fixed.configure(game,{"serial":45,"type":56,"texts":[],"commands":[["nomove"],["noclose"],["resizepic","0","0","2600","300","100"]]})
 check(not fixed.movable and not fixed.closable,"native nomove and noclose flags are retained")
 fixed.free()
 shop.free()
 browser.free()
 game.close()
 game.free()
 for frame in 3: await process_frame
 print("COMMERCE UI CHECKS: %d passed / %d total" % [checks-failed,checks])
 quit(0 if failed==0 else 1)
