# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from memory import memset_zero
from particle import *

struct Field:
    var particles: UnsafePointer[Particle]
    var width: Int
    var height: Int
    var skip: Bool

    fn __init__(inout self, width: Int, height: Int):
        self.width = width
        self.height = height
        self.skip = False
        var size = width * height
        self.particles = UnsafePointer[Particle].alloc(size)
        memset_zero(self.particles, size)

    fn __moveinit__(inout self, owned other: Self):
        self.particles = other.particles
        self.width = other.width
        self.height = other.height
        self.skip = other.skip

    fn __del__(owned self):
        self.particles.free()

    fn clear(inout self):
        memset_zero(self.particles, self.width * self.height)

    fn __getitem__(ref[_] self, x: Int, y: Int) -> ref[__lifetime_of(self)] Particle:
        return self.particles[x + y*self.width]