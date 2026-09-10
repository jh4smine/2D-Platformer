extends Node2D

@onready var score_label: Label = $HUD/ScorePanel/ScoreLabel
@onready var fade: ColorRect = $HUD/Fade
@onready var warning_label: Label = $HUD/WarningLabel
@onready var heart_container: HBoxContainer = $CanvasLayer/heartcontainer

# Required score configured per level
const LEVEL_REQUIREMENTS = {
	1: 5,
	2: 13,
	3: 23,
	4: 35
}

var level: int = 1
var score: int = 0
var level_start_score: int = 0 # Stores score at the start of the current level
var current_level_node: Node = null
var warning_tween: Tween = null

# Life tracking variables
var max_lives: int = 8
var current_lives: int = 8

# Helper to retrieve the target score for the current level
func get_required_score() -> int:
	return LEVEL_REQUIREMENTS.get(level, 5)

func _ready() -> void:
	fade.modulate.a = 1.0 
	if warning_label:
		warning_label.modulate.a = 0.0 # Ensure warning starts invisible
		
	# Store reference if Level1 is pre-placed in scene tree
	if has_node("Level1"):
		current_level_node = get_node("Level1")
		
	current_lives = max_lives
	update_lives_display()
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
	
	if current_level_node and is_instance_valid(current_level_node):
		current_level_node.queue_free()
		
	# Instantiate current level dynamically
	var level_path = "res://scenes/levels/level_%s.tscn" % level_number
	if ResourceLoader.exists(level_path):
		current_level_node = load(level_path).instantiate()
		add_child(current_level_node)
		_setup_level(current_level_node)
	else:
		print("Error: Could not find scene at path: ", level_path)
	
	# fade in
	await _fade(0.0)
	

func _setup_level(level_node: Node) -> void:
	# 1. Reset player movement state for the new level
	var player = level_node.get_node_or_null("Player")
	if player:
		player.can_move = true

	# 2. Connect exit
	var exit = level_node.get_node_or_null("Exit")
	if exit:
		if not exit.body_entered.is_connected(_on_exit_body_entered):
			exit.body_entered.connect(_on_exit_body_entered)
	
	# 3. Connect collectibles (Apples / Oranges)
	for container_name in ["Collect", "Oranges"]:
		var container = level_node.get_node_or_null(container_name)
		if container:
			for item in container.get_children():
				if item.has_signal("collected") and not item.collected.is_connected(increase_score):
					item.collected.connect(increase_score)
			
	# 4. Connect ALL Killzones / Enemies recursively inside the loaded level
	_connect_death_signals_recursive(level_node)


# Helper function to find any Killzone/Enemy node in the entire sub-tree
func _connect_death_signals_recursive(node: Node) -> void:
	if node.has_signal("player_died"):
		if not node.player_died.is_connected(_on_player_died):
			node.player_died.connect(_on_player_died)
			
	for child in node.get_children():
		_connect_death_signals_recursive(child)


## Signals
func _on_player_died(body):
	if body and body.has_method("die"):
		body.die()
		
	current_lives -= 1
	update_lives_display()
	
	if current_lives <= 0:
		# Game Over -> Reset lives & start back from Level 1
		current_lives = max_lives
		update_lives_display()
		level = 1
		await _load_level(1, false, true)
	else:
		# Respawn inside current level
		await _load_level(level, false, false)

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
			if heart.visible:
				var tween = create_tween()
				# Flash red twice
				tween.tween_property(heart, "modulate", Color.RED, 0.1)
				tween.tween_property(heart, "modulate", Color.WHITE, 0.1)
				tween.tween_property(heart, "modulate", Color.RED, 0.1)
				# Fade out
				tween.tween_property(heart, "modulate:a", 0.0, 0.15)
				tween.finished.connect(func(): heart.visible = false)

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
	
	if warning_tween and warning_tween.is_running():
		warning_tween.kill()
		
	warning_tween = create_tween()
	warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.2)
	warning_tween.tween_interval(1.5)
	warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)

## Score
func increase_score() -> void:
	score += 1
	score_label.text = "SCORE: %s" % score

## Fade
func _fade(to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", to_alpha, 1.5)
	await tween.finished
