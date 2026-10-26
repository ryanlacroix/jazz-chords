class_name EarTrainer
extends Control
## Interval ear training: hear two notes, name the interval. Settings (which
## intervals, which direction) live in a slide-up panel. Totals persist in
## user://stats.cfg, which is IndexedDB on the web.

enum Direction { UP, DOWN, TOGETHER }

const STATS_PATH := "user://stats.cfg"
const DIRECTION_NAMES := ["Up", "Down", "Together"]
const DEFAULT_INTERVALS := [2, 3, 4, 5, 7, 12]

var enabled: Array = DEFAULT_INTERVALS.duplicate()
var direction := Direction.UP
var correct := 0
var asked := 0
var streak := 0
var best_streak := 0
var total_correct := 0
var total_asked := 0

var _question := 0  # semitones; 0 = no question yet
var _low := 60
var _answered := false

var _score: Label
var _status: Label
var _replay: Button
var _next: Button
var _answers := {}  # semitones -> Button
var _keyboard: PianoKeyboard
var _settings: BottomSheet
var _interval_toggles := {}
var _direction_toggles: Array[Button] = []


func _init() -> void:
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", AppTheme.GAP)
	add_child(main)

	var header := PanelContainer.new()
	var vbox := VBoxContainer.new()
	header.add_child(vbox)
	_score = AppTheme.label("", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_status = AppTheme.label("", AppTheme.FONT_LARGE)
	for l in [_score, _status]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(l)
	main.add_child(header)

	_replay = AppTheme.button("Replay")
	_replay.custom_minimum_size.y = 220
	_replay.add_theme_font_size_override("font_size", AppTheme.FONT_LARGE)
	_replay.pressed.connect(_play_question)
	main.add_child(_replay)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", AppTheme.GAP)
	grid.add_theme_constant_override("v_separation", AppTheme.GAP)
	for iv in Theory.INTERVALS:
		var b := AppTheme.button(iv.short)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 150
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", AppTheme.FONT_LARGE)
		b.pressed.connect(_on_answer.bind(iv.semitones))
		grid.add_child(b)
		_answers[iv.semitones] = b
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(grid)

	_keyboard = PianoKeyboard.new()
	_keyboard.custom_minimum_size.y = 480
	main.add_child(_keyboard)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", AppTheme.GAP)
	var settings := AppTheme.button("Settings")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(func(): _settings.open())
	_next = AppTheme.button("Start")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_new_question)
	actions.add_child(settings)
	actions.add_child(_next)
	main.add_child(actions)

	_build_settings()


func _ready() -> void:
	_load()
	_sync_settings_ui()
	_update_answers()
	_update_score()
	_status.text = "Tap Start to hear an interval"


# --- Quiz -------------------------------------------------------------------

func _new_question() -> void:
	var choices := enabled.duplicate()
	if choices.size() > 1:
		choices.erase(_question)  # avoid repeating the same interval twice in a row
	_question = choices.pick_random()
	_low = randi_range(48, 72 - _question)
	_answered = false
	_next.text = "Next"
	_status.text = "Which interval?"
	_keyboard.clear()
	_update_answers()
	_play_question()


func _play_question() -> void:
	if _question == 0:
		return
	var notes := [_low, _low + _question]
	match direction:
		Direction.UP:
			Synth.play_sequence(notes, 0.7)
		Direction.DOWN:
			notes.reverse()
			Synth.play_sequence(notes, 0.7)
		Direction.TOGETHER:
			Synth.play_chord(notes)


func _on_answer(semitones: int) -> void:
	if _question == 0:
		Synth.play_sequence([60, 60 + semitones], 0.5)  # no quiz yet: just demo it
		return
	if _answered:
		Synth.play_sequence([_low, _low + semitones], 0.5)  # compare with the answer
		return
	_answered = true
	asked += 1
	total_asked += 1
	var name: String = Theory.INTERVALS[_question - 1].name
	if semitones == _question:
		correct += 1
		total_correct += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		_status.text = "Yes! %s" % name
	else:
		streak = 0
		_status.text = "No, it was: %s" % name
		AppTheme.tint(_answers[semitones], AppTheme.BAD)
	AppTheme.tint(_answers[_question], AppTheme.GOOD)
	var high := _low + _question
	# Note name on the key, octave number underneath (black keys are narrow).
	for n in [_low, high]:
		var name_and_octave := Theory.midi_name(n)
		var octave := str(floori(n / 12.0) - 1)
		var color := AppTheme.ROOT if n == _low else AppTheme.TONE
		_keyboard.highlight([n], [name_and_octave.trim_suffix(octave)], color, [octave])
	_keyboard.center_on([_low, high])
	_update_score()
	_save()


func _update_answers() -> void:
	for s in _answers:
		AppTheme.untint(_answers[s])
		_answers[s].disabled = not enabled.has(s)
	_replay.disabled = _question == 0


func _update_score() -> void:
	var pct := 100.0 * total_correct / total_asked if total_asked > 0 else 0.0
	_score.text = "Session %d/%d  ·  Streak %d  ·  Best %d  ·  All-time %d%%" % [correct, asked, streak, best_streak, roundi(pct)]


# --- Settings sheet ---------------------------------------------------------

func _build_settings() -> void:
	_settings = BottomSheet.new()
	_settings.closed.connect(_save)
	add_child(_settings)
	var box := _settings.content

	box.add_child(AppTheme.label("Intervals", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM))
	var grid := BottomSheet.toggle_grid(3)
	for iv in Theory.INTERVALS:
		var b := AppTheme.button(iv.name, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
		b.toggled.connect(_on_interval_toggled.bind(iv.semitones))
		grid.add_child(b)
		_interval_toggles[iv.semitones] = b
	box.add_child(grid)

	box.add_child(AppTheme.label("Direction", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", AppTheme.GAP)
	for d in DIRECTION_NAMES.size():
		var b := AppTheme.button(DIRECTION_NAMES[d], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_direction.bind(d))
		drow.add_child(b)
		_direction_toggles.append(b)
	box.add_child(drow)

	var reset := AppTheme.button("Reset all-time stats")
	reset.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
	reset.pressed.connect(_reset_stats)
	box.add_child(reset)
	var done := AppTheme.button("Done")
	done.pressed.connect(_settings.close)
	box.add_child(done)


func _on_interval_toggled(on: bool, semitones: int) -> void:
	if on and not enabled.has(semitones):
		enabled.append(semitones)
	elif not on:
		if enabled.size() == 1:
			_interval_toggles[semitones].set_pressed_no_signal(true)  # keep at least one
			return
		enabled.erase(semitones)
	enabled.sort()
	if not _answered and _question != 0 and not enabled.has(_question):
		_question = 0
		_next.text = "Start"
		_status.text = "Tap Start to hear an interval"
	_update_answers()


func _on_direction(d: int) -> void:
	direction = d
	_sync_settings_ui()


func _sync_settings_ui() -> void:
	for s in _interval_toggles:
		_interval_toggles[s].set_pressed_no_signal(enabled.has(s))
	for i in _direction_toggles.size():
		_direction_toggles[i].set_pressed_no_signal(i == direction)


func _reset_stats() -> void:
	total_correct = 0
	total_asked = 0
	best_streak = streak
	_update_score()
	_save()


# --- Persistence ------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(STATS_PATH) != OK:
		return
	total_correct = cfg.get_value("stats", "total_correct", 0)
	total_asked = cfg.get_value("stats", "total_asked", 0)
	best_streak = cfg.get_value("stats", "best_streak", 0)
	var saved: Array = cfg.get_value("settings", "intervals", DEFAULT_INTERVALS)
	enabled = saved.filter(func(s): return s >= 1 and s <= 12)
	if enabled.is_empty():
		enabled = DEFAULT_INTERVALS.duplicate()
	direction = clampi(cfg.get_value("settings", "direction", Direction.UP), 0, DIRECTION_NAMES.size() - 1)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATS_PATH)  # keep other screens' sections
	cfg.set_value("stats", "total_correct", total_correct)
	cfg.set_value("stats", "total_asked", total_asked)
	cfg.set_value("stats", "best_streak", best_streak)
	cfg.set_value("settings", "intervals", enabled)
	cfg.set_value("settings", "direction", direction)
	cfg.save(STATS_PATH)
