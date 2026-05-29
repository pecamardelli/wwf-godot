extends SceneTree
## Author Doink's MotionTable (special-move registry) -> res://assets/motions/doink_motions.tres
## Run: godot --headless --path . -s tools/build_doink_motiontable.gd
## Scan order follows doink_secret_moves (DOINK.ASM:214): throws before the head grab.

const MOT := "res://assets/motions/doink/"
const SEQ := "res://assets/sequences/doink/"
const OUT := "res://assets/motions/doink_motions.tres"

func _init() -> void:
	var t := MotionTable.new()
	# Grab INITIATORS only (arcade doink_secret_moves). Head-hold follow-ups
	# (piledriver/head_slam/joy_buzzer) are dispatched separately from HEADHOLD
	# context (Task 16 loads them by path), NOT scanned here in normal play.
	t.add(load(MOT + "hip_toss.tres"),   load(SEQ + "hip_toss.tres"))
	t.add(load(MOT + "grab_fling.tres"), load(SEQ + "grab_fling.tres"))
	t.add(load(MOT + "neck_grab.tres"),  load(SEQ + "neck_grab.tres"))
	var err := ResourceSaver.save(t, OUT)
	print("doink_motions -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
