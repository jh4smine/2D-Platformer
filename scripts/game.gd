extends Node2D
@onready var score_label: Label = $HUD/ScorePanel/ScoreLabel
@onready var fade: ColorRect = $HUD/Fade
@onready var warning_label: Label = $HUD/WarningLabel

# Required score configured per level
const LEVEL_REQUIREMENTS = {
	1: 5,
	2: 13,
	3: 23
}

var level: int = 1
var score: int = 0
var level_start_score: int = 0 # Stores score at the start of the current level
var current_level_one: Node = null
var warning_tween: Tween = null

# Helper to retrieve the target score for the current level
func get_required_score() -> int:
	return LEVEL_REQUIREMENTS.get(level, 5)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# set up level
	fade.modulate.a = 1.0 
	if warning_label:
		warning_label.modulate.a = 0.0 # Ensure warning starts invisible
	current_level_one = get_node("Level1")
	await _load_level(level, true, false)


## level management --

func _load_level(level_number: int, first_load: bool, reset_score: bool) -> void:
	# fade out
	if not first_load:
		await _fade(1.0)
		
	if reset_score:
		score = 0
		level_start_score = 0
		score_label.text = "SCORE: 0"
	else:
		# Reset score to what it was when entering this level
		score = level_start_score
		score_label.text = "SCORE: %s" % score
	
	if current_level_one:
		current_level_one.queue_free()
		
	# change level
	var level_path = "res://scenes/levels/level_%s.tscn" % level_number
	current_level_one = load(level_path).instantiate()
	add_child(current_level_one)
	current_level_one.name = "Level1"
	_setup_level(current_level_one)
	
	# fade in
	await _fade(0.0)
	

func _setup_level(level_one: Node) -> void:
	# 1. Reset player movement state for the new level
	var player = level_one.get_node_or_null("Player")
	if player:
		player.can_move = true

	# 2. Connect exit
	var exit = level_one.get_node_or_null("Exit")
	if exit:
		if not exit.body_entered.is_connected(_on_exit_body_entered):
			exit.body_entered.connect(_on_exit_body_entered)
	
	# 3. Connect apples
	var apples = level_one.get_node_or_null("Collect")
	if apples:
		for item in apples.get_children():
			if item.has_signal("collected"):
				if not item.collected.is_connected(increase_score):
					item.collected.connect(increase_score)
			
	# 4. Connect collectibles (oranges)
	var oranges = level_one.get_node_or_null("Oranges")
	if oranges:
		for item in oranges.get_children():
			if item.has_signal("collected"):
				if not item.collected.is_connected(increase_score):
					item.collected.connect(increase_score)
			
	# 5. Connect enemies
	var enemies = level_one.get_node_or_null("Enemies")
	if enemies:
		for enemy in enemies.get_children():
			if enemy.has_signal("player_died"):
				if not enemy.player_died.is_connected(_on_player_died):
					enemy.player_died.connect(_on_player_died)

## Signals
func _on_player_died(body):
	body.die()
	await _load_level(level, false, false)
	
func _on_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var required = get_required_score()
		if score >= required:
			level += 1
			level_start_score = score # Checkpoint score for the next level
			body.can_move = false
			await _load_level(level, false, false)
		else:
			show_warning("Need at least %s score to advance! (%s/%s)" % [required, score, required])

## UI Warnings
func show_warning(message: String) -> void:
	if not warning_label:
		return
		
	warning_label.text = message
	
	# Kill existing animation if triggered again quickly
	if warning_tween and warning_tween.is_running():
		warning_tween.kill()
		
	warning_tween = create_tween()
	warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.2) # Fade in
	warning_tween.tween_interval(1.5) # Hold display
	warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5) # Fade out


## Score
func increase_score() -> void:
	score += 1
	score_label.text = "SCORE: %s" % score
	
	
## Fade

func _fade(to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", to_alpha, 1.5)
	await tween.finished
