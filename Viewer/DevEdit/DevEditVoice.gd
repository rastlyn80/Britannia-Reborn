extends Node
# Talk: records one request from the microphone inside the game and turns it
# into text with local Whisper (whisper.cpp, scripts/setup-speech.ps1): free,
# offline, 99 languages, nothing leaves the computer. Without Whisper installed
# it falls back to Windows speech recognition (scripts/listen.ps1).
# Recording stops on the second press, after 3.5 s of silence following
# speech, or after 20 s; held with the hotkey (F8) it records until release. Emits heard(text, info) or failed(reason).
signal heard(text: String, info: Dictionary)
signal failed(reason: String)
signal state_changed(state: String)

const BUS := "DevEditMic"
const SETTINGS := "user://dev-edit-voice.cfg"
const MAX_SECONDS := 20.0
const SILENCE_SECONDS := 3.5
# Whisper language codes offered in the panel ("auto" detects).
const LANGUAGES := [["auto","Auto-detect"],["en","English"],["it","Italiano"],["es","Español"],["fr","Français"],["de","Deutsch"],["pt","Português"],["nl","Nederlands"],["pl","Polski"],["sv","Svenska"],["ru","Русский"],["uk","Українська"],["tr","Türkçe"],["ar","العربية"],["hi","हिन्दी"],["ja","日本語"],["ko","한국어"],["zh","中文"]]

# Voice chat (Network/VoiceChat.gd) uses its own settings and files.
var settings_path := SETTINGS
var file_base := "dev-edit-voice"
var state := "idle" # idle, recording, recognizing
var language := "auto"
var translate := true
var device := "Default"
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var samples := PackedFloat32Array()
var rate := 48000.0
var started := 0
var held := false
var spoke := false
var quiet_since := 0
var level := 0.0
var pid := 0
var job := {}
# Open microphone (voice chat): each utterance ends after a short pause, and
# the silence before speech is not kept (only a short lead-in).
var silence_seconds := SILENCE_SECONDS
var open_mic := false
# Names Whisper cannot know (characters, creatures and NPCs around you): the
# game that owns this recorder supplies them; they bias recognition through
# Whisper's prompt and a sound-alike correction afterwards.
var game: Node
const NAME_RANGE := 18
const PROMPT_NAMES := 40

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		language = str(config.get_value("voice","language",language))
		translate = bool(config.get_value("voice","translate",translate))
		device = str(config.get_value("voice","device",device))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("voice","language",language)
	config.set_value("voice","translate",translate)
	config.set_value("voice","device",device)
	config.save(settings_path)

static func engine() -> Dictionary:
	var path := ProjectSettings.globalize_path("res://../.tools/whisper/speech.json")
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not FileAccess.file_exists(str(data.get("cli",""))) or not FileAccess.file_exists(str(data.get("model",""))): return {}
	return data

func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()

func set_device(name: String) -> void:
	device = name
	if name in AudioServer.get_input_device_list(): AudioServer.input_device = name
	save_settings()

func _setup() -> void:
	if player: return
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,BUS)
		capture = AudioEffectCapture.new()
		capture.buffer_length = 0.5
		AudioServer.add_bus_effect(index,capture)
		# Recorded, never played back: the capture effect runs before the bus volume.
		AudioServer.set_bus_volume_db(index,-80.0)
	else: capture = AudioServer.get_bus_effect(index,0)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = BUS
	add_child(player)

# Hold-to-talk: records while the key is down, recognizes on release.
func hold(down: bool) -> void:
	if down and state == "idle":
		held = true
		start()
		held = state == "recording"
	elif not down and held:
		held = false
		stop()

# Press once to start, again to stop.
func toggle() -> void:
	if state == "recording": stop()
	elif state == "idle": start()

func start() -> void:
	if engine().is_empty():
		# Windows recognition listens to the microphone itself.
		var base := OS.get_user_data_dir().path_join(file_base)
		if FileAccess.file_exists(base+".json"): DirAccess.remove_absolute(base+".json")
		job = {"started":Time.get_ticks_msec(),"seconds":0.0,"base":base,"whisper":false}
		pid = OS.create_process("powershell.exe",["-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File",ProjectSettings.globalize_path("res://../scripts/listen.ps1"),"-Out",base+".json"])
		if pid <= 0:
			pid = 0
			failed.emit("Could not start speech recognition.")
			return
		_set_state("recognizing")
		return
	if not ProjectSettings.get_setting("audio/driver/enable_input",false):
		failed.emit("microphone input is disabled in the project settings")
		return
	_setup()
	if device != "Default" and device in AudioServer.get_input_device_list(): AudioServer.input_device = device
	samples.clear()
	capture.clear_buffer()
	rate = AudioServer.get_mix_rate()
	player.play()
	started = Time.get_ticks_msec()
	spoke = false
	quiet_since = started
	_set_state("recording")

# Ends a recording without recognizing it.
func cancel() -> void:
	if state != "recording": return
	player.stop()
	samples.clear()
	_set_state("idle")

func stop() -> void:
	if state != "recording": return
	_drain()
	player.stop()
	var seconds := samples.size()/rate
	if not spoke or seconds < 0.3:
		_set_state("idle")
		failed.emit("Heard nothing — press Talk and speak.")
		return
	_recognize()

func _process(_delta: float) -> void:
	if state == "recording":
		_drain()
		var now := Time.get_ticks_msec()
		if open_mic and not spoke: started = now
		if (now-started)/1000.0 > MAX_SECONDS*(3 if held else 1) or (not held and spoke and (now-quiet_since)/1000.0 > silence_seconds): stop()
	elif state == "recognizing" and pid > 0 and not OS.is_process_running(pid): _finished()

func _drain() -> void:
	var frames := capture.get_frames_available()
	if frames <= 0: return
	var buffer := capture.get_buffer(frames)
	var peak := 0.0
	for frame in buffer:
		var mono := (frame.x+frame.y)*0.5
		samples.append(mono)
		peak = maxf(peak,absf(mono))
	level = lerpf(level,peak,0.5)
	if open_mic and not spoke and samples.size() > int(rate*0.8): samples = samples.slice(samples.size()-int(rate*0.4))
	# Speech starts above the noise floor; silence after it ends the request.
	if peak > 0.06:
		spoke = true
		quiet_since = Time.get_ticks_msec()

# 16 kHz mono 16-bit PCM, what Whisper expects.
static func wav(data: PackedFloat32Array, from_rate: float) -> PackedByteArray:
	var count := int(data.size()*16000.0/from_rate)
	var pcm := PackedByteArray()
	pcm.resize(count*2)
	for i in count:
		var at := i*from_rate/16000.0
		var j := int(at)
		var a := data[mini(j,data.size()-1)]
		var b := data[mini(j+1,data.size()-1)]
		pcm.encode_s16(i*2,int(clampf(lerpf(a,b,at-j),-1.0,1.0)*32767.0))
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	var header := PackedByteArray()
	header.resize(4)
	header.encode_u32(0,36+pcm.size())
	out.append_array(header)
	out.append_array("WAVEfmt ".to_ascii_buffer())
	var fmt := PackedByteArray()
	fmt.resize(20)
	fmt.encode_u32(0,16)
	fmt.encode_u16(4,1)
	fmt.encode_u16(6,1)
	fmt.encode_u32(8,16000)
	fmt.encode_u32(12,32000)
	fmt.encode_u16(16,2)
	fmt.encode_u16(18,16)
	out.append_array(fmt)
	out.append_array("data".to_ascii_buffer())
	header.encode_u32(0,pcm.size())
	out.append_array(header)
	out.append_array(pcm)
	return out

func _recognize() -> void:
	_set_state("recognizing")
	var base := OS.get_user_data_dir().path_join(file_base)
	var clip := base+".wav"
	var file := FileAccess.open(clip,FileAccess.WRITE)
	file.store_buffer(wav(samples,rate))
	file.close()
	var seconds := samples.size()/rate
	var whisper := engine()
	if FileAccess.file_exists(base+".json"): DirAccess.remove_absolute(base+".json")
	job = {"started":Time.get_ticks_msec(),"seconds":seconds,"base":base,"whisper":true}
	pid = OS.create_process(str(whisper.cli),args(whisper,clip,base,seconds))
	if pid <= 0:
		pid = 0
		_set_state("idle")
		failed.emit("Could not start speech recognition.")

# The encoder only looks at the recorded length (50 frames per second) instead
# of a fixed 30 s window, which makes short commands about twice as fast.
func args(whisper: Dictionary, clip: String, base: String, seconds: float) -> PackedStringArray:
	var list := PackedStringArray(["-m",str(whisper.model),"-f",clip,"-l",language,"-nt","-np","-oj","-of",base,"-t",str(clampi(OS.get_processor_count()-2,2,12)),"-ac",str(clampi(int(ceil(seconds*50.0))+128,384,1500))])
	if translate: list.append("-tr")
	var names := nearby_names(game)
	if not names.is_empty(): list.append_array(["--prompt",", ".join(names.slice(0,PROMPT_NAMES))+"."])
	return list

# Proper names of mobiles within NAME_RANGE tiles, nearest first, and your
# own; "a hawk"-style generic names are left out (Whisper knows those words).
static func nearby_names(session: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if session == null or not "entities" in session: return out
	var me := Vector2i(int(session.player.get("x",0)),int(session.player.get("y",0)))
	var found: Array = []
	for serial in session.entities:
		var mobile: Dictionary = session.entities[serial]
		var name := str(session.entity_names.get(serial,"")).strip_edges()
		var distance := maxi(absi(int(mobile.get("x",0))-me.x),absi(int(mobile.get("y",0))-me.y))
		if name.is_empty() or distance > NAME_RANGE or name.to_lower().begins_with("a ") or name.to_lower().begins_with("an "): continue
		found.append([distance,name])
	found.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
	var own := str(session.entity_names.get(int(session.player.get("serial",0)),session.player.get("name","")))
	if own != "": out.append(own)
	for entry in found:
		if not out.has(entry[1]): out.append(entry[1])
	return out

# A word (or two run together) that sounds like a nearby name becomes that
# name: "rusty lin" -> "Rastlyn". Conservative: at least four letters and
# close in spelling, or the same consonant skeleton.
static func correct_names(text: String, names: PackedStringArray) -> String:
	var words := text.split(" ",false)
	for name in names:
		var target := _letters(name)
		if target.length() < 4: continue
		var span := name.split(" ",false).size()
		for size in [span,span+1]:
			var i := 0
			while i+size <= words.size():
				var piece := _letters(" ".join(words.slice(i,i+size)))
				if piece != target and piece.length() >= 3 and (_similar(piece,target) or _skeleton(piece) == _skeleton(target) and _skeleton(target).length() >= 3):
					# Keep the punctuation that followed: "rusty lin," -> "Rastlyn,".
					var trailing := RegEx.create_from_string("[^A-Za-z0-9]+$").search(words[i+size-1])
					var tail := trailing.get_string() if trailing else ""
					var replaced := words.slice(0,i)
					replaced.append(name+tail)
					replaced.append_array(words.slice(i+size))
					words = PackedStringArray(replaced)
				i += 1
	return " ".join(words)

static func _letters(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if c >= "a" and c <= "z": out += c
	return out

static func _skeleton(word: String) -> String:
	var out := word.left(1)
	for c in word.substr(1):
		if c in "aeiouyhw" or out.ends_with(c): continue
		out += c
	return out

static func _similar(a: String, b: String) -> bool:
	return 1.0-float(_distance(a,b))/float(maxi(a.length(),b.length())) >= 0.75

static func _distance(a: String, b: String) -> int:
	var row: Array = range(b.length()+1)
	for i in a.length():
		var next: Array = [i+1]
		for j in b.length():
			next.append(mini(mini(row[j+1]+1,next[j]+1),row[j]+(0 if a[i] == b[j] else 1)))
		row = next
	return row[b.length()]

func _finished() -> void:
	pid = 0
	_set_state("idle")
	var path := str(job.base)+".json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var ms := Time.get_ticks_msec()-int(job.started)
	if not data is Dictionary:
		failed.emit("Speech recognition returned nothing.")
		return
	if job.whisper:
		var text := ""
		for segment in data.get("transcription",[]): text += str(segment.get("text",""))
		text = text.strip_edges()
		# Whisper writes bracketed notes such as [BLANK_AUDIO] for non-speech.
		if text.is_empty() or (text.begins_with("[") and text.ends_with("]")) or (text.begins_with("(") and text.ends_with(")")):
			failed.emit("Heard nothing — press Talk and speak.")
			return
		text = correct_names(text,nearby_names(game))
		heard.emit(text,{"engine":"whisper","language":str(data.get("result",{}).get("language","")),"translated":translate,"ms":ms,"seconds":job.seconds})
	else:
		var text := str(data.get("text","")).strip_edges()
		if text.is_empty():
			failed.emit({"NoSpeech":"Heard nothing — press Talk and speak.","LowConfidence":"Did not catch that clearly — try again."}.get(str(data.get("status","")),"Speech recognition: "+str(data.get("status","")).left(120))+" (Whisper is not installed: run scripts/setup-speech.ps1 for better, offline, multilingual speech.)")
			return
		heard.emit(text,{"engine":"windows","ms":ms})

func _set_state(value: String) -> void:
	state = value
	state_changed.emit(value)
