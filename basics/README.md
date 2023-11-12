## Basics

Here we have simple programs which try to explain a particular topic of NES
programming. They are single files which already contain all you need in order
to have a working program. This means that there is quite a lot of boilerplate
you might not be aware. For this reason I encourage you to start with the
`sprite.s` file, which has a step by step explanation on how the NES is
initialized and what do all these magic "HEADER" and other jargon actually mean.
Thus, for absolute beginners go to:

- `sprite.s`: detailed explanation on how to initialize the NES in order to have
  some background and a sprite shown on screen. Follow along the code in order
  to get a detailed explanation on each section.
- `input.s`: how to read the input from one controller.

After this, you should be good to go for full examples like the one on the
`space` directory, in which we take the example on `sprite.s` and make it move
and shoot bullets depending on the given input.

Whenever you are done with that, you can then move into other topics like:

- `persist.s`: using the MMC1 chip in order to persist data.
- `unrom.s`: bank switching using the UNROM chip.
