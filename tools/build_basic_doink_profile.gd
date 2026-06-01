@tool
extends SceneTree
## Builds assets/ai_profiles/basic_doink.tres — an aggressive, in-your-face first opponent.
## Run: godot --headless --path . --script res://tools/build_basic_doink_profile.gd

func _init() -> void:
	var p := AIProfile.new()
	p.skill = 7
	p.aggression = 0.85                 # presses hard; rarely backs off
	p.preferred_range = AIProfile.PreferredRange.CLOSE
	p.run_tendency = 0.35               # closes the gap quickly when far
	p.special_frequency = 0.35          # more grabs/throws, not just jabs
	p.limb_bias = 0.45
	p.block_skill = 0.7
	p.reversal_skill = 0.6
	p.backoff_tendency = 0.15
	p.patience = 0.15
	p.reaction_delay = Vector2i(6, 16)  # acts ~3x more often than before (was 16-44)
	p.stance_duration_scale = 1.0
	# Aggression-forward mood mix: mostly PRESSING/KAMIKAZE, only an occasional SPACING breather.
	p.enabled_stances = [AIController.Stance.PRESSING, AIController.Stance.KAMIKAZE,
		AIController.Stance.SPACING]
	p.stance_weights = {
		AIController.Stance.PRESSING: 4.0,
		AIController.Stance.KAMIKAZE: 3.0,
		AIController.Stance.SPACING: 0.5,
	}
	var dir := "res://assets/ai_profiles"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := ResourceSaver.save(p, dir + "/basic_doink.tres")
	print("save basic_doink.tres -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
