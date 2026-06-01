@tool
extends SceneTree
## Builds assets/ai_profiles/basic_doink.tres — a beatable, PRESSING-heavy first opponent.
## Run: godot --headless --path . --script res://tools/build_basic_doink_profile.gd

func _init() -> void:
	var p := AIProfile.new()
	p.skill = 6
	p.aggression = 0.65
	p.preferred_range = AIProfile.PreferredRange.CLOSE
	p.run_tendency = 0.15
	p.special_frequency = 0.2
	p.limb_bias = 0.4
	p.block_skill = 0.8
	p.reversal_skill = 0.6
	p.backoff_tendency = 0.3
	p.patience = 0.25
	p.reaction_delay = Vector2i(16, 44)
	p.stance_duration_scale = 1.0
	p.enabled_stances = [AIController.Stance.PRESSING, AIController.Stance.SPACING,
		AIController.Stance.KAMIKAZE]
	p.stance_weights = {
		AIController.Stance.PRESSING: 4.0,
		AIController.Stance.SPACING: 2.0,
		AIController.Stance.KAMIKAZE: 1.0,
	}
	var dir := "res://assets/ai_profiles"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := ResourceSaver.save(p, dir + "/basic_doink.tres")
	print("save basic_doink.tres -> ", err)
	quit()
