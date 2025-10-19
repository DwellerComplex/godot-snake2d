@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	add_custom_type("SnakeBody2D", "CharacterBody2D", preload("snake_body_2d.gd"), preload("snake_body_2d_icon.svg"))
	add_custom_type("SnakeSprite2D", "Sprite2D", preload("snake_sprite_2d.gd"), preload("snake_sprite_2d_icon.svg"))

func _exit_tree() -> void:
	remove_custom_type("SnakeBody2D")
	remove_custom_type("SnakeSprite2D")
