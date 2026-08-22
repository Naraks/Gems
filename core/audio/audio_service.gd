class_name GameAudioService
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SAMPLE_RATE := 11025
const MUSIC_SAMPLE_RATE := 22050
const MUSIC_DURATION_SECONDS := 8.0
const DEFAULT_MUSIC_VOLUME := 0.65
const DEFAULT_SFX_VOLUME := 0.80
const SFX_OUTPUT_SCALE := 0.70
const SFX_RECIPES := {
	&"swap": [360.0, 520.0, 0.08],
	&"match": [620.0, 820.0, 0.12],
	&"cascade": [760.0, 1120.0, 0.15],
	&"weakness": [880.0, 1320.0, 0.16],
	&"damage": [180.0, 92.0, 0.14],
	&"gem_sword": [1180.0, 260.0, 0.18],
	&"gem_magic": [540.0, 1280.0, 0.24],
	&"gem_heart": [420.0, 620.0, 0.28],
	&"gem_coin": [1480.0, 1120.0, 0.32],
	&"gem_stone": [150.0, 72.0, 0.20],
	&"victory": [520.0, 1040.0, 0.42],
	&"defeat": [310.0, 92.0, 0.48],
	&"ui": [540.0, 680.0, 0.06],
}
const MUSIC_SCALES := {
	&"ruins": [220.0, 261.63, 329.63, 392.0],
	&"mines": [146.83, 174.61, 220.0, 261.63],
	&"tower": [196.0, 233.08, 293.66, 349.23],
	&"boss": [110.0, 130.81, 155.56, 185.0],
}

var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var music_enabled := false
var sfx_enabled := true
var settings_path := SETTINGS_PATH
var sfx_streams: Dictionary = {}
var music_streams: Dictionary = {}
var current_track := &""
var last_sfx := &""

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0


func _ready() -> void:
	_ensure_buses()
	_build_streams()
	_build_players()
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	_connect_ui_buttons(get_tree().root)


func _exit_tree() -> void:
	stop_all()
	_music_player.stream = null
	for player in _sfx_players:
		player.stream = null
	sfx_streams.clear()
	music_streams.clear()


func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _build_streams() -> void:
	for sound_name in SFX_RECIPES:
		var recipe: Array = SFX_RECIPES[sound_name]
		sfx_streams[sound_name] = _make_sfx(sound_name, float(recipe[0]), float(recipe[1]), float(recipe[2]))
	for track_name in MUSIC_SCALES:
		music_streams[track_name] = _make_music(MUSIC_SCALES[track_name], track_name == &"boss")


func _build_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for index in 4:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % (index + 1)
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)


func play_sfx(sound_name: StringName) -> void:
	if sound_name not in sfx_streams or _sfx_players.is_empty():
		return
	last_sfx = sound_name
	if not sfx_enabled or DisplayServer.get_name() == "headless":
		return
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = sfx_streams[sound_name]
	player.play()


func get_sfx_stream(sound_name: StringName) -> AudioStream:
	return sfx_streams.get(sound_name) as AudioStream


func play_music(track_name: StringName) -> void:
	if track_name == current_track and (_music_player.playing or DisplayServer.get_name() == "headless"):
		return
	if track_name not in music_streams:
		return
	current_track = track_name
	if not music_enabled or DisplayServer.get_name() == "headless":
		return
	_music_player.stream = music_streams[track_name]
	_music_player.play()


func play_music_for_battle(battle_number: int, is_boss: bool) -> void:
	if is_boss:
		play_music(&"boss")
	elif battle_number <= 10:
		play_music(&"ruins")
	elif battle_number <= 20:
		play_music(&"mines")
	else:
		play_music(&"tower")


func stop_all() -> void:
	_music_player.stop()
	for player in _sfx_players:
		player.stop()


func set_music_enabled(enabled: bool, save := true) -> void:
	music_enabled = enabled
	if music_enabled and not current_track.is_empty():
		play_music(current_track)
	else:
		_music_player.stop()
	if save:
		save_settings()


func set_sfx_enabled(enabled: bool, save := true) -> void:
	sfx_enabled = enabled
	if not sfx_enabled:
		for player in _sfx_players:
			player.stop()
	if save:
		save_settings()


func set_music_volume(value: float, save := true) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(MUSIC_BUS, music_volume)
	if save:
		save_settings()


func set_sfx_volume(value: float, save := true) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(SFX_BUS, sfx_volume * SFX_OUTPUT_SCALE)
	if save:
		save_settings()


func load_settings(path := "") -> void:
	if not path.is_empty():
		settings_path = path
	var config := ConfigFile.new()
	config.load(settings_path)
	set_music_enabled(bool(config.get_value("audio", "music_enabled", false)), false)
	set_sfx_enabled(bool(config.get_value("audio", "sfx_enabled", true)), false)
	set_music_volume(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), false)
	set_sfx_volume(float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), false)


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	return config.save(settings_path) == OK


func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.0001)))


func _on_node_added(node: Node) -> void:
	if node is Button:
		_connect_button(node)


func _connect_ui_buttons(node: Node) -> void:
	if node is Button:
		_connect_button(node)
	for child in node.get_children():
		_connect_ui_buttons(child)


func _connect_button(button: Button) -> void:
	var callback := play_sfx.bind(&"ui")
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _make_sfx(sound_name: StringName, start_frequency: float, end_frequency: float, duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, roundi(SAMPLE_RATE * duration))
	var samples := PackedByteArray()
	samples.resize(sample_count)
	var phase := 0.0
	for index in sample_count:
		var progress := float(index) / float(sample_count)
		var time := float(index) / SAMPLE_RATE
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / SAMPLE_RATE
		var envelope := pow(1.0 - progress, 1.6)
		var wave := sin(phase) * 0.72 + signf(sin(phase * 0.5)) * 0.12
		match sound_name:
			&"gem_sword":
				var strike := exp(-24.0 * time)
				var steel := sin(TAU * 1320.0 * time) * 0.46 + sin(TAU * 2137.0 * time) * 0.30 + sin(TAU * 3271.0 * time) * 0.18
				var slash := sin(TAU * (760.0 - progress * 520.0) * time) * 0.24
				wave = steel * strike + slash * pow(1.0 - progress, 2.0)
				envelope = 1.0
			&"gem_magic":
				var rise := 420.0 + progress * 860.0
				wave = sin(TAU * rise * time) * 0.50 + sin(TAU * rise * 1.5 * time) * 0.28 + sin(TAU * rise * 2.0 * time) * 0.14
				envelope = sin(progress * PI) * 0.92
			&"gem_heart":
				var first_pulse := exp(-32.0 * time)
				var second_time := maxf(0.0, time - 0.14)
				var second_pulse := exp(-34.0 * second_time) if time >= 0.14 else 0.0
				wave = sin(TAU * 260.0 * time) * first_pulse + sin(TAU * 330.0 * second_time) * second_pulse * 0.82
				envelope = 0.72
			&"gem_coin":
				var first_ring := exp(-10.0 * time)
				var second_time := maxf(0.0, time - 0.11)
				var second_ring := exp(-11.0 * second_time) if time >= 0.11 else 0.0
				wave = (
					(sin(TAU * 1760.0 * time) + sin(TAU * 2637.0 * time) * 0.46) * first_ring
					+ (sin(TAU * 1397.0 * second_time) + sin(TAU * 2093.0 * second_time) * 0.42) * second_ring * 0.88
				) * 0.58
				envelope = 1.0
			&"gem_stone":
				var debris := sin(TAU * 173.0 * time) * sin(TAU * 911.0 * time) + sin(TAU * 1277.0 * time) * 0.36
				wave = sin(TAU * 82.0 * time) * 0.72 + debris * 0.38
				envelope = exp(-22.0 * time)
		samples[index] = clampi(roundi(128.0 + wave * envelope * 82.0), 0, 255)
	return _wav(samples, false)


func _make_music(scale: Array, boss: bool) -> AudioStreamWAV:
	var sample_count := int(MUSIC_SAMPLE_RATE * MUSIC_DURATION_SECONDS)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var note_length := 0.50 if boss else 0.75
	var melody_pattern := [0, 2, 1, 3, 2, 1, 0, 1] if boss else [0, 2, 1, 3, 2, 1, 0, 2]
	for index in sample_count:
		var time := float(index) / MUSIC_SAMPLE_RATE
		var note_index := int(time / note_length)
		var note_progress := fmod(time, note_length) / note_length
		var frequency: float = float(scale[melody_pattern[note_index % melody_pattern.size()]])
		var root: float = float(scale[0]) * 0.5
		var third: float = float(scale[1]) * 0.5
		var fifth: float = float(scale[2]) * 0.5
		var breathing := 0.82 + sin(TAU * time / MUSIC_DURATION_SECONDS) * 0.12
		var pad := (
			sin(TAU * root * time) * 0.34
			+ sin(TAU * third * time + 0.7) * 0.24
			+ sin(TAU * fifth * time + 1.4) * 0.20
		) * breathing
		var pluck_envelope := exp(-4.2 * note_progress)
		var harp := (
			sin(TAU * frequency * time)
			+ sin(TAU * frequency * 2.0 * time) * 0.22
			+ sin(TAU * frequency * 3.0 * time) * 0.08
		) * pluck_envelope * (0.24 if boss else 0.18)
		var shimmer_frequency: float = float(scale[(note_index + 1) % scale.size()]) * 2.0
		var shimmer := sin(TAU * shimmer_frequency * time) * exp(-7.0 * note_progress) * 0.045
		var low_drone := sin(TAU * root * 0.5 * time) * (0.13 if boss else 0.08)
		var loop_fade := minf(1.0, minf(time / 0.12, (MUSIC_DURATION_SECONDS - time) / 0.12))
		var mixed := (pad * 0.34 + harp + shimmer + low_drone) * loop_fade
		var sample := clampi(roundi(mixed * 32767.0), -32768, 32767)
		samples[index * 2] = sample & 0xff
		samples[index * 2 + 1] = (sample >> 8) & 0xff
	return _wav_16(samples, sample_count)


func _wav(samples: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = samples
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _wav_16(samples: PackedByteArray, frame_count: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_SAMPLE_RATE
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frame_count
	return stream
