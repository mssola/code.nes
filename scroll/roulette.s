;;;
;; Divide the screen in three rows and make them move in different
;; directions/speed. This is achieved thanks to the MMC3 chip (check
;; `fx/blink.s` for further information on this chip). In particular, we are
;; using the scanline IRQ mechanism provided by this chip to react to different
;; parts of the screen being rendered:
;;
;;   1. The top of the screen moves fast on one direction.
;;   2. The center of the screen moves fast on the opposite direction.
;;   3. The bottom of the screen moves on the same direction as 1. but slower.
;;
;; This is achieved by setting an IRQ that hits on points 2. and 3., and then we
;; manipulate the PPU scroll register mid frame. That is, all you see are just
;; background elements being scrolled in different ways.
;;
;; This trick was used, for example, on Super Mario Bros. 3 for the roulette
;; mini-game. That being said, usually games used this capability to handle
;; scroll on the top part of the screen, and then resetting the scroll on the
;; lower part, so they could show a status section (again, as Super Mario Bros.
;; 3 does inside of a level, and in mmc3.s here).

;; Include helpful definitions.
.include "../shared/mmc3.s"

;; Variables used on this example.
.scope Vars
    zp_top_scroll    = $00
    zp_center_scroll = $01
    zp_bottom_scroll = $02
    zp_is_bottom     = $04         ; 0 -> scroll center; 1 -> scroll bottom
.endscope

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $10
    .byte $10
    .byte $42, $08
    .res 8, 0

.segment "VECTORS"
    .addr nmi, reset, irq

;;; NOTE: lots of banks, all of them empty since we don't need them :)

.segment "PRG0_00"
.byte $FF
.segment "PRG0_01"
.byte $FF
.segment "PRG0_02"
.byte $FF
.segment "PRG0_03"
.byte $FF
.segment "PRG0_04"
.byte $FF
.segment "PRG0_05"
.byte $FF
.segment "PRG0_06"
.byte $FF
.segment "PRG0_07"
.byte $FF
.segment "PRG0_08"
.byte $FF
.segment "PRG0_09"
.byte $FF
.segment "PRG0_0A"
.byte $FF
.segment "PRG0_0B"
.byte $FF
.segment "PRG0_0C"
.byte $FF
.segment "PRG0_0D"
.byte $FF
.segment "PRG0_0E"
.byte $FF
.segment "PRG1_00"
.byte $FF
.segment "PRG1_01"
.byte $FF
.segment "PRG1_02"
.byte $FF
.segment "PRG1_03"
.byte $FF
.segment "PRG1_04"
.byte $FF
.segment "PRG1_05"
.byte $FF
.segment "PRG1_06"
.byte $FF
.segment "PRG1_07"
.byte $FF
.segment "PRG1_08"
.byte $FF
.segment "PRG1_09"
.byte $FF
.segment "PRG1_0A"
.byte $FF
.segment "PRG1_0B"
.byte $FF
.segment "PRG1_0C"
.byte $FF
.segment "PRG1_0D"
.byte $FF
.segment "PRG1_0E"
.byte $FF

;;; NOTE: the first fixed PRG bank will simply contain utilities for moving the
;;; player around.
.segment "FIXED"
.include "../shared/diskun.s"
.include "../shared/clear.s"

;;; NOTE: the main bulk of this example. Comments only for the parts which are
;;; specific to this example.
.segment "TAIL"
.include "../shared/ppu.s"

.proc reset
    sei
    cld

    ;; NOTE: as explained on the `basics/sprite.s` example, this is done to
    ;; disable the APU frame IRQ. This is usually done without giving it a
    ;; second thought, but it's specially relevant on the MMC3 chip because
    ;; disabling this allows the `irq` handler to be able to assume that the
    ;; only kind of IRQ available is a scanline one.
    ldx #$40
    stx $4017

    ldx #$FF
    txs

    inx
    stx $2000
    stx $2001
    stx $4010

    ;;;
    ;; NOTE: Setup MMC3. Nothing different from `fx/blink.s`. Take that example
    ;; as a reference on how to configure the MMC3 chip and bank switching on
    ;; it.

    lda #$00
    sta MMC3::MIRRORING
    sta MMC3::IRQ_DISABLE

    lda #$80
    sta MMC3::RAM_PROTECT

    BANK_REGISTER_SET 0, 0
    BANK_REGISTER_SET 1, 2
    BANK_REGISTER_SET 2, 4
    BANK_REGISTER_SET 3, 5
    BANK_REGISTER_SET 4, 6
    BANK_REGISTER_SET 5, 7
    BANK_REGISTER_SET 6, 0
    BANK_REGISTER_SET 7, 1

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

    lda #$00
    sta $2003
    lda #$02
    sta $4014

@vblankwait2:
    bit $2002
    bpl @vblankwait2

    lda #$3F
    sta $2006
    lda #$00
    sta $2006

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta $2007
    dex
    bne @palettes_reset_loop
    jmp main
.endproc

;; The main function is used here only for further initialization purposes.
.proc main
    ;; Clear both screens to avoid funky business, as we are not doing anything
    ;; specially clever here.
    CLEAR_SCREENS $20, $24

    ;; Initialize both the palettes and the nametables.
    jsr Diskun::init_palettes
    jsr init_nametables

    ;; NOTE: enable back interrupts so we can set them up later on `nmi` code.
    cli

    lda #%10001000
    sta $2000
    lda #%00011110
    sta $2001

@main_game_loop:
    ;; NOTE: nothing :D

    lda #%10000000
    ora $20
    sta $20
@wait_for_render:
    bit $20
    bmi @wait_for_render

    ;; NOTE: no game logic, everything happens on NMI and IRQ handlers.

    jmp @main_game_loop
.endproc

;; NOTE: everything displayed on this example only happens on the background.
;; Moreover, to give a more accurate illusion of the scrolling, the same
;; background elements are repeated on the other nametable. That's why we have
;; to set the data twice on each section: once for each nametable.
.proc init_nametables
    ;; Top left
    WRITE_PPU_DATA $20A6, $01
    WRITE_PPU_DATA $20C6, $11
    WRITE_PPU_DATA $20A7, $02
    WRITE_PPU_DATA $20C7, $12

    WRITE_PPU_DATA $24A6, $01
    WRITE_PPU_DATA $24C6, $11
    WRITE_PPU_DATA $24A7, $02
    WRITE_PPU_DATA $24C7, $12

    ;; Top center
    WRITE_PPU_DATA $20AF, $01
    WRITE_PPU_DATA $20CF, $11
    WRITE_PPU_DATA $23CB, %01000100
    WRITE_PPU_DATA $20B0, $02
    WRITE_PPU_DATA $20D0, $12
    WRITE_PPU_DATA $23CC, %00010001

    WRITE_PPU_DATA $24AF, $01
    WRITE_PPU_DATA $24CF, $11
    WRITE_PPU_DATA $27CB, %01000100
    WRITE_PPU_DATA $24B0, $02
    WRITE_PPU_DATA $24D0, $12
    WRITE_PPU_DATA $27CC, %00010001

    ;; Top right
    WRITE_PPU_DATA $20B8, $01
    WRITE_PPU_DATA $20D8, $11
    WRITE_PPU_DATA $23CE, %00100010
    WRITE_PPU_DATA $20B9, $02
    WRITE_PPU_DATA $20D9, $12

    WRITE_PPU_DATA $24B8, $01
    WRITE_PPU_DATA $24D8, $11
    WRITE_PPU_DATA $27CE, %00100010
    WRITE_PPU_DATA $24B9, $02
    WRITE_PPU_DATA $24D9, $12

    ;; Center left
    WRITE_PPU_DATA $21E6, $01
    WRITE_PPU_DATA $2206, $11
    WRITE_PPU_DATA $21E7, $02
    WRITE_PPU_DATA $2207, $12

    WRITE_PPU_DATA $25E6, $01
    WRITE_PPU_DATA $2606, $11
    WRITE_PPU_DATA $25E7, $02
    WRITE_PPU_DATA $2607, $12

    ;; Center center
    WRITE_PPU_DATA $21EF, $01
    WRITE_PPU_DATA $220F, $11
    WRITE_PPU_DATA $21F0, $02
    WRITE_PPU_DATA $2210, $12
    WRITE_PPU_DATA $23DB, %01000000
    WRITE_PPU_DATA $23E3, %00000100
    WRITE_PPU_DATA $23DC, %00010000
    WRITE_PPU_DATA $23E4, %00000001

    WRITE_PPU_DATA $25EF, $01
    WRITE_PPU_DATA $260F, $11
    WRITE_PPU_DATA $25F0, $02
    WRITE_PPU_DATA $2610, $12
    WRITE_PPU_DATA $27DB, %01000000
    WRITE_PPU_DATA $27E3, %00000100
    WRITE_PPU_DATA $27DC, %00010000
    WRITE_PPU_DATA $27E4, %00000001

    ;; Center right
    WRITE_PPU_DATA $21F8, $01
    WRITE_PPU_DATA $2218, $11
    WRITE_PPU_DATA $21F9, $02
    WRITE_PPU_DATA $2219, $12
    WRITE_PPU_DATA $23DE, %00100000
    WRITE_PPU_DATA $23E6, %00000010

    WRITE_PPU_DATA $25F8, $01
    WRITE_PPU_DATA $2618, $11
    WRITE_PPU_DATA $25F9, $02
    WRITE_PPU_DATA $2619, $12
    WRITE_PPU_DATA $27DE, %00100000
    WRITE_PPU_DATA $27E6, %00000010

    ;; Bottom left
    WRITE_PPU_DATA $2326, $01
    WRITE_PPU_DATA $2327, $02
    WRITE_PPU_DATA $2346, $11
    WRITE_PPU_DATA $2347, $12

    WRITE_PPU_DATA $2726, $01
    WRITE_PPU_DATA $2727, $02
    WRITE_PPU_DATA $2746, $11
    WRITE_PPU_DATA $2747, $12

    ;; Bottom center
    WRITE_PPU_DATA $232F, $01
    WRITE_PPU_DATA $234F, $11
    WRITE_PPU_DATA $2330, $02
    WRITE_PPU_DATA $2350, $12
    WRITE_PPU_DATA $23F3, %01000100
    WRITE_PPU_DATA $23F4, %00010001

    WRITE_PPU_DATA $272F, $01
    WRITE_PPU_DATA $274F, $11
    WRITE_PPU_DATA $2730, $02
    WRITE_PPU_DATA $2750, $12
    WRITE_PPU_DATA $27F3, %01000100
    WRITE_PPU_DATA $27F4, %00010001

    ;; Bottom right
    WRITE_PPU_DATA $2338, $01
    WRITE_PPU_DATA $2358, $11
    WRITE_PPU_DATA $2339, $02
    WRITE_PPU_DATA $2359, $12
    WRITE_PPU_DATA $23F6, %00100010

    WRITE_PPU_DATA $2738, $01
    WRITE_PPU_DATA $2758, $11
    WRITE_PPU_DATA $2739, $02
    WRITE_PPU_DATA $2759, $12
    WRITE_PPU_DATA $27F6, %00100010

    rts
.endproc

;;;
;; NOTE: for this example the NMI is a bit different than on other examples. It
;; has to do mainly two things:
;;   1. Set up a scanline IRQ so the scroll at the center/bottom is different.
;;   2. Set the scroll for the top region.
.proc nmi
    bit $20
    bpl @next

    pha
    txa
    pha
    tya
    pha

    ;; NOTE: no DMA transfer as usual since there are no sprites involved.

    ;;;
    ;; NOTE: setting up IRQs for scanline counting.

    ;; Disable scanline IRQs and acknowledge any previous one. Technically
    ;; speaking this is not needed because the only times we set up an IRQ we
    ;; know it's going to be acknowledge where it is needed. That being said,
    ;; let's be safe.
    ldx #$00
    stx MMC3::IRQ_DISABLE

    ;; The screen is made up of 240 visible scan lines. Since we are dividing
    ;; the screen by 3: 240 / 3 = 80. Hence, the next IRQ should happen on
    ;; scanline 80, where we would need to update the scroll value through the
    ;; `{center/bottom}_scroll` values instead. Moreover, note that
    ;; `MMC3::IRQ_ENABLE` accepts any value, so the same value as the two other
    ;; registers is just fine.
    lda #80
    sta MMC3::IRQ_LATCH
    sta MMC3::IRQ_RELOAD
    sta MMC3::IRQ_ENABLE

    ;; The IRQ for scanline 80 has been set up. Now proceed with the scroll for
    ;; the top section. The scroll will only happen on the X axis and it's going
    ;; to be a bit fast.
    bit $2002
    lda Vars::zp_top_scroll
    clc
    adc #2
    sta Vars::zp_top_scroll
    sta $2005
    lda #$00
    sta $2005

    ;; NOTE: the rest as usual.

    lda #%01111111
    and $20
    sta $20

    pla
    tay
    pla
    tax
    pla
@next:
    rti
.endproc

;;;
;; NOTE: handle a scanline IRQ.
;;
;; Notice that we cannot at first glance know what kind of IRQ is hitting at the
;; moment, but we have disabled the frame counter on our `reset` code, so on the
;; context of the MMC3 chip the only thing left are scanline IRQs, which we have
;; set up on `nmi` code.
.proc irq
    ;; Save current context.
    pha
    txa
    pha
    tya
    pha

    ;; Disable IRQs and acknowledge the current one.
    ldx #$00
    stx MMC3::IRQ_DISABLE

    ;; What are we trying to scroll, exactly?
    lda Vars::zp_is_bottom
    beq @scroll_right

    ;; We are scrolling the bottom section, which scrolls in the same direction
    ;; as the top one but a bit slower at that. Load the next scroll value on
    ;; the `a` register and `Vars::zp_bottom_scroll`.
    lda Vars::zp_bottom_scroll
    clc
    adc #1
    sta Vars::zp_bottom_scroll
    ldy #0
    sty Vars::zp_is_bottom
    jmp @do_scroll

@scroll_right:
    ;; We are scrolling the center, which works by going on the opposite
    ;; direction as the top and bottom sections. Load the next scroll value on
    ;; the `a` register and `Vars::zp_center_scroll`.
    lda Vars::zp_center_scroll
    sec
    adc #$FD
    sta Vars::zp_center_scroll
    ldy #1
    sty Vars::zp_is_bottom

    ;; We are at the center, but there is still the bottom section to be
    ;; scrolled differently. Hence, set a new scanline IRQ 80 lines ahead of
    ;; where we are now. This is done in pretty much the same way as we did in
    ;; `nmi` code.
    ldx #80
    stx MMC3::IRQ_LATCH
    stx MMC3::IRQ_RELOAD
    stx MMC3::IRQ_ENABLE

@do_scroll:
    ;; Regardless of the path, the `a` register contains the value for the
    ;; scroll on the X axis. Store this value now and leave.
    sta $2005
    lda #$00
    sta $2005

    ;; Restore previous context.
    pla
    tay
    pla
    tax
    pla

    rti
.endproc

;;; NOTE: pretty much the same as `fx/blink.s`.

.segment "CHARS"
.incbin "../assets/diskun0.chr"
.incbin "../assets/diskun1.chr"
.res $1000, $00

;; The 15 other 8KB portions are left empty.
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
