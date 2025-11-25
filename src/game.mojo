# x--------------------------------------------------------------------------x #
# | Helehex Dustbin
# x--------------------------------------------------------------------------x #

from collections import Optional
from camera import Camera
from world import World, width, height
from particle import *

import sdl

comptime Window = sdl.Ptr[sdl.Window, MutAnyOrigin]
comptime Renderer = sdl.Ptr[sdl.Renderer, MutAnyOrigin]
comptime Texture = sdl.Ptr[sdl.Texture, MutAnyOrigin]
comptime KeyState = Span[Bool, ImmutAnyOrigin]

comptime fps = 100
comptime use_regioning = (True, False)
comptime regioning_pad = (128, 128)


def main():
    # initialize sdl and sub-systems (used for rendering and event handling)
    sdl.init(sdl.InitFlags.INIT_VIDEO | sdl.InitFlags.INIT_VIDEO)

    screen_size = (1200, 700)
    var window = Window()
    var renderer = Renderer()
    sdl.create_window_and_renderer("sdl3 test", screen_size[0], screen_size[1], sdl.WindowFlags(0), sdl.Ptr(to=window), sdl.Ptr(to=renderer))

    camera = Camera(renderer)
    world = World()
    cursor_size = 1
    mouse_pos = (Float32(), Float32())
    cursor_pos = (0, 0)

    selected = sand
    running = True
    frame_count = 0
    smooth_fps = 0.0

    var numkeys = Int32()
    var key_state = Span(ptr=sdl.get_keyboard_state(sdl.Ptr(to=numkeys)), length=Int(numkeys))

    # main game loop
    while running:
        var step = False

        # handle events
        var event = sdl.Event(UInt32(0))
        while sdl.poll_event(UnsafePointer(to=event)):
            event_type = sdl.EventType(Int(event[sdl.CommonEvent].type))
            if event_type == sdl.EventType.EVENT_QUIT:
                running = False
            elif event_type == sdl.EventType.EVENT_WINDOW_PIXEL_SIZE_CHANGED:
                camera.on_size_changed(renderer)
            elif event_type == sdl.EventType.EVENT_MOUSE_WHEEL:
                var mouse_wheel_event = event[sdl.MouseWheelEvent]
                cursor_size = max(0, cursor_size + Int(mouse_wheel_event.y))
            elif event_type == sdl.EventType.EVENT_KEY_DOWN:
                var keyboard_event = event[sdl.KeyboardEvent]
                if keyboard_event.key.value == sdl.Keycode.SDLK_SPACE.value:
                    world.run = not world.run
                if keyboard_event.key.value == sdl.Keycode.SDLK_F.value:
                    world.run = True
                    step = True
                elif keyboard_event.key.value == sdl.Keycode.SDLK_EQUALS.value:
                    camera.set_scale(camera.view_scale + 1, renderer)
                elif keyboard_event.key.value == sdl.Keycode.SDLK_MINUS.value:
                    camera.set_scale(camera.view_scale - 1, renderer)
                elif keyboard_event.key.value == sdl.Keycode.SDLK_1.value:
                    selected = fire
                elif keyboard_event.key.value == sdl.Keycode.SDLK_2.value:
                    selected = vapor
                elif keyboard_event.key.value == sdl.Keycode.SDLK_3.value:
                    selected = dust
                elif keyboard_event.key.value == sdl.Keycode.SDLK_4.value:
                    selected = water
                elif keyboard_event.key.value == sdl.Keycode.SDLK_5.value:
                    selected = sand
                elif keyboard_event.key.value == sdl.Keycode.SDLK_6.value:
                    selected = stone

        var mouse_buttons = sdl.get_mouse_state(UnsafePointer(to=mouse_pos[0]), UnsafePointer(to=mouse_pos[1]))
        cursor_pos = camera.view2world(Int(mouse_pos[0]) // camera.view_scale, Int(mouse_pos[1]) // camera.view_scale)

        # spawn particles at cursor position if dropping is not none
        dropping = Optional[fn(mut world: World, skip: Bool = False) -> Particle](None)
        if mouse_buttons.value & 1:
            dropping = selected
        elif mouse_buttons.value & 2:
            dropping = space
        elif mouse_buttons.value & 4:
            dropping = fire
        if dropping:
            for x in range(max(cursor_pos[0] - cursor_size, 0), min(cursor_pos[0] + cursor_size + 1, width)):
                for y in range(max(cursor_pos[1] - cursor_size, 0), min(cursor_pos[1] + cursor_size + 1, height)):
                    world[x, y] = dropping.unsafe_value()(world)

        # update world
        region = (0, 0, width, height)

        @parameter
        if use_regioning[0]:
            region[0] = camera.view_pos_x - regioning_pad[0]
            region[2] = camera.view_pos_x + camera.view_size_x + regioning_pad[0]

        @parameter
        if use_regioning[1]:
            region[1] = camera.view_pos_y - regioning_pad[1]
            region[3] = camera.view_pos_y + camera.view_size_y + regioning_pad[1]

        world.update(key_state, region)

        # update camera
        camera.update(key_state)

        if step:
            step = False
            world.run = False

        # draw world
        camera.draw(world, renderer)

        # draw cursor
        var sp = selected(world)
        sdl.set_render_draw_color(renderer, sp.r, sp.g, sp.b, 127)
        sdl.set_render_draw_blend_mode(renderer, sdl.BlendMode.BLENDMODE_ADD)
        rect = sdl.FRect(Int(mouse_pos[0]) - cursor_size*camera.view_scale, Int(mouse_pos[1]) - cursor_size*camera.view_scale, cursor_size*camera.view_scale*2, cursor_size*camera.view_scale*2)
        sdl.render_rect(renderer, UnsafePointer(to=rect))
        sdl.render_present(renderer)

        # limit fps
        # clock.tick()
        # frame_count += 1
        # smooth_fps = (smooth_fps * 0.9) + (0.1/clock.delta_time)
        # if frame_count % 100 == 1:
        #     print("fps: ", int(smooth_fps))
