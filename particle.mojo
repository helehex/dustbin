# x----------------------------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x----------------------------------------------------------------------------------------------x #

from sdl import Color
from random import random_ui64
from field import Field


# +----------------------------------------------------------------------------------------------+ #
# | Particle
# +----------------------------------------------------------------------------------------------+ #
#
@value
@register_passable("trivial")
struct Particle:
    var skip: Bool
    var type: UInt8
    var data: Int8
    var r: UInt8
    var g: UInt8
    var b: UInt8


# +----------------------------------------------------------------------------------------------+ #
# | Border
# +----------------------------------------------------------------------------------------------+ #
#
fn border() -> Particle:
    return Particle(False, -1, 0, 0, 0, 0)


# +----------------------------------------------------------------------------------------------+ #
# | Space
# +----------------------------------------------------------------------------------------------+ #
#
fn space(skip: Bool) -> Particle:
    return Particle(skip, 0, 0, 14, 10, 8)


@always_inline("nodebug")
fn update_space[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    pass


# +----------------------------------------------------------------------------------------------+ #
# | Fire
# +----------------------------------------------------------------------------------------------+ #
#
fn fire(skip: Bool) -> Particle:
    return Particle(skip, 1, 0, 240, 160, 80)


@always_inline("nodebug")
fn update_fire[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    if field.rand() % 16 == 0:
        particle.r = (particle.r // 2) + 20
        particle.g = (particle.g // 6) + 20
        particle.b = (particle.b // 6) + 20
        if particle.r == 40:
            particle = space(field.skip)

    var xo = field.dir() * (field.rand() % 4 == 0)
    var yo = -(field.rand() % 2)

    if field.denser(particle, neighbor(xo, yo)):
        field.swap(particle, neighbor(xo, yo))


# +----------------------------------------------------------------------------------------------+ #
# | Vapor
# +----------------------------------------------------------------------------------------------+ #
#
fn vapor(skip: Bool) -> Particle:
    return Particle(skip, 2, 0, 20, 40, 80)


@always_inline("nodebug")
fn update_vapor[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    if (field.rand() % 16384) == 0:
        particle = water(field.skip)
        return

    var xo = field.dir()
    var yo = field.dir() - (field.rand() % 4 == 0)

    if field.denser(particle, neighbor(xo, yo)):
        field.swap(particle, neighbor(xo, yo))


# +----------------------------------------------------------------------------------------------+ #
# | Dust
# +----------------------------------------------------------------------------------------------+ #
#
fn dust(skip: Bool) -> Particle:
    return Particle(skip, 3, 0, random_ui64(160, 180).cast[DType.uint8](), random_ui64(140, 160).cast[DType.uint8](), 120)


@always_inline("nodebug")
fn update_dust[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    if (field.denser(neighbor(0, -1), particle) and field.rand() % 8 == 0) or (neighbor(0, 1).type == 4 and field.rand() % 32 == 0):
        particle = sand(field.skip)

    var fx = field.sign()
    var fy = field.sign()

    if neighbor(fx, fy).type == 1:
        particle = fire(field.skip)

    if field.rand() % 4 != 0:
        return
    
    if field.denser(particle, neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return

    var xo = field.sign() * ((field.rand() % 2) + 1)

    if field.denser(particle, neighbor(xo, 1)):
        field.swap(particle, neighbor(xo, 1))
    elif field.denser(particle, neighbor(xo*2, 2)):
        field.swap(particle, neighbor(xo*2, 2))


# +----------------------------------------------------------------------------------------------+ #
# | Water
# +----------------------------------------------------------------------------------------------+ #
#
fn water(skip: Bool) -> Particle:
    return Particle(skip, 4, 0, 40, 80, random_ui64(180, 200).cast[DType.uint8]())


@always_inline("nodebug")
fn update_water[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    if field.denser(particle, neighbor(0, -1)) and (field.rand() % 16384) == 0:
        particle = vapor(field.skip)
        return

    if field.denser(particle, neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return

    var xo = int(particle.data) or field.dir()

    if field.denser(particle, neighbor(xo, 1)):
        particle.data = xo
        particle.r = 80
        particle.g = 140
        particle.b = 215
        field.swap(particle, neighbor(xo, 1))
    elif field.denser(particle, neighbor(xo, 0)):
        particle.data = xo
        particle.r = 120
        particle.g = 180
        particle.b = 230
        field.swap(particle, neighbor(xo, 0))
    else:
        particle.data -= abs(particle.data) // particle.data
        particle.r = 40
        particle.g = 80
        particle.b = 200


# +----------------------------------------------------------------------------------------------+ #
# | Sand
# +----------------------------------------------------------------------------------------------+ #
#
fn sand(skip: Bool) -> Particle:
    return Particle(skip, 5, 0, random_ui64(180, 200).cast[DType.uint8](), random_ui64(160, 180).cast[DType.uint8](), 60)


@always_inline("nodebug")
fn update_sand[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    if field.empty(neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return
    elif field.denser(particle, neighbor(0, 1)) and field.rand() % 4 != 0:
        return

    var xo = field.sign()

    if field.denser(particle, neighbor(xo, 1)):
        field.swap(particle, neighbor(xo, 1))
    elif field.denser(particle, neighbor(xo*2, 2)):
        field.swap(particle, neighbor(xo*2, 2))


# +----------------------------------------------------------------------------------------------+ #
# | Stone
# +----------------------------------------------------------------------------------------------+ #
#
fn stone(skip: Bool) -> Particle:
    return Particle(skip, 6, 0, random_ui64(100, 120).cast[DType.uint8](), random_ui64(100, 120).cast[DType.uint8](), random_ui64(100, 120).cast[DType.uint8]())


@always_inline("nodebug")
fn update_stone[lif: AnyLifetime[True].type, //, neighbor: fn (Int, Int) capturing -> ref[lif] Particle](inout field: Field, inout particle: Particle):
    var ox = field.sign()

    if field.same(particle, neighbor(ox, 0)):
        return

    if field.denser(particle, neighbor(0, 1)):
        field.swap(particle, neighbor(0, 1))
        return