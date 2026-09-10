extends Area2D

signal player_died(body)

var is_dead: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_dead:
		is_dead = true
		
		# Instantly disable collision shape so it cannot trigger again
		$CollisionShape2D.set_deferred("disabled", true)
		
		# Emit death signal to game manager
		player_died.emit(body)
