# x--------------------------------------------------------------------------x #
# | Helehex Dustbin
# x--------------------------------------------------------------------------x #

from algorithm import parallelize
from game import Renderer, Texture, KeyState
from world import World, width, height

import sdl

alias max_view_scale = 16
alias min_view_scale = 1


# +----------------------------------------------------------------------------------------------+ #
# | Camera
# +----------------------------------------------------------------------------------------------+ #
#
struct Camera:
    var view_scale: Int
    var view_size_x: Int
    var view_size_y: Int
    var view_pos_x: Int
    var view_pos_y: Int
    var texture: Texture

    fn __init__(out self, renderer: Renderer) raises:
        self.view_scale = 2
        var screen_size = (Int32(), Int32())
        sdl.get_render_output_size(
            renderer,
            UnsafePointer(to=screen_size[0]),
            UnsafePointer(to=screen_size[1]),
        )
        self.view_size_x = Int(screen_size[0] // self.view_scale)
        self.view_size_y = Int(screen_size[1] // self.view_scale)
        self.view_pos_x = 0
        self.view_pos_y = height - self.view_size_y
        self.texture = sdl.create_texture(
            renderer,
            sdl.PixelFormat.PIXELFORMAT_RGBA32,
            sdl.TextureAccess.TEXTUREACCESS_STREAMING,
            self.view_size_x,
            self.view_size_y,
        )

    fn set_scale(mut self, var scale: Int, renderer: Renderer) raises:
        scale = min(max(min_view_scale, scale), max_view_scale)
        if scale != self.view_scale:
            self.view_pos_x += self.view_size_x // 2
            self.view_pos_y += self.view_size_y // 2
            self.view_scale = scale
            self.on_size_changed(renderer)
            self.view_pos_x -= self.view_size_x // 2
            self.view_pos_y -= self.view_size_y // 2

    fn on_size_changed(mut self, renderer: Renderer) raises:
        screen_width = Int32()
        screen_height = Int32()
        sdl.get_render_output_size(
            renderer,
            UnsafePointer(to=screen_width),
            UnsafePointer(to=screen_height),
        )
        self.view_size_x = Int(screen_width // self.view_scale)
        self.view_size_y = Int(screen_height // self.view_scale)

        # TODO: for some reason, doing the obvious thing here doesn't work...
        self.texture = sdl.create_texture(
            renderer,
            sdl.PixelFormat.PIXELFORMAT_RGBA32,
            sdl.TextureAccess.TEXTUREACCESS_STREAMING,
            self.view_size_x,
            self.view_size_y,
        )

    @always_inline
    fn view2world(self, x: Int, y: Int) -> Tuple[Int, Int]:
        return (x + self.view_pos_x) % width, (y + self.view_pos_y) % height

    fn update(mut self, key_state: KeyState):
        # move camera
        var mevement_speed = (10 // self.view_scale) + 1
        if key_state[sdl.Scancode.SCANCODE_W]:
            self.view_pos_y -= mevement_speed
        if key_state[sdl.Scancode.SCANCODE_A]:
            self.view_pos_x -= mevement_speed
        if key_state[sdl.Scancode.SCANCODE_S]:
            self.view_pos_y += mevement_speed
        if key_state[sdl.Scancode.SCANCODE_D]:
            self.view_pos_x += mevement_speed

    fn draw(self, world: World, renderer: Renderer) raises:
        var _pixels = UnsafePointer[NoneType, MutAnyOrigin]()
        var pitch = Int32()
        sdl.lock_texture(
            self.texture,
            UnsafePointer[sdl.Rect, ImmutAnyOrigin](),
            UnsafePointer(to=_pixels),
            UnsafePointer(to=pitch),
        )
        var pixels = _pixels.bitcast[ColorRGBA32]()

        for y in range(self.view_size_y):
            for x in range(self.view_size_x):
                var pos = self.view2world(x, y)
                particle = world[pos[0], pos[1]]
                pixels[x + y * self.view_size_x] = ColorRGBA32(
                    particle.r, particle.g, particle.b, 255
                )

        sdl.unlock_texture(self.texture)
        sdl.render_texture(
            renderer,
            self.texture,
            UnsafePointer[sdl.FRect, ImmutAnyOrigin](),
            UnsafePointer[sdl.FRect, ImmutAnyOrigin](),
        )


# +----------------------------------------------------------------------------------------------+ #
# | Colors
# +----------------------------------------------------------------------------------------------+ #
#
@fieldwise_init
@register_passable("trivial")
struct ColorRGB24:
    var r: UInt8
    var g: UInt8
    var b: UInt8


@fieldwise_init
@register_passable("trivial")
struct ColorRGBA32:
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
