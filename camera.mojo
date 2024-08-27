# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from algorithm import parallelize
from sdl import Keyboard, KeyCode, Renderer, Texture, TexturePixelFormat, TextureAccess
from field import *


alias max_view_scale = 16
alias min_view_scale = 1


struct Camera:
    var view_scale: Int
    var view_size_x: Int
    var view_size_y: Int
    var view_pos_x: Int
    var view_pos_y: Int
    var texture: Texture

    fn __init__(inout self, renderer: Renderer) raises:
        self.view_scale = 2
        var screen_size = renderer.get_output_size()
        self.view_size_x = screen_size[0] // self.view_scale
        self.view_size_y = screen_size[1] // self.view_scale
        self.view_pos_x = 0
        self.view_pos_y = height - self.view_size_y
        self.texture = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, self.view_size_x, self.view_size_y)

    fn set_scale(inout self, owned scale: Int, renderer: Renderer) raises:
        scale = min(max(min_view_scale, scale), max_view_scale)
        if scale != self.view_scale:
            self.view_pos_x += (self.view_size_x // 2)
            self.view_pos_y += (self.view_size_y // 2)
            self.view_scale = scale
            self.on_size_changed(renderer)
            self.view_pos_x -= (self.view_size_x // 2)
            self.view_pos_y -= (self.view_size_y // 2)
    
    fn on_size_changed(inout self, renderer: Renderer) raises:
        var screen_size = renderer.get_output_size()
        self.view_size_x = screen_size[0] // self.view_scale
        self.view_size_y = screen_size[1] // self.view_scale

        # TODO: for some reason, doing the obvious thing here doesn't work...
        var texture = Texture(renderer, TexturePixelFormat.RGBA8888, TextureAccess.STREAMING, self.view_size_x, self.view_size_y)
        self.texture = texture^

    @always_inline("nodebug")
    fn view2field(self, x: Int, y: Int) -> (Int, Int):
        return (x + self.view_pos_x) % width, (y + self.view_pos_y) % height

    fn update(inout self, keyboard: Keyboard):
        # move camera
        var mevement_speed = (10 // self.view_scale) + 1
        if keyboard.state[KeyCode.W]:
            self.view_pos_y -= mevement_speed
        if keyboard.state[KeyCode.A]:
            self.view_pos_x -= mevement_speed
        if keyboard.state[KeyCode.S]:
            self.view_pos_y += mevement_speed
        if keyboard.state[KeyCode.D]:
            self.view_pos_x += mevement_speed

    fn draw(self, field: Field, renderer: Renderer) raises:
        alias clear_color = Color(14, 10, 8, 0)
        alias chunk_size = 128

        var pixels = self.texture.lock()._ptr.bitcast[Color]()
        
        @parameter
        fn chunk(chunk: Int):
            var start = chunk * chunk_size
            var end = min(start + chunk_size, self.view_size_y)
            var ptr = pixels + (start * self.view_size_x)
            for y in range(start, end):
                for x in range(self.view_size_x):
                    var xy = self.view2field(x, y)
                    var particle = field[xy[0], xy[1]]
                    var c0 = int(particle.type == 0)
                    var c1 = 1 - c0
                    ptr[] = Color(0, (clear_color.b * c0) + (particle.b * c1), (clear_color.g * c0) + (particle.g * c1), (clear_color.r * c0) + (particle.r * c1))
                    ptr += 1

        parallelize[chunk]((self.view_size_y // chunk_size) + 1)

        _ = pixels
        self.texture.unlock()
        renderer.copy(self.texture, None)