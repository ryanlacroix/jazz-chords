class_name ScaleExplorer
extends VBoxContainer
## Pick a root and a scale; see its degrees on the keyboard, play it up and
## down, and jump to the chords it fits.

signal open_chord(root_index: int, quality: String)

var root := 0
var scale_id := "dorian"
var _notes: Array[int] = []

var _title: Button
var _hint: Label
var _notation: NotationCard
var _spelling: Label
var _formula: Label
var _roots: NoteGrid
var _scales: OptionList
var _fits: HFlowContainer
var _keyboard: PianoKeyboard
var _tempo: HSlider
var _tempo_label: Label
var _play: Button


func _init() -> void:
	add_theme_constant_override("separation", AppTheme.GAP)

	var header := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	header.add_child(vbox)
	_title = NotationCard.make_symbol_button(AppTheme.FONT_LARGE)
	_title.pressed.connect(_toggle_notation)
	_spelling = AppTheme.label("", AppTheme.FONT_LARGE)
	_formula = AppTheme.label("", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_hint = AppTheme.label("Tap the scale name to explain it", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	for l in [_spelling, _formula, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in [_title, _spelling, _formula, _hint]:
		vbox.add_child(c)
	add_child(header)

	# Stays open while browsing scales, so each one can be read in turn.
	_notation = NotationCard.new(true)
	add_child(_notation)

	_roots = NoteGrid.new()
	_roots.root_selected.connect(_on_root)
	add_child(_roots)

	_scales = OptionList.new(Theory.SCALES, 2, func(s): return Theory.SCALES[s].name)
	_scales.selected.connect(_on_scale)
	add_child(_scales)

	var fits_row := HBoxContainer.new()
	fits_row.add_theme_constant_override("separation", AppTheme.GAP)
	var fits_label := AppTheme.label("Fits", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	fits_label.custom_minimum_size.y = AppTheme.TOUCH
	fits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fits_row.add_child(fits_label)
	_fits = HFlowContainer.new()
	_fits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fits.add_theme_constant_override("h_separation", AppTheme.GAP)
	_fits.add_theme_constant_override("v_separation", AppTheme.GAP)
	fits_row.add_child(_fits)
	add_child(fits_row)

	_keyboard = PianoKeyboard.new()
	_keyboard.custom_minimum_size.y = 480
	add_child(_keyboard)

	var tempo_row := HBoxContainer.new()
	tempo_row.add_theme_constant_override("separation", AppTheme.GAP * 2)
	_tempo_label = AppTheme.label("", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_tempo_label.custom_minimum_size.x = 260
	_tempo = HSlider.new()
	_tempo.min_value = 60
	_tempo.max_value = 240
	_tempo.step = 10
	_tempo.value = 120
	_tempo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tempo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tempo.custom_minimum_size.y = 90
	_tempo.focus_mode = Control.FOCUS_NONE
	_tempo.value_changed.connect(func(v): _tempo_label.text = "Tempo %d" % v)
	tempo_row.add_child(_tempo_label)
	tempo_row.add_child(_tempo)
	add_child(tempo_row)
	_tempo_label.text = "Tempo %d" % _tempo.value

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", AppTheme.GAP)
	_play = AppTheme.button("Play up & down")
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.pressed.connect(_on_play)
	for c in [_keyboard.make_octave_button(-1), _play, _keyboard.make_octave_button(1)]:
		actions.add_child(c)
	add_child(actions)

	Synth.sequence_step.connect(_on_step)


func _ready() -> void:
	_scales.select(scale_id)
	_refresh()


func _on_root(index: int) -> void:
	root = index
	_refresh()


func _on_scale(key: String) -> void:
	scale_id = key
	_refresh()


func _on_play() -> void:
	var down := _notes.duplicate()
	down.reverse()
	Synth.play_sequence(_notes + down.slice(1), 30.0 / _tempo.value)


func _on_step(_index: int, midi: int) -> void:
	if is_visible_in_tree():
		_keyboard.flash(midi, 30.0 / _tempo.value)


func _toggle_notation() -> void:
	_notation.visible = not _notation.visible
	_hint.visible = not _notation.visible


func _refresh() -> void:
	Synth.stop_sequence()
	_notes = Theory.scale_notes(root, scale_id)
	var degrees := Theory.scale_degrees_by_pitch(scale_id)
	var names := Theory.spell_degrees(root, degrees)
	_title.text = "%s %s" % [Theory.scale_root_name(root, scale_id), Theory.SCALES[scale_id].name]
	_notation.show_scale(scale_id)
	_spelling.text = "  ".join(names)
	_formula.text = "  ".join(degrees.map(Theory.degree_display))

	_keyboard.clear()
	var top := _notes[_notes.size() - 1]
	_keyboard.highlight([_notes[0], top], ["R", "R"], AppTheme.ROOT, [names[0], names[0]])
	_keyboard.highlight(_notes.slice(1, _notes.size() - 1), degrees.slice(1).map(Theory.degree_display), AppTheme.TONE, Array(names.slice(1)))
	_keyboard.center_on(_notes)

	for c in _fits.get_children():
		c.queue_free()
	for q in Theory.chords_for_scale(scale_id):
		var chip := AppTheme.button(Theory.chord_symbol(root, q))
		chip.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
		chip.custom_minimum_size.x = 150
		chip.pressed.connect(func(): open_chord.emit(root, q))
		_fits.add_child(chip)
