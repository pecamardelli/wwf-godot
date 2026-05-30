extends SceneTree
## Derive a per-frame grip-anchor offset table for a held animation and EMIT it as a paste-ready
## GDScript array (no hand-transcription — that's how the wobble crept in). For the headlock we
## pin the NECK = the head/neck band's edge nearest the captor, which is the side the user sees
## drift. Offsets are zero-mean so they don't shift the tuned base placement, only kill drift.
## Run: godot --headless --path . -s tools/anchor_probe.gd

const ANIM := "headlocked"
const BASE := "res://assets/sprites/doink/"
const HEAD_BAND := 38   # px below the topmost opaque row = the head/neck zone
const PIN_LEFT_EDGE := true   # neck/grip is the body's LEFT edge in the raw art

func _init() -> void:
	var dir := DirAccess.open(BASE + ANIM)
	if dir == null:
		print("no dir for ", ANIM); quit(); return
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".png"): files.append(f)
	files.sort()
	# Measure the pinned edge of the head band for every frame.
	var edges: Array = []
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(BASE + ANIM + "/" + f))
		if img == null: continue
		var full := img.get_used_rect()
		var top := full.position.y
		var w := img.get_width()
		var band_bottom: int = mini(top + HEAD_BAND, img.get_height())
		var lo := w
		var hi := -1
		for y in range(top, band_bottom):
			for x in range(w):
				if img.get_pixel(x, y).a > 0.1:
					if x < lo: lo = x
					if x > hi: hi = x
		edges.append(lo if PIN_LEFT_EDGE else hi)
	# Zero-mean offset = mean(edge) - edge[i]: pins the edge to its average position.
	var mean := 0.0
	for e in edges: mean += e
	mean /= float(edges.size())
	var out := "["
	for i in range(edges.size()):
		var off := roundf(mean - float(edges[i]))
		out += "%.1f" % off
		if i < edges.size() - 1: out += ", "
	out += "]"
	print("edges = ", edges, "  mean = %.2f" % mean)
	print("PASTE -> \"%s\": %s," % [ANIM, out])
	quit()
