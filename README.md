# Snake 2D for Godot
Snake 2D is a Godot Engine (v4.5.1) plugin for 2D snake-like movement.

Cool Wiggler | Leviathan | Restless Thing
--- | --- | ---
![Cool Wiggler](./images/cool_wiggler.gif) | ![Leviathan](./images/leviathan.gif) | ![Restless Thing](./images/restless_thing.gif)

## Contents
This plugin adds two extra nodes to a Godot project:
* SnakeBody2D
* SnakeSprite2D

SnakeBody2D is for steering the snake and has all the snake movement logic.
SnakeSprite2D is just a sprite that "builds" the body of the snake.

A demo scene is included in this repository.
* scenes/snake_2d_demo.tscn

It is optional and not needed for the plugin to work.

## How it works
The SnakeBody2D saves positions in regular distances to itself. 
This creates a "center line" that starts at the head and ends by the tail of the snake.
A sinewave is sampled for each SnakeSprite2D.
The resulting position is rotated and becomes an offset from the center line, that is then applied to the SnakeSprite2D.
The sprites now follow the body, like a snake. 

![Sine follow path](./images/sine.png)

Lastly, effects were added like contraction and jitter to make the movement more interesting and fun.

## Usage
The plugin is located in the addons/snake_2d folder.
Download the repository like a normal plugin for godot.
Place the addons folder with its contents inside your root Godot project directory.
Go to Project/Project Settings/Plugins and enable the plugin.

Add a SnakeBody2D node to a scene. 
Add multiple SnakeSprite2D nodes as children to the SnakeBody2D node.
Add some textures to the sprites and run the scene to test it.

Uncheck SnakeBody2D.follow_mouse.
Define SnakeBody2D.target_position in a parent node to follow enemies or the player or anything that has a position.

Want a Line2D instead of sprites? Add a Line2D node as child of SnakeBody2D.
You still need SnakeSprite2D nodes but you can keep the texture properties empty.

Play around with the exported values to get the desired movement.
