extends Node
## Procedural piano-like tones, safe for non-threaded web builds.
##
## Web "sample" playback can't use AudioStreamGenerator, so each MIDI note is
## rendered once into an AudioStreamWAV and cached. Rendering uses two
## single-cycle wavetables (bright and mellow) cross-faded over the note's
## decay, which is cheap enough to do on demand in GDScript.

signal sequence_step(index: int, midi: int)
signal sequence_finished

const MIX_RATE := 22050
const NOTE_SECONDS := 1.8
const TABLE_SIZE := 1024
const VOICES := 12
const PREWARM_RANGE := Vector2i(36, 84)
const CUT_FADE_SEC := 0.06

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
## Fade-out tweens for notes cut short, by player, so a reused voice cancels it.
var _fades := {}
var _bright := PackedFloat32Array()
var _mellow := PackedFloat32Array()
var _sequence_id := 0
var _prewarm_note := PREWARM_RANGE.x


func _ready() -> void:
	_bright = _make_table([1.0, 0.55, 0.32, 0.2, 0.12, 0.07, 0.04])
	_mellow = _make_table([1.0, 0.18, 0.05])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


## Renders the remaining notes a few per frame so the first chord doesn't stutter.
func _process(_delta: float) -> void:
	if _prewarm_note > PREWARM_RANGE.y:
		set_process(false)
		return
	_get_stream(_prewarm_note)
	_prewarm_note += 1


func play_note(midi: int, volume_db := 0.0) -> AudioStreamPlayer:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	if _fades.has(p):
		_fades[p].kill()
		_fades.erase(p)
	p.stream = _get_stream(midi)
	p.volume_db = -6.0 + volume_db
	p.play()
	return p


## Plays notes together, or rolled low to high when arpeggiate is set. A
## duration above zero fades the block chord out after that many seconds.
func play_chord(notes: Array, arpeggiate := false, duration := 0.0) -> void:
	if arpeggiate:
		play_sequence(notes, 0.22)
		return
	stop_sequence()
	# Keep the sum of simultaneous notes from clipping.
	var gain := -2.0 * maxf(0, notes.size() - 2)
	for n in notes:
		var p := play_note(n, gain)
		if duration > 0.0:
			_cut(p, duration)


## Fades a voice out after delay seconds; a short fade avoids a click.
func _cut(p: AudioStreamPlayer, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(p, "volume_db", -60.0, CUT_FADE_SEC)
	tw.tween_callback(func():
		p.stop()
		_fades.erase(p))
	_fades[p] = tw


## Plays notes one after another, emitting sequence_step for each so the UI
## can light the key. Starting a new sequence cancels the previous one.
func play_sequence(notes: Array, step_sec: float) -> void:
	_sequence_id += 1
	var my_id := _sequence_id
	for i in notes.size():
		if my_id != _sequence_id:
			return
		play_note(notes[i])
		sequence_step.emit(i, notes[i])
		await get_tree().create_timer(step_sec).timeout
	if my_id == _sequence_id:
		sequence_finished.emit()


func stop_sequence() -> void:
	_sequence_id += 1


func _get_stream(midi: int) -> AudioStreamWAV:
	if not _cache.has(midi):
		_cache[midi] = _render(midi)
	return _cache[midi]


func _make_table(harmonics: Array) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(TABLE_SIZE + 1)
	var peak := 0.0
	for i in TABLE_SIZE:
		var x := TAU * i / TABLE_SIZE
		var v := 0.0
		for h in harmonics.size():
			v += harmonics[h] * sin(x * (h + 1))
		t[i] = v
		peak = maxf(peak, absf(v))
	for i in TABLE_SIZE:
		t[i] /= peak
	t[TABLE_SIZE] = t[0]
	return t


func _render(midi: int) -> AudioStreamWAV:
	var freq := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var n := int(MIX_RATE * NOTE_SECONDS)
	var step := freq * TABLE_SIZE / MIX_RATE
	# Higher notes decay faster, like a real piano.
	var decay := 1.6 + (midi - 36) * 0.06
	var attack := int(MIX_RATE * 0.004)
	var release := int(MIX_RATE * 0.08)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var idx := int(phase)
		var frac := phase - idx
		var b := lerpf(_bright[idx], _bright[idx + 1], frac)
		var m := lerpf(_mellow[idx], _mellow[idx + 1], frac)
		var env := exp(-t * decay)
		var s := lerpf(m, b, exp(-t * 6.0)) * env
		if i < attack:
			s *= float(i) / attack
		elif i > n - release:
			s *= float(n - i) / release
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0 * 0.8))
		phase += step
		if phase >= TABLE_SIZE:
			phase -= TABLE_SIZE
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
