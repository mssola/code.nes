## Scrolling

Scrolling is a big topic and it's something that evolved with the NES hardware.
This set of examples try to cover it as much as possible while being
approachable as single files.

First of all, you should take a look at `level.s`, which shows how games can
scroll a level and continuously load/unload the next/previous sections of the
level.

The second example is `sprite0.s`, which covers the scrolling done by games such
as Super Mario Bros. or Punch-out. That is, we use the "sprite 0 hit" detection
to keep the top level part of the screen from moving (so to show relevant
information), while allowing the rest of the screen to scroll as expected. In
the end, it's the same example as `level.s` (same level to scroll), but the top
part does not move and shows a "THIS DOES NOT MOVE" message.

Last but not least, the `mmc3.s` example shows how to configure the MMC3 chip
(e.g. Super Mario Bros. 3, Kirby's Adventure) to have better control on which
parts of the screen to scroll or not. To showcase this the example implements a
Pong game by scrolling the paddles instead of directly setting their positions.
This is probably the most stupid way to use this hardware expansion (kind of
like killing a fly with a cannon), but it at least shows a simple way to have
two independent scrolls while having a static middle ground.
