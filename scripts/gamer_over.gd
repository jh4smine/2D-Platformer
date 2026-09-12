extends Control

func _ready() -> void:
	# Ensure the UI and buttons respond while game logic is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set expand origin to screen/control center
	pivot_offset = size / 2.0
	
	# Set initial transparent state and small scale for pop-in effect
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	
	# Connect restart button dynamically
	var btn = find_child("*Button*", true, false)
	if btn and btn is Button:
		btn.pressed.connect(_on_restart_pressed)
		
	# Trigger entrance animation
	animate_pop_in()

func animate_pop_in() -> void:
	# Create parallel tween that runs even while scene tree is paused
	var tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Fade in opacity (0.0 to 1.0)
	tween.tween_property(self, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Scale up with a slight spring bounce (0.5 to 1.0)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	var game_root = get_tree().current_scene
	if game_root and game_root.has_method("restart_from_beginning"):
		game_root.restart_from_beginning()
	else:
		get_tree().reload_current_scene()
