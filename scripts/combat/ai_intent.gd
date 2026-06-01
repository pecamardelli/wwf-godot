class_name AIIntent
extends RefCounted
## The per-frame decision the AIController hands to an Enemy. Plain data, no behavior.

enum Action { IDLE, STRIKE, GRAB, BLOCK }

var move_dir: Vector2 = Vector2.ZERO   ## desired walk direction, analog -1..1 per axis
var action: int = Action.IDLE
var button: int = -1                    ## MoveTable.Btn when action == STRIKE
var move_id: String = ""                ## grapple sequence id when action == GRAB
var want_run: bool = false
