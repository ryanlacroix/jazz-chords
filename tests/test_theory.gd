extends SceneTree
## Run: godot --headless -s tests/test_theory.gd

var failures := 0
var checks := 0


func _init() -> void:
	_test_spelling()
	_test_chord_notes()
	_test_voicings()
	_test_scales()
	_test_tables()
	_test_chord_pcs()
	_test_root_names()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func check_eq(got, want, what: String) -> void:
	check(got == want, "%s: got %s, want %s" % [what, got, want])


func root(name: String) -> int:
	return Theory.ROOTS.find(name)


func spelled(root_name: String, quality: String) -> String:
	return " ".join(Theory.spell_degrees(root(root_name), Theory.chord_degrees(quality)))


func spelled_scale(root_name: String, scale: String) -> String:
	return " ".join(Theory.spell_degrees(root(root_name), Theory.scale_degrees_by_pitch(scale)))


func _test_spelling() -> void:
	check_eq(spelled("C", "maj7"), "C E G B", "Cmaj7")
	check_eq(spelled("Bb", "7"), "Bb D F Ab", "Bb7")
	check_eq(spelled("F#", "m7b5"), "F# A C E", "F#m7b5")
	check_eq(spelled("C", "dim7"), "C Eb Gb Bbb", "Cdim7")
	check_eq(spelled("Eb", "7alt"), "Eb G Db Fb F# Cb", "Eb7alt")
	check_eq(spelled("Db", "maj7#11"), "Db F Ab C Eb G", "Dbmaj7#11")
	check_eq(spelled("B", "7#9"), "B D# F# A C##".replace("C##", "Cx"), "B7#9")
	check_eq(spelled("G", "13"), "G B D F A E", "G13")
	check_eq(spelled_scale("D", "dorian"), "D E F G A B C", "D dorian")
	check_eq(spelled_scale("Eb", "altered"), "Eb Fb F# G A Cb Db", "Eb altered")
	check_eq(spelled_scale("F", "lydian"), "F G A B C D E", "F lydian")
	check_eq(spelled_scale("Ab", "ionian"), "Ab Bb C Db Eb F G", "Ab major")
	check_eq(spelled_scale("C", "blues"), "C Eb F Gb G Bb", "C blues")
	check_eq(spelled_scale("G", "half_whole"), "G Ab A# B C# D E F", "G half-whole")
	check_eq(Theory.midi_name(60), "C4", "midi 60")
	check_eq(Theory.midi_name(61), "Db4", "midi 61")
	check_eq(Theory.midi_name(36), "C2", "midi 36")


func _test_chord_notes() -> void:
	check_eq(Theory.chord_notes(root("C"), "maj7"), [48, 52, 55, 59], "Cmaj7 notes")
	check_eq(Theory.chord_notes(root("A"), "m7"), [57, 60, 64, 67], "Am7 notes")
	for q in Theory.CHORDS:
		for r in 12:
			var notes := Theory.chord_notes(r, q)
			check(notes.max() <= 84 and notes.min() >= 36, "%s%s in keyboard range" % [Theory.ROOTS[r], q])


func _test_voicings() -> void:
	var v := Theory.voice_chord(root("D"), "m7", Theory.Voicing.ROOTLESS_A)
	check_eq(v.degrees, ["b3", "5", "b7", "9"], "Dm7 rootless A degrees")
	check_eq(v.notes, [53, 57, 60, 64], "Dm7 rootless A notes (F A C E)")
	v = Theory.voice_chord(root("G"), "7", Theory.Voicing.ROOTLESS_B)
	check_eq(v.degrees, ["b7", "9", "3", "13"], "G7 rootless B degrees")
	check_eq(v.notes, [53, 57, 59, 64], "G7 rootless B notes (F A B E)")
	v = Theory.voice_chord(root("C"), "7", Theory.Voicing.SHELL)
	check_eq(v.notes, [36, 52, 58], "C7 shell")
	check(not Theory.voicings_for("maj").has(Theory.Voicing.SHELL), "triad has no shell")
	check(not Theory.voicings_for("6").has(Theory.Voicing.ROOTLESS_A), "6 chord has no rootless")
	check(Theory.voicings_for("6").has(Theory.Voicing.SHELL), "6 chord has shell")
	for q in Theory.CHORDS:
		for voicing in Theory.voicings_for(q):
			for r in 12:
				var notes: Array = Theory.voice_chord(r, q, voicing).notes
				check(notes.max() <= 84 and notes.min() >= 36, "%s%s voicing %d in range" % [Theory.ROOTS[r], q, voicing])
				var sorted := notes.duplicate()
				sorted.sort()
				check(sorted == notes, "%s%s voicing %d ascending" % [Theory.ROOTS[r], q, voicing])


func _test_scales() -> void:
	check_eq(Theory.scale_notes(root("C"), "ionian"), [60, 62, 64, 65, 67, 69, 71, 72], "C major notes")
	check_eq(Theory.scale_notes(root("A"), "aeolian"), [57, 59, 60, 62, 64, 65, 67, 69], "A minor notes (starts below C4)")
	for s in Theory.SCALES:
		for r in 12:
			var notes := Theory.scale_notes(r, s)
			check(notes.max() - notes.min() == 12, "%s %s spans an octave" % [Theory.ROOTS[r], s])
	check(Theory.scales_for_chord("7").has("mixolydian"), "mixolydian fits 7")
	check(Theory.scales_for_chord("m7b5").has("locrian_2"), "locrian #2 fits m7b5")


func _test_tables() -> void:
	for s in Theory.SCALES:
		for q in Theory.chords_for_scale(s):
			check(Theory.CHORDS.has(q), "scale %s fits unknown chord %s" % [s, q])
		# Every scale degree must be a distinct pitch.
		var pcs := {}
		for d in Theory.scale_degrees(s):
			pcs[Theory.degree_semitones(d) % 12] = true
		check_eq(pcs.size(), Theory.scale_degrees(s).size(), "%s distinct pitches" % s)
	for i in Theory.INTERVALS.size():
		check_eq(Theory.INTERVALS[i].semitones, i + 1, "interval table order")


func _test_chord_pcs() -> void:
	check_eq(Theory.chord_pcs(root("D"), "m7"), [0, 2, 5, 9], "Dm7 pitch classes")
	check(Theory.chord_pcs(root("C"), "dim7").has(9), "Cdim7 bb7 is on the A key")
	check_eq(Theory.chord_pcs(root("C"), "13"), [0, 2, 4, 7, 9, 10], "C13 pitch classes")
	for q in Theory.CHORDS:
		check_eq(Theory.chord_pcs(0, q).size(), Theory.chord_degrees(q).size(), "%s has distinct pitch classes" % q)
	check_eq(Theory.OFFSET_LABELS.size(), 12, "offset labels")
	for q in Theory.CHORDS:
		check(Theory.chord_explanation(q) != "", "%s has a notation explanation" % q)
	for q in Theory.CHORD_EXPLANATIONS:
		check(Theory.CHORDS.has(q), "explanation for unknown chord %s" % q)
	for sc in Theory.SCALES:
		var text := Theory.scale_explanation(sc)
		check(text != "", "%s has an explanation" % sc)
		# The formula quoted in the text must match the scale's actual degrees.
		check(text.contains(" ".join(Theory.scale_degrees(sc))), "%s explanation quotes its formula" % sc)
	for sc in Theory.SCALE_EXPLANATIONS:
		check(Theory.SCALES.has(sc), "explanation for unknown scale %s" % sc)


func _test_root_names() -> void:
	check_eq(Theory.chord_symbol(root("Db"), "m7b5"), "C#m7b5", "Dbm7b5 becomes C#m7b5")
	check_eq(spelled("Db", "m7b5"), "C# E G B", "C#m7b5 spelling")
	check_eq(Theory.chord_symbol(root("Db"), "m7"), "Dbm7", "Dbm7 keeps its name (no double flats)")
	check_eq(Theory.chord_symbol(root("Bb"), "m7b5"), "Bbm7b5", "Bbm7b5 keeps its name")
	check_eq(Theory.chord_symbol(root("Ab"), "dim7"), "G#dim7", "Abdim7 needs Ebb and Gbb, so G#dim7")
	check_eq(Theory.chord_symbol(root("F#"), "maj7"), "F#maj7", "F#maj7 keeps its name")
	check_eq(Theory.chord_symbol(root("Db"), "7"), "Db7", "Db7 keeps its name")
	check_eq(Theory.chord_symbol(root("Ab"), "m"), "Abm", "Abm keeps its name")
	check_eq(Theory.chord_symbol(root("Ab"), "maj7"), "Abmaj7", "Abmaj7")
	check_eq(Theory.chord_symbol(root("F#"), "m7"), "F#m7", "F#m7")
	check_eq(Theory.chord_symbol(root("Bb"), "m7"), "Bbm7", "Bbm7")
	check_eq(Theory.chord_symbol(root("Eb"), "m7"), "Ebm7", "Ebm7")
	check_eq(Theory.scale_root_name(root("Db"), "locrian"), "C#", "C# locrian")
	check_eq(spelled_scale("Db", "locrian"), "C# D E F# G A B", "C# locrian spelling")
	check_eq(Theory.scale_root_name(root("Db"), "ionian"), "Db", "Db major")
	# Voicings are spelled with the full chord's root name.
	var name := Theory.chord_root_name(root("Db"), "m7b5")
	var v := Theory.voice_chord(root("Db"), "m7b5", Theory.Voicing.SHELL)
	check_eq(" ".join(Theory.spell_degrees(root("Db"), v.degrees, name)), "C# E B", "C#m7b5 shell spelling")
	# Whatever name is chosen, the spelled notes must be the chord's pitch classes.
	for q in Theory.CHORDS:
		for r in 12:
			var names := Theory.spell_degrees(r, Theory.chord_degrees(q))
			check_eq(names[0], Theory.chord_root_name(r, q), "%s%s first note is the root name" % [r, q])
			var pcs: Array[int] = []
			for n in names:
				var pc: int = (Theory.LETTER_PCS[Theory.LETTERS.find(n[0])] + Theory.parse_degree(n.substr(1).replace("x", "##") + "1").acc + 12) % 12
				if not pcs.has(pc):
					pcs.append(pc)
			pcs.sort()
			check_eq(pcs, Theory.chord_pcs(r, q), "%s%s spelled pitches" % [r, q])
