;; Check `basics/sprite.s` for a deeper look on the logic below.
.proc reset
    sei
    cld

    ldx #$40
    stx APU::FRAME_COUNTER

    ldx #$FF
    txs

    inx
    stx PPU::CONTROL
    stx PPU::MASK
    stx APU::DMC

    bit PPU::STATUS
@vblankwait1:
    bit PPU::STATUS
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

    lda #$00
    sta OAM::ADDR
    lda #$02
    sta OAM::DMA

@vblankwait2:
    bit PPU::STATUS
    bpl @vblankwait2

    lda #$3F
    sta PPU::ADDRESS
    lda #$00
    sta PPU::ADDRESS

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta PPU::DATA
    dex
    bne @palettes_reset_loop

    jmp main
.endproc
