extends Node3D
# Sound effects and music the server asks for (Environment module: 0x54
# sound, 0x6D music), played from the owner's own install through the local
# index written by scripts/prepare-audio.py (sounds are 16-bit 22 kHz PCM
# inside soundLegacyMUL.uop; music is Music/Digital MP3). Sounds are placed
# at their tile in 3D; music crossfades. Without the index the game is silent.
const INDEX := "res://local-audio/index.json"
const VOICES := 16
const CACHE := 160
var scene: Node3D
var index := {}
var uop: FileAccess
var streams := {}
var order: Array = []
var voices: Array[AudioStreamPlayer3D] = []
var music_players: Array[AudioStreamPlayer] = []
var music_now := -1
var sound_volume := 0.8
var music_volume := 0.45

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	if FileAccess.file_exists(INDEX):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
		if parsed is Dictionary: index = parsed
	if index.has("uop") and FileAccess.file_exists(str(index.uop)): uop = FileAccess.open(str(index.uop),FileAccess.READ)
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 6.0
		voice.max_distance = 30.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(voice)
		voices.append(voice)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80
		add_child(player)
		music_players.append(player)
	var environment: RefCounted = scene.game.module("environment")
	environment.sound.connect(play_sound)
	environment.music.connect(play_music)
	scene.game.ended.connect(func(): play_music(-1))

func available() -> bool: return uop != null

func stream(sound: int) -> AudioStreamWAV:
	if uop == null: return null
	var key := str(sound)
	if not index.sounds.has(key) and index.get("aliases",{}).has(key): key = str(int(index.aliases[key]))
	if streams.has(key): return streams[key]
	if not index.sounds.has(key): return null
	var where: Array = index.sounds[key]
	uop.seek(int(where[0]))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(index.get("rate",22050))
	wav.stereo = false
	wav.data = uop.get_buffer(int(where[1]))
	streams[key] = wav
	order.append(key)
	if order.size() > CACHE: streams.erase(order.pop_front())
	return wav

func play_sound(request: Dictionary) -> void:
	var wav := stream(int(request.get("id",0)))
	if wav == null or scene == null: return
	var voice: AudioStreamPlayer3D = null
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null: voice = voices[0]
	voice.stream = wav
	voice.position = scene.entity_point(int(request.x),int(request.y),int(request.z)) if int(request.get("x",0)) > 0 else (scene.camera.global_position if scene.camera else Vector3.ZERO)
	voice.volume_db = linear_to_db(maxf(0.001,sound_volume))
	voice.play()

func play_music(track: int) -> void:
	if track == music_now: return
	music_now = track
	var outgoing := music_players[0]
	var incoming := music_players[1]
	music_players.reverse()
	var fade := create_tween().set_parallel(true)
	fade.tween_property(outgoing,"volume_db",-80.0,2.0)
	fade.chain().tween_callback(outgoing.stop)
	var entry: Dictionary = index.get("music",{}).get(str(track),{})
	if track < 0 or entry.is_empty() or not FileAccess.file_exists(str(entry.path)): return
	var mp3 := AudioStreamMP3.new()
	mp3.data = FileAccess.get_file_as_bytes(str(entry.path))
	mp3.loop = bool(entry.get("loop",false))
	incoming.stream = mp3
	incoming.volume_db = -80
	incoming.play()
	create_tween().tween_property(incoming,"volume_db",linear_to_db(maxf(0.001,music_volume)),2.5)
