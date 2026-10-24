extends Node
class_name SfxManager

static var instance: SfxManager = null

var audio_players: Array[AudioStreamPlayer] = []
var max_players: int = 8
var current_player_idx: int = 0

var sfx_chalk: AudioStreamWAV
var sfx_nail: AudioStreamWAV
var sfx_activate: AudioStreamWAV
var sfx_snap: AudioStreamWAV
var sfx_ghost_spot: AudioStreamWAV
var sfx_ghost_contain: AudioStreamWAV
var sfx_seal_win: AudioStreamWAV
var sfx_warning: AudioStreamWAV
var sfx_player_hit: AudioStreamWAV

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(max_players):
		var p = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		audio_players.append(p)
	
	_generate_sounds()

static func play_chalk() -> void:
	if instance:
		instance._play_chalk_internal()

static func play_nail() -> void:
	if instance:
		instance._play_nail_internal()

static func play_activate() -> void:
	if instance:
		instance._play_activate_internal()

static func play_snap() -> void:
	if instance:
		instance._play_snap_internal()

static func play_ghost_spot() -> void:
	if instance:
		instance._play_ghost_spot_internal()

static func play_ghost_contain() -> void:
	if instance:
		instance._play_ghost_contain_internal()

static func play_seal_win() -> void:
	if instance:
		instance._play_seal_win_internal()

static func play_warning() -> void:
	if instance:
		instance._play_warning_internal()

static func play_player_hit() -> void:
	if instance:
		instance._play_player_hit_internal()

func _play_chalk_internal() -> void:
	play_sfx(sfx_chalk, -4.0, randf_range(0.85, 1.25))

func _play_nail_internal() -> void:
	play_sfx(sfx_nail, 1.0, randf_range(0.95, 1.05))

func _play_activate_internal() -> void:
	play_sfx(sfx_activate, 0.0, 1.0)

func _play_snap_internal() -> void:
	play_sfx(sfx_snap, 3.0, 1.0)

func _play_ghost_spot_internal() -> void:
	play_sfx(sfx_ghost_spot, 2.0, randf_range(0.9, 1.1))

func _play_ghost_contain_internal() -> void:
	play_sfx(sfx_ghost_contain, 1.0, 1.0)

func _play_seal_win_internal() -> void:
	play_sfx(sfx_seal_win, 3.0, 1.0)

func _play_warning_internal() -> void:
	play_sfx(sfx_warning, -2.0, randf_range(0.98, 1.02))

func _play_player_hit_internal() -> void:
	play_sfx(sfx_player_hit, 2.0, 0.8)

func play_sfx(stream: AudioStreamWAV, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or audio_players.is_empty():
		return
	var player = audio_players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_players
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func _generate_sounds() -> void:
	sfx_chalk = _synth_noise(0.08, 0.35, true)
	sfx_nail = _synth_strike(0.15, 380.0, 0.6)
	sfx_activate = _synth_chord([220.0, 330.0, 440.0, 554.37], 0.8, 0.45)
	sfx_snap = _synth_snap(0.4, 0.8)
	sfx_ghost_spot = _synth_eerie(0.6, 260.0, 180.0, 0.5)
	sfx_ghost_contain = _synth_eerie(1.2, 140.0, 220.0, 0.6)
	sfx_seal_win = _synth_chord([261.6, 329.6, 392.0, 523.25, 659.25], 1.5, 0.6)
	sfx_warning = _synth_strike(0.08, 700.0, 0.35)
	sfx_player_hit = _synth_snap(0.3, 0.6)

# --- Procedural Synthesizers ---

func _create_wav(data: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _synth_noise(duration: float, gain: float, decay: bool) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(total_samples)
	for i in range(total_samples):
		var t = float(i) / total_samples
		var env = 1.0 - t if decay else 1.0
		var noise = (randf() * 2.0 - 1.0) * gain * env
		var val = clampi(int(128 + noise * 127), 0, 255)
		data[i] = val
	return _create_wav(data, sample_rate)

func _synth_strike(duration: float, freq: float, gain: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(total_samples)
	for i in range(total_samples):
		var t = float(i) / sample_rate
		var env = exp(-t * 28.0) * gain
		var sample = sin(2.0 * PI * freq * t) * env
		if i < 40:
			sample += (randf() * 2.0 - 1.0) * gain * 0.8
		var val = clampi(int(128 + sample * 127), 0, 255)
		data[i] = val
	return _create_wav(data, sample_rate)

func _synth_chord(freqs: Array, duration: float, gain: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(total_samples)
	var n_freqs = freqs.size()
	for i in range(total_samples):
		var t = float(i) / sample_rate
		var total_t = float(i) / total_samples
		var env = sin(total_t * PI) if total_t < 0.2 else (1.0 - (total_t - 0.2) / 0.8)
		env *= gain
		var sum: float = 0.0
		for f in freqs:
			sum += sin(2.0 * PI * f * t)
		sum = (sum / n_freqs) * env
		var val = clampi(int(128 + sum * 127), 0, 255)
		data[i] = val
	return _create_wav(data, sample_rate)

func _synth_eerie(duration: float, start_f: float, end_f: float, gain: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(total_samples)
	var phase: float = 0.0
	for i in range(total_samples):
		var p = float(i) / total_samples
		var f = lerpf(start_f, end_f, p)
		var lfo = sin(p * 20.0 * PI) * 15.0
		var current_freq = f + lfo
		phase += 2.0 * PI * current_freq / sample_rate
		var env = sin(p * PI) * gain
		var sample = sin(phase) * env
		var val = clampi(int(128 + sample * 127), 0, 255)
		data[i] = val
	return _create_wav(data, sample_rate)

func _synth_snap(duration: float, gain: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(total_samples)
	for i in range(total_samples):
		var t = float(i) / sample_rate
		var env_snap = exp(-t * 80.0)
		var env_boom = exp(-t * 9.0)
		var whip = (randf() * 2.0 - 1.0) * env_snap * 1.5
		var bass = sin(2.0 * PI * (65.0 - t * 30.0) * t) * env_boom * 0.8
		var sample = (whip + bass) * gain
		var val = clampi(int(128 + sample * 127), 0, 255)
		data[i] = val
	return _create_wav(data, sample_rate)
