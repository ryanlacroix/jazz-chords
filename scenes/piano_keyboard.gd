class_name PianoKeyboard
extends Control
## On-screen piano drawn in code. Shows `visible_whites` white keys at a time
## out of the full C2..C6 range; the view slides with shift_octave() and
## center_on(). Handles multitouch directly so several keys can sound at once.
##
## A ScrollContainer isn't used because its drag-to-scroll would fight with
## pressing keys on a touchscreen.
##
## Notes held on a MIDI controller (the Midi autoload) are drawn pressed too,
## and the view slides to keep them in sight.

signal key_pressed(midi: int)
signal view_changed

const LOW := 36  # C2
const HIGH := 84  # C6
const WHITE_COLOR := Color("f2f2f2")
const BLACK_COLOR := Color("22252c")

@export var visible_whites := 14
@export var play_on_press := true
@export var follow_midi := true
var input_enabled := true

var view_offset := 0.0:
	set(v):
		view_offset = clampf(v, 0.0, _max_offset())
		queue_redraw()
		view_changed.emit()

## midi -> {color: Color, label: String, sub: String}
var _highlights := {}
## When >= 0, every unhighlighted key shows its degree name from this root.
var _degree_root := -1
## touch index -> midi, for keys currently held down.
var _held := {}
## midi -> seconds left of the "just played" flash.
var _lit := {}
var _whites: Array[int] = []
var _white_index := {}
var _tween: Tween
var _tween_target := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for m in range(LOW, HIGH + 1):
		if not Theory.is_black(m):
			_white_index[m] = _whites.size()
			_whites.append(m)


func _ready() -> void:
	view_offset = _white_of(60) - 3.5  # start around C4
	set_process(false)
	Midi.note_on.connect(_on_midi_note_on)
	Midi.note_off.connect(func(_m): queue_redraw())


# --- Public API -------------------------------------------------------------

func highlight(notes: Array, labels: Array = [], color := AppTheme.TONE, subs: Array = []) -> void:
	for i in notes.size():
		_highlights[notes[i]] = {
			"color": color,
			"label": labels[i] if i < labels.size() else "",
			"sub": subs[i] if i < subs.size() else "",
		}
	queue_redraw()


func unhighlight(notes: Array) -> void:
	for n in notes:
		_highlights.erase(n)
	queue_redraw()


## Labels every key R, b2, 2 ... 7 counting from root_pc (Theory.OFFSET_LABELS).
func set_degree_labels(root_pc: int) -> void:
	_degree_root = root_pc
	queue_redraw()


func clear_degree_labels() -> void:
	_degree_root = -1
	queue_redraw()


func _degree_label(midi: int) -> String:
	return Theory.OFFSET_LABELS[(midi - _degree_root) % 12]


func clear() -> void:
	_highlights.clear()
	_lit.clear()
	queue_redraw()


## Briefly outlines a key, used to follow along with playback.
func flash(midi: int, seconds := 0.3) -> void:
	_lit[midi] = seconds
	set_process(true)
	queue_redraw()


## Slides the view so the given notes are centred (or start at the left edge
## when they span more than the visible keys).
func center_on(notes: Array) -> void:
	if notes.is_empty():
		return
	var lo := _white_of(notes.min())
	var hi := _white_of(notes.max()) + 1.0
	var target := (lo + hi) / 2.0 - visible_whites / 2.0
	if hi - lo > visible_whites:
		target = lo - 0.5
	_slide_to(target)


func shift_octave(direction: int) -> void:
	_slide_to(view_offset + 7 * direction)


func can_shift(direction: int) -> bool:
	return view_offset > 0.01 if direction < 0 else view_offset < _max_offset() - 0.01


## A "<" or ">" button that slides this keyboard an octave and disables
## itself at the end of the range.
func make_octave_button(direction: int) -> Button:
	var b := AppTheme.button("<" if direction < 0 else ">")
	b.custom_minimum_size.x = AppTheme.TOUCH
	b.pressed.connect(shift_octave.bind(direction))
	view_changed.connect(func(): b.disabled = not can_shift(direction))
	return b


# --- Geometry ---------------------------------------------------------------

func _max_offset() -> float:
	return float(_whites.size() - visible_whites)


## Fractional white-key position of a note; black keys sit on the boundary.
func _white_of(midi: int) -> float:
	midi = clampi(midi, LOW, HIGH)
	if Theory.is_black(midi):
		return _white_index[midi - 1] + 1.0
	return float(_white_index[midi])


func _white_w() -> float:
	return size.x / visible_whites


func _black_size() -> Vector2:
	return Vector2(_white_w() * 0.62, size.y * 0.6)


func _white_rect(midi: int) -> Rect2:
	var w := _white_w()
	return Rect2((_white_index[midi] - view_offset) * w, 0, w, size.y)


func _black_rect(midi: int) -> Rect2:
	var bs := _black_size()
	var x := (_white_of(midi) - view_offset) * _white_w() - bs.x / 2.0
	return Rect2(x, 0, bs.x, bs.y)


func _note_at(pos: Vector2) -> int:
	var w := _white_w()
	var wi := int(floor(pos.x / w + view_offset))
	if wi < 0 or wi >= _whites.size():
		return -1
	var white := _whites[wi]
	if pos.y < _black_size().y:
		for m in [white - 1, white + 1]:
			if m >= LOW and m <= HIGH and Theory.is_black(m) and _black_rect(m).has_point(pos):
				return m
	return white


## Judged against where the view is sliding to, if it's moving.
func _in_view(midi: int) -> bool:
	var offset := _tween_target if _tween and _tween.is_running() else view_offset
	var x := _white_of(midi)
	return x >= offset and x + 1.0 <= offset + visible_whites


func _slide_to(target: float) -> void:
	target = clampf(target, 0.0, _max_offset())
	_tween_target = target
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "view_offset", target, 0.25)


# --- Input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Touches also arrive as emulated mouse events; those are handled above.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_touch(-1, event.position, event.pressed)
			accept_event()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var m := _note_at(pos)
		if m < 0:
			return
		_held[index] = m
		if play_on_press:
			Synth.play_note(m)
		key_pressed.emit(m)
	else:
		_held.erase(index)
	queue_redraw()


func _on_midi_note_on(midi: int, _velocity: int) -> void:
	if follow_midi and is_visible_in_tree() and not _in_view(midi):
		center_on(Midi.held_notes())
	queue_redraw()


func _process(delta: float) -> void:
	for m in _lit.keys():
		_lit[m] -= delta
		if _lit[m] <= 0.0:
			_lit.erase(m)
	if _lit.is_empty():
		set_process(false)
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var font := get_theme_default_font()
	var w := _white_w()
	var label_size := int(clampf(w * 0.5, 26, 48))
	var sub_size := int(label_size * 0.78)
	var held := _held.values() + Midi.held_notes()
	draw_rect(Rect2(Vector2.ZERO, size), AppTheme.BG)

	for m in _whites:
		var r := _white_rect(m)
		if r.end.x < 0 or r.position.x > size.x:
			continue
		var key := r.grow_individual(-2, 0, -2, 0)
		var h: Dictionary = _highlights.get(m, {})
		var col: Color = h.get("color", WHITE_COLOR)
		if held.has(m):
			col = col.darkened(0.25)
		draw_rect(key, col)
		var text_col := Color.WHITE if h else Color(0.45, 0.47, 0.52)
		if h:
			_text(font, h.label, Vector2(key.position.x, key.end.y - 34 - sub_size), key.size.x, label_size, text_col)
			_text(font, h.sub, Vector2(key.position.x, key.end.y - 22), key.size.x, sub_size, text_col)
		elif _degree_root >= 0:
			_text(font, _degree_label(m), Vector2(key.position.x, key.end.y - 34 - sub_size), key.size.x, label_size, text_col)
		elif m % 12 == 0:
			_text(font, Theory.midi_name(m), Vector2(key.position.x, key.end.y - 22), key.size.x, sub_size, text_col)
		if _lit.has(m):
			draw_rect(key.grow(-4), AppTheme.ACCENT, false, 8)

	for m in range(LOW, HIGH + 1):
		if not Theory.is_black(m):
			continue
		var r := _black_rect(m)
		if r.end.x < 0 or r.position.x > size.x:
			continue
		var h: Dictionary = _highlights.get(m, {})
		var col: Color = h.get("color", BLACK_COLOR)
		if held.has(m):
			col = col.lightened(0.25) if not h else col.darkened(0.25)
		draw_rect(r, col)
		if h:
			var small := int(label_size * 0.82)
			_text(font, h.label, Vector2(r.position.x, r.end.y - 26 - sub_size), r.size.x, small, Color.WHITE)
			_text(font, h.sub, Vector2(r.position.x, r.end.y - 16), r.size.x, int(sub_size * 0.85), Color.WHITE)
		elif _degree_root >= 0:
			_text(font, _degree_label(m), Vector2(r.position.x, r.end.y - 26 - sub_size), r.size.x, int(label_size * 0.82), Color(0.7, 0.72, 0.78))
		if _lit.has(m):
			draw_rect(r.grow(-3), AppTheme.ACCENT, false, 6)


func _text(font: Font, text: String, baseline: Vector2, width: float, font_size: int, color: Color) -> void:
	if text == "":
		return
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
