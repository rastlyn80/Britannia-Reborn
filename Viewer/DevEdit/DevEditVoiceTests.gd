extends SceneTree
# Talk / local Whisper speech: WAV encoding, recognizer arguments, and (when
# Whisper is installed and --clip=<wav> is given) the whole path: a spoken
# command resampled by the game's encoder and recognized by whisper.cpp.
# --mic records 1.5 s from the real microphone (needs a window, not --headless).
const Voice = preload("res://DevEdit/DevEditVoice.gd")
var passed := 0
var failed := 0

func check(condition: bool, name: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		print("FAIL ",name)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var clip := ""
	var mic := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="): clip = arg.substr(7)
		if arg == "--mic": mic = true
	# Encoder: 1 s of a 48 kHz sine becomes 16000 16-bit mono samples.
	var tone := PackedFloat32Array()
	for i in 48000: tone.append(sin(i*TAU*440.0/48000.0)*0.5)
	var bytes := Voice.wav(tone,48000.0)
	check(bytes.size() == 44+32000 and bytes.slice(0,4).get_string_from_ascii() == "RIFF" and bytes.decode_u32(24) == 16000 and bytes.decode_u16(22) == 1 and bytes.decode_u16(34) == 16,"WAV header: 16 kHz mono 16-bit, one second")
	var peak := 0
	for i in 16000: peak = maxi(peak,absi(bytes.decode_s16(44+i*2)))
	check(peak > 15000 and peak <= 16384,"resampled amplitude kept (peak %d)" % peak)
	# Arguments: language, translation, encoder window sized to the clip.
	var voice: Node = Voice.new()
	voice.language = "it"
	voice.translate = true
	var a: PackedStringArray = voice.args({"model":"m.bin"},"c.wav","out",4.0)
	check(a[a.find("-l")+1] == "it" and a.has("-tr") and a[a.find("-ac")+1] == "384","short clip: chosen language, translated, small encoder window")
	voice.translate = false
	a = voice.args({"model":"m.bin"},"c.wav","out",40.0)
	check(not a.has("-tr") and a[a.find("-ac")+1] == "1500","long clip: full window; no translation when off")
	voice.free()
	# The panel builds the language, translation and microphone controls.
	var mode: CanvasLayer = load("res://DevEdit/DevEditMode.gd").new()
	var column := VBoxContainer.new()
	mode._voice_controls(column)
	var row: Node = column.get_child(0)
	check(row.get_child_count() == 3 and row.get_child(0) is OptionButton and row.get_child(0).item_count == Voice.LANGUAGES.size() and row.get_child(1) is CheckBox,"panel shows language (%d), English-commands and microphone controls" % Voice.LANGUAGES.size())
	mode.free()
	column.free()
	var engine := Voice.engine()
	if engine.is_empty(): print("DEV EDIT VOICE: Whisper not installed (scripts/setup-speech.ps1); recognition skipped")
	elif clip != "":
		var source := FileAccess.get_file_as_bytes(clip)
		check(source.size() > 44,"test clip readable: "+clip)
		if source.size() <= 44:
			print("DEV EDIT VOICE TESTS: %d passed, %d failed" % [passed,failed])
			quit(1)
			return
		var rate := source.decode_u32(24)
		var samples := PackedFloat32Array()
		for i in range(44,source.size()-1,2): samples.append(source.decode_s16(i)/32768.0)
		var base := OS.get_user_data_dir().path_join("voice-test")
		for stale in [base+".wav",base+".json"]:
			if FileAccess.file_exists(stale): DirAccess.remove_absolute(stale)
		var file := FileAccess.open(base+".wav",FileAccess.WRITE)
		file.store_buffer(Voice.wav(samples,rate))
		file.close()
		var runner: Node = Voice.new()
		runner.language = "auto"
		runner.translate = false
		var start := Time.get_ticks_msec()
		OS.execute(str(engine.cli),runner.args(engine,base+".wav",base,samples.size()/float(rate)))
		var ms := Time.get_ticks_msec()-start
		runner.free()
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base+".json"))
		var text := ""
		if data is Dictionary:
			for segment in data.transcription: text += str(segment.text)
		print("DEV EDIT VOICE: %d ms (%.1f s clip, %s): %s" % [ms,samples.size()/float(rate),str(data.result.language) if data is Dictionary else "?",text.strip_edges()])
		check("roof" in text.to_lower() and "wall" in text.to_lower(),"spoken command recognized through the game's encoder")
	if mic:
		var recorder: Node = Voice.new()
		root.add_child(recorder)
		recorder._setup()
		recorder.player.play()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec()-start < 1500:
			recorder._drain()
			await process_frame
		recorder.player.stop()
		print("DEV EDIT VOICE: microphone '%s' delivered %d samples in 1.5 s at %d Hz" % [AudioServer.input_device,recorder.samples.size(),int(AudioServer.get_mix_rate())])
		check(recorder.samples.size() > 20000,"real microphone delivers audio")
	print("DEV EDIT VOICE TESTS: %d passed, %d failed" % [passed,failed])
	quit(failed)
