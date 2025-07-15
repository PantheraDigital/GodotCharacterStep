# Character Step
These files are for a playable demo that include the main script that handles the step up/down functionality, as well as a basic third person controller and the demo level.

Go to [Scripts/character_step.gd](https://github.com/PantheraDigital/GodotCharacterStep/blob/main/scripts/character_step.gd) if you just want the file without the demo level and player controller.

Play the demo here: https://pantheraonline.itch.io/godot-characterstep-demo



https://github.com/user-attachments/assets/9c2834e0-623b-409f-9874-5603fcfb5348



https://github.com/user-attachments/assets/32aec206-cc72-4d67-9d82-e5840932d47a



## Purpose:
This static class helps CharacterBody3D objects ascend and descend ledges such as stairs.
 
 
## Usage:
Be sure to utilize these methods within the CharacterBody3D’s _physics_process() and to limit step_down and step_up calls when possible.
For example they don't need to be called if not moving. step_down() does not need to be called unless the CharacterBody3D is falling.
step_up() does not need to be called unless there is a wall/unwalkable surface in front of CharacterBody3D.

step_up should come BEFORE move_and_slide \
It is designed to look ahead be used before applying movement to the character.

step_down should come AFTER move_and_slide \
It is designed to fix character position after movement has been applied.
 
 
## Inspired by Godot: Stair-stepping Demo addon 
https://github.com/kelpysama/Godot-Stair-Step-Demo/tree/main

It did not quite work for me for my third person controller so I built my own, 
taking some techniques from it, but remaking it to work as a static class so it can 
easily be added to any character scripts.
