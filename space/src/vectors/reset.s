.segment "CODE"

;; Check `basics/sprite.s` for a deeper look on the logic below. I have only
;; added code after configuration/reset is done.
.proc reset
    sei
    cld
    ldx #$40
    stx $4017

    ldx #$FF
    txs

    inx
    stx $2000
    stx $2001
    stx $4010

    bit $2002
@vblankwait1:
    bit $2002
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

@vblankwait2:
    bit $2002
    bpl @vblankwait2

    ;;;
    ;; NOTE: configuration/reset is done, the code below is our actual program :D

    jmp main
.endproc
