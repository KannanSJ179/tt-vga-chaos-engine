<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The circuit relies on several modules that generate video bits for particular images based either on formulas or predefined data matrixes, then, according to the coordinates x and y of the sync generator (current pixel position) and the position defined for the image/sprite it outputs video data or the main circuit paints the blue background.

- Corsshair: paints the cross that represent game cursor to indicate where an explossion will occur, is manually moved by the player.
- Explosion: a formula-based image/sprite that paints a growing/shrinking square from 4x4 to 48x48 in white representing an anti-aereal bomb defense explosion.
- Fortress: represents the "life" of the player, it is the main target of the incoming missiles waves, supports up to 3 hits per level and the game ends if during the same level it receives the 3 missile hits.
- Game Over Banner: a matrix-based sprite that shows the "GAME OVER" message in red color when the player loses.
- Level Banner: a matrix-based sprite that shows the "LEVEL N" message on the top left of the screen indicating the current level with a number from 0 to 9.
- Missile Starter: a pesudo-random generator for missile starting point indicating also the direction in the x axis so missiles mostly head towards the fortress.
- Missile: draws the line representing the trajectory of a missile in flight in yellow, also, detects colission with explosion and/or fortress based on current pixel colors.
- Start Banner: a matrix-based sprite that shows the "PRESS START" when the game resets or after the game ends to indicate the user how to begin playing.

## How to test

Just connect the monitor and the controller to the corresponding PMODs and play

## External hardware

You must have at least the VGA PMOD plus an monitor supporting 640x480 VGA resolution, ideally you have the GamePad PMOD plus a compatible controller to play the game
