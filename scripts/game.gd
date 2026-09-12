extends Node2D

@onready var score_label: Label = $HUD/ScorePanel/ScoreLabel
@onready var fade: ColorRect = $HUD/Fade
@onready var warning_label: Label = $HUD/WarningLabel
@onready var heart_container: HBoxContainer = $CanvasLayer/heartcontainer

# Preload your game over scene
const GAME_OVER_SCENE = preload("res://scenes/gamer_over.tscn")

# Required score configured per level
const LEVEL_REQUIREMENTS = {
	1: 5,
	2: 13,
	3: 23,
	4: 35
}

var level: int = 1
var score: int = 0
var level_start_score: int = 0
var current_level_node: Node = null
var warning_tween: Tween = null
var current_game_over_instance: Node = null

# Life tracking variables
var max_lives: int = 8
var current_lives: int = 8
var is_restarting: bool = false # Guard flag to prevent lingering death signals

func get_required_score() -> int:
	return LEVEL_REQUIREMENTS.get(level, 5)

func _ready() -> void:
	fade.modulate.a = 0.0 # Start level completely visible
	if warning_label:
		warning_label.modulate.a = 0.0
		
	if has_node("Level1"):
		current_level_node = get_node("Level1")
		
	current_lives = max_lives
	update_lives_display()
	await _load_level(level, true, false)

## Level Management

func _load_level(level_number: int, first_load: bool, reset_score: bool) -> void:
	if not first_load:
		await _fade(1.0)
		
	if reset_score:
		score = 0
		level_start_score = 0
		score_label.text = "SCORE: 0"
	else:
		score = level_start_score
		score_label.text = "SCORE: %s" % score
	
	if current_level_node and is_instance_valid(current_level_node):
		current_level_node.queue_free()
		
	var level_path = "res://scenes/levels/level_%s.tscn" % level_number
	if ResourceLoader.exists(level_path):
		current_level_node = load(level_path).instantiate()
		add_child(current_level_node)
		_setup_level(current_level_node)
	else:
		print("Error: Could not find scene at path: ", level_path)
	
	await _fade(0.0)

func _setup_level(level_node: Node) -> void:
	var player = level_node.get_node_or_null("Player")
	if player:
		player.can_move = true

	var exit = level_node.get_node_or_null("Exit")
	if exit:
		if not exit.body_entered.is_connected(_on_exit_body_entered):
			exit.body_entered.connect(_on_exit_body_entered)
	
	for container_name in ["Collect", "Oranges"]:
		var container = level_node.get_node_or_null(container_name)
		if container:
			for item in container.get_children():
				if item.has_signal("collected") and not item.collected.is_connected(increase_score):
					item.collected.connect(increase_score)
			
	_connect_death_signals_recursive(level_node)

func _connect_death_signals_recursive(node: Node) -> void:
	if node.has_signal("player_died"):
		if not node.player_died.is_connected(_on_player_died):
			node.player_died.connect(_on_player_died)
			
	for child in node.get_children():
		_connect_death_signals_recursive(child)

## Signals

func _on_player_died(body):
	# Ignore death signals if we are currently handling a Game Over restart
	if is_restarting:
		return

	if body and body.has_method("die"):
		body.die()
		
	current_lives -= 1
	update_lives_display()
	
	if current_lives <= 0:
		trigger_game_over()
	else:
		await _load_level(level, false, false)

func trigger_game_over() -> void:
	get_tree().paused = true
	if current_game_over_instance and is_instance_valid(current_game_over_instance):
		current_game_over_instance.queue_free()
		
	current_game_over_instance = GAME_OVER_SCENE.instantiate()
	$HUD.add_child(current_game_over_instance)

func restart_from_beginning() -> void:
	is_restarting = true # Block any death triggers while cleaning up old level
	get_tree().paused = false
	
	if current_game_over_instance and is_instance_valid(current_game_over_instance):
		current_game_over_instance.queue_free()
		current_game_over_instance = null
		
	level = 1
	await _load_level(1, false, true)
	
	# Restore full 8 lives ONLY after Level 1 is fully spawned
	current_lives = max_lives
	update_lives_display()
	is_restarting = false # Unlock death tracking

func update_lives_display() -> void:
	if not heart_container:
		return
		
	var hearts = heart_container.get_children()
	for i in range(hearts.size()):
		var heart = hearts[i]
		
		if i < current_lives:
			heart.visible = true
			heart.modulate = Color.WHITE
		else:
			heart.visible = false

func _on_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var required = get_required_score()
		if score >= required:
			level += 1
			level_start_score = score
			body.can_move = false
			await _load_level(level, false, false)
		else:
			show_warning("Need at least %s score to advance! (%s/%s)" % [required, score, required])

## UI Warnings

func show_warning(message: String) -> void:
	if not warning_label:
		return
		
	warning_label.text = message
	
	if warning_tween and warning_tween.is_running():
		warning_tween.kill()
		
	warning_tween = create_tween()
	warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.2)
	warning_tween.tween_interval(1.5)
	warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)

## Score & Fade

func increase_score() -> void:
	score += 1
	score_label.text = "SCORE: %s" % score

func _fade(to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", to_alpha, 1.5)
	await tween.finished
