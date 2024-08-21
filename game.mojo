# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from random import seed
from sdl import *
from field import Field
from particle import *

alias width = 600
alias height = 300
alias scale = 3


def main():
    seed()

    # initialize sdl and sub-systems (used for rendering and event handling)
    sdl = SDL(video=True, events=True)
    clock = Clock(sdl, 100)
    mouse = Mouse(sdl)
    renderer = Renderer(Window(sdl, "Dustbin", width * scale, height * scale), RendererFlags.SDL_RENDERER_ACCELERATED)
    tex = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.TARGET, width, height)
    field = Field(width, height)
    rnd = 123456789
    cursor_size = 1
    running = True

    # main game loop
    while running:
        event_list = sdl.event_list()
        for event in event_list:
            if event[].isa[events.QuitEvent]():
                running = False
            if event[].isa[events.MouseWheelEvent]():
                cursor_size = max(0, cursor_size + int(event[].unsafe_get[events.MouseWheelEvent]()[].y))
            # elif event[].isa[events.MouseButtonEvent]():
            #     var mouse_button_event = event[].unsafe_take[events.MouseButtonEvent]()
            #     if mouse_button_event.button == 1:
            #         field[int(mouse_button_event.x), int(mouse_button_event.y)] = 1

        mouse_x = mouse.get_position()[0] // scale
        mouse_y = mouse.get_position()[1] // scale

        # spawn particles at cursor position
        if mouse.get_buttons() & 1:
            for x in range(max(mouse_x - cursor_size, 0), min(mouse_x + cursor_size + 1, field.width)):
                for y in range(max(mouse_y - cursor_size, 0), min(mouse_y + cursor_size + 1, field.height)):
                    field[x, y] = sand(not field.skip)
        if mouse.get_buttons() & 2:
            for x in range(max(mouse_x - cursor_size, 0), min(mouse_x + cursor_size + 1, field.width)):
                for y in range(max(mouse_y - cursor_size, 0), min(mouse_y + cursor_size + 1, field.height)):
                    field[x, y] = empty()
        elif mouse.get_buttons() & 4:
            for x in range(max(mouse_x - cursor_size, 0), min(mouse_x + cursor_size + 1, field.width)):
                for y in range(max(mouse_y - cursor_size, 0), min(mouse_y + cursor_size + 1, field.height)):
                    field[x, y] = water(not field.skip)

        update(field, rnd)
        draw(field, tex, renderer)
        clock.tick()


fn update(inout field: Field, inout rnd: Int):
    
    # is the cell empty
    @parameter
    fn empty(x: Int, y: Int) -> Bool:
        if 0 <= x < field.width and 0 <= y < field.height:
            return field[x, y].type == 0
        return False

    # is the particle at (x, y) less dense than p
    @parameter
    fn thinner(p: Particle, x: Int, y: Int) -> Bool:
        if 0 <= x < field.width and 0 <= y < field.height:
            return field[x, y].type < p.type
        return False

    # swap particles
    @parameter
    fn swap(x1: Int, y1: Int, x2: Int, y2: Int):
        var p1 = field[x1, y1]
        var p2 = field[x2, y2]
        p1.skip = field.skip
        field[x1, y1] = p2
        field[x2, y2] = p1

    # random number generator
    @parameter
    fn rand() -> Int:
        rnd = (rnd ^ 61) ^ (rnd >> 16)
        rnd = rnd + (rnd << 3)
        rnd = rnd ^ (rnd >> 4)
        rnd = rnd * 0x27d4eb2d
        rnd = rnd ^ (rnd >> 15)
        return rnd

    # randomly returns either 1 or -1
    @parameter
    fn sign() -> Int:
        return ((rand() % 2) * 2) - 1

    # randomly returns either 2, 1, 0, -1 or -2
    @parameter
    fn dir() -> Int:
        return (rand() % 5) - 2

    # loop over all particles
    for y in range(field.height):
        for x in range(field.width):
            var particle = field[x, y]
            field[x, y].skip = field.skip

            # particle already updated, continue
            if particle.skip == field.skip:
                continue

            # update the sand particle
            if particle.type == 3:
                if thinner(particle, x, y + 1):
                    swap(x, y, x, y + 1)
                    continue

                var xo = sign()

                if thinner(particle, x + xo, y + 1):
                    swap(x, y, x + xo, y + 1)
                # elif thinner(particle, x - xo, y + 1):
                #     swap(x, y, x - xo, y + 1)

            # update the water particle
            elif particle.type == 2:
                if thinner(particle, x, y - 1) and (rand() % 10000) == 1:
                    field[x, y] = vapor(not field.skip)
                    continue

                if thinner(particle, x, y + 1):
                    swap(x, y, x, y + 1)
                    continue

                var xo = dir()

                if thinner(particle, x + xo, y):
                    swap(x, y, x + xo, y)
                elif thinner(particle, x - xo, y):
                    swap(x, y, x - xo, y)

            # update the vapor particle
            elif particle.type == 1:
                if (rand() % 10000) == 1:
                    field[x, y] = water(not field.skip)
                    continue

                var xo = dir()
                var yo = dir()

                if thinner(particle, x + xo, y + yo):
                    swap(x, y, x + xo, y + yo)
                # elif thinner(particle, x + xo, y - yo):
                #     swap(x, y, x + xo, y - yo)
                # elif thinner(particle, x - xo, y + yo):
                #     swap(x, y, x - xo, y + yo)
                # elif thinner(particle, x - xo, y - yo):
                #     swap(x, y, x - xo, y - yo)

    field.skip = not field.skip


def draw(field: Field, tex: Texture, renderer: Renderer):
    alias clear_color = Color(12, 8, 4)
    renderer.set_target(tex)
    renderer.set_color(clear_color)
    renderer.clear()

    for x in range(field.width):
        for y in range(field.height):
            var particle = field[x, y]
            if particle.type == 3:
                renderer.set_color(particle.color)
                renderer.draw_point[DType.int32](x, y)
            elif particle.type  == 2:
                renderer.set_color(particle.color)
                renderer.draw_point[DType.int32](x, y)
            elif particle.type  == 1:
                renderer.set_color(particle.color)
                renderer.draw_point[DType.int32](x, y)

    renderer.reset_target()
    renderer.copy(tex, None)
    renderer.present()