extends SceneTree
## Dedicated local test accounts only; never select an existing owner character.
const Game = preload("res://Network/GameSession.gd")
var game: Node
var error := ""
var results: Array=[]
var visual: Node3D
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, seconds: float=15.) -> bool:
	var start:=Time.get_ticks_msec()
	while not condition.call():
		if not error.is_empty() or Time.get_ticks_msec()-start>seconds*1000: return false
		await process_frame
	return true
func fail(message: String) -> void:
	push_error(message+" "+error)
	if game: game.close()
	quit(1)
func run() -> void:
	var cosmetics:= "--cosmetics" in OS.get_cmdline_user_args()
	var motion:= "--motion" in OS.get_cmdline_user_args()
	var male_test_name:="Styled Man" if cosmetics else "Batch Man"
	var credentials_path:="res://../work/character-polish/human-test-accounts.json"
	var credentials: Array=[]
	if FileAccess.file_exists(credentials_path):
		credentials=JSON.parse_string(FileAccess.get_file_as_string(credentials_path))
	else:
		for female in [false,true]:
			credentials.append({"username":"hbatch"+str(Time.get_unix_time_from_system()).replace(".","").right(12)+("f" if female else "m"),"password":Crypto.new().generate_random_bytes(18).hex_encode().left(24)})
		var f:=FileAccess.open(credentials_path,FileAccess.WRITE)
		f.store_string(JSON.stringify(credentials))
	for sex in 2:
		if sex==1 and "--visual" in OS.get_cmdline_user_args():
			visual=load("res://Main.tscn").instantiate()
			root.add_child(visual)
			visual.accept_player_input=false
			game=visual.game
		else:
			game=Game.new()
			root.add_child(game)
		game.failed.connect(func(reason: String): error=reason)
		var account: Dictionary=credentials[sex]
		game.connect_account(account.username,account.password)
		if not await until(func(): return game.phase=="characters"):
			fail("Dedicated account login failed")
			return
		var character_name:=("Styled Woman" if sex else male_test_name) if cosmetics else ("Batch Woman" if sex else male_test_name)
		var desired:={"skin_hue":1002,"hair_id":0x203c if sex else 0x203d,"hair_hue":1118 if sex else 1147,"beard_id":0 if sex else 0x204d,"beard_hue":1102}
		var existing:=-1
		for character in game.characters:
			if character.name==character_name: existing=int(character.slot)
		if existing>=0: game.select_character(existing,character_name)
		else:
			var slot:=-1
			var city:=-1
			for character in game.characters:
				if character.name.is_empty(): slot=int(character.slot); break
			for place in game.cities:
				if place.name=="Britain": city=int(place.index)
			if slot<0 or city<0:
				fail("Missing test slot or Britain start")
				return
			game.create_character(character_name,slot,city,sex==1,desired if cosmetics else {})
		if not await until(func(): return game.phase=="world" and game.equipment.size()>=3):
			fail("Native creation/entry or equipment timeout")
			return
		var expected:=0x191 if sex else 0x190
		var expected_worn:=8 if sex else 10
		var expected_unworn:=0 if sex else 2
		await create_timer(.5).timeout
		# Recover only these dedicated fixtures if an interrupted test left its
		# robe in the backpack. Never operate on an owner's selected character.
		if not game.equipment.has(22):
			game.open_backpack()
			if not await until(func():return game.container_serial==int(game.backpack) and not game.container_items.is_empty()):fail("Dedicated fixture backpack unavailable");return
			var restore: Dictionary={}
			for candidate: Dictionary in game.container_items.values():
				if int(candidate.id) in [0x1f03,0x1f04]:restore=candidate;break
			if restore.is_empty() or not game.move_item(int(restore.serial),int(game.player.serial),true):fail("Dedicated fixture robe unavailable");return
			if not await until(func():return game.pending_transfer.is_empty() and game.equipment.has(22)):fail("Dedicated fixture robe restore failed");return
		print("LIVE BODY ",game.player.get("body",0)," WORN ",game.equipment.values().map(func(w): return {"id":int(w.id),"layer":int(w.layer)}))
		if int(game.player.get("body",0))!=expected:
			fail("Native body disagrees with requested sex")
			return
		if cosmetics:
			var native: Dictionary=game.appearance_for(int(game.player.serial))
			if int(native.hair_id)!=int(desired.hair_id) or int(native.hair_hue)!=int(desired.hair_hue) or int(native.beard_id)!=int(desired.beard_id) or (sex==0 and int(native.beard_hue)!=int(desired.beard_hue)):
				fail("Server hair/beard appearance disagrees with requested native fields"); return
		var avatar:=preload("res://Presentation/Avatar.gd").new()
		avatar.initial_body=expected
		root.add_child(avatar)
		avatar.set_physics_process(false)
		avatar.apply_server_appearance(game.player,game.equipment.values())
		var motion_receiver: Callable
		if motion:
			motion_receiver=func(request: Dictionary):
				if int(request.serial)==int(game.player.serial):avatar.receive_native_action(request)
			game.mobile_action_received.connect(motion_receiver)
			game.set_war_mode(true)
			if not await until(func():return (int(game.player.get("flags",0))&0x40)!=0):fail("Native war-mode confirmation timeout");return
			avatar.apply_server_appearance(game.player,game.equipment.values())
			if not avatar.human_visual.war_mode:fail("Native guard stance not applied");return
			var armed: bool=preload("res://Presentation/HumanWardrobe.gd").resolve(game.equipment.values()).pieces.has("weapon")
			if avatar.human_visual.animator.current_animation!=("Sword_Idle" if armed else "Unarmed_Idle"):fail("Confirmed war mode did not select the ready pose");return
			game.set_war_mode(false)
			if not await until(func():return (int(game.player.get("flags",0))&0x40)==0):fail("Native peace confirmation timeout");return
			avatar.apply_server_appearance(game.player,game.equipment.values())
			if avatar.human_visual.animator.current_animation!="Idle":fail("Confirmed peace mode did not restore the relaxed pose");return
			game.request_emote("bow")
			if not await until(func():return avatar.human_visual.action_clip=="Bow"):fail("Server bow did not reach human motion playback");return
			if visual and visual.avatars.has(int(game.player.serial)) and visual.avatars[int(game.player.serial)].human_visual.action_clip!="Bow":fail("Live-world action signal did not reach player avatar");return
		if avatar.human_visual==null or int(avatar.human_visual.outfit_bits)!=expected_worn:
			fail("Starter clothes did not appear on shared human renderer: bits="+str(avatar.human_visual.outfit_bits if avatar.human_visual else -1))
			return
		var item: Dictionary={}
		for worn: Dictionary in game.equipment.values():
			if int(worn.layer)==22: item=worn; break
		if item.is_empty() or not game.move_item(int(item.serial),int(game.backpack)):
			fail("Cannot begin native clothing removal")
			return
		if not await until(func(): return game.pending_transfer.is_empty() and not game.equipment.has(int(item.layer))):
			fail("Native unequip did not clear appearance")
			return
		avatar.apply_server_appearance(game.player,game.equipment.values())
		var removed_bits:=int(avatar.human_visual.outfit_bits)
		if removed_bits!=expected_unworn:
			fail("Removed native clothing remained visible")
			return
		if sex==1 and (not avatar.human_visual.parts.any(func(part: MeshInstance3D):return part.name.begins_with("Extra_shirt")) or not avatar.human_visual.parts.any(func(part: MeshInstance3D):return part.name.begins_with("Extra_kilt"))):
			fail("Native shirt/skirt layers did not appear beneath the removed robe");return
		if not avatar.human_visual.parts.any(func(part: MeshInstance3D):return part.name.begins_with("Extra_shoes")) or (sex==0 and not avatar.human_visual.parts.any(func(part: MeshInstance3D):return part.name.begins_with("Extra_doublet"))):
			fail("Native civilian doublet/shoes were not presented after robe removal");return
		if not game.move_item(int(item.serial),int(game.player.serial),true):
			fail("Cannot begin native clothing equip")
			return
		if not await until(func(): return game.pending_transfer.is_empty() and game.equipment.has(int(item.layer))):
			fail("Native equip did not restore appearance")
			return
		avatar.apply_server_appearance(game.player,game.equipment.values())
		if int(avatar.human_visual.outfit_bits)!=expected_worn:
			fail("Re-equipped clothing not restored visually")
			return
		var original_serial:=int(game.player.serial)
		results.append({"female":sex==1,"body":expected,"serial":original_serial,"equipment_ids":game.equipment.values().map(func(w): return int(w.id)),"unequip_bits":removed_bits,"reequip_bits":expected_worn})
		if motion:results[-1].native_war_mode_and_bow_playback=true
		avatar.hide()
		if motion:
			game.mobile_action_received.disconnect(motion_receiver);motion_receiver=Callable()
		avatar.queue_free()
		await process_frame
		game.close()
		await create_timer(1.).timeout
		error=""
		game.connect_account(account.username,account.password)
		if not await until(func(): return game.phase=="characters"):
			fail("Reconnect account failed")
			return
		for character in game.characters:
			if character.name==character_name: game.select_character(character.slot,character_name); break
		if not await until(func(): return game.phase=="world" and game.equipment.size()>=3):
			fail("Reconnect character failed")
			return
		if int(game.player.serial)!=original_serial or int(game.player.get("body",0))!=expected:
			fail("Native identity/sex did not persist")
			return
		results[-1].reconnect=true
		if cosmetics:
			var persisted: Dictionary=game.appearance_for(original_serial)
			if persisted.hair_id!=desired.hair_id or persisted.hair_hue!=desired.hair_hue or persisted.beard_id!=desired.beard_id or (sex==0 and persisted.beard_hue!=desired.beard_hue):
				fail("Native hair/beard types or colours did not persist"); return
			results[-1].native_appearance=persisted
		if sex==1:
			var observer:=Game.new()
			root.add_child(observer)
			observer.failed.connect(func(reason: String): error=reason)
			observer.connect_account(credentials[0].username,credentials[0].password)
			if not await until(func(): return observer.phase=="characters"):
				fail("Observer login failed"); return
			for character in observer.characters:
				if character.name==male_test_name: observer.select_character(character.slot,character.name); break
			if not await until(func(): return observer.phase=="world" and observer.mobile_equipment.has(original_serial)):
				fail("Female appearance not received by second client"); return
			if int(observer.entities[original_serial].body)!=0x191:
				fail("Second client did not receive female body"); return
			if cosmetics and (observer.appearance_for(original_serial).hair_id!=desired.hair_id or observer.appearance_for(original_serial).hair_hue!=desired.hair_hue):
				fail("Second client hair type/colour mismatch"); return
			game.move_item(int(item.serial),int(game.backpack))
			if not await until(func(): return game.pending_transfer.is_empty() and not observer.mobile_equipment[original_serial].has(22)):
				fail("Second client retained removed robe"); return
			game.move_item(int(item.serial),int(game.player.serial),true)
			if not await until(func(): return game.pending_transfer.is_empty() and observer.mobile_equipment[original_serial].has(22)):
				fail("Second client missed re-equipped robe"); return
			results[-1].second_client_body_and_robe_updates=true
			if motion:
				var remote:=preload("res://Presentation/Avatar.gd").new();remote.initial_body=0x191;root.add_child(remote);remote.set_physics_process(false)
				remote.apply_server_appearance(observer.entities[original_serial],observer.mobile_equipment[original_serial].values())
				var remote_receiver: Callable=func(request: Dictionary):
					if int(request.serial)==original_serial:remote.receive_native_action(request)
				observer.mobile_action_received.connect(remote_receiver)
				game.request_emote("bow")
				if not await until(func():return remote.human_visual.action_clip=="Bow"):fail("Second client missed native bow playback");return
				results[-1].second_client_native_action_playback=true
				observer.mobile_action_received.disconnect(remote_receiver);remote_receiver=Callable();remote.queue_free()
			observer.close()
			observer.queue_free()
		if visual:
			await create_timer(2.).timeout
			visual.boom.spring_length=3.5
			for i in 20: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../outputs/third-dawn/female-live-britain.png")
			visual.character_sheet.toggle("character")
			for i in 20: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../outputs/third-dawn/female-live-character-sheet.png")
		game.close()
		if visual: visual.queue_free()
		else: game.queue_free()
		await process_frame
	for i in 4:await process_frame
	var f:=FileAccess.open("res://../outputs/third-dawn/human-batch-live.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"characters":results,"failures":[]},"\t"))
	print("HUMAN BATCH LIVE PASS: male/female native creation or re-entry, clothes removal/re-equip, reconnect identity and sex")
	if motion:print("NATIVE MOTION LIVE PASS: server war/peace, bow on both bodies, live-world player and second-client action playback")
	quit(0)
