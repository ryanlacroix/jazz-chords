class_name Theory
extends RefCounted
## Music-theory data and helpers. Everything here is static and UI-free.
##
## Chords and scales are defined by degree labels ("1", "b3", "#11", "bb7").
## A label carries both the pitch (semitones above the root) and the letter
## (scale step), which is what lets us spell notes correctly: Bb7 -> Bb D F Ab,
## Cdim7 -> C Eb Gb Bbb.

const LETTERS := ["C", "D", "E", "F", "G", "A", "B"]
const LETTER_PCS := [0, 2, 4, 5, 7, 9, 11]

## The 12 roots offered in the UI, with conventional jazz spellings.
const ROOTS := ["C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
## The other name for each black-key root. best_root_name() switches to it only
## to avoid double flats/sharps (C#m7b5 rather than Dbm7b5 = Db Fb Abb Cb).
const ALT_ROOTS := {1: "C#", 3: "D#", 6: "Gb", 8: "G#", 10: "A#"}

## Semitones above the root for each natural degree number.
const DEGREE_SEMITONES := {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11, 8: 12, 9: 14, 11: 17, 13: 21}

## quality -> {name, group, degrees}. Order of insertion is display order.
const CHORDS := {
	"maj": {"name": "Major triad", "group": "Triads", "degrees": ["1", "3", "5"]},
	"m": {"name": "Minor triad", "group": "Triads", "degrees": ["1", "b3", "5"]},
	"aug": {"name": "Augmented triad", "group": "Triads", "degrees": ["1", "3", "#5"]},
	"dim": {"name": "Diminished triad", "group": "Triads", "degrees": ["1", "b3", "b5"]},
	"maj7": {"name": "Major 7th", "group": "Major", "degrees": ["1", "3", "5", "7"]},
	"maj9": {"name": "Major 9th", "group": "Major", "degrees": ["1", "3", "5", "7", "9"]},
	"6": {"name": "Major 6th", "group": "Major", "degrees": ["1", "3", "5", "6"]},
	"6/9": {"name": "Six-nine", "group": "Major", "degrees": ["1", "3", "5", "6", "9"]},
	"maj7#11": {"name": "Lydian major 7th", "group": "Major", "degrees": ["1", "3", "5", "7", "9", "#11"]},
	"m7": {"name": "Minor 7th", "group": "Minor", "degrees": ["1", "b3", "5", "b7"]},
	"m9": {"name": "Minor 9th", "group": "Minor", "degrees": ["1", "b3", "5", "b7", "9"]},
	"m6": {"name": "Minor 6th", "group": "Minor", "degrees": ["1", "b3", "5", "6"]},
	"mMaj7": {"name": "Minor-major 7th", "group": "Minor", "degrees": ["1", "b3", "5", "7"]},
	"7": {"name": "Dominant 7th", "group": "Dominant", "degrees": ["1", "3", "5", "b7"]},
	"9": {"name": "Dominant 9th", "group": "Dominant", "degrees": ["1", "3", "5", "b7", "9"]},
	"13": {"name": "Dominant 13th", "group": "Dominant", "degrees": ["1", "3", "5", "b7", "9", "13"]},
	"7sus4": {"name": "7 sus 4", "group": "Dominant", "degrees": ["1", "4", "5", "b7"]},
	"7b9": {"name": "7 flat 9", "group": "Altered dominant", "degrees": ["1", "3", "5", "b7", "b9"]},
	"7#9": {"name": "7 sharp 9", "group": "Altered dominant", "degrees": ["1", "3", "5", "b7", "#9"]},
	"7#11": {"name": "7 sharp 11", "group": "Altered dominant", "degrees": ["1", "3", "5", "b7", "9", "#11"]},
	"7#5": {"name": "7 sharp 5", "group": "Altered dominant", "degrees": ["1", "3", "#5", "b7"]},
	"7alt": {"name": "Altered dominant", "group": "Altered dominant", "degrees": ["1", "3", "b7", "b9", "#9", "b13"]},
	"m7b5": {"name": "Half-diminished", "group": "Diminished", "degrees": ["1", "b3", "b5", "b7"]},
	"dim7": {"name": "Diminished 7th", "group": "Diminished", "degrees": ["1", "b3", "b5", "bb7"]},
	"sus4": {"name": "Sus 4", "group": "Suspended", "degrees": ["1", "4", "5"]},
	"sus2": {"name": "Sus 2", "group": "Suspended", "degrees": ["1", "2", "5"]},
}

## What each chord symbol's suffix means, shown when the name is tapped in
## Practice. Explains the notation in degrees, never in note names.
const CHORD_EXPLANATIONS := {
	"maj": "\"maj\" on its own means a plain major triad: root, major 3rd (3) and perfect 5th (5). Charts often write just the letter, e.g. \"C\".",
	"m": "\"m\" means minor: the 3rd is lowered a half step (b3). Root, b3, 5. Also written \"min\" or \"-\".",
	"aug": "\"aug\" (or \"+\") means augmented: a major triad with the 5th raised a half step (#5). Root, 3, #5.",
	"dim": "\"dim\" (or \"°\") means diminished: a minor 3rd and a flat 5th. Root, b3, b5.",
	"maj7": "\"maj7\" is a major triad plus the major 7th (7), a half step below the root. The \"maj\" applies to the 7th; the 3rd is major too. Also written \"Δ7\" or \"M7\".",
	"maj9": "\"maj9\" is a maj7 chord with the 9th added. A 9th is the 2nd an octave up, so it's the \"2\" key. Numbers above 7 imply the 7th as well.",
	"6": "A plain \"6\" adds the 6th to a major triad: root, 3, 5, 6. There's no 7th; the 6 takes its place.",
	"6/9": "\"6/9\" (six-nine) is a major triad with both the 6th and the 9th added. The slash here does NOT mean a bass note; it just means \"6 and 9\". The 9th is the \"2\" key.",
	"maj7#11": "A maj7 chord (with its 9th) plus a raised 11th. \"#11\" is the 4th raised a half step, an octave up, so it's on the \"b5\" key. This is the Lydian sound.",
	"m7": "\"m\" makes the 3rd minor (b3), and a plain \"7\" always means the flat 7th (b7). Root, b3, 5, b7. Also written \"-7\" or \"min7\".",
	"m9": "An m7 chord with the 9th added (the \"2\" key). Root, b3, 5, b7, 9.",
	"m6": "A minor triad with the major 6th added: root, b3, 5, 6. The \"m\" only affects the 3rd, so the 6th stays natural.",
	"mMaj7": "\"m\" makes the 3rd minor, and \"Maj7\" makes the 7th major. Root, b3, 5, 7. Also written \"m(maj7)\" or \"-Δ7\".",
	"7": "A plain \"7\" is the dominant 7th: a major triad plus the flat 7th (b7). Root, 3, 5, b7. A 7th is always flat unless the symbol says \"maj\".",
	"9": "A plain \"9\" is a dominant chord: it implies the b7, then adds the 9th (the \"2\" key). Root, 3, 5, b7, 9.",
	"13": "A plain \"13\" is a dominant chord with the b7, the 9th and the 13th. The 13th is the 6th an octave up (the \"6\" key). The 11th is normally left out because it clashes with the 3rd.",
	"7sus4": "\"sus4\" means suspended: the 3rd is replaced by the 4th. With the \"7\" that's root, 4, 5, b7, with no 3rd at all.",
	"7b9": "A dominant 7th (root, 3, 5, b7) plus the flat 9th. \"b9\" is the 2nd lowered a half step, an octave up, so it's on the \"b2\" key.",
	"7#9": "A dominant 7th plus the sharp 9th. \"#9\" is on the same key as a minor 3rd (\"b3\"), so the chord has both a major and a minor 3rd sound. This is the \"Hendrix chord\".",
	"7#11": "A dominant 9th chord plus the sharp 11th: the 4th raised a half step, on the \"b5\" key. Root, 3, 5, b7, 9, #11. This is the Lydian dominant sound.",
	"7#5": "A dominant 7th with the 5th raised a half step (#5, on the \"b6\" key). Also written \"7+\" or \"aug7\".",
	"7alt": "\"alt\" means altered: a dominant 7th whose 5th and 9th are raised or lowered (b9, #9, #11/b5, b13). Players choose which ones to use. In this app it's root, 3, b7, b9, #9, b13.",
	"m7b5": "Read it in parts: \"m\" is a minor 3rd (b3), \"7\" is the flat 7th (b7), and \"b5\" lowers the 5th a half step. Root, b3, b5, b7. Also called half-diminished (ø).",
	"dim7": "Fully diminished: every note is a minor 3rd above the one below. Root, b3, b5, bb7. The \"bb7\" (double-flat 7th) is on the same key as the \"6\". Also written \"°7\".",
	"sus4": "\"sus\" means suspended: the 3rd is replaced by the 4th, so the chord is neither major nor minor. Root, 4, 5. Plain \"sus\" usually means sus4.",
	"sus2": "\"sus2\": the 3rd is replaced by the 2nd. Root, 2, 5.",
}

## scale id -> {name, group, degrees, fits}. "fits" lists CHORDS keys.
const SCALES := {
	"ionian": {"name": "Major (Ionian)", "group": "Major modes", "degrees": ["1", "2", "3", "4", "5", "6", "7"], "fits": ["maj7", "maj9", "6", "6/9", "maj"]},
	"dorian": {"name": "Dorian", "group": "Major modes", "degrees": ["1", "2", "b3", "4", "5", "6", "b7"], "fits": ["m7", "m9", "m6", "m"]},
	"phrygian": {"name": "Phrygian", "group": "Major modes", "degrees": ["1", "b2", "b3", "4", "5", "b6", "b7"], "fits": ["m7", "m"]},
	"lydian": {"name": "Lydian", "group": "Major modes", "degrees": ["1", "2", "3", "#4", "5", "6", "7"], "fits": ["maj7#11", "maj7", "maj9", "6"]},
	"mixolydian": {"name": "Mixolydian", "group": "Major modes", "degrees": ["1", "2", "3", "4", "5", "6", "b7"], "fits": ["7", "9", "13", "7sus4"]},
	"aeolian": {"name": "Natural minor (Aeolian)", "group": "Major modes", "degrees": ["1", "2", "b3", "4", "5", "b6", "b7"], "fits": ["m7", "m9", "m"]},
	"locrian": {"name": "Locrian", "group": "Major modes", "degrees": ["1", "b2", "b3", "4", "b5", "b6", "b7"], "fits": ["m7b5", "dim"]},
	"melodic_minor": {"name": "Melodic minor", "group": "Melodic minor", "degrees": ["1", "2", "b3", "4", "5", "6", "7"], "fits": ["mMaj7", "m6", "m"]},
	"lydian_dominant": {"name": "Lydian dominant", "group": "Melodic minor", "degrees": ["1", "2", "3", "#4", "5", "6", "b7"], "fits": ["7#11", "7", "9", "13"]},
	"locrian_2": {"name": "Locrian #2", "group": "Melodic minor", "degrees": ["1", "2", "b3", "4", "b5", "b6", "b7"], "fits": ["m7b5"]},
	"altered": {"name": "Altered (Super Locrian)", "group": "Melodic minor", "degrees": ["1", "b9", "#9", "3", "#11", "b13", "b7"], "fits": ["7alt", "7#9", "7b9", "7#5"]},
	"harmonic_minor": {"name": "Harmonic minor", "group": "Harmonic minor", "degrees": ["1", "2", "b3", "4", "5", "b6", "7"], "fits": ["mMaj7", "m"]},
	"phrygian_dominant": {"name": "Phrygian dominant", "group": "Harmonic minor", "degrees": ["1", "b2", "3", "4", "5", "b6", "b7"], "fits": ["7b9"]},
	"whole_tone": {"name": "Whole tone", "group": "Symmetric", "degrees": ["1", "2", "3", "#4", "#5", "b7"], "fits": ["7#5", "aug"]},
	"half_whole": {"name": "Diminished (half-whole)", "group": "Symmetric", "degrees": ["1", "b9", "#9", "3", "#11", "5", "13", "b7"], "fits": ["7b9", "7#9", "13"]},
	"whole_half": {"name": "Diminished (whole-half)", "group": "Symmetric", "degrees": ["1", "2", "b3", "4", "b5", "b6", "6", "7"], "fits": ["dim7", "dim"]},
	"bebop_major": {"name": "Bebop major", "group": "Bebop", "degrees": ["1", "2", "3", "4", "5", "#5", "6", "7"], "fits": ["maj7", "6", "maj"]},
	"bebop_dominant": {"name": "Bebop dominant", "group": "Bebop", "degrees": ["1", "2", "3", "4", "5", "6", "b7", "7"], "fits": ["7", "9", "13"]},
	"major_pentatonic": {"name": "Major pentatonic", "group": "Pentatonic & blues", "degrees": ["1", "2", "3", "5", "6"], "fits": ["maj", "6", "6/9", "maj7", "7"]},
	"minor_pentatonic": {"name": "Minor pentatonic", "group": "Pentatonic & blues", "degrees": ["1", "b3", "4", "5", "b7"], "fits": ["m7", "m", "7sus4"]},
	"blues": {"name": "Blues", "group": "Pentatonic & blues", "degrees": ["1", "b3", "4", "b5", "5", "b7"], "fits": ["7", "m7"]},
}

## What each scale is and how to read its formula, shown when the scale name
## is tapped. Formulas are measured against the major scale.
const SCALE_EXPLANATIONS := {
	"ionian": "The major scale, 1 2 3 4 5 6 7, built from steps W W H W W W H. Every formula in this app is measured against it: a plain number (3, 7) is the major-scale note, \"b\" lowers it a half step and \"#\" raises it.",
	"dorian": "A minor scale with a natural 6th: 1 2 b3 4 5 6 b7. It's the 2nd mode of the major scale (D to D on the white keys) and the go-to sound for m7 chords, like the ii in a ii-V-I.",
	"phrygian": "A minor scale with a flat 2nd: 1 b2 b3 4 5 b6 b7. It's the 3rd mode of the major scale (E to E on the white keys). The b2 gives it a dark, Spanish sound.",
	"lydian": "A major scale with a raised 4th: 1 2 3 #4 5 6 7. It's the 4th mode of the major scale (F to F on the white keys). Its #4 is the #11 in maj7#11 chords.",
	"mixolydian": "A major scale with a flat 7th: 1 2 3 4 5 6 b7. It's the 5th mode of the major scale (G to G on the white keys) and the basic sound of a dominant 7 chord.",
	"aeolian": "The natural minor scale: 1 2 b3 4 5 b6 b7. It's the 6th mode of the major scale (A to A on the white keys).",
	"locrian": "1 b2 b3 4 b5 b6 b7, the 7th mode of the major scale (B to B on the white keys). It fits m7b5 chords, though its b2 is tense, so jazz players often use Locrian #2 instead.",
	"melodic_minor": "Jazz melodic minor: a major scale with only the 3rd lowered, 1 2 b3 4 5 6 7, played the same going up and down. Its modes give many jazz sounds: Lydian dominant, Altered and Locrian #2.",
	"lydian_dominant": "1 2 3 #4 5 6 b7: Mixolydian with a raised 4th, or Lydian with a flat 7th. It's the 4th mode of melodic minor and fits 7#11 chords.",
	"locrian_2": "Locrian with a natural 2nd: 1 2 b3 4 b5 b6 b7. It's the 6th mode of melodic minor and a smoother choice than Locrian over m7b5 chords.",
	"altered": "The 7th mode of melodic minor, written as chord tones: 1 b9 #9 3 #11 b13 b7. It contains every alteration of a dominant chord at once. On the keys, b9 is \"b2\", #9 is \"b3\", #11 is \"b5\" and b13 is \"b6\". Also called Super Locrian; it fits 7alt chords.",
	"harmonic_minor": "Natural minor with a raised 7th: 1 2 b3 4 5 b6 7. The step and a half between b6 and 7 gives it its exotic sound. It fits mMaj7 chords.",
	"phrygian_dominant": "The 5th mode of harmonic minor: 1 b2 3 4 5 b6 b7, which is Phrygian with a major 3rd. It's used over 7b9 chords that resolve to a minor chord.",
	"whole_tone": "Only whole steps: 1 2 3 #4 #5 b7, six notes. There are only two different whole-tone scales. It fits 7#5 and augmented chords.",
	"half_whole": "A symmetric 8-note scale that alternates half and whole steps, starting with a half step. Written as chord tones: 1 b9 #9 3 #11 5 13 b7. It fits 7b9 chords; also called the dominant diminished scale.",
	"whole_half": "A symmetric 8-note scale that alternates whole and half steps: 1 2 b3 4 b5 b6 6 7. It fits dim7 chords. Both b6 and 6 are in it, so one letter appears twice.",
	"bebop_major": "The major scale plus a #5 passing note: 1 2 3 4 5 #5 6 7. With 8 notes, chord tones land on the beats when you play eighth notes from the root.",
	"bebop_dominant": "Mixolydian plus the major 7th as a passing note: 1 2 3 4 5 6 b7 7. With 8 notes, chord tones land on the beats in eighth-note lines.",
	"major_pentatonic": "Five notes: 1 2 3 5 6. It's the major scale without the 4th and 7th, the two notes that make half steps, so it never clashes.",
	"minor_pentatonic": "Five notes: 1 b3 4 5 b7. It's natural minor without the 2nd and b6.",
	"blues": "Minor pentatonic plus the b5 \"blue note\": 1 b3 4 b5 5 b7.",
}

## Intervals for ear training, indexed by semitone count.
const INTERVALS := [
	{"short": "m2", "name": "Minor 2nd", "semitones": 1},
	{"short": "M2", "name": "Major 2nd", "semitones": 2},
	{"short": "m3", "name": "Minor 3rd", "semitones": 3},
	{"short": "M3", "name": "Major 3rd", "semitones": 4},
	{"short": "P4", "name": "Perfect 4th", "semitones": 5},
	{"short": "TT", "name": "Tritone", "semitones": 6},
	{"short": "P5", "name": "Perfect 5th", "semitones": 7},
	{"short": "m6", "name": "Minor 6th", "semitones": 8},
	{"short": "M6", "name": "Major 6th", "semitones": 9},
	{"short": "m7", "name": "Minor 7th", "semitones": 10},
	{"short": "M7", "name": "Major 7th", "semitones": 11},
	{"short": "P8", "name": "Octave", "semitones": 12},
]

## Degree names for each semitone above a root, used to label keys in practice.
const OFFSET_LABELS := ["R", "b2", "2", "b3", "3", "4", "b5", "5", "b6", "6", "b7", "7"]

## The seven 7th chords of a major key: [semitones above the tonic, quality].
const DIATONIC_7THS := [[0, "maj7"], [2, "m7"], [4, "m7"], [5, "maj7"], [7, "7"], [9, "m7"], [11, "m7b5"]]

enum Voicing { ROOT, SHELL, ROOTLESS_A, ROOTLESS_B }

## Bottom of the "left hand" register used for chord voicings (C3).
const VOICING_BASE := 48


# --- Degree labels ----------------------------------------------------------

## Splits "b13" into {acc: -1, num: 13}.
static func parse_degree(label: String) -> Dictionary:
	var acc := 0
	var i := 0
	while i < label.length() and (label[i] == "b" or label[i] == "#"):
		acc += -1 if label[i] == "b" else 1
		i += 1
	return {"acc": acc, "num": int(label.substr(i))}


static func degree_semitones(label: String) -> int:
	var d := parse_degree(label)
	return DEGREE_SEMITONES[d.num] + d.acc


## Letter steps above the root letter: 3 -> 2, 9 -> 1, 13 -> 5.
static func degree_letter_offset(label: String) -> int:
	return (parse_degree(label).num - 1) % 7


## Display label for a degree; the root is shown as "R".
static func degree_display(label: String) -> String:
	return "R" if label == "1" else label


# --- Note names -------------------------------------------------------------

static func accidental(diff: int) -> String:
	match diff:
		-2: return "bb"
		-1: return "b"
		1: return "#"
		2: return "x"
	return ""


## Spells a pitch class against a given letter, e.g. (11, "C") -> "Cb".
static func spell_with_letter(pc: int, letter_index: int) -> String:
	var diff := wrapi(pc - LETTER_PCS[letter_index], -6, 6)
	return LETTERS[letter_index] + accidental(diff)


## Spells one degree above a named root: ("Bb", "b7") -> "Ab".
static func spell_degree(root_name: String, label: String) -> String:
	var letter_index := LETTERS.find(root_name[0])
	var root_pc: int = (LETTER_PCS[letter_index] + parse_degree(root_name.substr(1) + "1").acc + 12) % 12
	var pc: int = (root_pc + degree_semitones(label)) % 12
	var letter := (letter_index + degree_letter_offset(label)) % 7
	return spell_with_letter(pc, letter)


## Spells degrees above a root. The root's name comes from best_root_name()
## for these degrees unless one is given, e.g. to spell a voicing with the same
## root name as its full chord.
static func spell_degrees(root_index: int, degrees: Array, root_name := "") -> PackedStringArray:
	if root_name == "":
		root_name = best_root_name(root_index, degrees)
	var out := PackedStringArray()
	for d in degrees:
		out.append(spell_degree(root_name, d))
	return out


## Number of double flats/sharps in a spelling (Abb, Fx...).
static func double_accidentals(names: PackedStringArray) -> int:
	var count := 0
	for n in names:
		if n.ends_with("bb") or n.ends_with("x"):
			count += 1
	return count


## The usual name from ROOTS, unless it would need double flats or sharps and
## ALT_ROOTS needs fewer: Dbm7b5 -> C#m7b5, but Dbm7 and Bbm7b5 stay as they are.
static func best_root_name(root_index: int, degrees: Array) -> String:
	var name: String = ROOTS[root_index]
	if not ALT_ROOTS.has(root_index):
		return name
	var doubles := double_accidentals(spell_degrees(root_index, degrees, name))
	if doubles == 0:
		return name
	var alt: String = ALT_ROOTS[root_index]
	return alt if double_accidentals(spell_degrees(root_index, degrees, alt)) < doubles else name


## Plain name for a MIDI note, using sharps or flats: 61 -> "Db4".
static func midi_name(midi: int, prefer_flats := true) -> String:
	const FLATS := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
	const SHARPS := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var names: Array = FLATS if prefer_flats else SHARPS
	return "%s%d" % [names[midi % 12], floori(midi / 12.0) - 1]


static func is_black(midi: int) -> bool:
	return [1, 3, 6, 8, 10].has(midi % 12)


# --- Chords -----------------------------------------------------------------

static func chord_symbol(root_index: int, quality: String) -> String:
	return chord_root_name(root_index, quality) + quality


## Splits a written symbol into root and quality: "Bbm7" ->
## {root = 10, name = "Bb", quality = "m7"}. No quality starts with b or #.
static func parse_chord_symbol(symbol: String) -> Dictionary:
	var name := symbol.substr(0, 2 if symbol.length() > 1 and symbol[1] in ["b", "#"] else 1)
	var acc: int = parse_degree(name.substr(1) + "1").acc
	var root_pc: int = (LETTER_PCS[LETTERS.find(name[0])] + acc + 12) % 12
	return {"root": root_pc, "name": name, "quality": symbol.substr(name.length())}


static func chord_root_name(root_index: int, quality: String) -> String:
	return best_root_name(root_index, chord_degrees(quality))


static func scale_root_name(root_index: int, scale: String) -> String:
	return best_root_name(root_index, scale_degrees(scale))


static func scale_explanation(scale: String) -> String:
	return SCALE_EXPLANATIONS.get(scale, "")


static func chord_explanation(quality: String) -> String:
	return CHORD_EXPLANATIONS.get(quality, "")


static func chord_degrees(quality: String) -> Array:
	return CHORDS[quality].degrees


## The chord's distinct pitch classes, sorted: Dm7 -> [0, 2, 5, 9] (C D F A).
static func chord_pcs(root_index: int, quality: String) -> Array[int]:
	var out: Array[int] = []
	for d in chord_degrees(quality):
		var pc := (root_index + degree_semitones(d)) % 12
		if not out.has(pc):
			out.append(pc)
	out.sort()
	return out


## Names the chord made by a set of MIDI notes (any octave or inversion):
## [root_index, quality], or [] if no chord in CHORDS has exactly those
## pitch classes. Ambiguous sets (Am7 = C6) prefer the bass note as root.
static func identify_chord(notes: Array) -> Array:
	var pcs: Array[int] = []
	for m in notes:
		if not pcs.has(m % 12):
			pcs.append(m % 12)
	if pcs.size() < 3:
		return []
	pcs.sort()
	var bass: int = notes.min() % 12
	for r in [bass] + range(12):
		for q in CHORDS:
			if chord_pcs(r, q) == pcs:
				return [r, q]
	return []


## The chord degree a note plays in the chord ("b7", "9" ...), or "".
static func degree_for(root_index: int, quality: String, midi: int) -> String:
	for d in chord_degrees(quality):
		if degree_semitones(d) % 12 == (midi - root_index) % 12:
			return d
	return ""


## Close-position chord tones, root at C3..B3.
static func chord_notes(root_index: int, quality: String) -> Array[int]:
	var base := VOICING_BASE + root_index
	var out: Array[int] = []
	for d in chord_degrees(quality):
		out.append(base + degree_semitones(d))
	return out


## The chord's 3rd-like degree (3, b3, or the 4/2 of a sus chord), or "".
static func _find_degree(degrees: Array, nums: Array) -> String:
	for n in nums:
		for d in degrees:
			if parse_degree(d).num == n:
				return d
	return ""


## Which voicings make sense for a quality. Shells need a 3rd and a 7th/6th;
## rootless voicings additionally need a 7th (not a 6th) and no dim7 symmetry.
static func voicings_for(quality: String) -> Array[int]:
	var degrees := chord_degrees(quality)
	var out: Array[int] = [Voicing.ROOT]
	var third := _find_degree(degrees, [3, 4])
	var seventh := _find_degree(degrees, [7, 6])
	if third != "" and seventh != "":
		out.append(Voicing.SHELL)
		if parse_degree(seventh).num == 7 and quality != "dim7":
			out.append(Voicing.ROOTLESS_A)
			out.append(Voicing.ROOTLESS_B)
	return out


## Returns {notes: Array[int], degrees: Array} for a voicing, low to high.
static func voice_chord(root_index: int, quality: String, voicing: int) -> Dictionary:
	var degrees := chord_degrees(quality)
	if voicing == Voicing.ROOT or not voicings_for(quality).has(voicing):
		return {"notes": chord_notes(root_index, quality), "degrees": degrees.duplicate()}

	var third := _find_degree(degrees, [3, 4])
	var seventh := _find_degree(degrees, [7, 6])
	if voicing == Voicing.SHELL:
		var root := VOICING_BASE - 12 + root_index
		return {
			"notes": [root, root + 12 + degree_semitones(third) % 12, root + 12 + degree_semitones(seventh) % 12],
			"degrees": ["1", third, seventh],
		}

	# Rootless (Bill Evans) voicings: 3-5-7-9 (A) or 7-9-3-5 (B). They use the
	# chord's own 9th and 5th/13th when it has altered ones, otherwise the
	# natural 9 and the 5th (13th on dominants, the standard colour).
	var ninth := _find_degree(degrees, [9])
	if ninth == "":
		ninth = "9"
	var fifth := _find_degree(degrees, [13])
	if fifth == "":
		fifth = _find_degree(degrees, [5])
	if fifth == "":
		fifth = "5"
	if fifth == "5" and seventh == "b7" and third == "3":
		fifth = "13"
	var order: Array = [third, fifth, seventh, ninth]
	if voicing == Voicing.ROOTLESS_B:
		order = [seventh, ninth, third, fifth]
	# Start the bottom note in the E3..Eb4 window, then stack upward.
	var notes: Array[int] = []
	var prev := 51
	for d in order:
		var pc := (root_index + degree_semitones(d)) % 12
		var n := prev + 1 + wrapi(pc - (prev + 1), 0, 12)
		notes.append(n)
		prev = n
	return {"notes": notes, "degrees": order}


static func voicing_name(voicing: int) -> String:
	return ["Root", "Shell", "Rootless A", "Rootless B"][voicing]


# --- Scales -----------------------------------------------------------------

static func scale_degrees(scale: String) -> Array:
	return SCALES[scale].degrees


## Ascending scale from the root at C4..B4 region, including the top octave.
static func scale_notes(root_index: int, scale: String, octaves := 1, base := 60) -> Array[int]:
	var semis: Array[int] = []
	for d in scale_degrees(scale):
		semis.append(degree_semitones(d) % 12)
	semis.sort()
	var start := base + root_index
	if start > base + 6:
		start -= 12
	var out: Array[int] = []
	for o in octaves:
		for s in semis:
			out.append(start + o * 12 + s)
	out.append(start + octaves * 12)
	return out


## Degree labels sorted by pitch, matching scale_notes() order for one octave.
static func scale_degrees_by_pitch(scale: String) -> Array:
	var degrees := scale_degrees(scale).duplicate()
	degrees.sort_custom(func(a, b): return degree_semitones(a) % 12 < degree_semitones(b) % 12)
	return degrees


static func chords_for_scale(scale: String) -> Array:
	return SCALES[scale].fits


static func scales_for_chord(quality: String) -> Array:
	var out := []
	for s in SCALES:
		if SCALES[s].fits.has(quality):
			out.append(s)
	return out


## [root, quality] for each diatonic 7th chord of the major key on `key`.
static func diatonic_chords(key: int) -> Array:
	return DIATONIC_7THS.map(func(c): return [(key + c[0]) % 12, c[1]])


## Unique group names in display order.
static func groups(table: Dictionary) -> Array:
	var out := []
	for k in table:
		if not out.has(table[k].group):
			out.append(table[k].group)
	return out
