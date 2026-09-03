extends Area2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# Audio player created dynamically in code
@onready var collect_sfx: AudioStreamPlayer2D = AudioStreamPlayer2D.new()

signal collected

func _ready() -> void:
	# Add the sound player to the scene and load collect_apple.wav
	add_child(collect_sfx)
	collect_sfx.stream = preload("res://assets/Sounds/collect_apple.wav")

func _on_body_entered(_body: Node2D) -> void:
	# Play collection sound
	collect_sfx.play()
	
	animated_sprite_2d.animation = "collected"
	collected.emit()
	call_deferred_thread_group("_disable_collision")

func _disable_collision() -> void:
	collision_shape_2d.disabled = true

func _on_animated_sprite_2d_animation_looped() -> void:
	if animated_sprite_2d.animation == "collected":
		queue_free()
