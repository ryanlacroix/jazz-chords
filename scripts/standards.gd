class_name Standards
extends RefCounted
## Chord progressions of well-known jazz standards, for Practice's Jazz order.
## Each is one chorus in its usual key, spelled as commonly charted, with
## repeated chords collapsed. Symbols must use qualities from Theory.CHORDS.

const ROSTER := [
	{"name": "Autumn Leaves", "chords": "Cm7 F7 Bbmaj7 Ebmaj7 Am7b5 D7 Gm7 Am7b5 D7 Gm7 Cm7 F7 Bbmaj7 Ebmaj7 Am7b5 D7 Gm7 C7 Fm7 Bb7 Ebmaj7 Am7b5 D7 Gm7"},
	{"name": "All the Things You Are", "chords": "Fm7 Bbm7 Eb7 Abmaj7 Dbmaj7 Dm7 G7 Cmaj7 Cm7 Fm7 Bb7 Ebmaj7 Abmaj7 Am7b5 D7 Gmaj7 Am7 D7 Gmaj7 F#m7b5 B7 Emaj7 C7#5 Fm7 Bbm7 Eb7 Abmaj7 Dbmaj7 Dbm7 Gb7 Cm7 Bdim7 Bbm7 Eb7 Abmaj7"},
	{"name": "Blue Bossa", "chords": "Cm7 Fm7 Dm7b5 G7 Cm7 Ebm7 Ab7 Dbmaj7 Dm7b5 G7 Cm7 Dm7b5 G7"},
	{"name": "Fly Me to the Moon", "chords": "Am7 Dm7 G7 Cmaj7 C7 Fmaj7 Bm7b5 E7 Am7 A7 Dm7 G7 Cmaj7 Bm7b5 E7 Am7 Dm7 G7 Cmaj7 C7 Fmaj7 Bm7b5 E7 Am7 A7 Dm7 G7 Em7 A7 Dm7 G7 Cmaj7"},
	{"name": "Take the A Train", "chords": "C6 D7#11 Dm7 G7 C6 Fmaj7 D7 Dm7 G7 C6 D7#11 Dm7 G7 C6"},
	{"name": "Giant Steps", "chords": "Bmaj7 D7 Gmaj7 Bb7 Ebmaj7 Am7 D7 Gmaj7 Bb7 Ebmaj7 F#7 Bmaj7 Fm7 Bb7 Ebmaj7 Am7 D7 Gmaj7 C#m7 F#7 Bmaj7 Fm7 Bb7 Ebmaj7 C#m7 F#7"},
	{"name": "Satin Doll", "chords": "Dm7 G7 Em7 A7 Am7 D7 Abm7 Db7 C6 Gm7 C7 Fmaj7 Am7 D7 G7 Dm7 G7 Em7 A7 Am7 D7 Abm7 Db7 C6"},
	{"name": "I Got Rhythm", "chords": "Bbmaj7 G7 Cm7 F7 Dm7 G7 Cm7 F7 Bb7 Ebmaj7 Edim7 Bbmaj7 G7 Cm7 F7 Bbmaj7 D7 G7 C7 F7 Bbmaj7 G7 Cm7 F7 Dm7 G7 Cm7 F7 Bb7 Ebmaj7 Edim7 Bbmaj7 F7 Bbmaj7"},
	{"name": "There Will Never Be Another You", "chords": "Ebmaj7 Dm7b5 G7 Cm7 Bbm7 Eb7 Abmaj7 Db7 Ebmaj7 Cm7 F7 Fm7 Bb7 Ebmaj7 Dm7b5 G7 Cm7 Bbm7 Eb7 Abmaj7 Db7 Ebmaj7 Am7b5 D7 Gm7 C7 Fm7 Bb7 Ebmaj7"},
	{"name": "Solar", "chords": "CmMaj7 Gm7 C7 Fmaj7 Fm7 Bb7 Ebmaj7 Ebm7 Ab7 Dbmaj7 Dm7b5 G7"},
]


## The standard's chords in order, each {root, name, quality}.
static func chords(index: int) -> Array:
	return Array(ROSTER[index].chords.split(" ")).map(Theory.parse_chord_symbol)
