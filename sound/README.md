These examples showcase how to produce sound on the NES/Famicom. This is a
complex topic, but here I'm trying to showcase it at a very fundamental
level. It's basically the same as to follow the guide from
[NerdyNights](https://nerdy-nights.nes.science/#audio_tutorial-0), which I read
extensively, mixing with things I learned by browsing the NESDev wiki. All in
all we have:

- [beep.s](./beep.s): the most basic example. It constantly sends a C# note to
  the square 1 channel (mind that square channels are also sometimes called
  "pulse" channels in the documentation).
- [select.s](./select.s): same as `beep.s` but while also using the square 2,
  triangle and noise channels. Note that now everything is muted, and you can
  unmute each channel by pressing A, B, Start or Select.
- [scale.s](./scale.s): reproduce a scale of notes over and over.
