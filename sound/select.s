;;;
;; Enable three sound channels and make them beep depending on the button that
;; is being pressed.

;;; Nothing remarkable here, go down below until you see some comments :)

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02, $01
    .res $0A, $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHARS"
    .incbin "../assets/basic.chr"

.segment "CODE"

.include "../shared/asm.s"
.include "../shared/apu.s"
.include "../shared/oam.s"
.include "../shared/ppu.s"
.include "../shared/clear.s"
.include "../shared/joypad.s"

.scope Vars
    zp_flags = $20
.endscope

.proc reset
    sei
    cld

    ldx #$40
    stx APU::m_frame_counter

    ldx #$FF
    txs

    inx
    stx PPU::m_control
    stx PPU::m_mask
    stx APU::m_dmc

    bit PPU::m_status
@vblankwait1:
    bit PPU::m_status
    bpl @vblankwait1

    ldx #0
    lda #0
@ram_reset_loop:
    sta $000, x
    sta $100, x
    sta $300, x
    sta $400, x
    sta $500, x
    sta $600, x
    sta $700, x
    inx
    bne @ram_reset_loop

    lda #$EF
@sprite_reset_loop:
    sta $200, x
    inx
    bne @sprite_reset_loop

    OAM_WRITE_SPRITES

@vblankwait2:
    bit PPU::m_status
    bpl @vblankwait2

    lda #$3F
    sta PPU::m_address
    lda #$00
    sta PPU::m_address

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta PPU::m_data
    dex
    bne @palettes_reset_loop

    __fallthrough__ main
.endproc

.proc main
    CLEAR_SCREEN

    ;; Just like beep.s
    lda #$0F
    sta APU::m_status

    ;; Square 1 is set up in the same way as in beep.s but it's muted. We will
    ;; handle playing/muting in the main game loop.
    lda #%10110000
    sta APU::m_square_1_envelope
    lda #$C9
    sta APU::m_square_1_low
    lda #$00
    sta APU::m_square_1_high
    sta APU::m_square_1_sweep

    ;; The square 2 channel is almost identical to the other square channel. The
    ;; only difference is with sweeps, for which both square channels are wired
    ;; up differently. To sum things up, when computing the target period with a
    ;; negative value, square 1 will use one's complement, while square 2 will
    ;; use two's complement. You can read more about this here:
    ;; https://www.nesdev.org/wiki/APU_Sweep.
    ;;
    ;; In any case, here we just set the E note with a different duty. We mute
    ;; it for the same reason as for square 1.
    lda #%01110000
    sta APU::m_square_2_envelope
    lda #$A9
    sta APU::m_square_2_low
    lda #$00
    sta APU::m_square_2_high
    sta APU::m_square_2_sweep

    ;; The triangle channel is a bit similar to the square ones, but triangle
    ;; waves have no concept of "duty": there's no percentage of how much time
    ;; it's in the "up" position because that's not how triangles work.
    ;;
    ;; The "control" register from the triangle channel has the most significant
    ;; bit which, when unset, tells the channel to use the internal
    ;; counters. The other bits hold a "value" which is only used with the
    ;; linear counter. Here we set to 1 the most significant bit and hence we
    ;; will control things manually instead of via the linear counter. If we set
    ;; the "value" to zero, like in this case, then we mute the channel. To
    ;; unmute it we can set any value (see below in the main game loop).
    lda #%10000000
    sta APU::m_triangle_control

    ;; NOTE: contrary to what you'd expect, address $4009 is not used by the
    ;; APU.

    ;; And the low/high registers from the triangle channel work in the very
    ;; same way as their square counterparts. Here we set a G#.
    ;;
    ;; That being said, take into account that the pitch of the triangle channel
    ;; is one octave below the square channels with an equivalent timer
    ;; value. If we were to have a table with notes for the square channels and
    ;; we wanted to use them for the triangle channel, we would need to 'lsr'
    ;; the value to get the same note.
    lda #$42
    sta APU::m_triangle_low
    lda #$00
    sta APU::m_triangle_high

    ;; The noise channel produces noise with a pseudo-random bit generator. Its
    ;; envelope register is pretty much the same as with the square channels,
    ;; but the two most significant bits are unused as "duty" is, like with the
    ;; triangle channel, not a thing on this context.
    lda #%00110000
    sta APU::m_noise_envelope

    ;; NOTE: address $400D is unused from the APU.

    ;; You then configure the mode of noise by writing to the $400E address. In the
    ;; low nibble you configure the "noise period", which in turn is the index
    ;; for a table that the APU will use as the real noise period (see:
    ;; https://www.nesdev.org/wiki/APU_Noise for specifics). Finally, only the
    ;; most significant bit is used on the high nibble, which sets the
    ;; "mode". Long story short, it dramatically shortens the period if set,
    ;; which will give you a more "metallic" sound. Change the current value
    ;; from "$0A" to "$8A" and test it by yourself ;-)
    lda #$0A
    sta APU::m_noise_mode

    ;; Finally, there is the counter register for the noise channel. Given that
    ;; we have disabled when we configured 'APU::m_noise_envelope', you'd think
    ;; that you wouldn't have to touch it, but you'd be wrong. This register
    ;; needs to be written at least once so to trigger the enablement of this
    ;; channel. We do it now with a zero value, which also does the trick.
    lda #0
    sta APU::m_noise_counter

    cli
    lda #%10001000
    sta PPU::m_control
    lda #%00011110
    sta PPU::m_mask

@main_game_loop:
    ;; Read the joypad so we can mute/unmute channels depending on the button
    ;; being pressed.
    READ_JOYPAD1

    ;; Mute/Play the square 1 channel
    bit Joypad::zp_buttons1
    bpl @reset_square_1
    lda #%10111000
    bne @set_square_1
@reset_square_1:
    lda #%10110000
@set_square_1:
    sta APU::m_square_1_envelope

    ;; Mute/Play the square 2 channel
    bit Joypad::zp_buttons1
    bvc @reset_square_2
    lda #%10111000
    bne @set_square_2
@reset_square_2:
    lda #%10110000
@set_square_2:
    sta APU::m_square_2_envelope

    ;; Mute/Play the triangle channel
    lda Joypad::zp_buttons1
    and #%00100000
    beq @reset_triangle
    lda #%10000001
    bne @set_triangle
@reset_triangle:
    lda #%10000000
@set_triangle:
    sta APU::m_triangle_control

    ;; Mute/Play the noise channel
    lda Joypad::zp_buttons1
    and #%00010000
    beq @reset_noise
    lda #%00111000
    bne @set_noise
@reset_noise:
    lda #%00110000
@set_noise:
    sta APU::m_noise_envelope

    ;; NOTE: done :)

    lda #%10000000
    ora Vars::zp_flags
    sta Vars::zp_flags
@wait_for_render:
    bit Vars::zp_flags
    bmi @wait_for_render

    jmp @main_game_loop
.endproc

.proc nmi
    bit Vars::zp_flags
    bpl @next

    pha
    txa
    pha
    tya
    pha

    lda #%01111111
    and Vars::zp_flags
    sta Vars::zp_flags

    pla
    tay
    pla
    tax
    pla
@next:
    rti
.endproc

.proc irq
    rti
.endproc
