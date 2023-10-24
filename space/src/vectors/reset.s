.segment "CODE"

reset:
    ;; Ignore IRQs and disable decimal mode.
    sei
    cld

    ;; Disable APU frame IRQ.
    ldx #$40
    stx APU::FRAME_COUNTER

    ;; Set up the stack register with the proper value.
    ldx #$ff
    txs

    ;; And now disable, in this order, NMI, rendering and DMC IRQs. Note that
    ;; `x` was set to $ff, so increasing it by one results in a zero, which is
    ;; the value then stored in the aforementioned memory locations.
    inx
    stx PPU::CONTROL
    stx PPU::MASK
    stx APU::DMC

    ;;;
    ;; NOTE: If you are using a mapper which needs some special configuration,
    ;; now it would be a good time set it up. I am not using a special mapper,
    ;; so there's nothing from me to do here.
    ;;;

    ;; First of the two VBLANK waits.
@vblankwait1:
    bit PPU::STATUS
    bpl @vblankwait1

    ;; Clear RAM memory. Notice that we are not clearing $200-$2ff, this is done
    ;; later.
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

    ;; Reset sprites by moving them off-screen.
    lda #$ef
@sprite_reset_loop:
    sta $200, x
    inx
    bne @sprite_reset_loop

    ;; Write "sprites" into OAM.
    OAM_WRITE_SPRITES

    ;; Last VBLANK wait.
@vblankwait2:
    bit PPU::STATUS
    bpl @vblankwait2

    ;; Reset palettes.
    PPU_ADDR $3F00

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta PPU::DATA
    dex
    bne @palettes_reset_loop

    ;; Jump into the main subroutine.
    jmp main
