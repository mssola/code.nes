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
NES memory. A safe bet is to go with either
[fceux](https://fceux.com/web/home.html) or
[Mesen](https://github.com/SourMesen/Mesen2/), which provide tools like RAM
watchers or a full debugger.

Notice also that I will use some terms without actually introducing them. That
is, I expect you to go over the [NES Dev
wiki](https://www.nesdev.org/wiki/Nesdev_Wiki) for glossary or for full
documentation on the stuff being shown here. For example, if I am writing an
example code using the UNROM or the MMC1 chips, I assume that you will go over
the [NES Dev wiki](https://www.nesdev.org/wiki/Nesdev_Wiki) for details on what
these chips actually are or how they were used. That is, if you find that on a
bunch of comments I write stuff like "memory mapper", "MMC3 chip", "OAM" or
stuff like that, just go to the [NES Dev
wiki](https://www.nesdev.org/wiki/Nesdev_Wiki) to get a better picture.

The examples are distributed like this:

- `basics`: simple examples which cover basic stuff for NES development. These
  examples are self-contained and supposed to be read by absolute newcomers. The
  description for each example is covered by an initial comment on each file.
- `space`: example in which you can move a spaceship with subpixel movement and
  shoot bullets.
- `scroll`: different scrolling tactics. Read the
  [scroll/README.md](./scroll/README.md) file for more info.

Other than that, I have also written complete games. Take a look at
[jetpac.nes](https://github.com/mssola/jetpac.nes), which is simple enough so a
newcomer can read it, but complex enough so it's an actual game.

## License

Released under the [GPLv3+](http://www.gnu.org/licenses/gpl-3.0.txt), Copyright
(C) 2023-<i>Ω</i> Miquel Sabaté Solà.

I have taken lots of ideas from different developers and open source projects.
Most notably, I have taken lots of notes from the [Famicom Party
Book](https://famicom.party/book/),
[NESHacker](https://www.youtube.com/c/neshacker) and, of course, from the
awesome [NES Dev wiki](https://www.nesdev.org/wiki/Nesdev_Wiki).
