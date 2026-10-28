extends CanvasLayer
# In-game developer edit mode (F9). Joins the server-authoritative session,
# shows selection/inspection, transform, placement and terrain brush tools with
# preview / accept / cancel, undo / redo, saved edit sets and live session
# status. Every action becomes a DevEditState command, the same textual model a
# future conversational assistant (or scripts/dev-edit.ps1) uses.
const State = preload("res://DevEdit/DevEditState.gd")
const Overlay = preload("res://DevEdit/DevEditOverlay.gd")
const Modern = preload("res://Network/ModernSkin.gd")
var world: Node3D
var game: Node
var state := State.new()
var overlay: Node3D
var active := false
var joined := false
var tool := "select"
var assets: Array = []
var selected := ""
var selected_record := {}
var selected_info := {}
var draft_target := ""
var draft_state := ""
var reserved := ""
var activity: Array[String] = []
var latency_ms: Array = []
var panel: PanelContainer
var session_label: Label
var inspector: Label
var warning: Label
var scope_label: Label
var activity_label: Label
var asset_picker: OptionButton
var step_picker: OptionButton
var radius_box: SpinBox
var delta_box: SpinBox
var surface_picker: OptionButton
var set_name: LineEdit
var tool_buttons: Dictionary = {}
var transform_box: Container
var terrain_box: Container
var accept_button: Button
var undo_button: Button
var redo_button: Button

func configure(owner_world: Node3D) -> void:
	world = owner_world
	game = world.game
	layer = 20
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://DevEdit/approved-assets.json"))
	if catalogue is Dictionary: assets = catalogue.assets
	overlay = Overlay.new()
	overlay.name = "DevEditOverlay"
	world.city_stream.add_child(overlay)
	overlay.configure(world.city_stream,state)
	game.dev_edit_received.connect(func(line: String): state.feed(line))
	game.ended.connect(func():
		joined = false
		state.reset()
		refresh())
	state.session_changed.connect(refresh)
	state.request_changed.connect(_request_changed)
	state.targets_changed.connect(_targets_changed)
	state.locks_changed.connect(func(_t: String): refresh())
	state.rejected.connect(func(_r: int, code: String, detail: String): note("Refused (%s): %s" % [code,detail]))
	_build()
	panel.hide()

func sender() -> Callable:
	return func(text: String) -> bool: return game.send_dev_edit(text)

func toggle() -> void:
	active = not active
	panel.visible = active
	overlay.set_markers(active)
	if active and not joined and game.phase == "world":
		joined = state.join(sender())
		note("Joining developer session…")
		overlay.warm(assets.map(func(asset: Dictionary): return int(asset.id)))
	if not active: cancel()
	refresh()

# ---- input from World (left click in the 3D view while active) ----

func click(screen: Vector2) -> void:
	var hit: Dictionary = overlay.pick(world.camera,screen)
	match tool:
		"select":
			if hit.has("target"): select(hit.target,hit.get("record",{}))
			else: select("",{})
		"place":
			if hit.has("ground"):
				var g: Vector3 = hit.ground
				_set_draft("n","a:%d:%s:%s:%d:0" % [current_asset(),State.number(g.x-0.5),State.number(g.y-0.5),int(g.z)])
		"terrain":
			if hit.has("ground"):
				var g: Vector3 = hit.ground
				_set_draft("b:%d:%d:%d:%d:%s" % [roundi(g.x),roundi(g.y),int(radius_box.value),int(delta_box.value),surface()],"")

func select(target: String, record: Dictionary) -> void:
	if reserved != "" and reserved != target:
		state.release(reserved,sender())
		reserved = ""
	cancel()
	selected = target
	selected_record = record
	selected_info = {}
	if target.begins_with("s:"):
		if record.is_empty(): selected_record = overlay.record_for(target)
		if not selected_record.is_empty(): selected_info = overlay.info_for(selected_record)
	if target != "" and editable() and state.locks.get(target,"") in ["",state.me]:
		state.reserve(target,sender())
		reserved = target
	refresh()

func editable() -> bool:
	if selected.begins_with("p:"): return state.state_of(selected) != ""
	return selected.begins_with("s:") and bool(selected_info.get("editable",false))

func current_asset() -> int:
	return int(assets[asset_picker.selected].id) if asset_picker.selected >= 0 and not assets.is_empty() else 0

func surface() -> String:
	return State.SURFACES[surface_picker.selected]

# The current placement of the selection: accepted overlay state or baseline.
func placement_of(target: String) -> Dictionary:
	var place := State.placement(state.state_of(target))
	if not place.is_empty(): return place
	if target.begins_with("s:") and not selected_record.is_empty():
		return {"x":float(selected_record.x),"y":float(selected_record.y),"z":int(selected_record.z),"yaw":0,"id":int(selected_record.id)}
	return {}

func encode(target: String, place: Dictionary) -> String:
	if target.begins_with("p:"): return "a:%d:%s:%s:%d:%d" % [place.id,State.number(place.x),State.number(place.y),place.z,posmod(int(place.yaw),360)]
	return "m:%s:%s:%d:%d:%d" % [State.number(place.x),State.number(place.y),place.z,posmod(int(place.yaw),360),place.id]

func nudge(dx: float, dy: float, dz: int, dyaw: int) -> void:
	if not editable(): return
	var drafted := State.placement(draft_state) if draft_target == selected else {}
	var base := drafted if not drafted.is_empty() else placement_of(selected)
	if base.is_empty(): return
	var step := 1.0 if step_picker.selected == 1 else 0.25
	base.x = float(base.x)+dx*step
	base.y = float(base.y)+dy*step
	base.z = int(base.z)+dz
	base.yaw = int(base.yaw)+dyaw
	_set_draft(selected,encode(selected,base))

func replace() -> void:
	if not editable(): return
	var base := placement_of(selected)
	base.id = current_asset()
	_set_draft(selected,encode(selected,base))

func hide_selected() -> void:
	if selected.begins_with("s:") and editable(): _set_draft(selected,"hide")

func restore_selected() -> void:
	if editable() or (selected.begins_with("s:") and state.state_of(selected) != ""): _set_draft(selected,"")

func _set_draft(target: String, desired: String) -> void:
	draft_target = target
	draft_state = desired
	var label := "DRAFT (not shared)"
	if desired == "" and target.begins_with("s:"):
		overlay.clear_draft()
	else:
		overlay.set_draft(target,desired,label)
	refresh()

func preview() -> void:
	if draft_target.is_empty(): return
	state.preview(draft_target,draft_state,sender())
	note("Shared preview of %s" % draft_target)

func accept() -> void:
	if draft_target.is_empty(): return
	var id := 0
	if draft_target == "n":
		var p := State.placement(draft_state)
		id = state.place(int(p.id),float(p.x),float(p.y),int(p.z),int(p.yaw),sender())
	elif draft_target.begins_with("b:"):
		var f := draft_target.split(":")
		id = state.brush(int(f[1]),int(f[2]),int(f[3]),int(f[4]),f[5],sender())
	else:
		id = state.set_state(draft_target,draft_state,describe(draft_target,draft_state),sender())
	if id == 0: note("Not sent: command could not be encoded or you are not in the world.")
	state.clear_preview(sender())
	overlay.clear_draft()
	draft_target = ""
	draft_state = ""
	refresh()

func cancel() -> void:
	if not draft_target.is_empty(): state.clear_preview(sender())
	overlay.clear_draft()
	draft_target = ""
	draft_state = ""
	if panel: refresh()

func describe(target: String, desired: String) -> String:
	if desired == "": return "restore "+target
	if desired == "hide": return "hide "+target
	return "edit "+target

# ---- feedback ----

func note(text: String) -> void:
	activity.push_front(text)
	if activity.size() > 9: activity.resize(9)
	if activity_label: activity_label.text = "\n".join(activity)

func _request_changed(id: int) -> void:
	var request: Dictionary = state.requests[id]
	match str(request.status):
		"pending": note("Pending: %s" % request.description)
		"applied": note("Applied r%d: %s" % [int(request.seq),request.description] if int(request.seq) > 0 else "Applied: %s %s" % [request.description,request.detail])
		"failed": note("Failed: %s — %s" % [request.description,request.detail])

func _targets_changed(targets: Array, seq: int, author: String, action: String) -> void:
	if action == "sync":
		note("Synchronized: revision %d, %d edited targets" % [seq,state.targets.values().filter(func(t: Dictionary): return t.state != "").size()])
	elif author != state.me:
		note("%s: %s · %d target(s) · r%d" % [author,action,targets.size(),seq])
	else:
		for id in state.requests:
			if int(state.requests[id].seq) == seq:
				var sent: int = state.requests[id].sent_msec
				# Visible = the frame after the overlay applied (terrain: after its swap).
				while not overlay.idle(): await get_tree().process_frame
				await RenderingServer.frame_post_draw
				latency_ms.append(Time.get_ticks_msec()-sent)
	if selected != "" and targets.has(selected): select(selected,selected_record)
	refresh()

func scope() -> String:
	if draft_target.begins_with("b:"):
		var f := draft_target.split(":")
		var cells := State.brush_cells(int(f[1]),int(f[2]),int(f[3]),int(f[4]))
		var touched: Array = overlay.affected_districts(cells.keys().map(func(c: Vector2i): return "t:%d:%d" % [c.x,c.y]))
		return "Scope: terrain disc r%s → %d samples around %s,%s · %d district mesh(es) rebuild · %+d Z, surface %s\nVISUAL PREVIEW ONLY: ModernUO movement still uses the original map." % [f[3],cells.size(),f[1],f[2],touched.size(),int(f[4]),f[5]]
	if draft_target == "n":
		var p := State.placement(draft_state)
		return "Scope: new decorative object (graphic %d) at %s, %s, Z %d · visual only, no collision" % [p.id,State.number(p.x),State.number(p.y),p.z]
	if not draft_target.is_empty():
		return "Scope: one %s %s → %s" % ["placed object" if draft_target.begins_with("p:") else "static",draft_target,"baseline" if draft_state == "" else draft_state]
	return "Scope: nothing pending. Choose a tool and click in the world."

func refresh() -> void:
	if panel == null: return
	var status := "offline (enter the world first)"
	if state.denied != "": status = "NOT AUTHORIZED: "+state.denied
	elif state.synced: status = "session %s · r%d · you: %s · editors: %s" % [state.session,state.revision,state.me,", ".join(state.editors.keys())]
	elif joined: status = "joining…"
	session_label.text = status
	var lines: Array[String] = []
	if selected.is_empty(): lines.append("No selection.")
	elif selected.begins_with("p:"):
		var p := State.placement(state.state_of(selected))
		lines.append("Placed object %s (graphic %d)" % [selected,int(p.get("id",0))])
		lines.append("At %s, %s, Z %d · yaw %d°" % [State.number(float(p.get("x",0))),State.number(float(p.get("y",0))),int(p.get("z",0)),int(p.get("yaw",0))])
		lines.append("Source: developer overlay · r%d by %s" % [state.revision_of(selected),state.author_of(selected)])
	else:
		var r := selected_record
		lines.append("%s · graphic 0x%04X (%d)" % [str(selected_info.get("name","?")),int(r.get("id",0)),int(r.get("id",0))])
		lines.append("Trammel %d, %d, Z %d · hue %d" % [int(r.get("x",0)),int(r.get("y",0)),int(r.get("z",0)),int(r.get("hue",0))])
		lines.append("Identity %s" % selected)
		lines.append("Source: prepared near_%d_%d record #%d · %s/%s · %d render part(s)" % [selected_info.get("district",Vector2i.ZERO).x,selected_info.get("district",Vector2i.ZERO).y,int(r.get("index",0)),selected_info.get("kind",""),selected_info.get("state",""),int(selected_info.get("entries",0))])
		if state.state_of(selected) != "": lines.append("Overlay: %s · r%d by %s" % [state.state_of(selected),state.revision_of(selected),state.author_of(selected)])
		if not selected_info.get("editable",false): lines.append("Not live-editable: "+str(selected_info.get("reason","")))
	if state.locks.has(selected): lines.append("Reserved by %s" % state.locks[selected])
	inspector.text = "\n".join(lines)
	var gameplay := ""
	if selected.begins_with("s:") and selected_info.get("blocking",false): gameplay = "VISUAL PREVIEW ONLY: ModernUO still treats this tile as blocked/unchanged; hiding or moving it does not change movement or line of sight."
	elif draft_target.begins_with("b:"): gameplay = "VISUAL PREVIEW ONLY: terrain height is not sent to ModernUO; movement and collision keep the original elevation."
	warning.text = gameplay
	warning.visible = gameplay != ""
	scope_label.text = scope()
	transform_box.visible = tool == "select"
	terrain_box.visible = tool == "terrain"
	var locked_by_other: bool = state.locks.get(selected,"") not in ["",state.me]
	accept_button.disabled = draft_target.is_empty() or not state.synced or (draft_target == selected and locked_by_other)
	undo_button.disabled = state.undo_candidate() == 0 or not state.synced
	redo_button.disabled = state.redo_candidate() == 0 or not state.synced
	undo_button.text = "Undo r%d" % state.undo_candidate() if state.undo_candidate() > 0 else "Undo"
	redo_button.text = "Redo r%d" % state.redo_candidate() if state.redo_candidate() > 0 else "Redo"
	for name in tool_buttons: tool_buttons[name].button_pressed = name == tool

# ---- panel ----

func _button(text: String, tip: String, action: Callable, parent: Container) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	parent.add_child(row)
	return row

func _text(parent: Container, size := 13, color := Modern.IVORY) -> Label:
	var l := Modern.label("",size,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 340
	parent.add_child(l)
	return l

func _build() -> void:
	panel = PanelContainer.new()
	panel.theme = Modern.theme()
	panel.add_theme_stylebox_override("panel",Modern.panel())
	panel.position = Vector2(12,64)
	panel.custom_minimum_size = Vector2(372,0)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(368,640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	scroll.add_child(column)
	column.add_child(Modern.label("Developer edit  (F9)",17,Modern.IVORY,700))
	session_label = _text(column,12)
	var tools := _row(column)
	for entry in [["select","Select","Select a static or placed object (click)"],["place","Place","Place an approved decorative asset (click the ground)"],["terrain","Terrain","Bounded terrain brush (click the ground)"]]:
		var b := _button(entry[1],entry[2],func():
			tool = entry[0]
			cancel()
			refresh(),tools)
		b.toggle_mode = true
		tool_buttons[entry[0]] = b
	column.add_child(Modern.label("Selection",14,Modern.IVORY,700))
	inspector = _text(column,12)
	warning = _text(column,12,Color("ffb347"))
	transform_box = VBoxContainer.new()
	column.add_child(transform_box)
	var move := _row(transform_box)
	_button("X−","Move west",func(): nudge(-1,0,0,0),move)
	_button("X+","Move east",func(): nudge(1,0,0,0),move)
	_button("Y−","Move north",func(): nudge(0,-1,0,0),move)
	_button("Y+","Move south",func(): nudge(0,1,0,0),move)
	_button("Z−","Lower one UO unit",func(): nudge(0,0,-1,0),move)
	_button("Z+","Raise one UO unit",func(): nudge(0,0,1,0),move)
	var turn := _row(transform_box)
	_button("⟲ 15°","Rotate counter-clockwise",func(): nudge(0,0,0,-15),turn)
	_button("⟳ 15°","Rotate clockwise",func(): nudge(0,0,0,15),turn)
	step_picker = OptionButton.new()
	step_picker.add_item("Step ¼ tile")
	step_picker.add_item("Step 1 tile")
	step_picker.tooltip_text = "Horizontal step"
	turn.add_child(step_picker)
	var change := _row(transform_box)
	_button("Hide","Hide this static (visual only)",hide_selected,change)
	_button("Replace","Replace with the asset chosen below",replace,change)
	_button("Baseline","Restore the converted baseline / remove a placed object",restore_selected,change)
	asset_picker = OptionButton.new()
	asset_picker.tooltip_text = "Approved decorative assets (DevEdit/approved-assets.json)"
	for asset in assets: asset_picker.add_item("%s (%d)" % [asset.label,int(asset.id)])
	column.add_child(asset_picker)
	terrain_box = VBoxContainer.new()
	column.add_child(terrain_box)
	var brush := _row(terrain_box)
	radius_box = SpinBox.new();radius_box.min_value = 0;radius_box.max_value = 6;radius_box.value = 2;radius_box.prefix = "r";radius_box.tooltip_text = "Brush radius in tiles (0-6)"
	delta_box = SpinBox.new();delta_box.min_value = -10;delta_box.max_value = 10;delta_box.value = 4;delta_box.prefix = "Z";delta_box.tooltip_text = "Height change at the centre, UO units (falls off to the edge)"
	surface_picker = OptionButton.new();surface_picker.tooltip_text = "Paint surface ('-' keeps it)"
	for name in State.SURFACES: surface_picker.add_item(name)
	for control in [radius_box,delta_box,surface_picker]: brush.add_child(control)
	scope_label = _text(column,12,Color("cfe8ff"))
	var commit := _row(column)
	_button("Preview","Share this draft with the other editors (not saved)",preview,commit)
	accept_button = _button("Accept","Send to the server; applied when accepted",accept,commit)
	_button("Cancel","Discard the draft and shared preview",cancel,commit)
	var history := _row(column)
	undo_button = _button("Undo","Undo your latest edit (refused if someone changed it since)",func(): state.undo(sender()),history)
	redo_button = _button("Redo","Redo your latest undo",func(): state.redo(sender()),history)
	var sets := _row(column)
	set_name = LineEdit.new()
	set_name.placeholder_text = "edit-set-name"
	set_name.custom_minimum_size.x = 150
	sets.add_child(set_name)
	_button("Save set","Write a deterministic edit set on the server (Server/runtime/DevEdit/sets)",func():
		if DevEditSessionName.valid(set_name.text): state.save(set_name.text,sender())
		else: note("Edit set names use a-z, 0-9 and '-'."),sets)
	_button("Load","Apply a saved edit set as one undoable operation",func():
		if DevEditSessionName.valid(set_name.text): state.load_set(set_name.text,sender()),sets)
	column.add_child(Modern.label("Activity",14,Modern.IVORY,700))
	activity_label = _text(column,12,Color("d8d2c4"))
	refresh()

class DevEditSessionName:
	static func valid(text: String) -> bool:
		if text.is_empty() or text.length() > 32: return false
		for c in text:
			if not (c >= "a" and c <= "z" or c >= "0" and c <= "9" or c == "-"): return false
		return true
