extends Node
## MIDI controller input. Notes from any connected device light the on-screen
## keyboards (via note_on/note_off) and sound through Synth.
##
## The default mapping suits an Akai MPK mini: its 25 keys send channel 1
## notes from C3 and pass straight through, its drum pads (channel 10) emit
## pad_pressed instead of sounding, and its knobs (CC messages) are ignored.
## Notes outside the on-screen range are folded by octaves into it.
##
## Godot's Web MIDI driver lists the inputs only once, when it opens, so on the
## web a separate MIDIAccess watches for plugging and unplugging and reopens.

signal note_on(midi: int, velocity: int)
signal note_off(midi: int)
signal notes_changed
signal devices_changed(names: PackedStringArray)
## A drum pad was struck; note is its raw note number (see PAD_* below).
signal pad_pressed(note: int)

## Zero-based; channel 10 is where drum pads conventionally sit.
const PAD_CHANNEL := 9
## MPK mini bottom-row pads, left to right, in their default bank A.
const PAD_BOTTOM_1 := 36
const PAD_BOTTOM_2 := 37
const PAD_BOTTOM_3 := 38
const LOW := 36  # PianoKeyboard.LOW
const HIGH := 84  # PianoKeyboard.HIGH

var devices := PackedStringArray()

## midi -> velocity, for notes currently held down.
var _held := {}
## Kept alive so JavaScript can keep calling them.
var _js_on_access: JavaScriptObject
var _js_on_state: JavaScriptObject
var _js_on_port: JavaScriptObject
var _js_access: JavaScriptObject
## Input port id -> "connected"/"disconnected".
var _port_states := {}
var _reopen_timer: Timer


func _ready() -> void:
	# Headless runs (tests, CI export) have no MIDI driver; opening one crashes.
	if DisplayServer.get_name() == "headless":
		return
	OS.open_midi_inputs()

	# The driver fills in device names asynchronously, so poll for them.
	var poll := Timer.new()
	poll.wait_time = 1.0
	poll.autostart = true
	poll.timeout.connect(_poll_devices)
	add_child(poll)

	_reopen_timer = Timer.new()
	_reopen_timer.one_shot = true
	_reopen_timer.wait_time = 0.3  # one plug-in fires several statechange events
	_reopen_timer.timeout.connect(reconnect)
	add_child(_reopen_timer)

	if OS.has_feature("web") and JavaScriptBridge.eval("!!navigator.requestMIDIAccess", true):
		_js_on_access = JavaScriptBridge.create_callback(_on_js_access)
		_js_on_state = JavaScriptBridge.create_callback(_on_js_state)
		_js_on_port = JavaScriptBridge.create_callback(_on_js_port)
		JavaScriptBridge.get_interface("navigator").requestMIDIAccess().then(_js_on_access)


## Reopens every MIDI input, picking up devices plugged in since the last open.
func reconnect() -> void:
	for m in held_notes():
		_release(m)
	if DisplayServer.get_name() == "headless":
		return
	OS.close_midi_inputs()
	OS.open_midi_inputs()


func held_notes() -> Array:
	var out := _held.keys()
	out.sort()
	return out


func is_held(midi: int) -> bool:
	return _held.has(midi)


func _input(event: InputEvent) -> void:
	if not event is InputEventMIDI:
		return
	if event.channel == PAD_CHANNEL:
		if event.message == MIDI_MESSAGE_NOTE_ON and event.velocity > 0:
			pad_pressed.emit(event.pitch)
		return
	var m := _fold(event.pitch)
	if event.message == MIDI_MESSAGE_NOTE_ON and event.velocity > 0:
		if _held.has(m):
			return
		_held[m] = event.velocity
		Synth.play_note(m, linear_to_db(clampf(event.velocity / 127.0, 0.25, 1.0)))
		note_on.emit(m, event.velocity)
		notes_changed.emit()
	elif event.message == MIDI_MESSAGE_NOTE_OFF or event.message == MIDI_MESSAGE_NOTE_ON:
		_release(m)


func _release(m: int) -> void:
	if _held.erase(m):
		note_off.emit(m)
		notes_changed.emit()


func _fold(pitch: int) -> int:
	while pitch < LOW:
		pitch += 12
	while pitch > HIGH:
		pitch -= 12
	return pitch


func _poll_devices() -> void:
	var now := OS.get_connected_midi_inputs()
	if now != devices:
		devices = now
		devices_changed.emit(devices)


func _on_js_access(args: Array) -> void:
	_js_access = args[0]
	_js_access.inputs.forEach(_js_on_port)
	_js_access.onstatechange = _js_on_state


## Records the inputs present at startup (forEach passes value, key, map).
func _on_js_port(args: Array) -> void:
	_port_states[str(args[0].id)] = str(args[0].state)


## Opening a port also fires statechange, so only a real plug or unplug of an
## input (its state changing) triggers a reopen.
func _on_js_state(args: Array) -> void:
	var port: JavaScriptObject = args[0].port
	if str(port.type) != "input":
		return
	var id := str(port.id)
	var state := str(port.state)
	if _port_states.get(id, "") == state:
		return
	_port_states[id] = state
	_reopen_timer.start()
