# x----------------------------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x----------------------------------------------------------------------------------------------x #

from os import abort
from field import Field

alias update_particle = List(update_space, update_fire, update_vapor, update_dust, update_water, update_sand, update_stone)

alias fire_decay = 16
alias vapor2water_prb = 1<<14
alias water2vapor_prb = 1<<14


# +----------------------------------------------------------------------------------------------+ #
# | Particle
# +----------------------------------------------------------------------------------------------+ #
#
@value
@register_passable("trivial")
struct Particle:
    alias skip_flag = 0b00000001

    var flags: UInt8
    var type: UInt8
    var data: SIMD[DType.int8, 2]
    var temp: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8

    @always_inline
    fn update[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout self, inout field: Field):
        # TODO: Cannot use update_particle[self.type] directly
        @parameter
        for i in range(1, len(update_particle)):
            if self.type == i:
                alias _fn = update_particle[i]
                _fn[neighbor](self, field)
                return

    # TODO: Issues related to getattr/setattr (#3341)
    # Cannot have getattr and setattr of different attr types.
    # Cannot have overloads of setattr
    # Cannot have a parametric getattr with a setattr (probably not necessary anyways).
    @always_inline
    fn __getattr__(self, name: StringLiteral) -> Bool:
        if name == "skip":
            return bool(self.flags & self.skip_flag)
        else:
            return bool(abort("invalid particle attribute"))

    @always_inline
    fn __setattr__(inout self, name: StringLiteral, attr: Bool):
        if name == "skip":
            self.flags = (self.flags & ~self.skip_flag) | (attr * self.skip_flag)
        else:
            abort("invalid particle attribute")

    # @always_inline
    # fn __setattr__(inout self, name: StringLiteral, attr: UInt8):
    #     if name == "skip":
    #         self.flags = (self.flags & ~self.skip_flag) | attr
    #     else:
    #         abort("invalid particle attribute")


# +----------------------------------------------------------------------------------------------+ #
# | Border
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn border() -> Particle:
    return Particle(0, -1, 0, 0, 0, 0, 0)


# +----------------------------------------------------------------------------------------------+ #
# | Space
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn space(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 0, 0, 0, 14, 10, 8)


@always_inline
fn update_space[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    pass


# +----------------------------------------------------------------------------------------------+ #
# | Fire
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn fire(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 1, 0, 0, 240, 160, 80)


@always_inline
fn update_fire[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    if field.rand_prb[fire_decay]():
        particle.r = (particle.r // 2) + 20
        particle.g = (particle.g // 6) + 20
        particle.b = (particle.b // 6) + 20
        if particle.r == 40:
            particle = space(field)

    var xo = field.rand_bal[1]() * field.rand_prb[4]()
    var yo = -(field.rand() % 2)

    if field.denser(particle, neighbor(xo, yo)):
        field.swap(particle, neighbor(xo, yo))


# +----------------------------------------------------------------------------------------------+ #
# | Vapor
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn vapor(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 2, 0, 0, 20, 40, 80)


@always_inline
fn update_vapor[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    if field.rand_prb[vapor2water_prb]():
        particle = water(field)
        return

    var xo = field.rand_bal[1]()
    var yo = field.rand_bal[1]() - field.rand_prb[4]()

    if field.denser(particle, neighbor(xo, yo)):
        field.swap(particle, neighbor(xo, yo))


# +----------------------------------------------------------------------------------------------+ #
# | Dust
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn dust(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 3, 0, 0, field.rand_range[160, 180](), field.rand_range[140, 160](), 120)


@always_inline
fn update_dust[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    if (field.denser(neighbor(0, -1), particle) and field.rand_prb[8]()) or (neighbor(0, 1).type == 4 and field.rand_prb[32]()):
        particle = sand(field)

    var fx = field.rand_dir()
    var fy = field.rand_dir()

    if neighbor(fx, fy).type == 1:
        particle = fire(field)

    if not field.rand_prb[4]():
        return
    
    if field.denser(particle, neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return

    var xo = field.rand_dir() * ((field.rand() % 2) + 1)

    if field.denser(particle, neighbor(xo, 1)):
        field.swap(particle, neighbor(xo, 1))
    elif field.denser(particle, neighbor(xo*2, 2)):
        field.swap(particle, neighbor(xo*2, 2))


# +----------------------------------------------------------------------------------------------+ #
# | Water
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn water(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 4, 0, 0, 40, 80, 180)


@always_inline
fn update_water[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    if field.denser(particle, neighbor(0, -1)) and field.rand_prb[water2vapor_prb]():
        particle = vapor(field)
        return

    if field.denser(particle, neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return

    var xo = int(particle.data[0]) or field.rand_bal[3]()

    if field.denser(particle, neighbor(xo, 1)):
        particle.data[0] = xo
        particle.r = 80
        particle.g = 140
        particle.b = 215
        field.swap(particle, neighbor(xo, 1))
    elif field.denser(particle, neighbor(xo, 0)):
        particle.data[0] = xo
        particle.r = 120
        particle.g = 180
        particle.b = 230
        field.swap(particle, neighbor(xo, 0))
    else:
        particle.data[0] -= abs(particle.data[0]) // particle.data[0]
        particle.r = 40
        particle.g = 80
        particle.b = 200


# +----------------------------------------------------------------------------------------------+ #
# | Sand
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn sand(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 5, 0, 0, field.rand_range[180, 200](), field.rand_range[160, 180](), 60)


@always_inline
fn update_sand[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    if field.empty(neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return
    elif field.denser(particle, neighbor(0, 1)) and not field.rand_prb[4]():
        return

    var xo = field.rand_dir()

    if field.denser(particle, neighbor(xo, 1)):
        field.swap(particle, neighbor(xo, 1))
    elif field.denser(particle, neighbor(xo*2, 2)):
        field.swap(particle, neighbor(xo*2, 2))


# +----------------------------------------------------------------------------------------------+ #
# | Stone
# +----------------------------------------------------------------------------------------------+ #
#
@always_inline
fn stone(inout field: Field, skip: Bool = False) -> Particle:
    return Particle(field.skip & Particle.skip_flag, 6, 0, 0, field.rand_range[100, 120](), field.rand_range[100, 120](), field.rand_range[100, 120]())


@always_inline
fn update_stone[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout particle: Particle, inout field: Field):
    var ox = field.rand_dir()

    if field.same(particle, neighbor(ox, 0)):
        return

    if field.denser(particle, neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return