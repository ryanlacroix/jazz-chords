extends Node
## Debug helper: run the app with `-- --shot --out=<dir>` to save a PNG of
## each screen in a few states, then quit. Needs a real window (not --headless).

var _out := "user://shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var main := get_parent()
	await _shot("0_start")
	main.get_node("StartOverlay").queue_free()
	await _shot("1_chords_cmaj7")
	await _test_multitouch(main._chords._keyboard)
	main._chords.show_chord(2, "m7")
	main._chords.voicing = Theory.Voicing.ROOTLESS_A
	main._chords._refresh()
	await _shot("2_chords_dm7_rootless")
	main._chords.show_chord(3, "7alt")
	await _shot("3_chords_eb7alt")
	main._chords._symbol.pressed.emit()
	main._chords.show_chord(1, "7alt")  # one of the longest explanations
	var card_ok: bool = main._chords._notation.visible and main._chords._notation.topic == "7alt"
	print("chords tab notation follows the selected quality: ", "PASS" if card_ok else "FAIL")
	await _shot("3b_chords_notation")
	main._chords._symbol.pressed.emit()
	main.show_tab(1)
	await _shot("4_scales")
	main._scales._roots.select(3)
	main._scales._on_root(3)
	main._scales._scales.select("altered")
	main._scales._on_scale("altered")
	main._scales._title.pressed.emit()
	main._scales._on_scale("dorian")
	var scale_ok: bool = main._scales._notation.visible and main._scales._notation.topic == "dorian"
	print("scales tab notation follows the selected scale: ", "PASS" if scale_ok else "FAIL")
	main._scales._on_scale("altered")
	await _shot("5_scales_eb_altered")
	await _practice(main)
	await _midi(main)
	main.show_tab(3)
	await _shot("6_ear_start")
	main._ear._new_question()
	var wrong: int = 12 if main._ear._question != 12 else 7
	main._ear._on_answer(wrong)
	await _shot("7_ear_answered")
	main._ear._settings.open()
	await get_tree().create_timer(0.4).timeout
	await _shot("8_ear_settings")
	get_tree().quit()


func _practice(main: Node) -> void:
	var p: ChordPractice = main._practice
	main.show_tab(2)
	# Opening the tab sounds the chord briefly without revealing it on the keys.
	var sounding := func(): return Synth._players.filter(func(v): return v.playing).size()
	var demo_ok: bool = sounding.call() == Theory.chord_notes(p.root, p.quality).size() \
			and p._keyboard._lit.is_empty() and p._selected.is_empty()
	await get_tree().create_timer(Synth.CUT_FADE_SEC + ChordPractice.DEMO_SECONDS + 0.1).timeout
	demo_ok = demo_ok and sounding.call() == 0
	print("practice demo chord plays for a second, keys unlit: ", "PASS" if demo_ok else "FAIL")
	# Key filter: with only Bb enabled, every chord must be rooted on Bb.
	var saved_keys := p.keys.duplicate()
	p._set_keys([10])
	var ok := true
	for i in 20:
		p._new_chord()
		ok = ok and p.root == 10
	print("key filter {Bb}: ", "PASS" if ok else "FAIL")
	p._set_keys(saved_keys)
	p.root = 2
	p.quality = "m7"
	p._present()
	await _shot("6a_practice_question")
	# Two-finger tap on the practice keyboard toggles keys on, then off again.
	await _test_multitouch(p._keyboard)
	print("practice keys selected after taps: ", p._selected.keys())
	await _test_multitouch(p._keyboard)
	print("practice keys selected after second taps: ", p._selected.keys(), " (expect [])")
	p._on_key(50)  # D3 = R
	p._on_key(53)  # F3 = b3
	await _shot("6b_practice_partial")
	p._on_key(57)  # A3 = 5
	p._on_key(60)  # C4 = b7 -> solved
	print("solved after Dm7: ", p.solved > 0 and not p._keyboard.input_enabled)
	await get_tree().create_timer(0.2).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("6c_practice_solved.png"))
	await get_tree().create_timer(1.3).timeout
	print("next chord after success: ", p._symbol.text, " input=", p._keyboard.input_enabled)
	p._on_answer_button()
	await _shot("6d_practice_answer")
	p._settings.open()
	await get_tree().create_timer(0.4).timeout
	await _shot("6e_practice_settings")
	p._settings.close()
	await get_tree().create_timer(0.3).timeout
	p.root = 10
	p.quality = "6/9"
	p._present()
	p._symbol.pressed.emit()
	await _shot("6f_practice_explain")
	p.quality = "m7b5"
	p._present()
	p._symbol.pressed.emit()
	await _shot("6g_practice_explain_m7b5")
	p._new_chord()
	print("explanation hidden on next chord: ", "PASS" if not p._notation.visible else "FAIL")


## MIDI notes as an MPK mini sends them: keys on channel 1, pads on channel 10.
func _midi(main: Node) -> void:
	var p: ChordPractice = main._practice
	main.show_tab(2)
	# Opening the tab sounds the chord briefly without revealing it on the keys.
	var sounding := func(): return Synth._players.filter(func(v): return v.playing).size()
	var demo_ok: bool = sounding.call() == Theory.chord_notes(p.root, p.quality).size() \
			and p._keyboard._lit.is_empty() and p._selected.is_empty()
	await get_tree().create_timer(Synth.CUT_FADE_SEC + ChordPractice.DEMO_SECONDS + 0.1).timeout
	demo_ok = demo_ok and sounding.call() == 0
	print("practice demo chord plays for a second, keys unlit: ", "PASS" if demo_ok else "FAIL")
	p.root = 2
	p.quality = "m7"
	p._present()
	await _send_midi(36, true, 9)  # pad 1
	print("pad ignored: ", "PASS" if p._selected.is_empty() and Midi.held_notes().is_empty() else "FAIL")
	for m in [62, 65, 69]:  # D F A, an octave above the shown chord
		await _send_midi(m, true)
	await _shot("6h_practice_midi_partial")
	await _send_midi(65, false)
	print("released note drops out: ", "PASS" if not p._selected.has(65) else "FAIL")
	await _send_midi(65, true)
	await _send_midi(72, true)  # C -> Dm7
	print("held Dm7 solves: ", "PASS" if not p._keyboard.input_enabled else "FAIL")
	await _shot("6i_practice_midi_solved")
	for m in [62, 65, 69, 72]:
		await _send_midi(m, false)
	await get_tree().create_timer(1.3).timeout
	print("next chord starts empty: ", "PASS" if p._selected.is_empty() and p._keyboard.input_enabled else "FAIL")

	main.show_tab(0)
	for m in [45, 52, 55, 60]:  # A E G C: Am7 voiced as played
		await _send_midi(m, true)
	var c: ChordBuilder = main._chords
	print("chords tab names held chord: ", c._symbol.text, " ", "PASS" if c.root == 9 and c.quality == "m7" else "FAIL")
	await _shot("1b_chords_midi_am7")
	for m in [45, 52, 55, 60]:
		await _send_midi(m, false)
	await _send_midi(100, true)  # above the keyboard: folds down to E5
	print("high note folds into range: ", Midi.held_notes(), " (expect [76])")
	await _send_midi(100, false)
	main.show_tab(2)


func _send_midi(pitch: int, on: bool, channel := 0) -> void:
	var e := InputEventMIDI.new()
	e.channel = channel
	e.message = MIDI_MESSAGE_NOTE_ON if on else MIDI_MESSAGE_NOTE_OFF
	e.pitch = pitch
	e.velocity = 100 if on else 0
	Input.parse_input_event(e)
	await get_tree().process_frame  # parsed events are delivered on the next frame


## Presses two keys with two simultaneous touches, the way a phone would.
func _test_multitouch(kb: PianoKeyboard) -> void:
	var got := []
	kb.key_pressed.connect(func(m): got.append(m))
	var to_screen := get_viewport().get_screen_transform() * kb.get_global_transform_with_canvas()
	var y := kb.size.y * 0.85  # white-key area, below the black keys
	var w := kb.size.x / kb.visible_whites
	for i in 2:
		var t := InputEventScreenTouch.new()
		t.index = i
		t.pressed = true
		t.position = to_screen * Vector2(w * (2 * i + 0.5), y)
		Input.parse_input_event(t)
	await get_tree().process_frame
	for i in 2:
		var t := InputEventScreenTouch.new()
		t.index = i
		t.pressed = false
		t.position = to_screen * Vector2(w * (2 * i + 0.5), y)
		Input.parse_input_event(t)
	await get_tree().process_frame
	print("multitouch keys pressed: ", got, " (expect 2 different notes)")


func _shot(name: String) -> void:
	for i in 20:
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)
