;;;
;; Toggle between two nametables with smooth scrolling. You can press right/left
;; to move on that direction, or press Select as a toggle.
;;
;; The main take away is that the scroll is the last thing to be updated on
;; `nmi` code, and that the nametable on the PPU control register should be
;; update if the camera changed focus. In other words, if we gradually move into
;; the next nametable and the PPU scroll register wraps around; then the $00 on
;; that register doesn't mean to go over the same screen, but that it's $00 on
;; the other nametable. This is something that can be easily missed when
;; programming scrolling on the NES/Famicom for the first time.
;;
;; Besides initialization and setup functions like `setup_screens`, the most
;; relevant code is in `update` and `nmi`. Read the comments there carefully.

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02, $01
    .byte $01, $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHARS"
.incbin "../assets/diskun.chr"

.segment "CODE"

.include "../shared/diskun.s"
.include "./include/apu.s"
.include "./include/ppu.s"
.include "./include/oam.s"
.include "./include/globals.s"
.include "../shared/ppu.s"
.include "../shared/clear.s"

;; Variables used on this example.
.scope Vars
    ;; Whether we are scrolling or not.
    zp_scrolling = $A0

    ;; Right = 1; Left = 0.
    zp_direction = $A1

    ;; Scroll value on the X axis.
    zp_scroll = $A2
.endscope

;; Setup both nametables to contain the background indications that we want.
;; It's not much, just a square with a number to identify each screen.
.proc setup_screens
    CLEAR_SCREENS $20, $24

    WRITE_PPU_DATA $21AE, $31
    WRITE_PPU_DATA $21AF, $31
    WRITE_PPU_DATA $21CE, $31
    WRITE_PPU_DATA $21CF, $31

    WRITE_PPU_DATA $25AE, $32
    WRITE_PPU_DATA $25AF, $32
    WRITE_PPU_DATA $25CE, $32
    WRITE_PPU_DATA $25CF, $32

    rts
.endproc

.proc update
    ;; Are we already scrolling? If so just skip this.
    lda Vars::zp_scrolling
    bne @end

    ;; Read the joypad.
    jsr joypad_read

    ;; Is the player pressing left? If so then the direction is to the left.
    lda #Joypad::BUTTON_LEFT
    and Joypad::m_buttons1
    beq @check_right
    inc Vars::zp_scrolling
    lda #0
    sta Vars::zp_direction
    rts

@check_right:
    ;; Is the player pressing right? If so then the direction is to the right.
    lda #Joypad::BUTTON_RIGHT
    and Joypad::m_buttons1
    beq @check_select
    inc Vars::zp_scrolling
    lda #1
    sta Vars::zp_direction
    rts

@check_select:
    ;; Is the player pressing Select? Then the direction depends on the current
    ;; nametable.
    lda #Joypad::BUTTON_SELECT
    and Joypad::m_buttons1
    beq @end
    inc Vars::zp_scrolling
    ldx #0
    lda PPU::zp_control
    and #%00000001
    bne @left
    inx
@left:
    stx Vars::zp_direction

@end:
    rts
.endproc

.proc main
    lda #0
    sta Globals::zp_flags
    sta Vars::zp_scrolling
    sta Vars::zp_direction
    sta Vars::zp_scroll

    jsr setup_screens
    jsr Diskun::init_palettes

    cli
    lda #%10001000
    sta PPU::zp_control
    sta PPU::CONTROL
    lda #%00011110
    sta PPU::MASK

@main_game_loop:
    jsr update

    lda #%10000000
    ora Globals::zp_flags
    sta Globals::zp_flags
@wait_for_render:
    bit Globals::zp_flags
    bmi @wait_for_render

    jmp @main_game_loop
.endproc

.proc nmi
    bit Globals::zp_flags
    bpl @next

    pha
    txa
    pha
    tya
    pha

    ;; Are we scrolling at all? If not, then just go to `@set_scroll` which will
    ;; simply set the scroll to 0 again.
    lda Vars::zp_scrolling
    beq @set_scroll

    ;; We are scrolling... on which direction?
    lda Vars::zp_direction
    beq @left

    ;; If we are scrolling right, flip the nametable if we already reached zero.
    ;; Otherwise we can set the new scroll value.
    inc Vars::zp_scroll
    beq @flip_nametable
    jmp @set_scroll

@left:
    ;; If we are scrolling left, and it's actually the first step, change the
    ;; nametable already. Otherwise set the new scroll value.
    dec Vars::zp_scroll
    lda #$FF
    cmp Vars::zp_scroll
    bne @set_scroll

@flip_nametable:
    ;; Reset the PPU address latch.
    bit PPU::STATUS

    ;; Flip the current nametable.
    lda PPU::zp_control
    eor #%00000001
    sta PPU::zp_control
    sta PPU::CONTROL

@set_scroll:
    ;; Set whatever was computed as the new scroll. Note that `zp_scrolling` can
    ;; be set at the same value, as we only care whenever it reaches 0, when it
    ;; should stop scrolling.
    lda Vars::zp_scroll
    sta Vars::zp_scrolling
    sta PPU::SCROLL
    lda #$00
    sta PPU::SCROLL

    ;; And the rest as usual.

    lda #%01111111
    and Globals::zp_flags
    sta Globals::zp_flags

    pla
    tay
    pla
    tax
    pla
@next:
    rti
.endproc

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

    OAM_WRITE_SPRITES

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

.proc irq
    rti
.endproc
