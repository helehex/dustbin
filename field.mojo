# x--------------------------------------------------------------------------x #
# | Copyright (c) 2024 Helehex
# x--------------------------------------------------------------------------x #

from memory import memset_zero
from sdl import Keyboard
from particle import *

alias width = 4096
alias height = 1024
alias wrap_x = True


struct Field:
    var run: Bool
    var rnd: Int
    var skip: Bool
    var border: Particle
    var particles: UnsafePointer[Particle]
    
    fn __init__(inout self):
        self.run = True
        self.skip = False
        self.rnd = 123456789
        var size = width * height
        self.border = border()
        self.particles = UnsafePointer[Particle].alloc(size)
        for idx in range(size):
            self.particles[idx] = space(self)

    fn __del__(owned self):
        self.particles.free()

    fn clear(inout self):
        memset_zero(self.particles, width * height)

    fn __getitem__(ref[_] self, x: Int, y: Int) -> ref[__lifetime_of(self)] Particle:
        return self.particles[x + y*width]

    @always_inline("nodebug")
    fn empty(self, inout p: Particle) -> Bool:
        """Returns True if the cell at (x, y) is empty."""
        return p.type == 0

    @always_inline("nodebug")
    fn denser(self, p1: Particle, p2: Particle) -> Bool:
        """Returns True if particle `p1` is denser than particle `p2`."""
        return p2.type != -1 and p1.type > p2.type

    @always_inline("nodebug")
    fn same(self, p1: Particle, p2: Particle) -> Bool:
        """Returns True if particle `p1` is denser than particle `p2`."""
        return p2.type != -1 and p1.type == p2.type

    @always_inline("nodebug")
    fn swap(inout self, inout p1: Particle, inout p2: Particle):
        """Swaps the particle `p1` with particle `p2`. Does not check bounds."""
        p1.skip = self.skip
        swap(p1, p2)

    @always_inline("nodebug")
    fn rand(inout self) -> Int:
        rnd = (self.rnd ^ 61) ^ (self.rnd >> 16)
        rnd = rnd + (rnd << 3)
        rnd = rnd ^ (rnd >> 4)
        rnd = rnd * 0x27d4eb2d
        rnd = rnd ^ (rnd >> 15)
        self.rnd = rnd
        return rnd

    @always_inline("nodebug")
    fn sign(inout self) -> Int:
        """Randomly returns either `1` or `-1`."""
        return ((self.rand() % 2) * 2) - 1

    @always_inline("nodebug")
    fn dir(inout self) -> Int:
        """Randomly returns either 2, 1, 0, -1 or -2."""
        return (self.rand() % 7) - 3

    fn update(inout self, keyboard: Keyboard):

        # return if the field is paused
        if not self.run:
            return

        self.skip = not self.skip

        # loop over all particles
        for y in range(height):
            for x in range(width):

                @parameter
                fn neighbor(xo: Int, yo: Int) -> ref[__lifetime_of(self)] Particle:
                    var nx = x + xo
                    var ny = y + yo
                    @parameter
                    if wrap_x:
                        if 0 <= ny < height:
                            return self[nx % width, ny]
                        else:
                            return self.border
                    else:
                        if 0 <= nx < width and 0 <= ny < height:
                            return self[nx, ny]
                        else:
                            return self.border

                var particle = self[x, y]
                self[x, y].skip = self.skip

                # particle already updated, continue
                if particle.type == 0 or particle.skip == self.skip:
                    continue

                particle.update[neighbor](self)
                
                self[x, y] = particle