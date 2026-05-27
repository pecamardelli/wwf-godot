class_name SequenceFrame
extends Resource
## One frame of a move sequence (the arcade WL n,img macro + ANI_ commands).
## `duration_ticks` plays at the frame; `anim_frame` indexes the move's SpriteFrames anim.
## Commands fire when the frame BEGINS.

## Hitbox lifecycle command codes (referenced everywhere as SequenceFrame.Command.*).
enum Command { NONE = 0, STARTATTACK = 1, ATTACK_ON = 2, ATTACK_OFF = 3 }

@export var duration_ticks: int = 4
@export var anim_frame: int = 0
@export_enum("NONE", "STARTATTACK", "ATTACK_ON", "ATTACK_OFF") var command: int = Command.NONE
## Attack box for ATTACK_ON frames (ANI_ATTACK_ON x,y,w,h; Z depth default 10).
@export var attack_box: Box3 = null
