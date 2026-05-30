extends SceneTree
## Diagnostic: for the held headlock victim, isolate the HEAD/NECK band (top of the bent-over
## body) and report its horizontal edges per frame, so we can lock the grip point and kill the
## frame-to-frame drift. Run: godot --headless --path . -s tools/anchor_probe.gd

const ANIMS := ["headlocked"]
const BASE := "res://assets/sprites/doink/"
const HEAD_BAND := 38   # px below the topmost opaque row = the head/neck zone

func _scan(img: Image) -> Dictionary:
	var full := img.get_used_rect()
	var top := full.position.y
	var w := img.get_width()
	var h := img.get_height()
	var band_bottom: int = mini(top + HEAD_BAND, h)
	var hl := w   # head-band leftmost opaque x
	var hr := -1  # head-band rightmost opaque x
	for y in range(top, band_bottom):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.1:
				if x < hl: hl = x
				if x > hr: hr = x
	return {"full": full, "head_l": hl, "head_r": hr}

func _init() -> void:
	for anim in ANIMS:
		print("=== %s  (canvas center = 90; head band = top..+%d) ===" % [anim, HEAD_BAND])
		var dir := DirAccess.open(BASE + anim)
		if dir == null:
			print("  (no dir)"); continue
		var files: Array = []
		for f in dir.get_files():
			if f.ends_with(".png"): files.append(f)
		files.sort()
		var pl := -1   # prev head_l, for drift
		var pr := -1   # prev head_r
		for f in files:
			var img := Image.load_from_file(ProjectSettings.globalize_path(BASE + anim + "/" + f))
			if img == null: continue
			var s := _scan(img)
			var hl: int = s.head_l
			var hr: int = s.head_r
			var hc := (hl + hr) / 2
			var dl := 0 if pl < 0 else hl - pl
			var dr := 0 if pr < 0 else hr - pr
			print("  %s  head_L=%d head_R=%d head_cx=%d  | dL=%+d dR=%+d" % [f, hl, hr, hc, dl, dr])
			pl = hl; pr = hr
	quit()
