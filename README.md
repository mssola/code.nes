Hacking the Famicom/NES just for the fun of it :)

This repository contains a set of examples and experiments which target the
Famicom/NES. These examples are not full blown games nor standalone projects.
Rather, they should be seen as learning material and experiments. If you want to
check out standalone projects that I have written, check out the list on [Other
projects](#other-projects).

## Build

You can build everything by just calling `make` and binaries will then be
available in the `out` directory. Before doing that, though, you will need a
compiler for the 6502 platform. A good option is
[cc65](https://github.com/cc65/cc65), which is available on all major platforms,
and if you are feeling adventurous you can check out
[nasm](https://github.com/mssola/tools.nes). By default the Makefile uses `cc65`
but if you want to use another compiler you can pass the `CC65` and `CCOPTS`
variables to the Makefile.

After that, it's recommended that you run the ROMs with an emulator with
debugging support or at least some form of memory visualization. This is because
some examples have nothing to show for other than updating some values on the
Famicom/NES memory. A safe bet is to go with either
[fceux](https://fceux.com/web/home.html) or
[Mesen](https://github.com/SourMesen/Mesen2/), which provide tools like RAM
watchers or a full debugger.

## Examples

The examples are distributed like this:

- [basics](./basics/README.md): simple examples which cover basic stuff for
  Famicom/NES development. These examples are self-contained and supposed to be
  read by absolute newcomers. The description for each example is covered by an
  initial comment on each file.
- [space](./space/README.md): example in which you can move a spaceship with
  subpixel movement and shoot bullets. Consider this an evolution from the
  `basics/sprite.s` and `basics/input.s` examples. That is, we are no longer
  just showing a sprite, but we make it move and perform an action like shooting
  bullets.
- [scroll](./scroll/README.md): different scrolling tactics.
- [fx](./fx/README.md): simple graphical effects that can be pulled off.
- [rand](./rand/README.md): different strategies for producing random numbers.

## Other projects

- Full games: [jetpac.nes](https://github.com/mssola/jetpac.nes).
- Libraries: [list.nes](https://github.com/mssola/list.nes).
- Misc: [Advent of Code 2023](https://github.com/mssola/aoc2023.nes).
- Tooling: [tools.nes](https://github.com/mssola/tools.nes).
- [Code style](https://github.com/mssola/style.nes) that I'm trying to follow here.

## License

Released under the [GPLv3+](http://www.gnu.org/licenses/gpl-3.0.txt), Copyright
(C) 2023-<i>Ω</i> Miquel Sabaté Solà.

I have taken lots of ideas from different developers and open source projects.
Most notably, I have taken lots of notes from the [Famicom Party
Book](https://famicom.party/book/),
[NESHacker](https://www.youtube.com/c/neshacker) and, of course, from the
awesome [NES Dev wiki](https://www.nesdev.org/wiki/Nesdev_Wiki).
