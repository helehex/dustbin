# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from sdl import Color
from random import random_ui64


fn space(skip: Bool) -> Particle:
    return Particle(skip, 0, 0, 0, 0, 0)


fn fire(skip: Bool) -> Particle:
    return Particle(skip, 1, 0, 240, 160, 80)


fn vapor(skip: Bool) -> Particle:
    return Particle(skip, 2, 0, 20, 40, 80)


fn dust(skip: Bool) -> Particle:
    return Particle(skip, 3, 0, random_ui64(160, 180).cast[DType.uint8](), random_ui64(140, 160).cast[DType.uint8](), 120)


fn water(skip: Bool) -> Particle:
    return Particle(skip, 4, 0, 40, 80, random_ui64(180, 200).cast[DType.uint8]())


fn sand(skip: Bool) -> Particle:
    return Particle(skip, 5, 0, random_ui64(180, 200).cast[DType.uint8](), random_ui64(160, 180).cast[DType.uint8](), 60)


fn stone(skip: Bool) -> Particle:
    return Particle(skip, 6, 0, random_ui64(100, 120).cast[DType.uint8](), random_ui64(100, 120).cast[DType.uint8](), random_ui64(100, 120).cast[DType.uint8]())


@value
@register_passable("trivial")
struct Particle:
    var skip: Bool
    var type: UInt8
    var data: Int8
    var r: UInt8
    var g: UInt8
    var b: UInt8