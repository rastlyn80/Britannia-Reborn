extends SceneTree
# Protocol coverage and fixture checks (docs/PROTOCOL_BLUEPRINT.md):
# - every packet ModernUO (pinned revision) sends has a handler, and every
#   0xBF subcommand it sends too;
# - every packet ModernUO accepts has a builder somewhere, or is listed as
#   deliberately not sent;
# - module parsers read ModernUO's byte layouts correctly;
# - builders produce ModernUO's fixed lengths and consistent length fields.
const PacketModule = preload("res://Network/Packets/PacketModule.gd")
var failures := 0
var checks := 0
var session: Node

# Packets ModernUO sends on the game connection (Server/Network/Packets and
# UOContent senders; login-connection 0x8C and 0xA8 are handled by LoginProtocol).
const SERVER_SENDS := [0x0b,0x11,0x17,0x1a,0x1b,0x1c,0x1d,0x20,0x21,0x22,0x23,0x24,0x25,0x27,0x2c,0x2d,0x2e,0x2f,0x38,0x3a,0x3b,0x3c,0x4e,0x4f,0x53,0x54,0x55,0x56,0x5b,0x65,0x66,0x6c,0x6d,0x6e,0x6f,0x70,0x71,0x72,0x73,0x74,0x76,0x77,0x78,0x7b,0x7c,0x81,0x82,0x85,0x86,0x88,0x89,0x8b,0x90,0x95,0x97,0x98,0x99,0x9e,0xa1,0xa2,0xa3,0xa5,0xa6,0xa9,0xaa,0xae,0xaf,0xb0,0xb2,0xb7,0xb8,0xb9,0xba,0xbc,0xbd,0xbf,0xc0,0xc1,0xc2,0xc6,0xc7,0xc8,0xcc,0xd1,0xd4,0xd6,0xd8,0xda,0xdc,0xdd,0xdf,0xe2,0xf0,0xf2,0xf3,0xf5,0xf6]
const SERVER_EXTENDED := [0x04,0x06,0x08,0x10,0x14,0x17,0x18,0x19,0x1b,0x1d,0x20,0x21,0x22,0x25,0x26,0x2a]
# Packets ModernUO accepts -> where our client builds them.
const CLIENT_BUILDERS := {
	0x00:"deliberate: 0xF8 is the creation packet for this client version",
	0x01:"Requests.disconnect_notice",0x02:"GameSession.movement_packet",0x03:"Requests.ascii_speech",0x05:"ActionProtocol.attack",0x06:"ActionProtocol.double_click",
	0x07:"CommerceProtocol.lift",0x08:"CommerceProtocol.drop",0x09:"ActionProtocol.single_click",0x12:"ActionProtocol.text_command",0x13:"CommerceProtocol.equip",
	0x22:"GameSession.request_position",0x2c:"Player.death_choice",0x34:"MobileNames.query",0x3a:"GameSession.set_skill_lock",0x3b:"CommerceProtocol.buy",
	0x56:"WorldSystems.map_pin",0x5d:"GameSession.select_character",0x66:"Requests.book_pages",0x6c:"GameSession.target_packet",0x6f:"Social.trade_accept",
	0x71:"Requests.board_post",0x72:"GameSession.set_war_mode",0x73:"GameSession._process",0x75:"Player.rename",0x7d:"Dialogs.menu_choice",
	0x80:"LoginProtocol.account_packet",0x83:"Player.delete_character",0x91:"GameSession.game_handshake",0x93:"Requests.old_book_header",0x95:"Dialogs.hue_choice",
	0x98:"Mobiles.name_request",0x9a:"Dialogs.prompt_answer",0x9b:"GameSession.request_help",0x9f:"Social.sell",0xa0:"LoginProtocol",
	0xa4:"deliberate: legacy system information",0xa7:"Dialogs.tip_request",0xad:"ActionProtocol.speech",0xb1:"GumpProtocol.response",0xb3:"Social.chat_action",
	0xb5:"Social.open_chat",0xb6:"Dialogs.object_help",0xb8:"Player.profile_request",0xbd:"GameSession._handle",0xbe:"deliberate: assistant (Razor) version",
	0xbf:"extended (below)",0xc2:"Dialogs.prompt_answer",0xc8:"Environment.view_range_packet",0xd0:"deliberate: client configuration file",0xd1:"Player.logout_request",
	0xd4:"Requests.book_header",0xd6:"Tooltips.query",0xd7:"ActionProtocol.encoded",0xd9:"deliberate: hardware information",0xda:"deliberate: mahjong tables (raw replies)",
	0xe1:"deliberate: enhanced client type",0xec:"Requests.equip_items",0xed:"Requests.unequip_layers",0xef:"LoginProtocol.seed_packet",0xf0:"Social.party_locations",
	0xf1:"deliberate: new movement time sync (off on this shard)",0xf4:"deliberate: crash report",0xf8:"GameSession.creation_packet",0xfa:"deliberate: Ultima Store",0xfb:"Requests.public_house_content"}
const CLIENT_EXTENDED := {0x05:"Requests.screen_size",0x06:"Social.party_add",0x07:"Social.arrow_click",0x09:"Requests.disarm",0x0a:"Requests.stun",0x0b:"Requests.language",
	0x0c:"Requests.close_status",0x0e:"Requests.animate",0x0f:"deliberate: empty keep-alive",0x10:"Requests.query_properties",0x13:"CommerceProtocol.context_request",
	0x15:"CommerceProtocol.context_reply",0x1a:"GameSession.set_stat_lock",0x1c:"Requests.cast_spell",0x1e:"WorldSystems.design_query",0x24:"deliberate: unhandled-by-server probe",
	0x2a:"Player.race_change_reply",0x2c:"ActionProtocol.bandage",0x2d:"Requests.targeted_spell",0x2e:"Requests.targeted_skill",0x30:"Requests.target_resource",0x32:"ActionProtocol.toggle_flying"}
const SCRIPTS := {"GameSession":"res://Network/GameSession.gd","ActionProtocol":"res://Network/ActionProtocol.gd","CommerceProtocol":"res://Network/CommerceProtocol.gd","LoginProtocol":"res://Network/LoginProtocol.gd","GumpProtocol":"res://Network/GumpProtocol.gd","MobileNames":"res://Network/MobileNames.gd",
	"Requests":"res://Network/Packets/Requests.gd","Player":"res://Network/Packets/Player.gd","WorldSystems":"res://Network/Packets/WorldSystems.gd","Social":"res://Network/Packets/Social.gd","Dialogs":"res://Network/Packets/Dialogs.gd","Mobiles":"res://Network/Packets/Mobiles.gd","Environment":"res://Network/Packets/Environment.gd","Tooltips":"res://Network/Packets/Tooltips.gd"}
# ModernUO's registered fixed lengths for client packets we build.
const FIXED := {0x01:5,0x2c:2,0x56:11,0x75:35,0x7d:13,0x83:39,0x93:99,0x95:9,0xa7:4,0xb5:64,0xb6:9,0xc8:2,0xd1:2,0xfb:2}

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void: call_deferred("run")

static func be(value: int, bytes: int) -> PackedByteArray:
	var out := PackedByteArray()
	for i in range(bytes-1,-1,-1): out.append((value>>(i*8))&255)
	return out

static func packet(parts: Array, variable := false) -> PackedByteArray:
	var out := PackedByteArray()
	for part in parts: out.append_array(part if part is PackedByteArray else PackedByteArray([part]))
	if variable:
		out.insert(1,0)
		out.insert(1,0)
		out[1] = out.size()>>8
		out[2] = out.size()&255
	return out

static func uni(text: String, little: bool) -> PackedByteArray:
	var out := PackedByteArray()
	for i in text.length():
		var c := text.unicode_at(i)
		out.append_array(PackedByteArray([c&255,c>>8]) if little else PackedByteArray([c>>8,c&255]))
	out.append_array(PackedByteArray([0,0]))
	return out

func run() -> void:
	session = preload("res://Network/GameSession.gd").new()
	root.add_child(session)
	session.player.serial = 7
	coverage()
	builders()
	fixtures()
	world_systems()
	print("PROTOCOL TESTS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)

func coverage() -> void:
	var missing: Array = SERVER_SENDS.filter(func(id): return not id in session.OWN_PACKETS and not session.routes.has(id))
	check(missing.is_empty(),"Every packet ModernUO sends has a handler %s" % str(missing.map(func(id): return "0x%02X" % id)))
	var missing_extended: Array = SERVER_EXTENDED.filter(func(sub): return not sub in session.OWN_EXTENDED and not session.extended_routes.has(sub))
	check(missing_extended.is_empty(),"Every 0xBF subcommand ModernUO sends has a handler %s" % str(missing_extended))
	var unbuilt: Array = []
	for table in [CLIENT_BUILDERS,CLIENT_EXTENDED]:
		for id in table:
			var where: String = table[id]
			if where.begins_with("deliberate") or not "." in where: continue
			var parts := where.split(".")
			var script: GDScript = load(SCRIPTS[parts[0]])
			var source := script.source_code
			if not ("func "+parts[1]+"(") in source: unbuilt.append("0x%02X %s" % [id,where])
	check(unbuilt.is_empty(),"Every packet ModernUO accepts has a builder or is deliberately not sent %s" % str(unbuilt))

func builders() -> void:
	var Requests := preload("res://Network/Packets/Requests.gd")
	var Player := preload("res://Network/Packets/Player.gd")
	var Dialogs := preload("res://Network/Packets/Dialogs.gd")
	var Social := preload("res://Network/Packets/Social.gd")
	var World := preload("res://Network/Packets/WorldSystems.gd")
	var built := {0x01:Requests.disconnect_notice(),0x2c:Player.death_choice(1),0x56:World.map_pin(9,1,Vector2i(5,6)),0x75:Player.rename(9,"Rex"),
		0x7d:Dialogs.menu_choice({"serial":9,"id":1,"entries":[{"graphic":3,"hue":0}]},1),0x83:Player.delete_character(2),0x93:Requests.old_book_header(9,"T","A"),
		0x95:Dialogs.hue_choice({"serial":9,"graphic":0xfab},33),0xa7:Dialogs.tip_request(3),0xb5:Social.open_chat(),0xb6:Dialogs.object_help(9),
		0xc8:preload("res://Network/Packets/Environment.gd").view_range_packet(18),0xd1:Player.logout_request(),0xfb:Requests.public_house_content(true)}
	for id in FIXED:
		check(built[id].size() == FIXED[id] and built[id][0] == id,"0x%02X builds ModernUO's fixed length %d" % [id,FIXED[id]])
	var variable := [Requests.cast_spell(5),Requests.cast_spell(5,0x4000_0001),Requests.targeted_spell(5,9),Requests.targeted_skill(1,9),Requests.target_resource(9,2),Requests.animate(32),
		Requests.equip_items([1,2]),Requests.unequip_layers([5]),Requests.book_pages(9,{1:["a","b"]}),Requests.book_header(9,"T","A"),Requests.board_post(9,"S",["x"]),
		Requests.ascii_speech("hi"),Player.profile_request(9),Player.profile_update(9,"hello"),Player.race_change_reply(1002,0x203b,1147,0,0),Dialogs.prompt_answer({"serial":9,"id":9,"unicode":true},"Rex"),
		Dialogs.prompt_answer({"serial":9,"id":9,"unicode":false},"Rex"),Social.party_add(),Social.party_private(9,"hi"),Social.trade_accept(9,true),Social.trade_gold(9,100),Social.sell(9,[{"serial":3,"amount":2}]),
		Social.chat_action(0x41,"x"),Social.arrow_click(),Social.party_locations(),World.designer(7,0x04),World.designer_tile(7,0x06,0x1234,1,2),World.design_query(9),
		preload("res://Network/Packets/Tooltips.gd").query([1,2,3]),preload("res://Network/Packets/Mobiles.gd").name_request(9)]
	var consistent := variable.all(func(p: PackedByteArray): return p.size() >= 3 and ((p[1]<<8)|p[2]) == p.size())
	check(consistent,"Every variable-length request carries its own length (%d builders)" % variable.size())
	check(Requests.cast_spell(5) == packet([0xbf,be(0x1c,2),be(0,2),be(5,2)],true),"Cast spell matches ModernUO's reader (no book: 0, spell)")
	check(World.designer_tile(7,0x06,0x1234,1,2) == packet([0xd7,be(7,4),be(6,2),0,be(0x1234,4),0,be(1,4),0,be(2,4),0x0a],true),"House build uses encoded ints and the 0x0A terminator")

func fixtures() -> void:
	var tooltips: RefCounted = session.module("tooltips")
	session.entities[0x40001] = {"serial":0x40001}
	session._handle(packet([0xdc,be(0x40001,4),be(77,4)]))
	check(tooltips.wanted.has(0x40001),"A new tooltip revision queues a query")
	var name_line := uni("a ~1_val~ sword",true)
	name_line.resize(name_line.size()-2)
	session._handle(packet([0xd6,be(1,2),be(0x40001,4),be(0,2),be(77,4),be(1042971,4),be(name_line.size(),2),name_line,be(0,4)],true))
	check(tooltips.lists.has(0x40001) and tooltips.lines_of(0x40001).size() == 1,"Tooltip lines decode from 0xD6")
	session._handle(packet([0x17,be(0x50,4),be(2,2),be(1,2),1,be(2,2),1],true))
	check(session.mobile_statistics[0x50].poisoned and session.mobile_statistics[0x50].yellow_bar,"Health-bar flags set poison and the yellow bar")
	session._handle(packet([0x2d,be(0x50,4),be(100,2),be(55,2),be(20,2),be(10,2),be(30,2),be(29,2)]))
	check(session.mobile_statistics[0x50].hits == 55 and session.mobile_statistics[0x50].stam_max == 30,"Mobile attributes (0x2D)")
	var name := "Rex".to_ascii_buffer()
	name.resize(30)
	session._handle(packet([0x98,be(0x50,4),name],true))
	check(session.entity_names.get(0x50,"") == "Rex","Name reply (0x98)")
	var environment: RefCounted = session.module("environment")
	session._handle(packet([0x5b,13,45,10]))
	session._handle(packet([0xbc,3,1]))
	session._handle(packet([0x6d,be(9,2)]))
	check(environment.server_time.hour == 13 and environment.season == 3 and environment.music_index == 9,"Time, season and music")
	var effects: Array = []
	session.module("effects").spawned.connect(func(e): effects.append(e))
	session._handle(packet([0xc7,0,be(1,4),be(2,4),be(0x36d4,2),be(10,2),be(11,2),5,be(12,2),be(13,2),6,7,8,be(0,2),0,1,be(33,4),be(2,4),be(3000,2),be(4000,2),be(500,2),be(1,4),3,be(0,2)]))
	check(effects.size() == 1 and effects[0].graphic == 0x36d4 and effects[0].hue == 33 and effects[0].explode_sound == 500,"Particle effect (0xC7)")
	var hits: Array = []
	session.module("combat").damaged.connect(func(s,a): hits.append(a))
	session._handle(packet([0x0b,be(0x50,4),be(12,2)]))
	check(hits == [12],"Damage number (0x0B)")
	var buffs: RefCounted = session.module("buffs")
	var arguments := uni("\t5",true)
	session._handle(packet([0xdf,be(7,4),be(1037,2),be(1,2),be(0,4),be(1037,2),be(1,2),be(0,4),be(30,2),PackedByteArray([0,0,0]),be(1075655,4),be(1075656,4),be(0,4),be(1,2),be(0,2),arguments,be(1,2),be(0,2)],true))
	check(buffs.active.has(1037) and int(buffs.active[1037].seconds) == 30 and buffs.remaining(1037) > 29.0,"Buff with a 30 s timer (0xDF)")
	session._handle(packet([0xdf,be(7,4),be(1037,2),be(0,2),be(0,4)],true))
	check(not buffs.active.has(1037),"Buff removal")
	var social: RefCounted = session.module("social")
	session._handle(packet([0xbf,be(0x06,2),1,2,be(7,4),be(8,4)],true))
	check(social.party == [7,8],"Party member list (0xBF 0x06 1)")
	session._handle(packet([0xbf,be(0x06,2),2,1,be(8,4),be(7,4)],true))
	check(social.party == [7],"Party removal keeps the remaining members")
	var sell_items: Array = []
	social.sell_list.connect(func(v,items): sell_items.append_array(items))
	session._handle(packet([0x9e,be(9,4),be(1,2),be(3,4),be(0xf0e,2),be(0,2),be(5,2),be(12,2),be(4,2),"Logs".to_ascii_buffer()],true))
	check(sell_items.size() == 1 and sell_items[0].price == 12 and sell_items[0].name == "Logs","Vendor sell list (0x9E)")
	var trade_name := "Ann".to_ascii_buffer()
	trade_name.resize(30)
	session._handle(packet([0x6f,0,be(0x50,4),be(0x60,4),be(0x61,4),1,trade_name],true))
	check(social.trades.has(0x60) and social.trades[0x60].name == "Ann","Secure trade opens (0x6F)")
	var dialogs: RefCounted = session.module("dialogs")
	session._handle(packet([0x7c,be(9,4),be(1,2),3,"Arm".to_ascii_buffer(),2,be(0x13bb,2),be(0,2),4,"Mail".to_ascii_buffer(),be(0x13be,2),be(0,2),5,"Chain".to_ascii_buffer()],true))
	check(dialogs.menu.question == "Arm" and dialogs.menu.entries.size() == 2 and dialogs.menu.entries[1].name == "Chain","Item menu (0x7C)")
	session._handle(packet([0xc2,be(9,4),be(9,4),be(0,4),be(0,4),be(0,2)],true))
	check(dialogs.prompt.get("unicode",false),"Unicode prompt (0xC2)")
	var world: RefCounted = session.module("world")
	session._handle(packet([0xf5,be(9,4),be(0x139d,2),be(10,2),be(20,2),be(30,2),be(40,2),be(200,2),be(200,2),be(1,2)]))
	check(world.maps[9].to == Vector2i(30,40) and world.maps[9].facet == 1,"Map details (0xF5)")
	var tiles := be(0x0100,2)
	tiles.append_array(PackedByteArray([1,2,7]))
	var compressed := tiles.compress(FileAccess.COMPRESSION_DEFLATE)
	var header := (0<<28)|(1<<24)|((tiles.size()&0xff)<<16)|((compressed.size()&0xff)<<8)|((tiles.size()>>4)&0xf0)|((compressed.size()>>8)&0x0f)
	session._handle(packet([0xd8,3,0,be(0x40009,4),be(5,4),be(1,2),be(compressed.size()+4,2),1,be(header,4),compressed],true))
	check(world.designs.has(0x40009) and world.designs[0x40009].planes[0].tiles[0].id == 0x0100,"Custom house plane decodes (0xD8)")
	var player: RefCounted = session.module("player")
	session._handle(packet([0x2c,0]))
	check(player.dead,"Death status (0x2C)")
	var items: RefCounted = session.module("items")
	session._handle(packet([0xbf,be(0x1b,2),be(1,2),be(0x40010,4),be(0xefa,2),be(1,2),PackedByteArray([0b101,0,0,0,0,0,0,0x80])],true))
	check(items.spellbooks[0x40010].spells == [1,3,64],"Spellbook contents (0xBF 0x1B)")
	session.unhandled.clear()
	session._handle(packet([0xf2,be(0,4),be(0,4),be(0,4),be(0,4),be(0,4),be(0,4)]))
	check(session.unhandled.is_empty(),"Routed packets are not counted as unhandled")
	session._handle(packet([0xfe,1,2]))
	check(session.unhandled.has(0xfe),"Unknown packets are counted for the census")

# Phase 5: multis, placement, maps, boats, speech keywords, custom-house planes.
func world_systems() -> void:
	var Systems := preload("res://Network/Packets/WorldSystems.gd")
	var Keywords := preload("res://Network/SpeechKeywords.gd")
	check(Keywords.pack([54,79,353]) == PackedByteArray([0,0x30,0x36,0x04,0xf1,0x61]),"Speech keyword ids pack in 12 bits as ClassicUO writes them")
	check(Keywords.pack([2]) == PackedByteArray([0,0x10,0x02]),"One keyword packs as count, id")
	check(Keywords.matches("stop the ship",{"words":["stop"],"open_start":false,"open_end":true}) and not Keywords.matches("nonstop",{"words":["stop"],"open_start":true,"open_end":true}),"Keywords match whole words with open ends")
	session._handle(packet([0xf3,be(1,2),2,be(0x40020,4),be(0x13ec,2),0,be(1,2),be(1,2),be(1500,2),be(1600,2),0,0,be(0,2),0,be(0,2)]))
	check(session.multis.has(0x40020) and int(session.multis[0x40020].id) == 0x13ec and not session.world_items.has(0x40020),"A multi (0xF3 type 2) is kept as a house, not an item")
	session._handle(packet([0x1d,be(0x40020,4)]))
	check(not session.multis.has(0x40020),"Removing a multi forgets it")
	var target := packet([0x99,1,be(5,4),0,be(0,4),be(0,4),PackedByteArray([0,0,0]),be(0x68,2),be(0,2),be(4,2),be(0,2),be(0,4)])
	session._handle(target)
	var world: RefCounted = session.module("world")
	check(int(world.placement.multi) == 0x68 and world.placement.offset == Vector3i(0,4,0) and session.target_request.size() == 19,"Multi placement (0x99) is a target cursor with its multi and offset")
	var answer := Systems.place_multi(world.placement,1637,1466,-5,0x1797)
	check(answer.size() == 19 and answer[1] == 1 and answer[17] == 0x17 and answer[18] == 0x97 and answer[16] == 251,"Placement answers a location; on water it names the water tile")
	var pins: Array = []
	world.map_command.connect(func(s,c,p,n): pins.append([c,p,n]))
	session._handle(packet([0x56,be(9,4),1,0,be(203,2),be(181,2)]))
	session._handle(packet([0x56,be(9,4),4,2,be(0,2),be(0,2)]))
	check(pins.size() == 2 and pins[0][1] == Vector2i(203,181) and pins[1][0] == 4 and pins[1][2] == 2,"Map pins (0x56) carry their point and pin number")
	session.multis[0x40030] = {"serial":0x40030,"id":0,"x":100,"y":100,"z":-5}
	session.entities[0x50] = {"serial":0x50,"x":101,"y":101,"z":-2}
	session._handle(packet([0xf6,be(0x40030,4),1,1,0,be(100,2),be(99,2),be(-5 & 0xffff,2),be(1,2),be(0x50,4),be(101,2),be(100,2),be(-2 & 0xffff,2)],true))
	check(int(session.multis[0x40030].y) == 99 and int(session.entities[0x50].y) == 100,"A boat move (0xF6) carries its passengers")
	# A mode-2 plane: rows over the house bounds (ClassicUO ReadUnsafeCustomHouseData).
	var plane := sample_plane()
	var parts: Array = preload("res://Presentation/MultiPresenter.gd").design_parts({"planes":[plane]},-1)
	check(parts.is_empty(),"Designs of unknown multis build nothing")

static func sample_plane() -> Dictionary:
	return preload("res://Network/Packets/WorldSystems.gd").decode_plane(PackedByteArray([0,10,0,0]),2,1)
