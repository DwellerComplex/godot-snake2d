@tool
extends Sprite2D

## This is one part of the snakes body.
## Add multiple SnakeSprite2D nodes as children to a Snake2D node for a complete snake.
class_name SnakeSprite2D

#A tool function to display configuration warnings.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	
	if get_parent() is not SnakeBody2D:
		warnings.append("Parent should be a SnakeBody2D node.")
	
	return warnings
