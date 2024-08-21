# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from random import seed
from sdl import *
from field import Field
from particle import *

alias width = 1000
alias height = 600
alias scale = 2
alias fps = 100


def main():
    seed()

    # initialize sdl and sub-systems (used for rendering and event handling)
    sdl = SDL(video=True, events=True)
    clock = Clock(sdl, fps)
    mouse = Mouse(sdl)
    renderer = Renderer(Window(sdl, "Dustbin", width * scale, height * scale), RendererFlags.SDL_RENDERER_ACCELERATED)
    tex = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, width, height)
    field = Field(width, height)
    rnd = 123456789
    cursor_size = 1
    selected = sand
    running = True
    frame_count = 0

    # main game loop
    while running:
        event_list = sdl.event_list()
        for event in event_list:
            if event[].isa[events.QuitEvent]():
                running = False
            elif event[].isa[events.MouseWheelEvent]():
                cursor_size = max(0, cursor_size + int(event[].unsafe_get[events.MouseWheelEvent]()[].y))
            elif event[].isa[events.KeyDownEvent]():
                var e = event[].unsafe_take[events.KeyDownEvent]()
                if e.keysym.scancode == KeyCode._1:
                    selected = fire
                elif e.keysym.scancode == KeyCode._2:
                    selected = vapor
                elif e.keysym.scancode == KeyCode._3:
                    selected = dust
                elif e.keysym.scancode == KeyCode._4:
                    selected = water
                elif e.keysym.scancode == KeyCode._5:
                    selected = sand

        mouse_x = mouse.get_position()[0] // scale
        mouse_y = mouse.get_position()[1] // scale

        # spawn particles at cursor position
        if mouse.get_buttons() & 1:
            for x in range(max(mouse_x - cursor_size, 0), min(mouse_x + cursor_size + 1, field.width)):
                for y in range(max(mouse_y - cursor_size, 0), min(mouse_y + cursor_size + 1, field.height)):
                    field[x, y] = selected(not field.skip)
        if mouse.get_buttons() & 2:
            for x in range(max(mouse_x - cursor_size, 0), min(mouse_x + cursor_size + 1, field.width)):
                for y in range(max(mouse_y - cursor_size, 0), min(mouse_y + cursor_size + 1, field.height)):
                    field[x, y] = space(not field.skip)
        elif mouse.get_buttons() & 4:
            for x in range(max(mouse_x - cursor_size, 0), min(mouse_x + cursor_size + 1, field.width)):
                for y in range(max(mouse_y - cursor_size, 0), min(mouse_y + cursor_size + 1, field.height)):
                    field[x, y] = fire(not field.skip)

        # update field
        update(field, rnd)

        # draw field
        draw(field, tex, renderer, mouse)

        # draw cursor
        renderer.set_color(Color(255, 255, 255, 0))
        renderer.set_blendmode(BlendMode(BlendMode.MUL))
        renderer.draw_rect(Rect(mouse.get_position()[0] - cursor_size*scale, mouse.get_position()[1] - cursor_size*scale, cursor_size*scale*2, cursor_size*scale*2))
        renderer.present()

        # limit fps
        clock.tick()
        frame_count += 1
        # if frame_count % 100 == 1:
        #     print(1/clock.delta_time)


fn update(inout field: Field, inout rnd: Int):
    
    # is the cell empty
    @parameter
    @always_inline
    fn empty(x: Int, y: Int) -> Bool:
        if 0 <= x < field.width and 0 <= y < field.height:
            return field[x, y].type == 0
        return False

    # is the particle p denser than the particle at (x, y)
    @parameter
    @always_inline
    fn denser(p: Particle, x: Int, y: Int) -> Bool:
        if 0 <= x < field.width and 0 <= y < field.height:
            return field[x, y].type < p.type
        return False

    # swap particles
    @parameter
    @always_inline
    fn swap(x1: Int, y1: Int, x2: Int, y2: Int):
        var p1 = field[x1, y1]
        var p2 = field[x2, y2]
        p1.skip = field.skip
        field[x1, y1] = p2
        field[x2, y2] = p1

    # random number generator
    @parameter
    @always_inline
    fn rand() -> Int:
        rnd = (rnd ^ 61) ^ (rnd >> 16)
        rnd = rnd + (rnd << 3)
        rnd = rnd ^ (rnd >> 4)
        rnd = rnd * 0x27d4eb2d
        rnd = rnd ^ (rnd >> 15)
        return rnd

    # randomly returns either 1 or -1
    @parameter
    @always_inline
    fn sign() -> Int:
        return ((rand() % 2) * 2) - 1

    # randomly returns either 2, 1, 0, -1 or -2
    @parameter
    @always_inline
    fn dir() -> Int:
        return (rand() % 7) - 3

    # loop over all particles
    for y in range(field.height):
        for x in range(field.width):
            var particle = field[x, y]
            field[x, y].skip = field.skip

            # particle already updated, continue
            if particle.skip == field.skip:
                continue

            # update the sand particle
            if particle.type == 5:
                if empty(x, y + 1):
                    swap(x, y, x, y + 1)
                    continue
                elif denser(particle, x, y + 1) and rand() % 4 != 1:
                    continue

                var xo = sign()

                if denser(particle, x + xo, y + 1):
                    swap(x, y, x + xo, y + 1)
                elif denser(particle, x + xo*2, y + 2):
                    swap(x, y, x + xo*2, y + 2)

            # update the water particle
            elif particle.type == 4:
                if denser(particle, x, y - 1) and (rand() % 10000) == 1:
                    field[x, y] = vapor(not field.skip)
                    continue

                if denser(particle, x, y + 1):
                    swap(x, y, x, y + 1)
                    continue

                var xo = int(field[x, y].data) or dir()
                # var xo = dir()

                if denser(particle, x + xo, y):
                    field[x, y].data = xo
                    swap(x, y, x + xo, y)
                elif denser(particle, x + xo, y + 1):
                    field[x, y].data = xo
                    field[x, y].r = 80
                    field[x, y].g = 140
                    field[x, y].b = 230
                    swap(x, y, x + xo, y + 1)
                else:
                    field[x, y].data = 0
                    field[x, y].r = 40
                    field[x, y].g = 80
                    field[x, y].b = 200

            # update the dust particle
            if particle.type == 3:
                if (denser(field[x, y - 1], x, y) and rand() % 4 == 1) or (field[x, y + 1].type == 4 and rand() % 32 == 1):
                    field[x, y] = sand(not field.skip)

                if field[x, y - 1].type == 1 or field[x, y + 1].type == 1 or field[x - 1, y].type == 1 or field[x + 1, y].type == 1:
                    field[x, y] = fire(not field.skip)

                if rand() % 4 != 1:
                    continue
                
                if denser(particle, x, y + 1):
                    swap(x, y, x, y + 1)
                    continue

                var xo = sign() * ((rand() % 2) + 1)

                if denser(particle, x + xo, y + 1):
                    swap(x, y, x + xo, y + 1)
                elif denser(particle, x + xo*2, y + 2):
                    swap(x, y, x + xo*2, y + 2)

            # update the vapor particle
            elif particle.type == 2:
                if (rand() % 10000) == 1:
                    field[x, y] = water(not field.skip)
                    continue

                var xo = dir()
                var yo = dir() - (rand() % 4 == 1)

                if denser(particle, x + xo, y + yo):
                    swap(x, y, x + xo, y + yo)

            # update the fire particle
            elif particle.type == 1:
                if rand() % 16 == 1:
                    field[x, y].r = (field[x, y].r // 2) + 20
                    field[x, y].g = (field[x, y].g // 6) + 20
                    field[x, y].b = (field[x, y].b // 6) + 20
                    if field[x, y].r == 40:
                        field[x, y] = space(not field.skip)

                var xo = dir() * (rand() % 4 == 1)
                var yo = -(rand() % 2)

                if denser(particle, x + xo, y + yo):
                    swap(x, y, x + xo, y + yo)

    field.skip = not field.skip


fn draw(field: Field, tex: Texture, renderer: Renderer, mouse: Mouse) raises:
    alias clear_color = Color(255, 8, 10, 14)
    var pixels = tex.lock(Rect(0, 0, width, height))._ptr.bitcast[Color]()
    var idx = 0

    for y in range(field.height):
        var o = y*field.width
        for x in range(field.width):
            var particle = field.particles[o + x]
            if particle.type == 0:
                pixels[idx] = clear_color
            else:
                pixels[idx] = Color(0, particle.b, particle.g, particle.r)
            idx += 1

    tex.unlock()
    renderer.copy(tex, None)