;;;
;; Make an annoying "beep" sound.

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

    ;; In order to get sound, you need to enable/disable the channels you
    ;; want. One typical setup is to enable all of them except for DMC. You do
    ;; this by writing into $4015 (APU Status). Note that this register can also
    ;; be read. Reading from this register will give you the state of
    ;; interrupts, and the length of the counter for each channel. Yes, each
    ;; channel has an internal counter, but we can discuss this later.
    ;;
    ;; Anyways, if we want to enable all channels except DMC, we are in luck
    ;; because then we just need to set all bits for the low nibble.
    lda #$0F
    sta APU::m_status

    ;; This was the configuration for the APU. Now let's produce sound on the
    ;; Square 1 channel (registers: $4000-$4003).

    ;; Let's configure the Square 1 channel before producing any sound.
    ;;
    ;; The low nibble controls the volume: 0 for silent, 1 very low, F
    ;; maximum. Just to be annoying we will be setting the volume at a maximum
    ;; level.
    ;;
    ;; Then we have two bits which seem quite odd at first. Bit 4 sets/unsets
    ;; whether the volume is to be kept constant. If unset, then an internal
    ;; counter will tune it down when running out. Similarly, bit 5 sets/unsets
    ;; whether the length counter is to be accounted or not. See this counter
    ;; down below. All in all, here we make the sound constant, so the beep
    ;; never stops until we mute it (which we don't in this example).
    ;;
    ;; Finally we have the "duty" bits, which has four possibilities
    ;; available. These regulate the tone for the note, and it's basically the
    ;; percentage of time the square wave is in the "up" position.
    lda #%10111111
    sta APU::m_square_1_envelope

    ;; The $4001 address contains the sweep register, which is a way that the
    ;; APU has in order to produce different pitch effects, or workaround known
    ;; issues on some tones. I'm not touching it here other than resetting to 0.
    lda #0
    sta APU::m_square_1_sweep

    ;; The note to play is 11 bits long. This means that we need two bytes for
    ;; it, which for square 1 are $4002 and $4003. $4002 is the least
    ;; significant bits, and the three least significant bits from $4003 are the
    ;; most significant bits from this 11-bit note definition. How to know which
    ;; note corresponds to what value is easy via:
    ;; https://www.nesdev.org/wiki/APU_period_table. Thus, in NTSC, setting $0C9
    ;; to this 11-bit value gives us a C#.
    ;;
    ;; The 5 other bits from $4003 correspond to the length counter. That is,
    ;; you can regulate for how long this note has to be reproduced, and the APU
    ;; will (magically) track things for you. This is not available on this
    ;; configuration because we disabled the option when we configured
    ;; 'APU::m_square_1_envelope' (see above). Hence, we will set these bits to
    ;; 0.
    lda #$C9
    sta APU::m_square_1_low
    lda #$00
    sta APU::m_square_1_high

    ;; NOTE: and that's it :)

    cli
    lda #%10001000
    sta PPU::m_control
    lda #%00011110
    sta PPU::m_mask

@main_game_loop:

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
