class_name Hitbox
## 3D-AABB hit test (check_collis, COLLIS.ASM:486-524) and the mode-dependent hurt-box
## depth model (COLLIS.ASM:270-296). A hit lands only when all three axes overlap.

static func boxes_overlap(a: Box3, a_pos: Vector2, a_face: float, a_h: float,
		b: Box3, b_pos: Vector2, b_face: float, b_h: float) -> bool:
	var aw := Box3.world_aabb(a, a_pos, a_face, a_h)
	var bw := Box3.world_aabb(b, b_pos, b_face, b_h)
	return aw.intersects(bw)

## Defensive hurt box whose DEPTH (Z) is set by the victim's Mode.
## standing -30/60, ONGROUND -15/30, RUNNING -5/10. Width/height are a body default
## (per-frame IANI3* boxes are not readable from the arcade IMG headers - approximated).
static func hurt_box_for_mode(mode: int) -> Box3:
	var depth := 60.0
	match mode:
		Fighter.Mode.ONGROUND: depth = 30.0
		Fighter.Mode.RUNNING: depth = 10.0
		Fighter.Mode.INAIR: depth = 50.0   # airborne torso (arcade in-air hit volume, approximated)
		_: depth = 60.0
	var hb := Box3.new()
	hb.size = Vector3(44.0, 120.0, depth)
	hb.offset = Vector3(0.0, 60.0, 0.0)
	return hb

## Which way to push the victim: -1 if attacker is on the victim's +x side, else +1.
static func hit_side(attacker_pos: Vector2, victim_pos: Vector2) -> int:
	return -1 if attacker_pos.x >= victim_pos.x else 1
