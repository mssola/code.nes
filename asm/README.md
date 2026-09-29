For now there is only one example, `soft_irq.s`, which shows how you can tell
apart a hardware IRQ from a software IRQ, and how to get the "break mark" from a
software IRQ. In the end, this is all quite finnicky and prone to errors, so
just avoid doing anything with that and treat this example as a cool exercise on
6502 programming. I'd say that the better option in order to make assertions and
stuff like that would be to use Lua scripts on the emulator of your choice.
