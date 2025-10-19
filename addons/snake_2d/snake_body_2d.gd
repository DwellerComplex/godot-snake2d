@tool
extends CharacterBody2D

#Copyright (c) 2025 DwellerComplex (Crumblebit www.crumblebit.com) under MIT license.
#https://github.com/DwellerComplex/godot-snake2d
#Thank you for using my stuff! 

## Base scene for snake movement.
##Add SnakeSprite2D nodes as children.
##Want a Line2D instead of sprites? Add a Line2D node as child of this node.
##You still need SnakeSprite2D nodes but you can keep the texture properties empty.
class_name SnakeBody2D

#Arrive
@export var follow_mouse = true
@export var target_position = Vector2.ZERO
@export var arrive_distance = 10
@export var arrive_slowdown_distance = 200
@export var arrive_slowdown_factor = 0.1

@export var max_force = 100000
@export var max_speed = 400

#Wavy movement
@export var amplitude_curve:Curve = preload("snake_2d_curve.tres")
@export var amplitude = 8.0
@export var contraction = 20.0
##Speed based stretching. Makes the snake less wavy the closer it is to standing still.
@export_range(0.0, 1.0, 0.01) var rest_stretching_factor = 0.5
@export var parts_seperation = 7
##The snake tries to move away from itself. 
##Play around with the values or set number_parts_calculating_min_angle to 0 if it produces strange movement.
@export var parts_min_angle = 20
@export var parts_min_angle_speed = 20
##Set to 0 to ignore min angle and allow the snake to move into itself. Set to high number to include all parts.
@export var number_parts_calculating_min_angle = 20

@export var frequency_contraction = 0.02
##How much the snakes current velocity contributes to the contraction speed.
@export var speed_contraction_factor = 0.3
##Minimum contraction. Set to 0 for no contraction when the snake is not moving forward (0 velocity).
@export var speed_contraction_min = 0.1
@export var frequency_wave = 0.1
##How much the snakes current velocity contributes to the wave speed.
@export var speed_wave_factor = 0.15
##Minimum wavyness. Set to 0 for no wave when the snake is not moving forward (0 velocity).
@export var speed_wave_min = 4.0
##Adds some fun randomness to the SnakeSprite2D rotations.
@export_range(0.0, 1.0, 0.01) var random_jitter_factor = 0.0

var time_contraction = 0.0
var time_wave = 0.0

#The body is made up of sprites. 
var body = []
#Center line acts like a "spine", it is the snake without added wave movement to keep the snake stable.
#otherwise all offsets would accumulate.
var body_center_line:Array[Vector2] = []

func _ready() -> void:
	body = [self]
	
	for child in get_children():
		if child is SnakeSprite2D:
			child.top_level = true
			body.append(child)
	
	body_center_line.resize(body.size())
	
func _physics_process(delta):
	#Do not run physics process if in editor (only when playing).
	if Engine.is_editor_hint():
		return
	
	#Change target position in a parent node to follow other nodes like player or enemies.
	if follow_mouse:
		target_position = get_global_mouse_position()
	
	look_at(target_position)
	var acceleration = arrive(target_position, delta)
	velocity += acceleration.limit_length(max_force) * delta
	velocity = velocity.limit_length(max_speed)
	
	move_and_slide()
	#Have two similiar functions here to make the code more understandable and doing one thing at a time.
	#Could combine them with a single for loop.
	update_center_line(delta)
	update_body(delta)
		
	#Code for Line2D.
	if has_node("Line2D"):
		var curve = Curve2D.new()
		for part in body:
			curve.add_point(part.global_position)
		$Line2D.points = curve.get_baked_points()
		$Line2D.global_position = Vector2.ZERO
		$Line2D.global_rotation = 0.0
	
#Center line is the snake "spine" and adds the follow movement to the snake.
#It works like a simple chain; B rotates and moves towards A. Then C rotates and moves towards B...
func update_center_line(delta):
	#start the line at self.
	body_center_line[0] = global_position
	
	for i in range(1, body.size()):
		#"Body parts" are the SnakeSprite2Ds.
		var body_part_ahead = body[i-1]
		var body_part_center = body_center_line[i]
		var body_part_ahead_center = body_center_line[i-1]
		
		var target_dir = (body_part_ahead_center - body_part_center).normalized()
		
		#We can not target a direction of 0,0.
		if target_dir == Vector2.ZERO:
			target_dir = Vector2.RIGHT
		
		#Do a min angle fix. 
		#Making target_dir towards the actual bodypart instead of the center line gives more accurate results.
		if i < number_parts_calculating_min_angle:
			var ahead_forward_dir = Vector2.RIGHT.rotated(body_part_ahead.global_rotation)
			target_dir = min_angle_fix(target_dir, ahead_forward_dir, delta)
		
		body_center_line[i] = body_part_ahead_center - target_dir * parts_seperation
		
#This function adds wavy movement and offsets the body from the center line.
func update_body(delta):
	#The "time" variable sampled later in the equation sin(frequency * time * 2.0 * PI) * amplitude.
	time_contraction += delta * maxf(velocity.length() * speed_contraction_factor, speed_contraction_min)
	time_wave += delta * maxf(velocity.length() * speed_wave_factor, speed_wave_min)
	
	for i in range(1, body.size()):
		var body_part = body[i]
		var body_part_center = body_center_line[i]
		var body_part_ahead_center = body_center_line[i-1]
		
		var wave = sample_wave_and_contraction(i)
		wave = wave.rotated(body_part.global_rotation)
		
		#The more velocity the bigger the wave.
		wave = wave * maxf(velocity.length() / max_speed, 1.0 - rest_stretching_factor)
		
		#Rotate and position away from center line.
		body_part.global_rotation = (body_part_ahead_center - body_part_center).normalized().angle()
		body_part.global_position = body_part_center + wave
		
		#Some fun random jitter.
		body_part.global_rotation += randf_range(-PI, PI) * random_jitter_factor
		
#Prevent the snake from bending too much. 
#if you move it right and then directly left you will notice how it moves inside itself. 
#We can fix it by recalculating the target direction if the angle is too small; 
#we take the target direction of the body part and check it with dot- and cross products against the forward vector of the body part ahead. 
func min_angle_fix(target_dir, ahead_forward_dir, delta):
	#target_dir and ahead_forward_dir are normalized vectors.
	#Dot product gives us the angle between the two vectors in the form -1 (oposite direction) to 1 (same direction) (1 because they have a length of 1).
	var dot_product = target_dir.dot(ahead_forward_dir)
	#This difference between normalized vectors can also be represented as an angle.
	#Acos converts the dot product to an angle.
	var angle_to_straight = rad_to_deg(acos(dot_product))
	#The cross product tells us if target_dir is to the left or to the right of ahead_forward_dir, enabling us to rotate in the correct direction.
	var cross_product = target_dir.cross(ahead_forward_dir)

	if angle_to_straight > parts_min_angle:
		var target_dir_straightened
		if cross_product > 0:
			target_dir_straightened = ahead_forward_dir.rotated(deg_to_rad(-parts_min_angle))
		else:
			target_dir_straightened = ahead_forward_dir.rotated(deg_to_rad(parts_min_angle))
		
		target_dir = target_dir.slerp(target_dir_straightened, delta * parts_min_angle_speed)
		
	return target_dir
		
#Gets a single point from a curve. Consider adding noise or something else to sample from and give the snake unique movement.
func sample_wave_and_contraction(offset):
	var amplitude_shaven = amplitude * amplitude_curve.sample(float(offset) / body.size()) 
	
	var x = sin(frequency_contraction * (time_contraction - offset) * 2.0 * PI) * contraction
	var y = sin(frequency_wave * (time_wave - offset) * 2.0 * PI) * amplitude_shaven
	
	return Vector2(x, y)
		
#A simple arrive function. Google "steering behaviors" to learn more. 
func arrive(target : Vector2, delta):
	var target_acceleration = Vector2.ZERO
	var to_target = target - global_position
	var distance = to_target.length()-arrive_distance
	var desired_velocity
	
	if distance > arrive_slowdown_distance:
		desired_velocity = to_target.normalized() * max_speed 
	else:
		desired_velocity = to_target.normalized() * max_speed * (distance / arrive_slowdown_distance)
	desired_velocity = desired_velocity.limit_length(max_speed)
	target_acceleration = (desired_velocity - velocity)/delta * arrive_slowdown_factor
		
	return target_acceleration

#A tool function to display configuration warnings.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	
	var found_body = false
	for child in get_children():
		if child is SnakeSprite2D:
			found_body = true
			break
			
	if !found_body:
		warnings.append("Add SnakeSprite2D nodes as children to this node for visualizing the snake.")
	
	return warnings
