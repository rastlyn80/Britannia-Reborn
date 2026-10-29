extends "res://Network/ModernWindow.gd"
# Bulletin boards (0x71): the board's messages listed newest first with
# author and date, the chosen message's text, and posting (a new message or a
# reply) and removing your own (the server decides who may remove).
const Requests = preload("res://Network/Packets/Requests.gd")
var session: Node
var board := 0
var list := VBoxContainer.new()
var reading: RichTextLabel
var chosen := 0
var subject := LineEdit.new()
var text := TextEdit.new()

func _ready() -> void:
	setup("board","Bulletin board",Vector2(820,520),Vector2(380,110))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation",14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300,0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	list.add_theme_constant_override("separation",4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation",8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	reading = RichTextLabel.new()
	reading.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading.add_theme_color_override("default_color",Look.IVORY)
	reading.add_theme_font_override("normal_font",Look.ui_font(500))
	right.add_child(reading)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	right.add_child(actions)
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(func(): if chosen: session.send(Requests.board_remove(board,chosen)))
	actions.add_child(remove)
	var reply := Button.new()
	reply.text = "Reply"
	reply.pressed.connect(func():
		var post: Dictionary = session.board_posts.get(chosen,{})
		subject.text = "Re: "+str(post.get("title","")))
	actions.add_child(reply)
	right.add_child(Look.label("Write a message",13,Look.GOLD,700))
	subject.placeholder_text = "Subject"
	right.add_child(subject)
	text.custom_minimum_size = Vector2(0,110)
	right.add_child(text)
	var post := Button.new()
	post.text = "Post"
	post.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,6))
	post.add_theme_color_override("font_color",Color("14110b"))
	post.pressed.connect(func():
		if subject.text.strip_edges() == "": return
		session.send(Requests.board_post(board,subject.text,text.text.split("\n"),chosen if subject.text.begins_with("Re: ") else 0))
		subject.text = ""
		text.text = "")
	right.add_child(post)

func configure(game: Node) -> void:
	session = game
	session.board_received.connect(func(value: Dictionary):
		board = int(value.serial)
		title_label.text = str(value.get("title","Bulletin board"))
		chosen = 0
		reading.text = ""
		refresh()
		show()
		move_to_front())
	session.board_post_received.connect(func(_post: Dictionary): if visible: refresh())
	session.ended.connect(hide)

func refresh() -> void:
	clear(list)
	var keys: Array = session.board_posts.keys()
	keys.sort()
	keys.reverse()
	for key in keys:
		var post: Dictionary = session.board_posts[key]
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = int(key) == chosen
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0,48)
		b.text = "%s\n%s · %s" % [post.get("title",""),post.get("author",""),post.get("date","")]
		b.pressed.connect(func():
			chosen = int(key)
			if (post.get("lines",[]) as Array).is_empty(): session.request_board_post(int(key),true)
			_show(post)
			refresh())
		list.add_child(b)
	if keys.is_empty(): list.add_child(Look.label("No messages yet.",13,Look.ASH,500))
	if chosen and session.board_posts.has(chosen): _show(session.board_posts[chosen])

func _show(post: Dictionary) -> void:
	reading.text = "[b]%s[/b]\n%s · %s\n\n%s" % [str(post.get("title","")).replace("[","[lb]"),post.get("author",""),post.get("date",""),"\n".join(post.get("lines",[])).replace("[","[lb]")]
	reading.bbcode_enabled = true
