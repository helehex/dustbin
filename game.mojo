# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from random import seed
from collections import Optional
from sdl import *
from field import *
from camera import Camera
from particle import *


alias fps = 100


def main():
    seed()

    # initialize sdl and sub-systems (used for rendering and event handling)
    sdl = SDL(video=True, events=True)
    clock = Clock(sdl, fps)
    mouse = Mouse(sdl)
    keyboard = Keyboard(sdl)

    screen_size = (1200, 800)
    window = Window(sdl, "Dustbin", screen_size[0], screen_size[1])
    renderer = Renderer(window^, -1, RendererFlags.SDL_RENDERER_SOFTWARE)
    camera = Camera(renderer)
    field = Field()
    cursor_size = 1
    
    selected = sand
    running = True
    frame_count = 0
    smooth_fps = 0.0

    # main game loop
    while running:
        var step = False

        # handle events
        event_list = sdl.event_list()
        for event in event_list:
            if event[].isa[events.QuitEvent]():
                running = False
            elif event[].isa[events.WindowEvent]():
                var e = event[].unsafe_take[events.WindowEvent]()
                if e.event == events.WindowEventID.WINDOWEVENT_SIZE_CHANGED.cast[DType.uint8]():
                    camera.on_size_changed(renderer)
            elif event[].isa[events.MouseWheelEvent]():
                cursor_size = max(0, cursor_size + int(event[].unsafe_get[events.MouseWheelEvent]()[].y))
            elif event[].isa[events.KeyDownEvent]():
                var e = event[].unsafe_take[events.KeyDownEvent]()
                if e.keysym.scancode == KeyCode.SPACE:
                    field.run = not field.run
                if e.keysym.scancode == KeyCode.F:
                    field.run = True
                    step = True
                elif e.keysym.scancode == KeyCode.EQUALS:
                    camera.set_scale(camera.view_scale + 1, renderer)
                elif e.keysym.scancode == KeyCode.MINUS:
                    camera.set_scale(camera.view_scale - 1, renderer)
                elif e.keysym.scancode == KeyCode._1:
                    selected = fire
                elif e.keysym.scancode == KeyCode._2:
                    selected = vapor
                elif e.keysym.scancode == KeyCode._3:
                    selected = dust
                elif e.keysym.scancode == KeyCode._4:
                    selected = water
                elif e.keysym.scancode == KeyCode._5:
                    selected = sand
                elif e.keysym.scancode == KeyCode._6:
                    selected = stone

        mouse_pos = mouse.get_position()
        cursor_pos = camera.view2field(mouse_pos[0] // camera.view_scale, mouse_pos[1] // camera.view_scale)

        # spawn particles at cursor position if dropping is not none
        dropping = Optional[fn(field: Field, skip: Bool = False) -> Particle](None)
        if mouse.get_buttons() & 1:
            dropping = selected
        elif mouse.get_buttons() & 2:
            dropping = space
        elif mouse.get_buttons() & 4:
            dropping = fire
        if dropping:
            for x in range(max(cursor_pos[0] - cursor_size, 0), min(cursor_pos[0] + cursor_size + 1, width)):
                for y in range(max(cursor_pos[1] - cursor_size, 0), min(cursor_pos[1] + cursor_size + 1, height)):
                    field[x, y] = dropping.unsafe_value()(field)

        # update field and camera
        field.update(keyboard)
        camera.update(keyboard)
        if step:
            step = False
            field.run = False

        # draw field
        camera.draw(field, renderer)

        # draw cursor
        var sp = selected(field)
        renderer.set_color(Color(sp.r, sp.g, sp.b, 127))
        renderer.set_blendmode(BlendMode.ADD)
        renderer.draw_rect(Rect(mouse_pos[0] - cursor_size*camera.view_scale, mouse_pos[1] - cursor_size*camera.view_scale, cursor_size*camera.view_scale*2, cursor_size*camera.view_scale*2))
        renderer.present()

        # limit fps
        clock.tick()
        frame_count += 1
        smooth_fps = (smooth_fps * 0.9) + (0.1/clock.delta_time)
        if frame_count % 100 == 1:
            print("fps: ", int(smooth_fps))
