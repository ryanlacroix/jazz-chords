class_name ChordPractice
extends Control
## Chord practice: the app names a random chord, every key is labelled with
## its degree from that chord's root, and the user taps keys on/off until the
## selected notes match the chord (any octave, any inversion). On a MIDI
## controller the held notes are the answer: releasing a key drops it again.

const STATS_PATH := "user://stats.cfg"
const SECTION := "chord_practice"
const DEFAULT_GROUPS := ["Triads", "Major", "Minor", "Dominant", "Diminished"]
const NEXT_DELAY := 1.2

var keys: Array = range(12)
var groups: Array = DEFAULT_GROUPS.duplicate()
var root := 0
var quality := "maj7"
var solved := 0
var streak := 0
var best_streak := 0

## midi -> true for keys the user has turned on.
var _selected := {}
var _revealed := false
## Bumped on every new chord so a pending "next chord" timer can tell it's stale.
var _chord_id := 0

var _score: Label
var _symbol: Button
var _notation: NotationCard
var _status: Label
var _keyboard: PianoKeyboard
var _answer: Button
var _settings: BottomSheet
var _key_toggles: Array[Button] = []
var _group_toggles := {}


func _init() -> void:
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", AppTheme.GAP)
	add_child(main)

	var header := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	header.add_child(vbox)
	_score = AppTheme.label("", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	var prompt := AppTheme.label("Play this chord", AppTheme.FONT_BODY, AppTheme.TEXT_DIM)
	# The chord name is a flat button: tapping it explains the notation.
	_symbol = NotationCard.make_symbol_button(int(AppTheme.FONT_HUGE * 1.4))
	_symbol.pressed.connect(func():
		_notation.show_chord(quality)
		_notation.visible = not _notation.visible)
	var hint := AppTheme.label("Tap the chord name to explain it", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_status = AppTheme.label("", AppTheme.FONT_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [_score, prompt, hint, _status]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in [_score, prompt, _symbol, hint, _status]:
		vbox.add_child(c)
	main.add_child(header)

	# The space above the keyboard holds the explanation card when it's open.
	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(middle)
	_notation = NotationCard.new()
	middle.add_child(_notation)

	_keyboard = PianoKeyboard.new()
	_keyboard.custom_minimum_size.y = 820
	_keyboard.play_on_press = false
	_keyboard.key_pressed.connect(_on_key)
	main.add_child(_keyboard)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AppTheme.GAP)
	var clear := AppTheme.button("Clear")
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(_clear_selection)
	for c in [_keyboard.make_octave_button(-1), clear, _keyboard.make_octave_button(1)]:
		row.add_child(c)
	main.add_child(row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", AppTheme.GAP)
	var settings := AppTheme.button("Settings")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(func(): _settings.open())
	_answer = AppTheme.button("Show answer")
	_answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_answer.pressed.connect(_on_answer_button)
	actions.add_child(settings)
	actions.add_child(_answer)
	main.add_child(actions)

	_build_settings()
	Midi.note_on.connect(_on_midi_note_on)
	Midi.note_off.connect(_on_midi_note_off)


func _ready() -> void:
	_load()
	_sync_settings_ui()
	_update_score()
	_new_chord()


# --- Practice ---------------------------------------------------------------

## Every (root, quality) pair allowed by the key and chord-type filters.
func _pool() -> Array:
	var out := []
	for r in keys:
		for q in Theory.CHORDS:
			if groups.has(Theory.CHORDS[q].group):
				out.append([r, q])
	return out


func _new_chord() -> void:
	_chord_id += 1
	var pool := _pool()
	if pool.size() > 1:
		pool.erase([root, quality])  # never the same chord twice in a row
	var pick: Array = pool.pick_random()
	root = pick[0]
	quality = pick[1]
	_present()


## Resets the board for the current root and quality.
func _present() -> void:
	_revealed = false
	_selected.clear()
	_keyboard.input_enabled = true
	_keyboard.clear()
	_keyboard.set_degree_labels(root)
	_keyboard.center_on(Theory.chord_notes(root, quality))
	_symbol.text = Theory.chord_symbol(root, quality)
	_notation.visible = false
	_set_status("Tap or play the keys" if Midi.devices else "Tap the keys", AppTheme.TEXT)
	_answer.text = "Show answer"


func _on_key(midi: int) -> void:
	if _revealed:
		Synth.play_note(midi)
		return
	_select(midi, not _selected.has(midi))
	if _selected.has(midi):
		Synth.play_note(midi)
	_check()


## The Midi autoload has already sounded these notes.
func _on_midi_note_on(midi: int, _velocity: int) -> void:
	if _accepts_midi():
		_select(midi, true)
		_check()


func _on_midi_note_off(midi: int) -> void:
	if _accepts_midi():
		_select(midi, false)


func _accepts_midi() -> bool:
	return is_visible_in_tree() and not _revealed and _keyboard.input_enabled


func _select(midi: int, on: bool) -> void:
	if on:
		_selected[midi] = true
		_keyboard.highlight([midi], [Theory.OFFSET_LABELS[(midi - root) % 12]], AppTheme.ACCENT)
	else:
		_selected.erase(midi)
		_keyboard.unhighlight([midi])


func _selected_pcs() -> Array[int]:
	var out: Array[int] = []
	for m in _selected:
		if not out.has(m % 12):
			out.append(m % 12)
	out.sort()
	return out


func _check() -> void:
	if _selected_pcs() != Theory.chord_pcs(root, quality):
		return
	solved += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	_update_score()
	_save()
	var spelled := Theory.spell_degrees(root, Theory.chord_degrees(quality))
	_set_status("Correct!  " + "  ".join(spelled), AppTheme.GOOD)
	var notes := _selected.keys()
	notes.sort()
	_keyboard.highlight(notes, notes.map(func(m): return Theory.OFFSET_LABELS[(m - root) % 12]), AppTheme.GOOD)
	Synth.play_chord(notes)
	_keyboard.input_enabled = false
	var id := _chord_id
	get_tree().create_timer(NEXT_DELAY).timeout.connect(func():
		if id == _chord_id:
			_new_chord())


func _clear_selection() -> void:
	if _revealed or not _keyboard.input_enabled:
		return
	_keyboard.unhighlight(_selected.keys())
	_selected.clear()


func _on_answer_button() -> void:
	if _revealed or not _keyboard.input_enabled:
		_new_chord()
		return
	_revealed = true
	streak = 0
	_update_score()
	var notes := Theory.chord_notes(root, quality)
	var degrees := Theory.chord_degrees(quality)
	var spelled := Theory.spell_degrees(root, degrees)
	_keyboard.clear()
	_keyboard.highlight([notes[0]], ["R"], AppTheme.ROOT, [spelled[0]])
	_keyboard.highlight(notes.slice(1), degrees.slice(1), AppTheme.TONE, Array(spelled.slice(1)))
	_keyboard.center_on(notes)
	_set_status("  ".join(spelled), AppTheme.TEXT_DIM)
	_answer.text = "Next"
	Synth.play_chord(notes)


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _update_score() -> void:
	_score.text = "Solved %d  ·  Streak %d  ·  Best %d" % [solved, streak, best_streak]


# --- Settings ---------------------------------------------------------------

func _build_settings() -> void:
	_settings = BottomSheet.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)
	var box := _settings.content

	box.add_child(AppTheme.label("Keys", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM))
	var key_grid := BottomSheet.toggle_grid(6)
	for i in Theory.ROOTS.size():
		var b := AppTheme.button(Theory.ROOTS[i], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(_on_key_toggled.bind(i))
		key_grid.add_child(b)
		_key_toggles.append(b)
	box.add_child(key_grid)
	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", AppTheme.GAP)
	var all := AppTheme.button("All keys")
	all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all.pressed.connect(func(): _set_keys(range(12)))
	var none := AppTheme.button("Only " + Theory.ROOTS[root])
	none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	none.pressed.connect(func(): _set_keys([root]))
	_settings.visibility_changed.connect(func(): none.text = "Only " + Theory.ROOTS[root])
	key_row.add_child(all)
	key_row.add_child(none)
	box.add_child(key_row)

	box.add_child(AppTheme.label("Chord types", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM))
	var group_grid := BottomSheet.toggle_grid(2)
	for g in Theory.groups(Theory.CHORDS):
		var b := AppTheme.button(g, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
		b.toggled.connect(_on_group_toggled.bind(g))
		group_grid.add_child(b)
		_group_toggles[g] = b
	box.add_child(group_grid)

	var reset := AppTheme.button("Reset stats")
	reset.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
	reset.pressed.connect(_reset_stats)
	box.add_child(reset)
	var done := AppTheme.button("Done")
	done.pressed.connect(_settings.close)
	box.add_child(done)


func _set_keys(new_keys: Array) -> void:
	keys = new_keys.duplicate()
	_sync_settings_ui()


func _on_key_toggled(on: bool, index: int) -> void:
	if on and not keys.has(index):
		keys.append(index)
	elif not on:
		if keys.size() == 1:
			_key_toggles[index].set_pressed_no_signal(true)  # keep at least one
			return
		keys.erase(index)
	keys.sort()


func _on_group_toggled(on: bool, group: String) -> void:
	if on and not groups.has(group):
		groups.append(group)
	elif not on:
		if groups.size() == 1:
			_group_toggles[group].set_pressed_no_signal(true)  # keep at least one
			return
		groups.erase(group)


func _sync_settings_ui() -> void:
	for i in _key_toggles.size():
		_key_toggles[i].set_pressed_no_signal(keys.has(i))
	for g in _group_toggles:
		_group_toggles[g].set_pressed_no_signal(groups.has(g))


func _on_settings_closed() -> void:
	_save()
	if not keys.has(root) or not groups.has(Theory.CHORDS[quality].group):
		_new_chord()


func _reset_stats() -> void:
	solved = 0
	best_streak = streak
	_update_score()
	_save()


# --- Persistence ------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(STATS_PATH) != OK:
		return
	solved = cfg.get_value(SECTION, "solved", 0)
	best_streak = cfg.get_value(SECTION, "best_streak", 0)
	var saved_keys: Array = cfg.get_value(SECTION, "keys", keys)
	saved_keys = saved_keys.filter(func(k): return k >= 0 and k < 12)
	if not saved_keys.is_empty():
		keys = saved_keys
	var all_groups := Theory.groups(Theory.CHORDS)
	var saved_groups: Array = cfg.get_value(SECTION, "groups", groups)
	saved_groups = saved_groups.filter(func(g): return all_groups.has(g))
	if not saved_groups.is_empty():
		groups = saved_groups


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATS_PATH)  # keep other screens' sections
	cfg.set_value(SECTION, "solved", solved)
	cfg.set_value(SECTION, "best_streak", best_streak)
	cfg.set_value(SECTION, "keys", keys)
	cfg.set_value(SECTION, "groups", groups)
	cfg.save(STATS_PATH)
