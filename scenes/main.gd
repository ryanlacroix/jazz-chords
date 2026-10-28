extends Control
## App shell: screen host, bottom tab bar, safe-area padding, and the
## "tap to start" and "rotate your phone" overlays, and a toast when a MIDI
## controller connects or disconnects.

const TAB_NAMES := ["Chords", "Scales", "Practice", "Ear"]
const SIDE_MARGIN := 36
const MIN_EDGE_MARGIN := 24

var _margin: MarginContainer
var _screens: Array[Control] = []
var _tabs: Array[Button] = []
var _chords: ChordBuilder
var _scales: ScaleExplorer
var _practice: ChordPractice
var _ear: EarTrainer
var _rotate_overlay: Control
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	theme = AppTheme.build()

	var bg := ColorRect.new()
	bg.color = AppTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", AppTheme.GAP * 2)
	_margin.add_child(layout)

	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(host)
	_chords = ChordBuilder.new()
	_scales = ScaleExplorer.new()
	_practice = ChordPractice.new()
	_ear = EarTrainer.new()
	for s in [_chords, _scales, _practice, _ear]:
		s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(s)
		_screens.append(s)
	_scales.open_chord.connect(_on_open_chord)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", AppTheme.GAP)
	for i in TAB_NAMES.size():
		var b := AppTheme.button(TAB_NAMES[i], true)
		b.custom_minimum_size.y = 150
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(i))
		bar.add_child(b)
		_tabs.append(b)
	layout.add_child(bar)

	_add_start_overlay()
	_rotate_overlay = _overlay("Rotate your phone to portrait")
	add_child(_rotate_overlay)
	_add_toast()
	Midi.devices_changed.connect(_on_midi_devices)

	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	show_tab(0)

	if OS.get_cmdline_user_args().has("--shot"):
		add_child(load("res://tests/screenshot.gd").new())


func show_tab(index: int) -> void:
	Synth.stop_sequence()
	for i in _screens.size():
		_screens[i].visible = i == index
		_tabs[i].set_pressed_no_signal(i == index)


func _on_open_chord(root_index: int, quality: String) -> void:
	show_tab(0)
	_chords.show_chord(root_index, quality)


func _on_resized() -> void:
	var view := get_viewport_rect().size
	_rotate_overlay.visible = view.x > view.y
	# Convert the OS safe area (screen pixels) into viewport units.
	var window := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var top := MIN_EDGE_MARGIN
	var bottom := MIN_EDGE_MARGIN
	if window.y > 0 and safe.size.y > 0:
		var ratio := view.y / window.y
		top = maxi(top, int(safe.position.y * ratio))
		bottom = maxi(bottom, int((window.y - safe.end.y) * ratio))
	_margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	_margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	_margin.add_theme_constant_override("margin_top", top)
	_margin.add_theme_constant_override("margin_bottom", bottom)


## Browsers only allow audio after a user gesture, so the first tap starts it.
func _add_start_overlay() -> void:
	var o := _overlay("Jazz Chords\n\nTap to start")
	o.name = "StartOverlay"
	o.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			Synth.play_note(72, -30.0)
			if Midi.devices.is_empty():
				Midi.reconnect()  # some browsers only grant MIDI after a gesture
			o.queue_free())
	add_child(o)


func _add_toast() -> void:
	_toast = AppTheme.label("", AppTheme.FONT_SMALL)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", AppTheme._box(AppTheme.BUTTON, 24, 24))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.custom_minimum_size.x = 900
	_toast.offset_left = -450
	_toast.offset_right = 450
	_toast.offset_top = 60
	_toast.modulate.a = 0.0
	add_child(_toast)


func _on_midi_devices(names: PackedStringArray) -> void:
	_toast.text = "MIDI: " + ", ".join(names) if names else "MIDI disconnected"
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _overlay(text: String) -> Control:
	var o := ColorRect.new()
	o.color = AppTheme.BG
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var l := AppTheme.label(text, AppTheme.FONT_LARGE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(l)
	return o
