class_name AttackResolver
extends Node
## Each physics tick, resolve every live attack box against the SINGLE best target.
## Arcade COLLIS.ASM: a swing connects with one fighter and the collision loop exits on that
## first hit (MODE_STATUS_BIT) — a strike never damages two stacked opponents. We mirror that:
## a swing hits at most ONE fighter (the closest overlapping one), then is spent for its duration.
## Friendly fire is intentionally preserved (any fighter can be the victim, not just opponents) —
## it's just limited to one victim per swing.

func _physics_process(_delta: float) -> void:
	resolve_tick()

func resolve_tick() -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	for attacker in fighters:
		var atk_box: Box3 = attacker.current_attack_box()
		if atk_box == null:
			continue
		# Once this swing has already connected with someone, it's spent — no second victim.
		if not attacker._hit_by_current_move.is_empty():
			continue
		var move: MoveSequence = attacker.current_move()
		# Ground attacks (stomp / elbow drop) only connect with a foe that is actually lying down —
		# never a standing or already-rising fighter (arcade gates these by MODE_ONGROUND).
		var grounded_only: bool = move != null and not move.is_grapple \
			and AMode.reaction_for(move.attack_mode) == AMode.Family.ONGROUND
		var victim: Fighter = _closest_overlapping(attacker, atk_box, fighters, grounded_only)
		if victim == null:
			continue
		if move != null and move.is_grapple:
			if victim._is_guarding():
				attacker._hit_by_current_move.append(victim)   # resolve once
				attacker._player.notify_grab_blocked()
			elif _can_be_grabbed(victim):
				attacker._hit_by_current_move.append(victim)
				victim.receive_grab(attacker, move)
			# closest target isn't grab-eligible (downed/already grappled): whiff this frame
		else:
			victim.receive_hit(attacker, move)   # appends self to attacker._hit_by_current_move

## The closest other fighter whose hurt box overlaps `attacker`'s live attack box, or null.
## "Closest" mirrors the arcade's calc_closest targeting bias and keeps the choice deterministic
## (instead of scene-tree order) when two victims are stacked.
func _closest_overlapping(attacker: Fighter, atk_box: Box3, fighters: Array, grounded_only: bool = false) -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for victim in fighters:
		if victim == attacker:
			continue
		# A ground attack passes over a standing or rising foe — only a foe still lying down is hit.
		if grounded_only and (victim.mode != Fighter.Mode.ONGROUND or victim._getup_rising):
			continue
		var hb: Box3 = victim.hurt_box()
		if not Hitbox.boxes_overlap(atk_box, attacker.global_position, attacker.facing(), attacker._height,
				hb, victim.global_position, victim.facing(), victim._height):
			continue
		var d: float = attacker.global_position.distance_squared_to(victim.global_position)
		if d < best_d:
			best_d = d
			best = victim
	return best

## Grab eligibility (RESEARCH §A.4/§B.3): refuse dead / downed victims and anyone
## already inside the grapple FSM (already held, holding, or mid-throw).
func _can_be_grabbed(victim: Fighter) -> bool:
	if victim.is_dead():
		return false
	match victim.mode:
		Fighter.Mode.ONGROUND, Fighter.Mode.GRABBED, Fighter.Mode.GRABBING, \
		Fighter.Mode.HEADHOLD, Fighter.Mode.HEADHELD:
			return false
	return true
