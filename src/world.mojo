# x--------------------------------------------------------------------------x #
# | Helehex Dustbin
# x--------------------------------------------------------------------------x #

from particle import *
from game import KeyState

import sdl

alias width = 1 << 14
alias height = 1 << 10
alias wrap_x = True


# +----------------------------------------------------------------------------------------------+ #
# | World
# +----------------------------------------------------------------------------------------------+ #
#
struct World:
    var rnd: Int
    var run: Bool
    var skip: UInt8
    var border: Particle
    var particles: UnsafePointer[Particle, MutOrigin.external]

    fn __init__(out self):
        self.rnd = 13
        self.run = True
        self.skip = 0
        var size = width * height
        self.border = border()
        self.particles = alloc[Particle](size)
        for idx in range(size):
            self.particles[idx] = space(
                self
            )  # if idx % 16 != 0 else vapor(self)

    fn __del__(deinit self):
        self.particles.free()

    fn __getitem__(
        ref [_]self, x: Int, y: Int
    ) -> ref [origin_of(self)] Particle:
        return self.particles[x + y * width]

    @always_inline
    fn empty(self, mut p: Particle) -> Bool:
        """Returns True if the cell at (x, y) is empty."""
        return p.type == 0

    @always_inline
    fn denser(self, p1: Particle, p2: Particle) -> Bool:
        """Returns True if particle `p1` is denser than particle `p2`."""
        return p2.type != -1 and p1.type > p2.type

    @always_inline
    fn same(self, p1: Particle, p2: Particle) -> Bool:
        """Returns True if particle `p1` is denser than particle `p2`."""
        return p2.type != -1 and p1.type == p2.type

    @always_inline
    fn swap(mut self, mut p1: Particle, mut p2: Particle):
        """Swaps the particle `p1` with particle `p2`. Does not check bounds."""
        p1.skip = Bool(self.skip)
        swap(p1, p2)

    @always_inline
    fn rand(mut self) -> Int:
        self.rnd ^= self.rnd << 13
        self.rnd ^= self.rnd >> 17
        self.rnd ^= self.rnd << 5
        return self.rnd

    @always_inline
    fn rand_dir(mut self) -> Int:
        """Randomly returns either `1` or `-1`."""
        return ((self.rand() % 2) * 2) - 1

    @always_inline
    fn rand_bal[mag: IntLiteral](mut self) -> Int:
        """Randomly returns a value from `-mag` to `mag`."""
        return (self.rand() % ((mag * 2) + 1)) - mag

    @always_inline
    fn rand_prb[prb: IntLiteral](mut self) -> Bool:
        """Randomly returns 0, or 1 with probability `prb`."""
        return (self.rand() % prb) == 0

    @always_inline
    fn rand_range[low: IntLiteral, high: IntLiteral](mut self) -> Int:
        """Randomly returns a value greater than `low`, and less than `high`."""
        return (self.rand() % (high - low)) + low

    fn update(mut self, keyboard: KeyState, region: Tuple[Int, Int, Int, Int]):
        # return if the field is paused
        if not self.run:
            return

        # flip field.skip
        self.skip ^= Particle.skip_flag
        # set x_range, this switches direction every frame to avoid sideways bias
        var x_range = range(region[0], region[2], 1) if self.skip else reversed(
            range(region[0], region[2], 1)
        )

        # loop over particle region
        for _y in range(region[1], region[3]):
            var y = _y % height
            for _x in x_range:
                var x = _x % width
                var particle = self[x, y]

                # particle already updated, continue
                if particle.type == 0 or particle.skip == Bool(self.skip):
                    continue

                # define capturing neighbor function
                @parameter
                @always_inline
                fn neighbor(xo: Int, yo: Int) -> ref [MutAnyOrigin] Particle:
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

                # update particle
                particle.skip = Bool(self.skip)
                particle.update[neighbor](self)
                self[x, y] = particle
