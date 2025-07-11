# Character Step
These files are for a playable demo that include the main script that handles the step up/down functionality, as well as a basic third person controller and the demo level.

Go to [Scripts/character_step.gd](https://github.com/PantheraDigital/GodotCharacterStep/blob/main/scripts/character_step.gd) if you just want the file without the demo level and player controller.

Play the demo here: https://pantheraonline.itch.io/godot-characterstep-demo



https://github.com/user-attachments/assets/9c2834e0-623b-409f-9874-5603fcfb5348



https://github.com/user-attachments/assets/32aec206-cc72-4d67-9d82-e5840932d47a



## Purpose: 
This static class helps CharacterBody3D objects ascend and descend ledges such as stairs.
PhysicsServer3D.body_test_motion() is used to project the character as if they were 
moving up the ledge to test for collision. Then either a clear position is returned 
or the CharacterBody3D’s original position, where the body was before the projection, 
is returned to indicate the ledge can not be ascended or descended.

## Usage:
Be sure to utilize these methods within the CharacterBody3D’s _physics_process() 
and to use if statements to reduce the number of unnecessary calls. 
For step_up I recommend at least preventing calls if not moving.
For step_down I recommend having a was_on_floor bool, in a leading if statement as well 
as calling when velocity.y <= 0 and not is_on_floor(). 
was_on_floor should be set to is_on_floor() at the beginning of _physics_process() 
to determine if the CharacterBody3D was on a floor before it was moved.

step_up should come BEFORE move_and_slide \
move_and_slide will smooth the movement of the character after step_up

step_down should come AFTER move_and_slide \
this is because if the player is not grounded but they were grounded before they moved
then they have stepped off a ledge and it should be checked if they can step_down
 
 
## Inspired by Godot: Stair-stepping Demo addon 
https://github.com/kelpysama/Godot-Stair-Step-Demo/tree/main

It did not quite work for me for my third person controller so I built my own, 
taking some techniques from it, but remaking it to work as a static class so it can 
easily be added to any character scripts.
