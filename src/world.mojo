# x--------------------------------------------------------------------------x #
# | Helehex Dustbin
# x--------------------------------------------------------------------------x #

from sdl import Keyboard
from particle import *

alias width = 1<<14
alias height = 1<<10
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
    var particles: UnsafePointer[Particle]
    
    fn __init__(inout self):
        self.rnd = 13
        self.run = True
        self.skip = False
        var size = width * height
        self.border = border()
        self.particles = UnsafePointer[Particle].alloc(size)
        for idx in range(size):
            self.particles[idx] = space(self) # if idx % 16 != 0 else vapor(self)

    fn __del__(owned self):
        self.particles.free()

    fn __getitem__(ref[_] self, x: Int, y: Int) -> ref[__lifetime_of(self)] Particle:
        return self.particles[x + y*width]

    @always_inline
    fn empty(self, inout p: Particle) -> Bool:
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
    fn swap(inout self, inout p1: Particle, inout p2: Particle):
        """Swaps the particle `p1` with particle `p2`. Does not check bounds."""
        p1.skip = bool(self.skip)
        swap(p1, p2)

    @always_inline
    fn rand(inout self) -> Int:
        self.rnd ^= self.rnd << 13
        self.rnd ^= self.rnd >> 17
        self.rnd ^= self.rnd << 5
        return self.rnd

    @always_inline
    fn rand_dir(inout self) -> Int:
        """Randomly returns either `1` or `-1`."""
        return ((self.rand() % 2) * 2) - 1

    @always_inline
    fn rand_bal[mag: IntLiteral](inout self) -> Int:
        """Randomly returns a value from `-mag` to `mag`."""
        return (self.rand() % ((mag*2) + 1)) - mag

    @always_inline
    fn rand_prb[prb: IntLiteral](inout self) -> Bool:
        """Randomly returns 0, or 1 with probability `prb`."""
        return (self.rand() % prb) == 0

    @always_inline
    fn rand_range[low: IntLiteral, high: IntLiteral](inout self) -> Int:
        """Randomly returns a value greater than `low`, and less than `high`."""
        return (self.rand() % (high - low)) + low

    fn update(inout self, keyboard: Keyboard, region: (Int, Int, Int, Int)):
        # return if the field is paused
        if not self.run:
            return

        # flip field.skip
        self.skip ^= Particle.skip_flag
        # set x_range, this switches direction every frame to avoid sideways bias
        var x_range = (range(region[0], region[2], 1) if self.skip else reversed(range(region[0], region[2], 1)))

        # loop over particle region
        for _y in range(region[1], region[3]):
            var y = _y % height
            for _x in x_range:
                var x = _x % width
                var particle = self[x, y]

                # particle already updated, continue
                if particle.type == 0 or particle.skip == bool(self.skip):
                    continue

                # define capturing neighbor function
                @parameter
                @always_inline
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

                # update particle
                particle.skip = bool(self.skip)
                particle.update[neighbor](self)
                self[x, y] = particle