extends "res://Network/ModernWindow.gd"
# Books (0xD4/0x93 cover, 0x66 pages): an open book with two facing pages,
# page turns, and the title and author. Writable books can be edited: title,
# author and each page's lines are sent back (0xD4, 0x66) when you save.
const Requests = preload("res://Network/Packets/Requests.gd")
var session: Node
var book := {}
var spread := 1
var title_edit := LineEdit.new()
var author_edit := LineEdit.new()
var pages: Array = []
var page_labels: Array = []
var save: Button
var turn_note: Label

func _ready() -> void:
	setup("book","Book",Vector2(760,520),Vector2(400,120))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation",8)
	body.add_child(head)
	title_edit.placeholder_text = "Title"
	title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_edit.add_theme_font_override("font",Look.title_font())
	title_edit.add_theme_font_size_override("font_size",18)
	head.add_child(title_edit)
	author_edit.placeholder_text = "Author"
	author_edit.custom_minimum_size = Vector2(200,0)
	head.add_child(author_edit)
	var spread_row := HBoxContainer.new()
	spread_row.add_theme_constant_override("separation",14)
	spread_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spread_row)
	for side in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spread_row.add_child(column)
		var page := TextEdit.new()
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		page.add_theme_stylebox_override("normal",Look.box(Color("e9dfc7"),Color(0.55,0.45,0.3,0.6),6,1,14))
		page.add_theme_stylebox_override("read_only",Look.box(Color("e9dfc7"),Color(0.55,0.45,0.3,0.6),6,1,14))
		page.add_theme_stylebox_override("focus",Look.box(Color(0,0,0,0),Look.BRASS,6,1,14))
		for key in ["font_color","font_readonly_color"]: page.add_theme_color_override(key,Color("2b2117"))
		page.add_theme_font_override("font",Look.ui_font(500))
		page.add_theme_font_size_override("font_size",15)
		column.add_child(page)
		pages.append(page)
		var number := Look.label("",12,Look.ASH,600)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(number)
		page_labels.append(number)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	body.add_child(row)
	var back := Button.new()
	back.text = "‹ Previous"
	back.pressed.connect(func(): _turn(-2))
	row.add_child(back)
	turn_note = Look.label("",12,Look.ASH,500)
	turn_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(turn_note)
	save = Button.new()
	save.text = "Save writing"
	save.add_theme_stylebox_override("normal",Look.box(Look.BRASS,Look.BRASS,8,1,6))
	save.add_theme_color_override("font_color",Color("14110b"))
	save.pressed.connect(_save)
	row.add_child(save)
	var next := Button.new()
	next.text = "Next ›"
	next.pressed.connect(func(): _turn(2))
	row.add_child(next)

func configure(game: Node) -> void:
	session = game
	session.book_received.connect(func(value: Dictionary):
		var fresh := book.is_empty() or int(book.serial) != int(value.serial)
		book = value
		if fresh: spread = 1
		refresh()
		show()
		move_to_front())
	session.ended.connect(hide)

func _turn(step: int) -> void:
	_keep()
	spread = clampi(spread+step,1,maxi(1,int(book.get("page_count",1))))
	if spread%2 == 0: spread -= 1
	refresh()

# Edits on the visible pages stay in the book until saved.
func _keep() -> void:
	if not book.get("writable",false): return
	for side in 2:
		var number := spread+side
		if number <= int(book.get("page_count",0)): book.pages[number] = pages[side].text

func refresh() -> void:
	if book.is_empty(): return
	var writable: bool = book.get("writable",false)
	title_label.text = "Book"
	title_edit.text = str(book.get("title",""))
	author_edit.text = str(book.get("author",""))
	title_edit.editable = writable
	author_edit.editable = writable
	save.visible = writable
	var count := int(book.get("page_count",book.pages.size()))
	for side in 2:
		var number := spread+side
		pages[side].visible = number <= count
		pages[side].text = str(book.pages.get(number,""))
		pages[side].editable = writable
		page_labels[side].text = "Page %d" % number if number <= count else ""
	turn_note.text = "Pages %d–%d of %d" % [spread,mini(spread+1,count),count] if count > 0 else ""

func _save() -> void:
	_keep()
	session.send(Requests.book_header(int(book.serial),title_edit.text,author_edit.text))
	var lines := {}
	for number in book.pages:
		lines[int(number)] = str(book.pages[number]).split("\n").slice(0,8)
	session.send(Requests.book_pages(int(book.serial),lines))
	turn_note.text = "Saved"
