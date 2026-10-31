extends Node
# Live translation (docs/VOICE_AND_TRANSLATION.md): everything people and the
# server say is shown in the player's chosen language. A local, offline
# service (scripts/translate-server.py: Argos Translate, started here on
# demand) translates; nothing leaves the computer. Presentation only: the
# journal and overhead text ask `deliver` for the shown line, while game logic
# keeps reading the server's own text. Lines are handed back in the order they
# arrived; one the service cannot translate in time is shown as it was said.
signal status_changed(text: String)
const PORT := 47613
const URL := "http://127.0.0.1:%d" % PORT
const TIMEOUT := 2.5
# The languages offered (Argos Translate models via English).
const LANGUAGES := [["","Off (as spoken)"],["en","English"],["it","Italiano"],["es","Español"],["fr","Français"],["de","Deutsch"],["pt","Português"],["nl","Nederlands"],["pl","Polski"],["sv","Svenska"],["ru","Русский"],["uk","Українська"],["tr","Türkçe"],["ar","العربية"],["hi","हिन्दी"],["ja","日本語"],["ko","한국어"],["zh","中文"]]
var language := ""
var serving := false
var pid := 0
var starting := false
var cache := {}
# [{text, done, shown, callback, asked}] in arrival order.
var queue: Array = []
var busy: HTTPRequest
var sending: Dictionary = {}
var installing := false

func _ready() -> void:
	busy = HTTPRequest.new()
	busy.timeout = TIMEOUT*2
	add_child(busy)
	busy.request_completed.connect(_answered)

static func python() -> String:
	return ProjectSettings.globalize_path("res://../.tools/translate/Scripts/python.exe")

static func available() -> bool:
	return FileAccess.file_exists(python())

func set_language(code: String) -> void:
	language = code
	cache.clear()
	if language == "":
		status_changed.emit("Translation off: lines are shown as spoken.")
		return
	if not available():
		status_changed.emit("Translation is not installed: run scripts/setup-translation.ps1.")
		return
	if serving: _install(language)
	else: _start()

func _start() -> void:
	if starting: return
	starting = true
	status_changed.emit("Starting the translator…")
	# A service already running (another client on this computer) is reused.
	var probe := HTTPRequest.new()
	add_child(probe)
	probe.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		probe.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200: _up(body)
		else: _launch())
	probe.request(URL+"/health")

func _launch() -> void:
	pid = OS.create_process(python(),[ProjectSettings.globalize_path("res://../scripts/translate-server.py"),"--port",str(PORT),"--warm",language])
	if pid <= 0:
		starting = false
		status_changed.emit("Could not start the translator.")
		return
	_poll(0)

func _poll(attempt: int) -> void:
	if attempt > 60:
		starting = false
		status_changed.emit("The translator did not start.")
		return
	var probe := HTTPRequest.new()
	add_child(probe)
	probe.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		probe.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200: _up(body)
		else: get_tree().create_timer(0.5).timeout.connect(_poll.bind(attempt+1)))
	probe.request(URL+"/health")

func _up(body: PackedByteArray) -> void:
	starting = false
	serving = true
	var health: Variant = JSON.parse_string(body.get_string_from_utf8())
	var languages: Array = health.get("languages",[]) if health is Dictionary else []
	if language != "" and language not in languages: _install(language)
	else: status_changed.emit("Translating into %s." % name_of(language))
	_pump()

# A newly chosen language downloads its models once (English <-> language).
func _install(code: String) -> void:
	if installing or code == "en":
		status_changed.emit("Translating into %s." % name_of(code))
		return
	installing = true
	status_changed.emit("Downloading the %s translation model (once)…" % name_of(code))
	var request := HTTPRequest.new()
	request.timeout = 900
	add_child(request)
	request.request_completed.connect(func(result: int, code_: int, _h: PackedStringArray, _b: PackedByteArray):
		request.queue_free()
		installing = false
		status_changed.emit("Translating into %s." % name_of(language) if result == HTTPRequest.RESULT_SUCCESS and code_ == 200 else "Could not download the %s model." % name_of(code)))
	request.request(URL+"/install",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"languages":[code]}))

static func name_of(code: String) -> String:
	for entry in LANGUAGES:
		if entry[0] == code: return entry[1]
	return code

# Asks for `text` in the chosen language; `callback(shown)` is called once, in
# arrival order with other lines, immediately when translation is off.
func deliver(text: String, callback: Callable) -> void:
	if language == "" or not serving or worth(text) == false:
		if queue.is_empty():
			callback.call(text)
			return
		queue.append({"text":text,"done":true,"shown":text,"callback":callback,"asked":Time.get_ticks_msec()})
		_flush()
		return
	var key := text
	if cache.has(key):
		queue.append({"text":text,"done":true,"shown":cache[key],"callback":callback,"asked":Time.get_ticks_msec()})
		_flush()
		return
	queue.append({"text":text,"done":false,"shown":text,"callback":callback,"asked":Time.get_ticks_msec()})
	_pump()

# Numbers, coordinates and bracketed commands are left alone.
static func worth(text: String) -> bool:
	var stripped := text.strip_edges()
	if stripped.length() < 2 or stripped.begins_with("["): return false
	for character in stripped:
		if character.to_lower() != character.to_upper(): return true
	return false

func _pump() -> void:
	if not serving or busy.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or not sending.is_empty(): return
	for entry in queue:
		if entry.done: continue
		if cache.has(entry.text):
			entry.shown = cache[entry.text]
			entry.done = true
			continue
		sending = entry
		if busy.request(URL+"/translate",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify({"text":entry.text,"to":language})) != OK:
			sending = {}
			entry.done = true
		break
	_flush()

func _answered(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var entry := sending
	sending = {}
	if not entry.is_empty():
		var reply: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if reply is Dictionary and str(reply.get("text","")) != "":
			entry.shown = str(reply.text)
			cache[entry.text] = entry.shown
			if cache.size() > 3000: cache.clear()
		entry.done = true
	_flush()
	_pump()

func _flush() -> void:
	while not queue.is_empty() and queue[0].done:
		var entry: Dictionary = queue.pop_front()
		entry.callback.call(entry.shown)

func _process(_delta: float) -> void:
	# A line the service has not answered in time is shown as spoken.
	if queue.is_empty(): return
	var now := Time.get_ticks_msec()
	for entry in queue:
		if not entry.done and now-int(entry.asked) > TIMEOUT*1000 and entry != sending: entry.done = true
	if not sending.is_empty() and now-int(sending.asked) > TIMEOUT*1000: sending.done = true
	_flush()

func _exit_tree() -> void:
	if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
