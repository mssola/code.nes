;; Clear the first nametable by resetting it to the default tile ID. This is a
;; rather drastic measure only to be done on examples that don't actually load
;; columns in "clever" ways, but they just want a clean slate.
.macro CLEAR_SCREEN
    ldy #$20
    jsr clear_screen_y
.endmacro

;; Clear the given two nametables. `ONE` and `OTHER` have to be the high byte
;; for each nametable to clear. For example, on an horizontal scrolling game:
;; `CLEAR_SCREENS $20, $24`.
.macro CLEAR_SCREENS ONE, OTHER
    ldy #ONE
    jsr clear_screen_y

    ldy #OTHER
    jsr clear_screen_y
.endmacro

;; Clear the nametable with the high byte as defined in the `y` register.
.proc clear_screen_y
    bit $2002

    ldx #$FF
@loop:
    sty $2006
    stx $2006
    lda #$00
    sta $2007

    dex
    bne @loop

    iny
    cpy #$24
    bne @loop

    rts
.endproc
