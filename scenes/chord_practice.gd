class_name ChordPractice
extends Control
## Chord practice: the app names a random chord, every key is labelled with
## its degree from that chord's root, and the user taps keys on/off until the
## selected notes match the chord (any octave, any inversion). On a MIDI
## controller the held notes are the answer: releasing a key drops it again.

const STATS_PATH := "user://stats.cfg"
const SECTION := "chord_practice"
const DEFAULT_GROUPS := ["Triads", "Major", "Minor", "Dominant", "Diminished"]
const DEMO_SECONDS := 1.0

## Random: any chord from the pool. Full Keys: every enabled chord type on one
## root, shuffled, then another root. Diatonic: the seven 7th chords of one
## major key, shuffled, then another key. Jazz: a standard's progression in
## order, looping; the arrows beside its title switch standards.
enum Order { RANDOM, FULL_KEYS, DIATONIC, JAZZ }
const ORDER_NAMES := ["Random", "Full Keys", "Diatonic Chords", "Jazz"]

var keys: Array = range(12)
var groups: Array = DEFAULT_GROUPS.duplicate()
var root := 0
var quality := "maj7"
var solved := 0
var streak := 0
var best_streak := 0
var order := Order.RANDOM

## Chords still to come in the current key, as [root, quality]; the last is next.
var _queue: Array = []
## Root (Full Keys) or tonic (Diatonic) of the key being worked through.
var _key := -1
var _order_at_open := Order.RANDOM
## Index into Standards.ROSTER (-1 until Jazz picks one) and the current chord.
var _standard := -1
var _standard_pos := 0
## The root as the chart writes it (Jazz only); empty means the usual spelling.
var _root_name := ""

## midi -> true for keys the user has turned on.
var _selected := {}
var _revealed := false
## The new chord hasn't been sounded yet because the screen was hidden.
var _demo_pending := false

var _score: Label
var _prompt: Label
var _prev_standard: Button
var _next_standard: Button
var _symbol: Button
var _notation: NotationCard
var _status: Label
var _keyboard: PianoKeyboard
var _answer: Button
var _settings: BottomSheet
var _key_toggles: Array[Button] = []
var _group_toggles := {}
var _order_toggles: Array[Button] = []


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
	_prompt = AppTheme.label("Play this chord", AppTheme.FONT_BODY, AppTheme.TEXT_DIM)
	# The chord name is a flat button: tapping it explains the notation.
	_symbol = NotationCard.make_symbol_button(int(AppTheme.FONT_HUGE * 1.4))
	_symbol.pressed.connect(_toggle_notation)
	var hint := AppTheme.label("Tap the chord name to explain it", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_status = AppTheme.label("", AppTheme.FONT_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [_score, _prompt, hint, _status]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# In Jazz the prompt names the standard, with arrows to switch it.
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", AppTheme.GAP)
	_prev_standard = AppTheme.button("<")
	_next_standard = AppTheme.button(">")
	for b in [_prev_standard, _next_standard]:
		b.custom_minimum_size.x = AppTheme.TOUCH
		b.visible = false
	_prev_standard.pressed.connect(_switch_standard.bind(-1))
	_next_standard.pressed.connect(_switch_standard.bind(1))
	for c in [_prev_standard, _prompt, _next_standard]:
		prompt_row.add_child(c)
	for c in [_score, prompt_row, _symbol, hint, _status]:
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
	settings.pressed.connect(func():
		_order_at_open = order
		_settings.open())
	var hear := AppTheme.button("Hear again")
	hear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hear.pressed.connect(_play_demo)
	_answer = AppTheme.button("Show answer")
	_answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_answer.pressed.connect(_on_answer_button)
	actions.add_child(settings)
	actions.add_child(hear)
	actions.add_child(_answer)
	main.add_child(actions)

	_build_settings()
	Midi.note_on.connect(_on_midi_note_on)
	Midi.note_off.connect(_on_midi_note_off)
	Midi.pad_pressed.connect(_on_midi_pad)
	visibility_changed.connect(func():
		if _demo_pending and is_visible_in_tree():
			_play_demo())


func _ready() -> void:
	_load()
	_sync_settings_ui()
	_update_score()
	_new_chord(false)  # sounded once the tab is actually opened


# --- Practice ---------------------------------------------------------------

## Every (root, quality) pair allowed by the key and chord-type filters.
func _pool() -> Array:
	var out := []
	for r in keys:
		for q in Theory.CHORDS:
			if groups.has(Theory.CHORDS[q].group):
				out.append([r, q])
	return out


func _new_chord(sound := true) -> void:
	var pick: Array
	_root_name = ""
	if order == Order.JAZZ:
		if _standard < 0:
			_standard = randi() % Standards.ROSTER.size()
			_standard_pos = 0
		else:
			_standard_pos = (_standard_pos + 1) % Standards.chords(_standard).size()
		_show_standard_chord(sound)
		return
	if order == Order.RANDOM:
		var pool := _pool()
		if pool.size() > 1:
			pool.erase([root, quality])  # never the same chord twice in a row
		pick = pool.pick_random()
	else:
		if _queue.is_empty():
			_refill_queue()
		pick = _queue.pop_back()
	root = pick[0]
	quality = pick[1]
	_present_and_sound(sound)


func _present_and_sound(sound: bool) -> void:
	_present()
	_demo_pending = true
	if sound and is_visible_in_tree():
		_play_demo()


## Jumps to the first chord of the previous or next standard.
func _switch_standard(step: int) -> void:
	_standard = wrapi(_standard + step, 0, Standards.ROSTER.size())
	_standard_pos = 0
	_show_standard_chord(true)


func _show_standard_chord(sound: bool) -> void:
	var c: Dictionary = Standards.chords(_standard)[_standard_pos]
	root = c.root
	quality = c.quality
	_root_name = c.name
	_present_and_sound(sound)


## Moves on to a new random key and queues its chords in shuffled order.
func _refill_queue() -> void:
	var choices := keys.duplicate()
	if choices.size() > 1:
		choices.erase(_key)
	_key = choices.pick_random()
	if order == Order.DIATONIC:
		_queue = Theory.diatonic_chords(_key)
	else:
		_queue = _pool().filter(func(c): return c[0] == _key)
	_queue.shuffle()
	if _queue.size() > 1 and _queue[-1] == [root, quality]:
		_queue.reverse()  # never the same chord twice in a row


## Sounds the chord briefly without lighting any keys, so it isn't a giveaway.
func _play_demo() -> void:
	_demo_pending = false
	Synth.play_chord(Theory.chord_notes(root, quality), false, DEMO_SECONDS)


## Resets the board for the current root and quality.
func _present() -> void:
	_revealed = false
	_selected.clear()
	_keyboard.input_enabled = true
	_keyboard.clear()
	_keyboard.set_degree_labels(root)
	_keyboard.center_on(Theory.chord_notes(root, quality))
	_symbol.text = (_root_name if _root_name else Theory.chord_root_name(root, quality)) + quality
	_prompt.text = "Play this chord"
	if order == Order.DIATONIC:
		_prompt.text += "  ·  Key of " + Theory.ROOTS[_key]
	elif order == Order.JAZZ:
		_prompt.text = Standards.ROSTER[_standard].name
	_prev_standard.visible = order == Order.JAZZ
	_next_standard.visible = order == Order.JAZZ
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


func _toggle_notation() -> void:
	_notation.show_chord(quality)
	_notation.visible = not _notation.visible


## The first three bottom-row pads double as "Hear again", the chord symbol
## and the answer button.
func _on_midi_pad(note: int) -> void:
	if not is_visible_in_tree():
		return
	match note:
		Midi.PAD_BOTTOM_1:
			_play_demo()
		Midi.PAD_BOTTOM_2:
			_toggle_notation()
		Midi.PAD_BOTTOM_3:
			_on_answer_button()


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
	var spelled := Theory.spell_degrees(root, Theory.chord_degrees(quality), _root_name)
	_set_status("Correct!  " + "  ".join(spelled), AppTheme.GOOD)
	var notes := _selected.keys()
	notes.sort()
	_keyboard.highlight(notes, notes.map(func(m): return Theory.OFFSET_LABELS[(m - root) % 12]), AppTheme.GOOD)
	Synth.play_chord(notes)
	_keyboard.input_enabled = false
	_answer.text = "Next"


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
	var spelled := Theory.spell_degrees(root, degrees, _root_name)
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

	box.add_child(AppTheme.label("Chord order", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM))
	var order_row := BottomSheet.toggle_grid(2)
	for o in ORDER_NAMES.size():
		var b := AppTheme.button(ORDER_NAMES[o], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
		b.pressed.connect(_on_order.bind(o))
		order_row.add_child(b)
		_order_toggles.append(b)
	box.add_child(order_row)

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


func _on_order(o: int) -> void:
	order = o as Order
	_queue.clear()
	_standard = -1
	_sync_settings_ui()


func _set_keys(new_keys: Array) -> void:
	keys = new_keys.duplicate()
	_queue.clear()
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
	_queue.clear()


func _on_group_toggled(on: bool, group: String) -> void:
	if on and not groups.has(group):
		groups.append(group)
	elif not on:
		if groups.size() == 1:
			_group_toggles[group].set_pressed_no_signal(true)  # keep at least one
			return
		groups.erase(group)
	_queue.clear()


func _sync_settings_ui() -> void:
	for i in _key_toggles.size():
		_key_toggles[i].set_pressed_no_signal(keys.has(i))
	for g in _group_toggles:
		_group_toggles[g].set_pressed_no_signal(groups.has(g))
	for i in _order_toggles.size():
		_order_toggles[i].set_pressed_no_signal(i == order)


func _on_settings_closed() -> void:
	_save()
	var still_valid := true
	if order == Order.DIATONIC:
		still_valid = keys.has(_key)
	elif order != Order.JAZZ:
		still_valid = keys.has(root) and groups.has(Theory.CHORDS[quality].group)
	if order != _order_at_open or not still_valid:
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
	order = clampi(cfg.get_value(SECTION, "order", Order.RANDOM), 0, ORDER_NAMES.size() - 1) as Order


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATS_PATH)  # keep other screens' sections
	cfg.set_value(SECTION, "solved", solved)
	cfg.set_value(SECTION, "best_streak", best_streak)
	cfg.set_value(SECTION, "keys", keys)
	cfg.set_value(SECTION, "groups", groups)
	cfg.set_value(SECTION, "order", order)
	cfg.save(STATS_PATH)
