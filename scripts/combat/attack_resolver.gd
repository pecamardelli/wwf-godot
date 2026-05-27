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
			# Eligibility filters (dead/teammate/pin/in-ring) arrive with those
			# systems in later plans; for 2b a live box hits any other fighter once.
			var hb: Box3 = victim.hurt_box()
			if Hitbox.boxes_overlap(atk_box, attacker.global_position, attacker.facing(), 0.0,
					hb, victim.global_position, victim.facing(), 0.0):
				victim.receive_hit(attacker, attacker.current_move())
