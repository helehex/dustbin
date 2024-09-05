# Dustbin

A falling sand game demo, written in Mojo.

Currently, Dustbin uses the latest Mojo nightly version:  
`mojo 2024.9.505 (db76a77f)`.

To run dustbin, you need to have sdl installed:  
`sudo apt install libsdl2-dev`

Then run:  
`mojo game.mojo`

## Controls:
- Number keys to select element
- Left click to place selected element
- Right click to place fire
- Middle click to erase
- Scroll wheel to change placement size
- Plus and Minus to zoom camera
- W A S D to move camera
- Space to pause
- F to step one frame

> Dependecies:  
> You can find the sdl-bindings package used for rendering [here](https://github.com/Ryul0rd/sdl-bindings)