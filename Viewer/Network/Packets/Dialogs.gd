extends "res://Network/Packets/PacketModule.gd"
# Server dialogs that are not gumps: item and question menus (0x7C), the
# hue picker (0x95), text prompts (0x9A ASCII, 0xC2 Unicode), web links
# (0xA5), tips and notices (0xA6), sign gumps (0x8B), help text (0xB7) and
# help topics (0xBF 0x17). Each has its answer builder below. ClassicUO:
# OpenMenu, DyeData, ASCIIPrompt, UnicodePrompt, OpenUrl, TipWindow.
signal menu_opened(menu: Dictionary)
signal hue_picker_opened(picker: Dictionary)
signal prompt_opened(prompt: Dictionary)
signal url_requested(url: String)
signal tip_opened(tip: Dictionary)
signal sign_opened(sign: Dictionary)
signal help_text(serial: int, text: String)
signal help_topic(topic: int, show: bool)
var menu := {}
var hue_picker := {}
var prompt := {}

func routes() -> void:
	session.route(0x7c,_menu)
	session.route(0x95,func(p: PackedByteArray):
		hue_picker = {"serial":u32(p,1),"graphic":u16(p,7)}
		hue_picker_opened.emit(hue_picker))
	session.route(0x9a,func(p: PackedByteArray):
		prompt = {"serial":u32(p,3),"id":u32(p,7),"type":u32(p,11),"text":ascii_z(p,15)[0],"unicode":false}
		prompt_opened.emit(prompt))
	session.route(0xc2,func(p: PackedByteArray):
		prompt = {"serial":u32(p,3),"id":u32(p,7),"type":u32(p,11),"text":"","unicode":true}
		prompt_opened.emit(prompt))
	session.route(0xa5,func(p: PackedByteArray): url_requested.emit(ascii_z(p,3)[0]))
	session.route(0xa6,func(p: PackedByteArray): tip_opened.emit({"type":u8(p,3),"number":u32(p,4),"text":ascii(p,10,u16(p,8))}))
	session.route(0x8b,_sign)
	session.route(0xb7,func(p: PackedByteArray): help_text.emit(u32(p,3),utf16(p,7,p.size()-7,false)))
	session.route_extended(0x17,func(p: PackedByteArray): help_topic.emit(u32(p,6),u8(p,10) != 0))

func reset() -> void:
	menu = {}
	hue_picker = {}
	prompt = {}

func _menu(p: PackedByteArray) -> void:
	var question_length := u8(p,9)
	var at := 10+question_length
	var entries: Array = []
	for i in u8(p,at):
		var entry_at := at+1
		var name_length := u8(p,entry_at+4)
		entries.append({"graphic":u16(p,entry_at),"hue":u16(p,entry_at+2),"name":ascii(p,entry_at+5,name_length)})
		at = entry_at+4+name_length
	menu = {"serial":u32(p,3),"id":u16(p,7),"question":ascii(p,10,question_length),"entries":entries}
	menu_opened.emit(menu)

func _sign(p: PackedByteArray) -> void:
	var first := u16(p,9)
	sign_opened.emit({"serial":u32(p,3),"gump":u16(p,7),"text":ascii(p,11,first),"caption":ascii(p,13+first,u16(p,11+first))})

# --- answers ---
# Menu choice (0x7D); index 0 cancels. Entry indexes start at 1.
static func menu_choice(open: Dictionary, index: int) -> PackedByteArray:
	var packet := PackedByteArray([0x7d])
	packet.append_array(be32(int(open.get("serial",0))))
	packet.append_array(be16(int(open.get("id",0))))
	packet.append_array(be16(index))
	var entry: Dictionary = open.get("entries",[])[index-1] if index > 0 and index <= open.get("entries",[]).size() else {}
	packet.append_array(be16(int(entry.get("graphic",0))))
	packet.append_array(be16(int(entry.get("hue",0))))
	return packet

# Chosen hue (0x95).
static func hue_choice(picker: Dictionary, hue: int) -> PackedByteArray:
	var packet := PackedByteArray([0x95])
	packet.append_array(be32(int(picker.get("serial",0))))
	packet.append_array(be16(int(picker.get("graphic",0))))
	packet.append_array(be16(hue))
	return packet

# Prompt answer: 0x9A (ASCII) or 0xC2 (Unicode, "ENU"); cancel sends type 0.
static func prompt_answer(open: Dictionary, text: String, cancel := false) -> PackedByteArray:
	var payload := be32(int(open.get("serial",0)))
	payload.append_array(be32(int(open.get("id",0))))
	payload.append_array(be32(0 if cancel else 1))
	if open.get("unicode",true):
		payload.append_array("ENU".to_ascii_buffer())
		payload.append(0)
		for i in text.length():
			var code := text.unicode_at(i)
			payload.append_array(PackedByteArray([code&255,(code>>8)&255]))
		return variable(0xc2,payload)
	payload.append_array(text.to_ascii_buffer())
	payload.append(0)
	return variable(0x9a,payload)

# Next or previous tip (0xA7).
static func tip_request(number: int, next := true) -> PackedByteArray:
	var packet := PackedByteArray([0xa7])
	packet.append_array(be16(number))
	packet.append(0 if next else 1)
	return packet

# Help text for an object under the cursor (0xB6, language ENU).
static func object_help(serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0xb6])
	packet.append_array(be32(serial))
	packet.append(0)
	packet.append_array("ENU".to_ascii_buffer())
	return packet
