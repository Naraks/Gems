extends SceneTree

const SETTINGS_PATH := "res://audio_service_test.cfg"
const REQUIRED_SFX := [
	&"swap", &"match", &"cascade", &"weakness", &"damage", &"victory", &"defeat", &"ui",
	&"gem_sword", &"gem_magic", &"gem_heart", &"gem_coin", &"gem_stone",
]
const REQUIRED_MUSIC := [&"ruins", &"mines", &"tower", &"boss"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var audio = root.get_node("AudioService")
	failed = _check(AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"SFX") >= 0, "Music and SFX use separate audio buses") or failed
	failed = _check(is_equal_approx(audio.SFX_OUTPUT_SCALE, 0.70), "SFX output is attenuated by 30 percent") or failed
	for sound_name in REQUIRED_SFX:
		var stream := audio.get_sfx_stream(sound_name) as AudioStreamWAV
		failed = _check(stream != null and stream.data.size() > 0 and stream.data.size() <= 5513, "%s SFX is a short browser-friendly PCM stream" % sound_name) or failed
	for track_name in REQUIRED_MUSIC:
		var track := audio.music_streams.get(track_name) as AudioStreamWAV
		failed = _check(
			track != null
			and track.format == AudioStreamWAV.FORMAT_16_BITS
			and track.mix_rate == 22050
			and track.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and track.data.size() <= 352800,
			"%s music is a soft 16-bit looping browser track" % track_name,
		) or failed
	failed = _check(not audio.music_enabled, "Music playback remains disabled by default") or failed

	audio.play_music_for_battle(1, false)
	failed = _check(audio.current_track == &"ruins", "Battles 1–10 use the ruins track") or failed
	audio.play_music_for_battle(11, false)
	failed = _check(audio.current_track == &"mines", "Battles 11–20 use the mines track") or failed
	audio.play_music_for_battle(21, false)
	failed = _check(audio.current_track == &"tower", "Deep battles use the tower track") or failed
	audio.play_music_for_battle(10, true)
	failed = _check(audio.current_track == &"boss", "Bosses use their dedicated track") or failed

	var absolute_path := ProjectSettings.globalize_path(SETTINGS_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_path)
	audio.settings_path = SETTINGS_PATH
	audio.set_music_volume(0.25)
	audio.set_sfx_volume(0.40)
	audio.set_music_enabled(true)
	audio.set_sfx_enabled(false)
	audio.set_music_volume(1.0, false)
	audio.set_sfx_volume(1.0, false)
	audio.set_music_enabled(false, false)
	audio.set_sfx_enabled(true, false)
	audio.load_settings(SETTINGS_PATH)
	failed = _check(is_equal_approx(audio.music_volume, 0.25) and is_equal_approx(audio.sfx_volume, 0.40), "Music and SFX volumes persist independently") or failed
	failed = _check(audio.music_enabled and not audio.sfx_enabled, "Music and SFX toggle states persist independently") or failed
	DirAccess.remove_absolute(absolute_path)

	var run = load("res://ui/run/first_biome_run.tscn").instantiate()
	failed = _check(run.get_node_or_null("%MusicVolumeSlider") != null and run.get_node_or_null("%SfxVolumeSlider") != null, "Run menu exposes separate music and SFX controls") or failed
	run.free()
	var battle = load("res://ui/main/main.tscn").instantiate()
	failed = _check(battle.get_node_or_null("%MusicToggleButton") != null and battle.get_node_or_null("%SfxToggleButton") != null, "Battle HUD exposes music and SFX pictograms") or failed
	battle.free()
	audio.stop_all()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
		return false
	push_error("FAIL: " + description)
	return true
