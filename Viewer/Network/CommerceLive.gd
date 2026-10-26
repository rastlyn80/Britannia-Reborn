extends SceneTree
var session: Node
var scene: Node3D
var error := ""
var shop := {}
var inn := {}
var visit_ready := false
var transfer := -1
var audit_ready := false
var result := {}
var visual := false
func _initialize() -> void: call_deferred("run")
func until(condition: Callable,seconds: float = 8.0) -> bool:
 var start := Time.get_ticks_msec()
 while not condition.call():
  if not error.is_empty() or Time.get_ticks_msec()-start>seconds*1000: return false
  await process_frame
 return true
func fail(reason: String) -> void:
 push_error(reason+" "+error)
 if session: session.close()
 quit(1)
func audit() -> Dictionary:
 audit_ready = false
 session.send_command("[PreviewCommerceAudit")
 if not await until(func(): return audit_ready): return {}
 return JSON.parse_string(FileAccess.get_file_as_string("res://../Server/runtime/Data/UltimaClonePreview/commerce.local.json"))
func move(serial: int,parent: int,equip_item: bool = false,point: Vector3i = Vector3i(-999,-999,-999)) -> bool:
 transfer = -1
 if not session.move_item(serial,parent,equip_item,point): return false
 return await until(func(): return transfer != -1) and transfer == 1
func capture(name_text: String) -> void:
 if not visual: return
 for frame in 12: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/commerce-"+name_text+".png"))
func run() -> void:
 visual = "--visual" in OS.get_cmdline_user_args()
 if visual:
  scene = load("res://Main.tscn").instantiate()
  root.add_child(scene)
  scene.accept_player_input = false
  session = scene.game
 else:
  session = preload("res://Network/GameSession.gd").new()
  root.add_child(session)
 session.failed.connect(func(reason: String): error = reason)
 session.transfer_result.connect(func(success: bool,_text: String): transfer = 1 if success else 0)
 session.message_received.connect(func(text: String):
  if text.begins_with("UCSHOP1|"):
   var fields := text.split("|")
   shop = {"serial":int(fields[1]),"x":int(fields[2]),"y":int(fields[3]),"z":int(fields[4])}
  elif text.begins_with("UCINN1|"):
   var fields := text.split("|")
   inn = {"serial":int(fields[1]),"x":int(fields[2]),"y":int(fields[3]),"z":int(fields[4])}
  elif text.begins_with("UCSHOPVISIT1|") or text.begins_with("UCINNVISIT1|"): visit_ready = true
  elif text=="UCCOMMERCEAUDIT1": audit_ready = true
  else: print("NATIVE COMMERCE: ",text))
 session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
 if not await until(func(): return session.phase=="characters"):
  fail("Character list failed");return
 for character in session.characters:
  if not character.name.is_empty(): session.select_character(character.slot,character.name);break
 if not await until(func(): return session.phase=="world"):
  fail("World entry failed");return
 session.open_backpack()
 if not await until(func(): return not session.contents_of(session.backpack).is_empty()):
  fail("Backpack missing");return
 var baseline := await audit()
 if baseline.is_empty(): fail("Initial authoritative audit missing");return
 print("COMMERCE PASS: real backpack/equipment snapshot; native gold ",baseline.gold)
 session.send_command("[PreviewShop")
 if not await until(func(): return not shop.is_empty()):
  fail("Native shop setup failed");return
 var original := int(shop.serial)
 shop = {}
 session.send_command("[PreviewShop")
 if not await until(func(): return not shop.is_empty()) or int(shop.serial)!=original:
  fail("Vendor setup duplicated the NPC");return
 print("COMMERCE PASS: native tavern spawn is idempotent")
 session.send_command("[PreviewShopVisit")
 if not await until(func(): return visit_ready and session.entities.has(int(shop.serial))):
  fail("Shop approach failed");return
 if visual:
  scene.camera.reparent(scene)
  var center: Vector3 = scene.entity_point(shop.x,shop.y,shop.z)
  scene.camera.position = center+Vector3(3,2.2,4)
  scene.camera.look_at(center+Vector3.UP)
  scene.set_process(false)
 session.request_context(int(shop.serial))
 if not await until(func(): return not session.context_menu.is_empty()):
  fail("Native NPC actions missing");return
 var buy_index := -1
 for option in session.context_menu.options:
  if int(option.label)==3006103: buy_index = int(option.index)
 if buy_index<0 or not session.choose_context(buy_index):
  fail("Native Buy action missing");return
 if not await until(func(): return not session.vendor_stock.is_empty()):
  fail("Native stock/price list failed");return
 print("COMMERCE PASS: native context menu and ",session.vendor_stock.size()," stock/price records")
 await capture("shop")
 var dice := {}
 for item in session.vendor_stock:
  if int(item.id)==0xfa7: dice = item;break
 if dice.is_empty() or int(baseline.gold)<int(dice.price):
  fail("Native dice or existing development funds unavailable");return
 var previous := {}
 for item in session.contents_of(session.backpack): previous[int(item.serial)] = true
 session.buy_item(int(dice.serial))
 var bought := {}
 if not await until(func():
  for item in session.contents_of(session.backpack):
   if int(item.id)==0xfa7 and not previous.has(int(item.serial)):
    bought.merge(item,true)
    return true
  return false):
  fail("Purchase did not deliver a server-owned item");return
 var paid := await audit()
 if paid.is_empty() or int(paid.gold)!=int(baseline.gold)-int(dice.price):
  fail("Authoritative gold debit differs from native price");return
 print("COMMERCE PASS: bought real dice; native gold debit ",dice.price)
 await capture("purchase")
 session.return_to_britain()
 if not await until(func(): return session.player.x==1602 and session.player.y==1591 and session.player.z==20):
  fail("Ground-drop fixture approach failed");return
 if not await move(int(bought.serial),0,false,Vector3i(int(session.player.x)+1,int(session.player.y),int(session.player.z))) or not session.world_items.has(int(bought.serial)):
  fail("Native ground drop missing");return
 if not await move(int(bought.serial),session.backpack):
  fail("Native ground pickup missing");return
 print("COMMERCE PASS: native drop and pickup confirmed")
 var shoe := {}
 for layer in [3,4,5,22,1]:
  if session.equipment.has(layer) and session.known_items.has(int(session.equipment[layer].serial)):
   shoe = session.equipment[layer].duplicate();break
 if shoe.is_empty() or not await move(int(shoe.serial),session.backpack):
  fail("Native unequip failed");return
 if not await move(int(shoe.serial),int(session.player.serial),true):
  fail("Native re-equip failed");return
 print("COMMERCE PASS: native unequip and re-equip, layer ",shoe.layer)
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../Server/runtime/Data/UltimaClonePreview/audit.local.json"))
 var box := {}
 var fixed := {}
 for item in manifest.items:
  if item.family=="drawers" and int(item.z)==-20: box=item
  if item.family=="door" and int(item.z)==0: fixed=item
 if box.is_empty(): fail("Container fixture missing");return
 session.send_command("[PreviewVisit %d" % int(box.serial))
 if not await until(func(): return maxi(absi(int(session.player.x)-int(box.x)),absi(int(session.player.y)-int(box.y)))<=2 and absi(int(session.player.z)-int(box.z))<=16):
  fail("Container approach failed");return
 transfer = -1
 session.move_item(int(bought.serial),int(box.serial))
 if not await until(func(): return transfer!=-1) or transfer!=0:
  fail("Native public-container ownership rejection missing");return
 print("COMMERCE PASS: native ownership rules reject public-container deposits")
 session.send_command("[PreviewInn")
 if not await until(func(): return not inn.is_empty()):
  fail("Native innkeeper setup failed");return
 visit_ready = false
 session.send_command("[PreviewInnVisit")
 if not await until(func(): return visit_ready and session.entities.has(int(inn.serial))):
  fail("Inn approach failed");return
 session.context_menu.clear()
 session.vendor_stock.clear()
 session.request_context(int(inn.serial))
 if not await until(func(): return not session.context_menu.is_empty()):
  fail("Innkeeper actions missing");return
 buy_index = -1
 for option in session.context_menu.options:
  if int(option.label)==3006103: buy_index = int(option.index)
 if buy_index<0 or not session.choose_context(buy_index):
  fail("Native innkeeper Buy missing");return
 if not await until(func(): return not session.vendor_stock.is_empty()):
  fail("Inn stock missing");return
 var bag_offer := {}
 for item in session.vendor_stock:
  if int(item.id)==0x9b2: bag_offer=item;break
 if bag_offer.is_empty(): fail("Native backpack stock missing");return
 var previous_packs := {}
 for item in session.contents_of(session.backpack): previous_packs[int(item.serial)] = true
 session.buy_item(int(bag_offer.serial))
 var owned_bag := {}
 if not await until(func():
  for item in session.contents_of(session.backpack):
   if int(item.id)==0xe75 and not previous_packs.has(int(item.serial)):
    owned_bag.merge(item,true)
    return true
  return false):
  fail("Owned native backpack purchase missing");return
 await create_timer(1.1).timeout
 session.use_item(int(owned_bag.serial))
 if not await until(func(): return session.container_serial==int(owned_bag.serial)):
  fail("Owned bag open failed");return
 if not await move(int(bought.serial),int(owned_bag.serial)):
  fail("Owned bag deposit failed");return
 if not await move(int(bought.serial),session.backpack):
  fail("Owned bag withdrawal failed");return
 var total_price := int(dice.price)+int(bag_offer.price)
 print("COMMERCE PASS: native bag purchase, owned-container deposit and withdrawal")
 if not fixed.is_empty() and session.known_items.has(int(fixed.serial)):
  transfer = -1
  session.move_item(int(fixed.serial),session.backpack)
  if not await until(func(): return transfer!=-1) or transfer!=0:
   fail("Server did not reject immovable fixture");return
  print("COMMERCE PASS: server rejects an immovable world object")
 session.return_to_britain()
 if not await until(func(): return session.player.x==1602 and session.player.y==1591 and session.player.z==20):
  fail("Return home failed");return
 var final := await audit()
 if int(final.get("gold",-1))!=int(baseline.gold)-total_price:
  fail("Total native gold debit differs from both purchases");return
 result = {"native":true,"purchased_id":int(bought.id),"price":total_price,"gold_before":int(baseline.gold),"gold_after":int(final.get("gold",-1)),"owned_bag":int(owned_bag.serial),"equipment_layer":int(shoe.layer),"vendor_serial":int(shop.serial)}
 var file := FileAccess.open("res://../outputs/validation/commerce-check.local.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "))
 session.close()
 if scene: scene.free()
 else: session.free()
 for frame in 3: await process_frame
 print("COMMERCE LIVE PASSED: purchase, payment, container/ground transfers, equipment and recovery")
 quit()
