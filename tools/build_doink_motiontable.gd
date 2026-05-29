extends SceneTree
## Author Doink's MotionTable (special-move registry) -> res://assets/motions/doink_motions.tres
## Run: godot --headless --path . -s tools/build_doink_motiontable.gd
## Scan order follows doink_secret_moves (DOINK.ASM:214): throws before the head grab.

const MOT := "res://assets/motions/doink/"
const SEQ := "res://assets/sequences/doink/"
const OUT := "res://assets/motions/doink_motions.tres"

func _init() -> void:
	var t := MotionTable.new()
	t.add(load(MOT + "hip_toss.tres"),   load(SEQ + "hip_toss.tres"))
	t.add(load(MOT + "grab_fling.tres"), load(SEQ + "grab_fling.tres"))
	t.add(load(MOT + "neck_grab.tres"),  load(SEQ + "neck_grab.tres"))
	t.add(load(MOT + "piledriver.tres"), load(SEQ + "piledriver.tres"))
	t.add(load(MOT + "head_slam.tres"),  load(SEQ + "head_slam.tres"))
	var err := ResourceSaver.save(t, OUT)
	print("doink_motions -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
