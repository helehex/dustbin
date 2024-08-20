# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from sdl import Color
from random import random_ui64


fn empty() -> Particle:
    return Particle(False, 0, Color(0, 0, 0, 0))


fn sand(skip: Bool) -> Particle:
    return Particle(skip, 3, Color(random_ui64(180, 200).cast[DType.uint8](), random_ui64(160, 180).cast[DType.uint8](), 40, 255))


fn water(skip: Bool) -> Particle:
    return Particle(skip, 2, Color(40, 80, random_ui64(180, 200).cast[DType.uint8](), 255))


fn vapor(skip: Bool) -> Particle:
    return Particle(skip, 1, Color(20, 40, 80, 255))


@value
struct Particle:
    var skip: Bool
    var type: UInt8
    var color: Color