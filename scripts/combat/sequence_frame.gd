class_name SequenceFrame
extends Resource
## One frame of a move sequence (the arcade WL n,img macro + ANI_ commands).
## `duration_ticks` plays at the frame; `anim_frame` indexes the move's SpriteFrames anim.
## Commands fire when the frame BEGINS.

## Hitbox + grapple lifecycle command codes (referenced as SequenceFrame.Command.*).
enum Command {
	NONE = 0, STARTATTACK = 1, ATTACK_ON = 2, ATTACK_OFF = 3,
	WAIT_HIT_OPP = 4,   # hold here until the grab box connects (ANICNT zeroed on hit)
	SET_ATTACH = 5,     # bind the overlapped victim as our puppet
	SLAVE_ANIM = 6,     # set the victim's displayed anim (slave_anim) for following frames
	DAMAGE_OPP = 7,     # apply puppet damage to the victim once
	DETACH = 8,         # release the victim -> ONGROUND
	SET_OPP_MODE = 9,   # force the victim into opp_mode (e.g. INAIR during the airborne arc)
	CLR_OPP_MODE = 10,  # restore the victim from opp_mode
}

@export var duration_ticks: int = 4
@export var anim_frame: int = 0
@export_enum("NONE", "STARTATTACK", "ATTACK_ON", "ATTACK_OFF", "WAIT_HIT_OPP",
	"SET_ATTACH", "SLAVE_ANIM", "DAMAGE_OPP", "DETACH", "SET_OPP_MODE", "CLR_OPP_MODE")
var command: int = Command.NONE
## Attack box for ATTACK_ON / WAIT_HIT_OPP frames (ANI_ATTACK_ON x,y,w,h; Z depth default 10).
@export var attack_box: Box3 = null
## --- Victim ("slave") track, applied each tick while this fighter drives a victim. ---
@export var victim_anim_frame: int = 0            # frame index into the victim's slave_anim
@export var victim_offset: Vector3 = Vector3.ZERO # victim pos relative to attacker; x mirrored by facing
@export var slave_anim: String = ""               # SLAVE_ANIM payload: victim anim name
@export var opp_mode: int = 0                      # SET/CLR_OPP_MODE payload (Fighter.Mode)
@export var victim_amode: int = 0                  # DAMAGE_OPP payload: attack mode for the reaction
@export var victim_dizzy: bool = false             # DAMAGE_OPP payload: force dizzy
@export var wait_hit_max_ticks: int = 16           # WAIT_HIT_OPP whiff timeout
