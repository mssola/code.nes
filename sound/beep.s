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

    ;; This was the configuration for the APU. After that, all enabled channels
    ;; can produce output and it's going to be combined using a non-linear
    ;; mixing scheme (https://www.nesdev.org/wiki/APU_Mixer). Long story short:
    ;; all channels work independently and they are going to be properly
    ;; combined in the end, so a programmer can focus on each channel
    ;; separately.

    ;; This example uses the Square 1 channel to produce sound. Let's see how it
    ;; can be configured, and 'sound/select.s' will deal with the other
    ;; channels.
    ;;
    ;; The $4000 register configures how the square 1 channel will produce its
    ;; output via the envelope. The **envelope** is a hardware feature that
    ;; automatically controls the volume of a sound over time. The APU has two
    ;; modes of operation: constant volume or decay envelope mode. This is
    ;; regulated via bit 4 of the $4000 register: 1 for constant volume; 0 for
    ;; decay envelope mode. With this in mind, the low nibble of this register
    ;; works like this:
    ;;
    ;;   - Bit 4 = 1: the low nibble contains the **volume** of the sound, which
    ;;                will be frozen in time (i.e. constant). Set the volume to
    ;;                0 for a silent channel; 1 for very low volume, F for
    ;;                maximum volume.
    ;;   - Bit 4 = 0: the low nibble contains the **period** of decay of the
    ;;                volume. That is, it makes the volume to decay every V
    ;;                frames, where V is the value on the low nibble. This is in
    ;;                the end possible because of the internal frame counter
    ;;                from the APU. In this context, the volume will always
    ;;                start at F, and it will decay until reaching zero at the
    ;;                given period. With all of that in mind, then, note that
    ;;                higher number means decaying the volume slower.
    ;;
    ;; Another important bit is 5, which is the "looping" bit. That is, whether
    ;; the configured envelope should be repeated after a shot has been done. If
    ;; this bit is set to 1, then this envelope will be repeated over and
    ;; over. If, otherwise, the bit is set to 0, then it's a one-shot note. For
    ;; how long this one-shot should happen? This is regulated in $4003 as you
    ;; will see below.
    ;;
    ;; With this in mind note that in this example we set these two bits to
    ;; 1. Hence, it's an continuous beep, and the low nibble contains the volume
    ;; that will be constant over time. The value for the volume is F, hence
    ;; maximum volume.
    ;;
    ;; Finally we have the two most significant bits, which configure the "duty"
    ;; cycle. That is, on a square wave, what percentage of time should the wave
    ;; spend in the "up" position. We have two bits, so we can select four
    ;; different configurations of the wave's shape (see:
    ;; https://www.nesdev.org/wiki/APU_Pulse). Here we pick "10", which
    ;; corresponds to the 50% duty cycle, meaning that we want a square wave
    ;; that spends the same amount of time up and down.
    lda #%10111111
    sta APU::m_square_1_envelope

    ;; The $4001 address contains the sweep register, which is a way that the
    ;; APU has in order to produce different pitch effects, or workaround known
    ;; issues on some tones. Configuring the sweep register so we tend towards
    ;; lower frequencies (longer periods) can also be a way of muting the
    ;; channel. I'm not touching it here other than resetting to 0.
    lda #0
    sta APU::m_square_1_sweep

    ;; The note to play is 11 bits long. This means that we need two bytes for
    ;; it, which for square 1 are $4002 and $4003. $4002 contains the least
    ;; significant bits, and the three least significant bits from $4003 are the
    ;; most significant bits from this 11-bit note definition. How to know which
    ;; note corresponds to what value is easy via:
    ;; https://www.nesdev.org/wiki/APU_period_table. Thus, in NTSC, setting $0C9
    ;; to this 11-bit value gives us a C#.
    ;;
    ;; The 5 other bits from $4003 correspond to the length counter. That is,
    ;; you can regulate for how long this note has to be reproduced, and the APU
    ;; will (magically) track things for you. Funnily enough, this "counter" is
    ;; not really a counter, but an index to a table with the actual values. See
    ;; the table here: https://www.nesdev.org/wiki/APU_Length_Counter. This is
    ;; not available on this configuration because we disabled the option when
    ;; we configured 'APU::m_square_1_envelope' (see above). Hence, we will set
    ;; these bits to 0.
    ;;
    ;; NOTE: one gotcha from writing into $4003 is that it implicitely resets
    ;; the envelope. Hence, if you write to this every frame for whatever
    ;; reason, then you will never notice the fading.
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
