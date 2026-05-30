class_name AttackResolver
extends Node
## Each physics tick, match every live attack box against every other fighter's hurt box.
## A given swing hits each victim at most once (Fighter tracks _hit_by_current_move).

func _physics_process(_delta: float) -> void:
	resolve_tick()

func resolve_tick() -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	for attacker in fighters:
		var atk_box: Box3 = attacker.current_attack_box()
		if atk_box == null:
			continue
		for victim in fighters:
			if victim == attacker or attacker.already_hit(victim):
				continue
			var hb: Box3 = victim.hurt_box()
			if not Hitbox.boxes_overlap(atk_box, attacker.global_position, attacker.facing(), 0.0,
					hb, victim.global_position, victim.facing(), 0.0):
				continue
			var move: MoveSequence = attacker.current_move()
			if move != null and move.is_grapple:
				if victim._is_guarding():
					attacker._hit_by_current_move.append(victim)   # resolve once
					attacker._player.notify_grab_blocked()
				elif _can_be_grabbed(victim):
					attacker._hit_by_current_move.append(victim)
					victim.receive_grab(attacker, move)
			else:
				victim.receive_hit(attacker, move)

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
