<p align="center">
  <a href="https://github.com/mssola/NES/actions?query=workflow%3ACI" title="CI status for the main branch"><img src="https://github.com/mssola/NES/workflows/CI/badge.svg" alt="Build Status for main branch" /></a>
  <a href="http://www.gnu.org/licenses/gpl-3.0.txt" rel="nofollow"><img alt="License GPL 3" src="https://img.shields.io/badge/license-GPL_3-blue.svg" style="max-width:100%;"></a>
</p>

---

This repository consists of some examples on programs for the NES. You can build
them by just calling `make`. Before doing that, though, you will need a compiler
for the 6052 platform. A good option is [cc65](https://github.com/cc65/cc65),
which is available on all major platforms. Otherwise, if you want to use another
compiler, you can pass the `CC65` and `CCOPTS` variables to the Makefile. Either
way, the resulting ROMs will be placed in the `out` directory.

After that, it's recommended that you run the ROMs with an emulator with
debugging support or at least some form of memory visualization. This is because
some examples have nothing to show for other than updating some values on the
NES memory. A safe bet is to go with [fceux](https://fceux.com/web/home.html),
which works on all major platforms and provides tools like RAM watchers or a
full debugger.

All that being said, for now I have written the following examples:

- `examples/input.s`: it reads the input from the first controller and it
  increments a counter stored in memory for each press of the right arrow
  button.
- `examples/sprites`: shows a sprite with a background on screen. This is a
  detailed explanation on how all this magic can happen, with a very basic
  example and all those "magic" numbers explained.

## License

Released under the [GPLv3+](http://www.gnu.org/licenses/gpl-3.0.txt), Copyright
(C) 2023-<i>Ω</i> Miquel Sabaté Solà.

There are some files which I have taken from other people (e.g.
`examples/wrapper.s`). Take a look at each file for the specifics.
