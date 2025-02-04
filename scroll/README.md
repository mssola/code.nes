## Scrolling

Scrolling is a big topic and it's something that evolved with the NES hardware.
This set of examples try to cover it as much as possible while being
approachable as single files.

First of all, you should take a look at `level.s`, which shows how games can
scroll a level that spans multiple screens and continuously load/unload the
next/previous sections of the level.

The second example is `sprite0.s`, which covers the scrolling done by games such
as Super Mario Bros. or Punch-out. That is, we use the "sprite 0 hit" detection
to keep the top level part of the screen from moving (so to show relevant
information), while allowing the rest of the screen to scroll as expected. In
the end, it's the same example as `level.s` (same level to scroll), but the top
part does not move and shows a "THIS DOES NOT MOVE" message.

## Scrolling in different ways in the same frame

Some chips like the MMC3 give programmers a lot of flexibility when it comes to
mid-frame customization. That is, chips like the MMC3 give an interface in which
programmers can ask the chip to submit an IRQ on a given exact scanline. One
main usage of this was to allow a top section of the screen to scroll, while
leaving a small section at the bottom not to scroll. This way, games were no
longer required to have a status bar at the top and they could have it at the
bottom. But these chips allow for a lot of flexibility, so programmers can get
playful with it. One simple example is the roulette mini-game from Super Mario
Bros. 3. In here the game asks for two scanline IRQs and then the scroll
direction is changed on each given IRQ. This way, the background is split in
three sections that move in different directions/speed. Something similar (but
more simple) has been reproduced in [roulette.s](./roulette.s), giving the
following result:

![roulette.png](../docs/roulette.gif)
