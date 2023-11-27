;; Shared code for palettes across scrolling examples.
.scope Palettes
    DEFAULT_COLOR = $11

    ;; Copies all the palettes for our game into the proper PPU address.
    .proc init
        PPU_ADDR $3F00

        ldx #0
    @load_palettes_loop:
        lda palettes, x
        sta PPU::DATA
        inx
        cpx #$20
        bne @load_palettes_loop
        rts
    palettes:
        ;; Background
        .byte DEFAULT_COLOR, $36, $17, $0F
        .byte DEFAULT_COLOR, $00, $00, $00
        .byte DEFAULT_COLOR, $00, $00, $00
        .byte DEFAULT_COLOR, $00, $00, $00

        ;; Foreground
        .byte DEFAULT_COLOR, $28, $0F, $30
        .byte DEFAULT_COLOR, $00, $00, $00
        .byte DEFAULT_COLOR, $00, $00, $00
        .byte DEFAULT_COLOR, $00, $00, $00
    .endproc
.endscope
