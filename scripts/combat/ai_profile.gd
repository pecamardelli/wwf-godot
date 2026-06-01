class_name AIProfile
extends Resource
## Personality + competence of an AI fighter. The profile says WHO the fighter is
## (propensities); the active stance says what they are doing right now.

enum PreferredRange { CLOSE, MID, LONG }

@export_range(0, 29) var skill: int = 6            ## master competence (arcade DRN_SKILL)
@export_range(0.0, 1.0) var aggression: float = 0.6
@export var preferred_range: int = PreferredRange.CLOSE
@export_range(0.0, 1.0) var run_tendency: float = 0.2
@export_range(0.0, 1.0) var special_frequency: float = 0.25  ## grapple vs strike bias
@export_range(0.0, 1.0) var limb_bias: float = 0.4           ## 0 = fists, 1 = legs
@export_range(0.0, 2.0) var block_skill: float = 1.0
@export_range(0.0, 2.0) var reversal_skill: float = 1.0
@export_range(0.0, 1.0) var backoff_tendency: float = 0.3
@export_range(0.0, 1.0) var patience: float = 0.3
@export var reaction_delay: Vector2i = Vector2i(15, 40)       ## min,max ticks (arcade DRN_DELAY)
## Re-roll weights for the mood FSM, keyed by AIController.Stance (int). Missing = weight 0.
@export var stance_weights: Dictionary = {}
@export_range(0.1, 4.0) var stance_duration_scale: float = 1.0
## Which stances this fighter may enter. Keyed by AIController.Stance (int).
@export var enabled_stances: Array[int] = []
