@tool
extends SceneTree
## Builds assets/ai_profiles/basic_doink.tres — an aggressive, in-your-face first opponent.
## Run: godot --headless --path . --script res://tools/build_basic_doink_profile.gd

func _init() -> void:
	var p := AIProfile.new()
	p.skill = 7
	p.aggression = 0.7                  # presses, but not relentlessly
	p.preferred_range = AIProfile.PreferredRange.CLOSE
	p.run_tendency = 0.3                # closes the gap when far
	p.special_frequency = 0.18          # grabs are a garnish, not the main course
	p.limb_bias = 0.45
	p.block_skill = 0.7
	p.reversal_skill = 0.6
	p.backoff_tendency = 0.15
	p.patience = 0.15
	p.reaction_delay = Vector2i(8, 22)  # a bit more breathing room between actions
	p.stance_duration_scale = 1.0
	# Mood mix: PRESSING is the aggressive-but-fair default; an occasional SPACING breather; and
	# KAMIKAZE only rarely — that's the "gone crazy" stance that won't let a downed foe up.
	p.enabled_stances = [AIController.Stance.PRESSING, AIController.Stance.SPACING,
		AIController.Stance.KAMIKAZE]
	p.stance_weights = {
		AIController.Stance.PRESSING: 6.0,
		AIController.Stance.SPACING: 2.0,
		AIController.Stance.KAMIKAZE: 1.0,
	}
	var dir := "res://assets/ai_profiles"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := ResourceSaver.save(p, dir + "/basic_doink.tres")
	print("save basic_doink.tres -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
