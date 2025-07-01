extends Object
class_name CharacterStep3D

## Purpose:
## This static class helps CharacterBody3D objects ascend and descend ledges such as stairs.
## PhysicsServer3D.body_test_motion() is used to project the character as if they were 
## moving up the ledge to test for collision. Then either a clear position is returned 
## or the CharacterBody3D’s original position, where the body was before the projection, 
## is returned to indicate the ledge can not be ascended or descended.
##
## Usage:
## Be sure to utilize these methods within the CharacterBody3D’s _physics_process() 
## and to use if statements to reduce the number of unnecessary calls. 
## For step_up I recommend at least preventing calls if not moving.
## For step_down I recommend having a was_on_floor bool, in a leading if statement as well 
## as calling when velocity.y <= 0 and not is_on_floor(). 
## was_on_floor should be set to is_on_floor() at the beginning of _physics_process() 
## to determine if the CharacterBody3D was on a floor before it was moved.
##
## step_up should come BEFORE move_and_slide
## move_and_slide will smooth the movement of the character after step_up
##
## step_down should come AFTER move_and_slide
## this is because if the player is not grounded but they were grounded before they moved
## then they have stepped off a ledge and it should be checked if they can step_down

## Inspired by Godot: Stair-stepping Demo addon
## https://github.com/kelpysama/Godot-Stair-Step-Demo/tree/main
##
## It did not quite work for me for my third person controller so I built my own, 
## taking some techniques from it, but remaking it to work as a static class so it can 
## easily be added to any character scripts.


## Project the CharacterBody3D down to find suitable ground to “step down” to.
## Place AFTER CharacterBody3D.move_and_slide()
##
## Returns a global position for the CharacterBody3D to move to. 
##   The position is either a found suitable location to “step down” to, 
##   or the CharacterBody3D’s current global_position indicating no movement can be taken.
static func step_down(body : CharacterBody3D, collider : CollisionShape3D, max_step_height : float, direction : Vector3 = Vector3.INF) -> Vector3:
	var body_test_result = PhysicsTestMotionResult3D.new()
	var body_test_params = PhysicsTestMotionParameters3D.new()
	
	var vel_normalized : Vector3 = direction if (!direction.is_equal_approx(Vector3.INF)) else body.velocity.normalized()
	# colision projections will go forward 1/4 the width of the collider
	var collider_width : float = 0.0
	if "radius" in collider.shape:
		collider_width = collider.shape.radius / 2.0
	elif "size" in collider.shape:
		collider_width = (collider.shape.size.z / 2.0) / 2.0
	
	# slightly forward positions to check if straight down fails
	var mid_point_offset : Vector3 = vel_normalized * (collider_width / 2.0)
	var end_point_offset : Vector3 = vel_normalized * collider_width
	
	body_test_params.from = body.global_transform
	body_test_params.motion = Vector3(0, -max_step_height, 0)
	
	for i in range(3):
		# i == 0 uses body.position
		if i == 1:
			body_test_params.from.origin = body.global_position + mid_point_offset
		elif i == 2:
			body_test_params.from.origin = body.global_position + end_point_offset
		
		if PhysicsServer3D.body_test_motion(body.get_rid(), body_test_params, body_test_result):
			var floor_is_walkable : bool = body.floor_max_angle >= Vector3.UP.angle_to(body_test_result.get_collision_normal())
			if floor_is_walkable:
				var position : Vector3 = body.global_position
				if i == 1:
					position += mid_point_offset
				elif i == 2:
					position += end_point_offset
				position.y += body_test_result.get_travel().y
				return position
		else:
			break # early break if no ground bellow
		
	return body.global_position # not stepping down

## Project the CharacterBody3D up and over a ledge to find suitable ground to “step up” to.
## Place BEFORE CharacterBody3D.move_and_slide()
## 
## Returns a global position for the CharacterBody3D to move to. 
##    The position is either a found suitable location to “step up” to, 
##    or the CharacterBody3D’s current global_position indicating no movement can be taken.
static func step_up(body : CharacterBody3D, collider : CollisionShape3D, max_step_height : float, direction : Vector3 = Vector3.INF) -> Vector3:
	if body.velocity.is_zero_approx():
		return body.global_position
	
	var body_test_result = PhysicsTestMotionResult3D.new()
	var body_test_params = PhysicsTestMotionParameters3D.new()
	
	# colision projections will go forward 1/4 the width of the collider
	var vel_normalized : Vector3 = direction if (!direction.is_equal_approx(Vector3.INF)) else body.velocity.normalized()
	var collider_width : float = 0.0
	if "radius" in collider.shape:
		collider_width = collider.shape.radius / 2.0
	elif "size" in collider.shape:
		collider_width = (collider.shape.size.z / 2.0) / 2.0
		
	body_test_params.from = body.global_transform
	body_test_params.motion = vel_normalized * collider_width
	body_test_params.motion.y = 0.0 # remove gravity to project straight forward
	
	
	# project forward #
	if !PhysicsServer3D.body_test_motion(body.get_rid(), body_test_params, body_test_result):
		return body.global_position
	
	var remaining_forward_vector : Vector3 = body_test_result.get_remainder()
	body_test_params.from = body_test_params.from.translated(body_test_result.get_travel())
	
	
	# project up #
	body_test_params.motion = Vector3(0, max_step_height, 0)
	PhysicsServer3D.body_test_motion(body.get_rid(), body_test_params, body_test_result)
	body_test_params.from = body_test_params.from.translated(body_test_result.get_travel())
	
	
	# project forward remaining forward dist #
	body_test_params.motion = remaining_forward_vector
	PhysicsServer3D.body_test_motion(body.get_rid(), body_test_params, body_test_result)
	body_test_params.from = body_test_params.from.translated(body_test_result.get_travel())
	
	
	# project down #
	body_test_params.motion = Vector3(0, -max_step_height, 0)
	if !PhysicsServer3D.body_test_motion(body.get_rid(), body_test_params, body_test_result):
		return body.global_position
	
	if body.floor_max_angle < Vector3.UP.angle_to(body_test_result.get_collision_normal()):
		return body.global_position
	
	body_test_params.from = body_test_params.from.translated(body_test_result.get_travel())
	# the returned position is at the height of the step and the distance of the first projection forward (aka the step ledge)
	return body_test_params.from.origin - remaining_forward_vector
