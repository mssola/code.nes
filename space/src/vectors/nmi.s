;; See `basics/sprite.s` for more info. I'm not doing anything fancier here.
nmi:
    bit $20
    bpl @next

    ;; Save registers.
    pha
    txa
    pha
    tya
    pha

    ;; We can start rendering stuff.
    OAM_WRITE_SPRITES

    ;; Reset scroll.
    bit $2002                   ; PPUSTATUS
    lda #$00
    sta $2005                   ; PPUSCROLL
    sta $2005                   ; PPUSCROLL

    ;; And unset the render flag so the `main` code is unblocked.
    UNSET_RENDER_FLAG

    ;; Restore registers.
    pla
    tay
    pla
    tax
    pla
@next:
    rti
