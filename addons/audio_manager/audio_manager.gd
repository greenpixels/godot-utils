extends Node

@export_storage var audio_data: Dictionary[String, AudioStream] = {}
@export_storage var current_playing_audio_amount: Dictionary[String, int] = {}
@export_storage var current_bgm: AudioStreamPlayer
@export_storage var preloaded_keys: Array[String] = []

@export var master_volume: float = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master"))
@export var sound_volume: float = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Sound"))
@export var music_volume: float = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music"))
@export var mute_in_background := false

const MAX_PARALLEL_SOUNDS: int = 5
var incremental_fade_id := 0

func _ready() -> void:
	for audio_key in preloaded_keys:
		if not audio_data.has(audio_key):
			push_warning("Trying to preload an audio file that does not exist: " + audio_key)
			continue
		ResourceLoader.load(audio_data[audio_key].resource_path, "", ResourceLoader.CACHE_MODE_REUSE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mute_in_background:
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), 0)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), master_volume)

func play_hint_sound(audio_key: String, pitch: float = 1., volume: float = 1.) -> void:
	play_sound_effect(audio_key, pitch, volume, MAX_PARALLEL_SOUNDS, true)

func play_sound_effect(audio_key: String, pitch: float = 1., volume: float = 1., max_poly := MAX_PARALLEL_SOUNDS, is_hint := false) -> void:
	if not audio_data.has(audio_key):
		push_warning("Trying to play an audio file that does not exist: " + audio_key)
		return
	var audio_stream := audio_data[audio_key]

	if current_playing_audio_amount.has(audio_key):
		if current_playing_audio_amount[audio_key] > max_poly:
			return
		current_playing_audio_amount[audio_key] += 1
	else:
		current_playing_audio_amount[audio_key] = 1

	var stream_player := AudioStreamPlayer.new()
	if is_hint:
		stream_player.set_bus("Hints")
	else:
		stream_player.set_bus("Other")
	add_child(stream_player)
	stream_player.stream = audio_stream
	stream_player.pitch_scale = pitch
	stream_player.volume_linear = volume
	stream_player.play()
	
	stream_player.finished.connect(func() -> void: _on_audio_finished(stream_player, audio_key), CONNECT_ONE_SHOT)

func _on_audio_finished(stream_player: AudioStreamPlayer, audio_key: String) -> void:
	if current_playing_audio_amount.has(audio_key):
		current_playing_audio_amount[audio_key] -= 1
		if current_playing_audio_amount[audio_key] <= 0:
			current_playing_audio_amount.erase(audio_key)
	stream_player.queue_free()

func play_bgm(audio_key: String, fade_duration: float = 3.) -> void:
	if not audio_data.has(audio_key):
		push_warning("Trying to play an audio file that does not exist: " + audio_key)
		return
	stop_bgm(1)
	var stream_player := AudioStreamPlayer.new()
	var audio_stream := audio_data[audio_key]
	stream_player.set_bus("Music")
	add_child(stream_player)
	if not stream_player.is_node_ready():
		await stream_player.ready
	stream_player.stream = audio_stream
	stream_player.play()
	stream_player.volume_linear = 0.
	TweenHelper.tween("fade_in_" + str(incremental_fade_id), self).tween_property(stream_player, "volume_linear", 1., fade_duration)
	incremental_fade_id += 1
	current_bgm = stream_player
	
func stop_bgm(fade_duration: float = 1.) -> void:
	if not current_bgm: return
	var previous: AudioStreamPlayer = current_bgm
	var fade_out_tween: Tween = TweenHelper.tween("fade_out_" + str(incremental_fade_id), self)
	incremental_fade_id += 1
	fade_out_tween.tween_property(previous, "volume_linear", 0, fade_duration)
	fade_out_tween.tween_callback(previous.queue_free)
