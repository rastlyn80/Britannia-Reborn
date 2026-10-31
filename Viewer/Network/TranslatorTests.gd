extends SceneTree
# Live translation presentation (docs/VOICE_AND_TRANSLATION.md): lines keep
# their order, untranslatable or late lines are shown as spoken, and with
# translation off nothing waits. No translation service is needed.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var translator = preload("res://Network/Translator.gd").new()
	root.add_child(translator)
	var shown: Array = []
	var show := func(text: String): shown.append(text)
	translator.deliver("Hello",show)
	check(shown == ["Hello"],"translation off: a line is shown at once, as spoken")
	shown.clear()
	check(not translator.worth("12 34") and not translator.worth("[PreviewGo 1 2 3") and translator.worth("You see: a skeleton"),"numbers and commands are not sent for translation")
	# A served language: the first line waits for its answer, a cached second
	# line waits behind it, so the journal keeps the order things were said.
	translator.language = "it"
	translator.serving = true
	translator.cache["You have been poisoned!"] = "Sei stato avvelenato!"
	translator.deliver("Hail, traveller!",show)
	translator.deliver("You have been poisoned!",show)
	check(shown.is_empty(),"a line waiting for translation holds back the lines after it")
	translator._answered(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"text":"Salve, viaggiatore!","from":"en","to":"it"}).to_utf8_buffer())
	check(shown == ["Salve, viaggiatore!","Sei stato avvelenato!"],"answers are shown in arrival order (%s)" % [shown])
	check(translator.cache.get("Hail, traveller!","") == "Salve, viaggiatore!","a translated line is remembered")
	shown.clear()
	translator.deliver("A line the service never answers",show)
	translator.queue[0].asked = Time.get_ticks_msec()-10000
	translator.sending = translator.queue[0]
	translator._process(0.1)
	check(shown == ["A line the service never answers"],"a line not translated in time is shown as spoken")
	shown.clear()
	translator.deliver("1234",show)
	check(shown == ["1234"],"a line with nothing to translate is shown at once")
	translator.set_language("")
	translator.deliver("Back to English",show)
	check(shown.back() == "Back to English","switching translation off shows lines as spoken")
	check(preload("res://Network/Translator.gd").name_of("it") == "Italiano" and preload("res://Network/Translator.gd").name_of("") == "Off (as spoken)","languages are offered by their own names")
	# Long speech from the open microphone goes out as several lines.
	var parts: PackedStringArray = preload("res://Network/VoiceChat.gd").lines("word ".repeat(60).strip_edges())
	check(parts.size() == 3 and parts[0].length() <= 120,"long speech is split into talk-sized lines")
	print("TRANSLATOR TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
