# Jazz Chords

A Godot 4.7 app for learning jazz chords and scales, built for a phone browser in portrait.

## MIDI controllers

Plug in a USB MIDI keyboard and play. The notes light up the on-screen keys and sound through the app's synth, and the keyboard view follows your hands.

- **Practice:** hold the chord. Your held notes are the answer, in any octave or inversion.
- **Chords:** hold any chord and it gets named and shown as you voiced it.

The default mapping suits an Akai MPK mini. The keys (channel 1) play notes. The drum pads (channel 10) and the knobs are ignored. Notes outside C2–C6 fold into that range by octaves.

Web MIDI works in Chrome, Edge and Firefox, including Android Chrome with a USB-OTG adapter. It doesn't work in Safari or on iOS. The page has to be served over HTTPS or from localhost, and the browser asks for permission the first time. Controllers can be plugged in or unplugged while the app is running, and a short notice names the connected device.
