;; Shared code for palettes across scrolling examples.
.scope Palettes
    DEFAULT_COLOR = $11

    ;; Copies all the palettes for our game into the proper PPU address.
    ;;
    ;; NOTE: as explained in `metatile.s`, the engine for the scrolling examples
    ;; lack the ability to update the attributes for each tile. This is
    ;; embarrasing, but adding support for it would make these examples more
    ;; complex than they need to be. Hence we just reproduce the same palette
    ;; all over and avoid glitches on real hardware or emulators with randomized
    ;; memory.
    .proc init
        lda #$3F
        sta PPU::ADDRESS
        lda #$00
        sta PPU::ADDRESS

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
        .byte DEFAULT_COLOR, $36, $17, $0F
        .byte DEFAULT_COLOR, $36, $17, $0F
        .byte DEFAULT_COLOR, $36, $17, $0F

        ;; Foreground
        .byte DEFAULT_COLOR, $28, $0F, $30
        .byte DEFAULT_COLOR, $28, $0F, $30
        .byte DEFAULT_COLOR, $28, $0F, $30
        .byte DEFAULT_COLOR, $28, $0F, $30
    .endproc
.endscope
