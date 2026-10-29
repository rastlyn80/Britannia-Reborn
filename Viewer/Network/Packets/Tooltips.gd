extends "res://Network/Packets/PacketModule.gd"
# Object property lists (tooltips): the server announces each object's
# revision (0xDC, or 0xBF 0x10); changed ones are asked for in batches
# (0xD6 out) and arrive as cliloc lines (0xD6 in). The first line is the
# object's name. ClassicUO: OPLInfo, MegaCliloc, ObjectPropertiesListManager.
signal changed(serial: int)
const BATCH := 12
const INTERVAL_MS := 120
var revisions := {}
var lists := {}
var wanted: Array = []
var queued := {}
# Revision already asked for (reply on its way): not asked again.
var asked := {}
var next_send := 0

func routes() -> void:
	session.route(0xdc,func(p: PackedByteArray): announce(u32(p,1),u32(p,5)))
	session.route_extended(0x10,func(p: PackedByteArray): announce(u32(p,5),u32(p,9)))
	session.route(0xd6,_properties)

func reset() -> void:
	revisions.clear()
	lists.clear()
	asked.clear()
	wanted.clear()
	queued.clear()

func announce(serial: int, revision: int) -> void:
	revisions[serial] = revision
	if int(lists.get(serial,{}).get("revision",-1)) != revision and int(asked.get(serial,-1)) != revision: request(serial)

# Ask for one object's list (hover asks first: it goes to the front).
func request(serial: int, urgent := false) -> void:
	if queued.has(serial):
		if urgent:
			wanted.erase(serial)
			wanted.push_front(serial)
		return
	queued[serial] = true
	if urgent: wanted.push_front(serial)
	else: wanted.append(serial)

static func query(serials: Array) -> PackedByteArray:
	var payload := PackedByteArray()
	for serial in serials: payload.append_array(be32(int(serial)))
	return variable(0xd6,payload)

func tick() -> void:
	if wanted.is_empty() or Time.get_ticks_msec() < next_send: return
	var batch: Array = wanted.slice(0,BATCH)
	wanted = wanted.slice(BATCH)
	for serial in batch:
		queued.erase(serial)
		asked[serial] = revisions.get(serial,-1)
	session.send(query(batch))
	next_send = Time.get_ticks_msec()+INTERVAL_MS

func _properties(p: PackedByteArray) -> void:
	if p.size() < 15 or u16(p,3) > 1: return
	var serial := u32(p,5)
	var revision := u32(p,11)
	var lines: Array[String] = []
	var at := 15
	while at+4 <= p.size():
		var cliloc := u32(p,at)
		if cliloc == 0: break
		var length := u16(p,at+4)
		var argument := utf16(p,at+6,length,true)
		at += 6+length
		lines.append(session.labels.resolve(cliloc,argument))
	lists[serial] = {"revision":revision,"lines":lines}
	revisions[serial] = revision
	if not lines.is_empty() and not session.entity_names.has(serial) and session.entities.has(serial):
		session.entity_names[serial] = _plain(lines[0])
		session.entity_name_received.emit(serial,session.entity_names[serial])
	changed.emit(serial)

# Name (first line) and the remaining property lines, without markup.
func name_of(serial: int) -> String:
	var lines: Array = lists.get(serial,{}).get("lines",[])
	return _plain(lines[0]) if not lines.is_empty() else ""

func lines_of(serial: int) -> Array:
	return lists.get(serial,{}).get("lines",[]).map(func(line): return _plain(line))

static func _plain(text: String) -> String:
	var tags := RegEx.new()
	tags.compile("<[^>]*>")
	return tags.sub(text,"",true).strip_edges()
