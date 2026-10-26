class_name ChordBuilder
extends VBoxContainer
## Pick a root and a quality; see the chord on the keyboard with its interval
## labels, choose a voicing, and hear it.

var root := 0
var quality := "maj7"
var voicing := Theory.Voicing.ROOT
var _notes: Array = []

var _symbol: Button
var _hint: Label
var _notation: NotationCard
var _name: Label
var _spelling: Label
var _formula: Label
var _roots: NoteGrid
var _qualities: OptionList
var _voicing_buttons: Array[Button] = []
var _keyboard: PianoKeyboard


func _init() -> void:
	add_theme_constant_override("separation", AppTheme.GAP)

	var header := PanelContainer.new()
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	header.add_child(hbox)
	_symbol = NotationCard.make_symbol_button(AppTheme.FONT_HUGE)
	_symbol.pressed.connect(_toggle_notation)
	_name = AppTheme.label("", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_spelling = AppTheme.label("", AppTheme.FONT_LARGE)
	_formula = AppTheme.label("", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	_hint = AppTheme.label("Tap the chord name to explain it", AppTheme.FONT_SMALL, AppTheme.TEXT_DIM)
	for l in [_name, _spelling, _formula, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in [_symbol, _name, _spelling, _formula, _hint]:
		hbox.add_child(c)
	add_child(header)

	# Stays open while browsing qualities, so each one's notation can be read.
	_notation = NotationCard.new(true)
	add_child(_notation)

	_roots = NoteGrid.new()
	_roots.root_selected.connect(func(i): root = i; _refresh())
	add_child(_roots)

	_qualities = OptionList.new(Theory.CHORDS, 4, func(q): return q)
	_qualities.selected.connect(func(q): quality = q; _refresh())
	add_child(_qualities)

	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", AppTheme.GAP)
	for v in [Theory.Voicing.ROOT, Theory.Voicing.SHELL, Theory.Voicing.ROOTLESS_A, Theory.Voicing.ROOTLESS_B]:
		var b := AppTheme.button(Theory.voicing_name(v), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", AppTheme.FONT_SMALL)
		b.pressed.connect(func(): voicing = v; _refresh())
		vrow.add_child(b)
		_voicing_buttons.append(b)
	add_child(vrow)

	_keyboard = PianoKeyboard.new()
	_keyboard.custom_minimum_size.y = 480
	add_child(_keyboard)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", AppTheme.GAP)
	var block := AppTheme.button("Play")
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.pressed.connect(func(): Synth.play_chord(_notes))
	var arp := AppTheme.button("Arpeggio")
	arp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arp.pressed.connect(func(): Synth.play_chord(_notes, true))
	for c in [_keyboard.make_octave_button(-1), block, arp, _keyboard.make_octave_button(1)]:
		actions.add_child(c)
	add_child(actions)

	Synth.sequence_step.connect(func(_i, midi): if is_visible_in_tree(): _keyboard.flash(midi))


func _ready() -> void:
	_qualities.select(quality)
	_refresh()


## Used by the scale explorer's "fits chords" chips.
func show_chord(root_index: int, q: String) -> void:
	root = root_index
	quality = q
	_roots.select(root)
	_qualities.select(q)
	_qualities.reveal_selected.call_deferred()
	_refresh()


func _toggle_notation() -> void:
	_notation.visible = not _notation.visible
	_hint.visible = not _notation.visible


func _refresh() -> void:
	var available := Theory.voicings_for(quality)
	if not available.has(voicing):
		voicing = Theory.Voicing.ROOT
	for i in _voicing_buttons.size():
		_voicing_buttons[i].disabled = not available.has(i)
		_voicing_buttons[i].set_pressed_no_signal(i == voicing)

	var voiced := Theory.voice_chord(root, quality, voicing)
	_notes = voiced.notes
	var degrees: Array = voiced.degrees
	var names := Theory.spell_degrees(root, degrees, Theory.chord_root_name(root, quality))
	var labels := degrees.map(Theory.degree_display)

	_symbol.text = Theory.chord_symbol(root, quality)
	_notation.show_chord(quality)
	_name.text = "%s  ·  %s voicing" % [Theory.CHORDS[quality].name, Theory.voicing_name(voicing)]
	_spelling.text = "  ".join(names)
	_formula.text = "  ".join(Theory.chord_degrees(quality).map(Theory.degree_display))

	_keyboard.clear()
	var root_notes := []
	var root_names := []
	var other_notes := []
	var other_labels := []
	var other_names := []
	for i in _notes.size():
		if degrees[i] == "1":
			root_notes.append(_notes[i]); root_names.append(names[i])
		else:
			other_notes.append(_notes[i]); other_labels.append(labels[i]); other_names.append(names[i])
	_keyboard.highlight(root_notes, root_notes.map(func(_n): return "R"), AppTheme.ROOT, root_names)
	_keyboard.highlight(other_notes, other_labels, AppTheme.TONE, other_names)
	_keyboard.center_on(_notes)
