@icon("./snake_body_2d_icon.svg")
extends CharacterBody2D

#Copyright (c) 2025 DwellerComplex (Crumblebit www.crumblebit.com) under MIT license.
#https://github.com/DwellerComplex/godot-snake2d
#Thank you for using my stuff! 

## Base scene for snake movement.
##Add SnakeSprite2D nodes as children.
##Want a Line2D instead of sprites? Add a Line2D node as child of this node.
##You still need SnakeSprite2D nodes but you can keep the texture properties empty.
class_name SnakeBody2D

@export_group("Arrive")
##Defaults to mouse position if no node is assigned. 
@export var target_node:Node2D
##Distance from target where the snake "has arrived" and comes to a stop.
@export var arrive_distance = 10
##Distance from target where the snake begins to slow down. Should always be higher than Arrive Distance.
@export var arrive_slowdown_distance = 200
##A more aggresive slowdown factor to avoid overshooting the target.
@export var arrive_slowdown_factor = 5

@export var max_force = 100000
@export var max_speed = 400

@export_group("Sample Curves")
@export var amplitude_curve:Curve = preload("snake_2d_curve.tres")
##Amplitude amount. 
@export var amplitude = 8.0
@export_range(0.0, 0.5, 0.01, "or_greater") var wave_frequency = 0.1
##How much the snakes current velocity contributes to the wave speed.
@export_range(0.0, 0.5, 0.01, "or_greater") var wave_speed_factor = 0.15
##Minimum waviness. Set to 0 for no wave when the snake is not moving forward (0 velocity).
@export var wave_speed_min = 4.0
##Contraction amount. Around 20 gives a nice effect.
@export var contraction = 0.0
@export_range(0.0, 0.3, 0.01, "or_greater") var contraction_frequency = 0.02
##How much the snakes current velocity contributes to the contraction speed.
@export_range(0.0, 1.0, 0.01, "or_greater") var contraction_speed_factor = 0.3
##Minimum contraction. Set to 0 for no contraction when the snake is not moving forward (0 velocity).
@export var contraction_speed_min = 0.1

@export_group("Body Parts")
##Set to false to ignore max_bend_angle and allow the snake to move into itself. 
##Set to true to preventing the snake from bending too much.
@export var unbend_snake = true
##The speed at which the SnakeSprite2Ds rotate away from each other.
@export var unbend_speed = 20
##If max_bend_angle is smaller than the SnakeSprite2Ds rotations to each other, they try to "stretch out" the snake.
##Preventing the snake from bending too much.
##So, smaller angle means less bending, bigger angle means more bending.
@export_range(0, 360) var max_bend_angle:int = 20 
##Distance between SnakeSprite2Ds.
@export var parts_separation = 7

@export_group("Extra")
##Uncheck to override the global gravity completely with gravity_factor.
@export var use_project_settings_gravity = false
##Use small numbers like 0.01 for a more floaty effect if using global gravity. If 'x' is not working, make sure it is not 0 in the project settings.
@export var gravity_factor = Vector2.ZERO
##Speed based amplitude. Makes the snake less wavy the closer it is to standing still.
@export_range(0.0, 1.0, 0.01) var wave_damping_factor = 0.5
##Speed based parts separation. Makes the snake shorter the closer it is to standing still. 
@export_range(0.0, 0.9, 0.01) var compression_factor = 0.0
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
	#Set target_position to target_node. Defaults to mouse position if there is no target_node.
	var target_position = get_global_mouse_position()
	if is_instance_valid(target_node):
		target_position = target_node.global_position
	
	look_at(target_position)
	var acceleration = arrive(target_position, delta)
	velocity += acceleration.limit_length(max_force) 
	velocity = velocity.limit_length(max_speed)
	
	move_and_slide()
	#Have two similar functions here to make the code more understandable and doing one thing at a time.
	#Could combine them with a single for loop.
	update_center_line(delta)
	update_body(delta)
		
	#Code for Line2D.
	if has_node("Line2D"):
		var line = $Line2D
		var curve = Curve2D.new()
		for i in range(1, body.size()):
			#The first point is self and not body so we skip it.
			curve.add_point(body[i].global_position)
		line.points = curve.get_baked_points()
		line.global_position = Vector2.ZERO
		line.global_rotation = 0.0
	
#Center line is the snake "spine" and adds the follow movement to the snake.
#It works like a simple chain; B rotates and moves towards A. Then C rotates and moves towards B...
func update_center_line(delta):
	#Get gravity.
	var gravity = gravity_factor * delta 
	if use_project_settings_gravity == true:
		gravity *= get_gravity()
		
	#The more velocity the more seperation of body parts.
	var parts_separation_clamped = parts_separation * maxf(velocity.length() / max_speed, 1.0 - compression_factor)
	
	#Start the line at self.
	body_center_line[0] = global_position
	
	for i in range(1, body.size()):
		#"Body parts" are the SnakeSprite2Ds.
		var body_part_ahead = body[i-1]
		var body_part_center = body_center_line[i] 
		var body_part_ahead_center = body_center_line[i-1]
		
		#Apply gravity.
		body_part_center += gravity
		
		var target_dir = (body_part_ahead_center - body_part_center).normalized()
		
		#We can not target a direction of 0,0.
		if target_dir == Vector2.ZERO:
			target_dir = Vector2.RIGHT
		
		if unbend_snake == true:
			var ahead_forward_dir = Vector2.RIGHT.rotated(body_part_ahead.global_rotation)
			target_dir = unbend(target_dir, ahead_forward_dir, delta)
		
		body_center_line[i] = body_part_ahead_center - target_dir * parts_separation_clamped
		
#This function adds wavy movement and offsets the body from the center line.
func update_body(delta):
	#The "time" variable sampled later in the equation sin(frequency * time * 2.0 * PI) * amplitude.
	time_contraction += delta * maxf(velocity.length() * contraction_speed_factor, contraction_speed_min)
	time_wave += delta * maxf(velocity.length() * wave_speed_factor, wave_speed_min)
	
	for i in range(1, body.size()):
		var body_part = body[i]
		var body_part_center = body_center_line[i]
		var body_part_ahead_center = body_center_line[i-1]
		
		var wave = sample_wave_and_contraction(i)
		wave = wave.rotated(body_part.global_rotation)
		
		#The more velocity the bigger the wave.
		wave *= maxf(velocity.length() / max_speed, 1.0 - wave_damping_factor)
		
		#Rotate and position away from center line.
		body_part.global_rotation = (body_part_ahead_center - body_part_center).normalized().angle()
		body_part.global_position = body_part_center + wave
		
		#Some fun random jitter.
		body_part.global_rotation += randf_range(-PI, PI) * random_jitter_factor
		
#Prevent the snake from bending too much. 
#if you move it right and then directly left you will notice how it moves inside itself. 
#We can fix it by recalculating the target direction if the angle is too small; 
#We take the target direction of the body part and check it with dot- and cross products against the forward vector of the body part ahead. 
func unbend(target_dir, ahead_forward_dir, delta):
	#target_dir and ahead_forward_dir are normalized vectors.
	#Dot product gives us the angle between the two vectors in the form -1 (opposite direction) to 1 (same direction) (1 because they have a length of 1).
	var dot_product = target_dir.dot(ahead_forward_dir)
	#This difference between normalized vectors can also be represented as an angle.
	#Acos converts the dot product to an angle.
	var angle_to_straight = rad_to_deg(acos(dot_product))
	#The cross product tells us if target_dir is to the left or to the right of ahead_forward_dir, enabling us to rotate in the correct direction.
	var cross_product = target_dir.cross(ahead_forward_dir)

	if angle_to_straight > max_bend_angle:
		var target_dir_straightened
		if cross_product > 0:
			target_dir_straightened = ahead_forward_dir.rotated(deg_to_rad(-max_bend_angle))
		else:
			target_dir_straightened = ahead_forward_dir.rotated(deg_to_rad(max_bend_angle))
		
		target_dir = target_dir.slerp(target_dir_straightened, delta * unbend_speed)
		
	return target_dir
		
#Gets a single point from a curve. Consider adding noise or something else to sample from and give the snake unique movement.
func sample_wave_and_contraction(offset):
	var amplitude_shaven = amplitude * amplitude_curve.sample(float(offset) / body.size()) 
	
	#Equation is sin(frequency * time * 2.0 * PI) * amplitude.
	var x = sin(contraction_frequency * (time_contraction - offset) * 2.0 * PI) * contraction
	var y = sin(wave_frequency * (time_wave - offset) * 2.0 * PI) * amplitude_shaven
	
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
	
	target_acceleration = (desired_velocity - velocity) 
	#No idea if this is correct but it seems to work...
	target_acceleration *= (1.0 -exp(-arrive_slowdown_factor*delta))
		
	return target_acceleration
