# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from random import seed
from collections import Optional
from algorithm import parallelize
from sdl import *
from field import *
from particle import *

alias width = 6000
alias height = 800
alias fps = 100


def main():
    seed()

    # initialize sdl and sub-systems (used for rendering and event handling)
    sdl = SDL(video=True, events=True)
    clock = Clock(sdl, fps)
    mouse = Mouse(sdl)
    keyboard = Keyboard(sdl)
    view_scale = 1
    view_pos_x = 0
    view_pos_y = 0
    screen_size = (1200, 800)
    view_size = (screen_size[0] // view_scale, screen_size[1] // view_scale)
    window = Window(sdl, "Dustbin", screen_size[0], screen_size[1])
    renderer = Renderer(window^, RendererFlags.SDL_RENDERER_ACCELERATED)
    texture = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, view_size[0], view_size[1])
    field = Field(width, height)
    rnd = 123456789
    cursor_size = 1
    
    selected = sand
    running = True
    frame_count = 0
    smooth_fps = 0.0

    # main game loop
    while running:
        # handle events
        event_list = sdl.event_list()
        for event in event_list:
            if event[].isa[events.QuitEvent]():
                running = False
            elif event[].isa[events.WindowEvent]():
                var e = event[].unsafe_take[events.WindowEvent]()
                if e.event == events.WindowEventID.WINDOWEVENT_SIZE_CHANGED.cast[DType.uint8]():
                    screen_size = renderer.get_output_size()
                    view_size = (screen_size[0] // view_scale, screen_size[1] // view_scale)
                    texture = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, view_size[0], view_size[1])
            elif event[].isa[events.MouseWheelEvent]():
                cursor_size = max(0, cursor_size + int(event[].unsafe_get[events.MouseWheelEvent]()[].y))
            elif event[].isa[events.KeyDownEvent]():
                var e = event[].unsafe_take[events.KeyDownEvent]()
                if e.keysym.scancode == KeyCode.EQUALS:
                    new_scale = view_scale + 1
                    if new_scale <= 16:
                        view_pos_x += (view_size[0] // 2)
                        view_pos_y += (view_size[1] // 2)
                        view_size = (screen_size[0] // new_scale, screen_size[1] // new_scale)
                        texture = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, view_size[0], view_size[1])
                        view_pos_x -= (view_size[0] // 2)
                        view_pos_y -= (view_size[1] // 2)
                        view_scale = new_scale
                elif e.keysym.scancode == KeyCode.MINUS:
                    new_scale = view_scale - 1
                    if new_scale > 0:
                        view_pos_x += (view_size[0] // 2)
                        view_pos_y += (view_size[1] // 2)
                        view_size = (screen_size[0] // new_scale, screen_size[1] // new_scale)
                        texture = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, view_size[0], view_size[1])
                        view_pos_x -= (view_size[0] // 2)
                        view_pos_y -= (view_size[1] // 2)
                        view_scale = new_scale
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

        # view to field transformation
        @parameter
        @always_inline
        fn view2field(x: Int, y: Int) -> (Int, Int):
            return (x + view_pos_x) % field.width, (y + view_pos_y) % field.height

        mouse_pos = mouse.get_position()
        cursor_pos = view2field(mouse_pos[0] // view_scale, mouse_pos[1] // view_scale)

        # spawn particles at cursor position if dropping is not none
        dropping = Optional[fn(skip: Bool) -> Particle](None)
        if mouse.get_buttons() & 1:
            dropping = selected
        elif mouse.get_buttons() & 2:
            dropping = space
        elif mouse.get_buttons() & 4:
            dropping = fire
        if dropping:
            for x in range(max(cursor_pos[0] - cursor_size, 0), min(cursor_pos[0] + cursor_size + 1, field.width)):
                for y in range(max(cursor_pos[1] - cursor_size, 0), min(cursor_pos[1] + cursor_size + 1, field.height)):
                    field[x, y] = dropping.unsafe_value()(not field.skip)

        # move camera
        var mevement_speed = (10 // view_scale) + 1
        if keyboard.state[KeyCode.W]:
            view_pos_y -= mevement_speed
        if keyboard.state[KeyCode.A]:
            view_pos_x -= mevement_speed
        if keyboard.state[KeyCode.S]:
            view_pos_y += mevement_speed
        if keyboard.state[KeyCode.D]:
            view_pos_x += mevement_speed

        # update field
        update(field, rnd)

        # draw field
        draw[view2field](field, renderer, texture, view_size)

        # draw cursor
        renderer.set_color(Color(255, 255, 255, 0))
        renderer.set_blendmode(BlendMode.MUL)
        renderer.draw_rect(Rect(mouse_pos[0] - cursor_size*view_scale, mouse_pos[1] - cursor_size*view_scale, cursor_size*view_scale*2, cursor_size*view_scale*2))
        renderer.present()

        # limit fps
        clock.tick()
        frame_count += 1
        smooth_fps = (smooth_fps * 0.9) + (0.1/clock.delta_time)
        if frame_count % 100 == 1:
            print(smooth_fps)


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

    @parameter
    @always_inline
    fn same(p: Particle, x: Int, y: Int) -> Bool:
        if 0 <= x < field.width and 0 <= y < field.height:
            return field[x, y].type == p.type
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
            if particle.type == 0 or particle.skip == field.skip:
                continue

            # update the stone particle
            if particle.type == 6:
                var ox = sign()

                if same(particle, x + ox, y):
                    continue

                if denser(particle, x, y + 1):
                    swap(x, y, x, y + 1)
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
                    field[x, y] = vapor(field.skip)
                    continue

                if denser(particle, x, y + 1):
                    swap(x, y, x, y + 1)
                    continue

                var xo = int(field[x, y].data) or dir()
                # var xo = dir()

                if denser(particle, x + xo, y + 1):
                    field[x, y].data = xo
                    field[x, y].r = 80
                    field[x, y].g = 140
                    field[x, y].b = 230
                    swap(x, y, x + xo, y + 1)
                elif denser(particle, x + xo, y):
                    field[x, y].data = xo
                    field[x, y].r = 120
                    field[x, y].g = 180
                    field[x, y].b = 230
                    swap(x, y, x + xo, y)
                else:
                    field[x, y].data = 0
                    field[x, y].r = 40
                    field[x, y].g = 80
                    field[x, y].b = 200

            # update the dust particle
            elif particle.type == 3:
                if (y > 0 and denser(field[x, y - 1], x, y) and rand() % 8 == 1) or (y < height - 1 and field[x, y + 1].type == 4 and rand() % 32 == 1):
                    field[x, y] = sand(field.skip)

                var fx = sign()
                var fy = sign()

                if (0 <= x + fx < width and 0 <= y + fy < height and field[x + fx, y + fy].type == 1):
                    field[x, y] = fire(field.skip)

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
                    field[x, y] = water(field.skip)
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
                        field[x, y] = space(field.skip)

                var xo = dir() * (rand() % 4 == 1)
                var yo = -(rand() % 2)

                if denser(particle, x + xo, y + yo):
                    swap(x, y, x + xo, y + yo)

    field.skip = not field.skip


fn draw[view2field: fn(Int, Int) capturing -> (Int, Int)](field: Field, renderer: Renderer, texture: Texture, view_size: (Int, Int)) raises:
    alias clear_color = Color(14, 10, 8, 0)
    alias chunk_size = 128

    var pixels = texture.lock()._ptr.bitcast[Color]()
    
    @parameter
    fn chunk(chunk: Int):
        var start = chunk * chunk_size
        var end = min(start + chunk_size, view_size[1])
        var ptr = pixels + (start * view_size[0])
        for y in range(start, end):
            for x in range(view_size[0]):
                var xy = view2field(x, y)
                var particle = field[xy[0], xy[1]]
                var c0 = int(particle.type == 0)
                var c1 = 1 - c0
                ptr[] = Color(0, (clear_color.b * c0) + (particle.b * c1), (clear_color.g * c0) + (particle.g * c1), (clear_color.r * c0) + (particle.r * c1))
                ptr += 1

    parallelize[chunk]((view_size[1] // chunk_size) + 1)

    _ = pixels
    texture.unlock()
    renderer.copy(texture, None)
