extends SceneTree
## Run: godot --headless -s tests/bench_synth.gd  (times note rendering)

func _init() -> void:
	var synth: Node = load("res://scripts/synth.gd").new()
	synth._bright = synth._make_table([1.0, 0.55, 0.32, 0.2, 0.12, 0.07, 0.04])
	synth._mellow = synth._make_table([1.0, 0.18, 0.05])
	var t := Time.get_ticks_usec()
	for m in range(60, 70):
		synth._render(m)
	print("avg render ms: %.1f" % ((Time.get_ticks_usec() - t) / 10000.0))
	synth.free()
	quit()
