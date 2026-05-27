class_name SequenceFrame
extends Resource
## One frame of a move sequence (the arcade WL n,img macro + ANI_ commands).
## `duration_ticks` plays at the frame; `anim_frame` indexes the move's SpriteFrames anim.
## Commands fire when the frame BEGINS.

@export var duration_ticks: int = 4
@export var anim_frame: int = 0
## Hitbox lifecycle command on this frame.
@export_enum("NONE", "STARTATTACK", "ATTACK_ON", "ATTACK_OFF") var command: int = 0
## Attack box for ATTACK_ON frames (ANI_ATTACK_ON x,y,w,h; Z depth default 10).
@export var attack_box: Box3 = null
