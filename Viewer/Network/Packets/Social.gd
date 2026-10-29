extends "res://Network/Packets/PacketModule.gd"
# Party (0xBF 0x06), secure trade (0x6F), selling to vendors (0x9E), chat
# (0xB2), quest and tracking arrows (0xBA) and party or guild member
# locations (0xF0, assistant protocol). Each with its requests. ClassicUO:
# PartyManager, TradingGump, ShopGump (sell), ChatManager, QuestArrowGump.
signal party_changed
signal party_message(serial: int, text: String, private: bool)
signal party_invited(leader: int)
signal trade_changed(trade: Dictionary)
signal trade_closed(container: int)
signal sell_list(vendor: int, items: Array)
signal chat(command: int, first: String, second: String)
signal arrow_changed(arrow: Dictionary)
signal locations_changed
var party: Array = []
var invited_by := 0
# Trade container serial -> {them, mine, theirs, name, mine_accepted, theirs_accepted, gold, platinum}
var trades := {}
var arrow := {}
# Mobile serial -> {x, y, map, hits (guild only, %)}.
var member_locations := {}

func routes() -> void:
	session.route_extended(0x06,_party)
	session.route(0x6f,_trade)
	session.route(0x9e,_sell)
	session.route(0xb2,func(p: PackedByteArray):
		var first := utf16(p,9,p.size()-9,false)
		var second_at := 9+first.length()*2+2
		chat.emit(u16(p,3)+20,first,utf16(p,second_at,p.size()-second_at,false)))
	session.route(0xba,func(p: PackedByteArray):
		arrow = {"active":u8(p,1) != 0,"x":u16(p,2),"y":u16(p,4),"serial":u32(p,6) if p.size() >= 10 else 0}
		arrow_changed.emit(arrow))
	session.route(0xf0,_locations)

func reset() -> void:
	party.clear()
	invited_by = 0
	trades.clear()
	arrow = {}
	member_locations.clear()

func _party(p: PackedByteArray) -> void:
	match u8(p,5):
		1:
			party.clear()
			for i in u8(p,6): party.append(u32(p,7+i*4))
			party_changed.emit()
		2:
			party.clear()
			for i in u8(p,6): party.append(u32(p,11+i*4))
			party_changed.emit()
		3, 4: party_message.emit(u32(p,6),utf16(p,10,p.size()-10,false),u8(p,5) == 3)
		7:
			invited_by = u32(p,6)
			party_invited.emit(invited_by)

func _trade(p: PackedByteArray) -> void:
	var container := u32(p,4)
	match u8(p,3):
		0:
			trades[u32(p,8)] = {"them":container,"mine":u32(p,8),"theirs":u32(p,12),"name":ascii(p,17,30) if u8(p,16) else "","mine_accepted":false,"theirs_accepted":false,"gold":0,"platinum":0}
			trade_changed.emit(trades[u32(p,8)])
		1:
			trades.erase(container)
			trade_closed.emit(container)
		2:
			if trades.has(container):
				trades[container].mine_accepted = u32(p,8) != 0
				trades[container].theirs_accepted = u32(p,12) != 0
				trade_changed.emit(trades[container])
		3, 4:
			if trades.has(container):
				trades[container].gold = u32(p,8)
				trades[container].platinum = u32(p,12)
				trade_changed.emit(trades[container])

func _sell(p: PackedByteArray) -> void:
	var vendor := u32(p,3)
	var items: Array = []
	var at := 9
	for i in u16(p,7):
		if at+14 > p.size(): break
		var name_length := u16(p,at+12)
		items.append({"serial":u32(p,at),"graphic":u16(p,at+4),"hue":u16(p,at+6),"amount":u16(p,at+8),"price":u16(p,at+10),"name":ascii(p,at+14,name_length)})
		at += 14+name_length
	sell_list.emit(vendor,items)

func _locations(p: PackedByteArray) -> void:
	var kind := u8(p,3)
	var with_places := kind == 1 or u8(p,4) != 0
	var at := 4 if kind == 1 else 5
	while at+4 <= p.size():
		var serial := u32(p,at)
		at += 4
		if serial == 0: break
		if with_places:
			member_locations[serial] = {"x":u16(p,at),"y":u16(p,at+2),"map":u8(p,at+4),"hits":u8(p,at+5) if kind == 2 else -1}
			at += 5 if kind == 1 else 6
	locations_changed.emit()

# --- requests ---
static func _party_command(command: int, payload := PackedByteArray()) -> PackedByteArray:
	var body := be16(0x06)
	body.append(command)
	body.append_array(payload)
	return variable(0xbf,body)
# Invite (0 = the server asks for a target), remove, private and loot rights.
static func party_add(serial := 0) -> PackedByteArray: return _party_command(0x01,be32(serial))
static func party_remove(serial: int) -> PackedByteArray: return _party_command(0x02,be32(serial))
static func party_private(serial: int, text: String) -> PackedByteArray:
	var payload := be32(serial)
	payload.append_array(big_text(text))
	return _party_command(0x03,payload)
static func party_loot(allowed: bool) -> PackedByteArray: return _party_command(0x06,PackedByteArray([1 if allowed else 0]))
static func party_accept(leader: int) -> PackedByteArray: return _party_command(0x08,be32(leader))
static func party_decline(leader: int) -> PackedByteArray: return _party_command(0x09,be32(leader))

# Secure trade: cancel (1), accept toggle (2) and the gold offer (3).
static func trade_cancel(container: int) -> PackedByteArray:
	var payload := PackedByteArray([1])
	payload.append_array(be32(container))
	return variable(0x6f,payload)
static func trade_accept(container: int, accepted: bool) -> PackedByteArray:
	var payload := PackedByteArray([2])
	payload.append_array(be32(container))
	payload.append_array(be32(1 if accepted else 0))
	return variable(0x6f,payload)
static func trade_gold(container: int, gold: int, platinum := 0) -> PackedByteArray:
	var payload := PackedByteArray([3])
	payload.append_array(be32(container))
	payload.append_array(be32(gold))
	payload.append_array(be32(platinum))
	return variable(0x6f,payload)

# Sell to a vendor (0x9F): [{serial, amount}].
static func sell(vendor: int, items: Array) -> PackedByteArray:
	var payload := be32(vendor)
	payload.append_array(be16(items.size()))
	for item in items:
		payload.append_array(be32(int(item.serial)))
		payload.append_array(be16(int(item.amount)))
	return variable(0x9f,payload)

# Chat action (0xB3) and opening the chat window (0xB5, 64 bytes).
static func chat_action(action: int, parameter := "") -> PackedByteArray:
	var payload := "ENU".to_ascii_buffer()
	payload.append(0)
	payload.append_array(be16(action))
	payload.append_array(big_text(parameter))
	return variable(0xb3,payload)
static func open_chat(name := "") -> PackedByteArray:
	var packet := PackedByteArray([0xb5])
	packet.append_array("ENU".to_ascii_buffer())
	packet.append(0)
	packet.append_array(be16(0))
	packet.append_array(big_text(name))
	packet.resize(64)
	return packet

# Clicking the quest or tracking arrow (0xBF 0x07; right click cancels).
static func arrow_click(right := false) -> PackedByteArray:
	var payload := be16(0x07)
	payload.append(1 if right else 0)
	return variable(0xbf,payload)

# Party (0xF0 0x00) or guild (0xF0 0x01) member locations.
static func party_locations() -> PackedByteArray: return variable(0xf0,PackedByteArray([0x00]))
static func guild_locations(with_places := true) -> PackedByteArray: return variable(0xf0,PackedByteArray([0x01,1 if with_places else 0]))

static func big_text(text: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	for i in text.length(): bytes.append_array(be16(text.unicode_at(i)))
	bytes.append_array(be16(0))
	return bytes
