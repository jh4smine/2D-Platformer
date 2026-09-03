extends Control

# Audio players created completely in code
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var start_sound_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Reference to your ParallaxBackground node in the scene
@onready var parallax_bg: ParallaxBackground = $ParallaxBackground

const SCROLL_SPEED: float = 50.0 # Adjust speed here

func _ready() -> void:
	# Add audio nodes to the scene
	add_child(audio_player)
	add_child(start_sound_player)
	
	# Load sound files
	audio_player.stream = preload("res://assets/Sounds/Button_Pressed.wav")
	start_sound_player.stream = preload("res://assets/Sounds/start.wav")
	
	# Play opening menu sound automatically on load
	start_sound_player.play()

func _process(delta: float) -> void:
	# Scroll the background horizontally every frame
	parallax_bg.scroll_offset.x -= SCROLL_SPEED * delta

func _on_start_pressed() -> void:
	audio_player.play()
	await audio_player.finished
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options_pressed() -> void:
	audio_player.play()
	print("Settings pressed")

func _on_exit_pressed() -> void:
	audio_player.play()
	await audio_player.finished
	get_tree().quit()
