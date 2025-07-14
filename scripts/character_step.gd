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
## Use distance to override the distance step_up checks for steps. Defaultly uses half of the collider size.
## Use direction to override the direction step_up checks for steps. Defailtly uses body.velocity without body.velocity.y
## 
## Returns a Dictionary of the ledge position and ledge normal
static func step_up(body : CharacterBody3D, collider : CollisionShape3D, max_step_height : float, distance : float = -1.0, direction : Vector3 = Vector3.INF) -> Dictionary:
	const BAD_POSITION = {"point":Vector3.INF, "normal":Vector3.INF}
	if body.velocity.is_zero_approx():
		return BAD_POSITION
	
	var body_test_result = PhysicsTestMotionResult3D.new()
	var body_test_params = PhysicsTestMotionParameters3D.new()
	
	var vel_normalized : Vector3 = direction if direction.is_normalized() else direction.normalized()
	if (direction.is_equal_approx(Vector3.INF)):
		# remove gravity to project straight forward
		vel_normalized = Vector3(body.velocity.x, 0.0, body.velocity.z).normalized()
	
	var collider_width : float = distance
	if distance < 0.0:
		# colision projections will go forward 1/4 the width of the collider
		if "radius" in collider.shape:
			collider_width = collider.shape.radius / 2.0
		elif "size" in collider.shape:
			collider_width = (collider.shape.size.z / 2.0) / 2.0
	
	body_test_params.from = body.global_transform
	body_test_params.motion = vel_normalized * collider_width
	
	
	# project forward #
	if !PhysicsServer3D.body_test_motion(body.get_rid(), body_test_params, body_test_result):
		return BAD_POSITION
	
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
		return BAD_POSITION
	
	if body.floor_max_angle < Vector3.UP.angle_to(body_test_result.get_collision_normal()):
		return BAD_POSITION
	
	# the returned position is at the height of the step and the distance of the first projection forward (aka the step ledge)
	return {"point": body_test_result.get_collision_point(), "normal": body_test_result.get_collision_normal()}

## Snap intersect ray to the ground below origin, making it parallel to the ground.
## Will not raycast if ground is not found, unless allways_cast is set true.
## Will exclude RIDs passed into exclude array. Use CollisionObject3D.get_rid() to get the RID associated with a CollisionObject3D-derived node.
##
## Returns the results of the intersect_ray parallel to the ground or empty Dictionary if no collision.
## Returns {"error":"message"} if allways_cast is false and ray could not be aligned to ground.
static func snapped_intersect_ray(space_state : PhysicsDirectSpaceState3D, origin : Vector3, direction : Vector3, length : float, allways_cast : bool = false, exclude : Array = [], stabilizer_width : float = 0.01, stabilizer_height : float = 0.3) -> Dictionary:
	# visualization of rays
	#  A__B
	#  |\ |
	#  | \|
	#  X__C___x
	#  |
	#  |
	#  Y
	#
	# X = origin
	# A = stabilizer origin
	#
	# X->Y = floor normal ray (stabilizer_height + (stabilizer_height/2))
	# B->C = front stabalizer ray (stabilizer_height + VERTICAL_EXTENSION + slope_adjustment)
	# b->c = back stabalizer ray (stabilizer_height + VERTICAL_EXTENSION + slope_adjustment)
	# X->x = floor aligned raytrace (length)
	#
	# X->A = (stabilizer_height)
	# A->B = (stabilizer_width)
	const VERTICAL_EXTENSION : float = 0.2
	var query : PhysicsRayQueryParameters3D = null
	
	query = PhysicsRayQueryParameters3D.create(Vector3(origin.x, origin.y + (stabilizer_height * 0.5), origin.z), Vector3(origin.x, origin.y - stabilizer_height, origin.z))
	query.exclude = exclude
	var init_result : Dictionary = space_state.intersect_ray(query)
	if !init_result:
		if allways_cast:
			query = PhysicsRayQueryParameters3D.create(origin, origin + (direction * length))
			query.exclude = exclude
			return space_state.intersect_ray(query)
		else:
			return {"error":"no ground"} # no ground
	
	var floor_normal : Vector3 = init_result.normal
	var floor_angle : float = Vector3.UP.angle_to(floor_normal) if Vector3.UP.angle_to(floor_normal) < deg_to_rad(90.0) else deg_to_rad(89.9) # clamp floor angle
	
	if !direction.is_normalized():
		direction = direction.normalized()
	
	# front stabilizer ray
	var A : Vector3 = Vector3(origin.x, origin.y + stabilizer_height, origin.z)
	var B : Vector3 = A + (direction * stabilizer_width)
	var slope_adjustment : float = (A.distance_to(B) * tan(floor_angle)) # doesn't work with 90 deg or greater
	var height : float = stabilizer_height + slope_adjustment + VERTICAL_EXTENSION
	var C : Vector3 = Vector3(B.x, B.y - height, B.z)
	
	query = PhysicsRayQueryParameters3D.create(B,C)
	query.exclude = exclude
	var front_result : Dictionary = space_state.intersect_ray(query)
	
	# back stabilizer ray
	var b : Vector3 = A
	var c : Vector3 = Vector3(b.x, b.y - height, b.z)
	
	query = PhysicsRayQueryParameters3D.create(b,c)
	query.exclude = exclude
	var back_result : Dictionary = space_state.intersect_ray(query)
	
	# floor aligned ray
	var dir : Vector3 = origin + (direction * length)
	var start : Vector3 = origin
	if front_result and back_result:
		dir = (front_result.position - back_result.position).normalized()
		start = back_result.position
		start.y += 0.01 # small height adjustment to keep ray out of ground
	elif !allways_cast:
		return {"error":"stabilizer leg fail"} # trouble aligning 
	
	
	query = PhysicsRayQueryParameters3D.create(start, start + (dir * length))
	query.exclude = exclude
	return space_state.intersect_ray(query)
