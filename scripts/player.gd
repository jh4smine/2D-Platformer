extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Audio players created dynamically in code
@onready var jump_sfx: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
@onready var death_sfx: AudioStreamPlayer2D = AudioStreamPlayer2D.new()

const SPEED = 100.0
const JUMP_VELOCITY = -350.0
const COYOTE_TIME = 0.15

enum State { NORMAL, DYING, SPAWNING }
var current_state: State = State.NORMAL

# Compatibility getter/setter for game.gd and Level transitions
var can_move: bool:
	get:
		return current_state == State.NORMAL
	set(value):
		if value:
			current_state = State.NORMAL
		else:
			current_state = State.SPAWNING

# Compatibility getter for external scripts
var alive: bool:
	get:
		return current_state == State.NORMAL

var coyote_timer = 0.0

func _ready() -> void:
	# Add jump and death audio nodes and load sound files
	add_child(jump_sfx)
	add_child(death_sfx)
	jump_sfx.stream = preload("res://assets/Sounds/jump.wav")
	death_sfx.stream = preload("res://assets/Sounds/death.wav")

	animated_sprite.animation_finished.connect(_on_animation_finished)
	current_state = State.NORMAL # Guarantees player starts alive on scene load

func _physics_process(delta: float) -> void:
	if current_state != State.NORMAL:
		return

	# Handle coyote timer and gravity
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
		velocity += get_gravity() * delta

	# Jump logic + play audio (Uses "w" key from Input Map)
	if Input.is_action_just_pressed("w") and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_sfx.play()

	# Horizontal movement (Uses "a" for left, "d" for right)
	var direction := Input.get_axis("a", "d")
	if direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = (direction < 0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Animations
	if is_on_floor():
		if direction != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
	else:
		animated_sprite.play("jump")

	move_and_slide()

# Helper method for enemies checking body.has_method("is_alive")
func is_alive() -> bool:
	return current_state == State.NORMAL

func die() -> void:
	if current_state == State.DYING:
		return

	# Play death sound effect
	death_sfx.play()

	current_state = State.DYING
	velocity = Vector2.ZERO
	animated_sprite.play("hurt")

func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_state = State.SPAWNING
	animated_sprite.play("hurt2")

func _on_animation_finished() -> void:
	if current_state == State.DYING and animated_sprite.animation == "hurt":
		# Death phase 1 done -> play smoke cloud
		animated_sprite.play("hurt2")
	elif current_state == State.SPAWNING and animated_sprite.animation == "hurt2":
		# Spawn cloud done -> return control to player
		current_state = State.NORMAL
		animated_sprite.play("idle")
