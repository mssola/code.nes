;;;
;; Show like `level.s` but at the very top of the screen we have a "This is a
;; message" being shown. This message is part of the background but it does not
;; scroll like the rest of the screen, but it stays at the same coordinates all
;; the time. This is done through sprite 0 collision detection, which is a
;; technique is quite often for early games on the NES/Famicom library (e.g.
;; Super Mario Bros.).
;;
;; The code is really similar to what we had in `level.s`, so I have removed all
;; comments from sections that are identical to those of `level.s`. That is, you
;; can just read the comments to get a "diff" between this one and `level.s`.

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A

    .byte $02
    .byte $01

    .byte $01
    .byte $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CODE"

;; We include the engine as in `level.s`, but we tweak the row offset so we have
;; at least one empty row in order to fit the HUD from this example.
BACKGROUND_ROW_OFFSET = 1
.include "include/all.s"

;; Clear out the first two rows of tiles from the nametable identified by the
;; `x` register.
.proc clear_row_x
    bit PPU::STATUS

    stx PPU::ADDRESS
    lda #$00
    sta PPU::ADDRESS

    ldx #$40
@loop:
    sta PPU::DATA
    dex
    bne @loop

    rts
.endproc

;; Show our awesome HUD, which simply shows a background message with "This is a
;; message". Note that the first sprite on OAM will be initialized also here,
;; which if you look into the CHR file you will realize it's merely two dots put
;; together. The trick is to put this simple sprite right into the final "E" of
;; "message", so it's hidden there. Whenever the PPU detects the collision (i.e.
;; "sprite 0 collision"), we will be able to react accordingly.
;;
;; Note also that because of the limitations from the engine in `include` on not
;; being able to have multiple palettes, it really stands out. This is actually
;; useful on this example, but in a real game you'd want to dedicate a palette
;; which matches the same color from the background one. That is, you'd really
;; want to hide it.
.proc show_hud
    ;; Clear the first two rows of tiles for both nametables as this will be
    ;; where we will place the HUD.
    ldx #$20
    jsr clear_row_x
    ldx #$24
    jsr clear_row_x

    ;; Set the background for the HUD. Note that we need it in both nametables,
    ;; as the engine will actually flip the nametable being used on the
    ;; PPU::CONTROL register.

    ;; This
    WRITE_PPU_DATA $2028, $23
    WRITE_PPU_DATA $2029, $17
    WRITE_PPU_DATA $202A, $18
    WRITE_PPU_DATA $202B, $22
    WRITE_PPU_DATA $2428, $23
    WRITE_PPU_DATA $2429, $17
    WRITE_PPU_DATA $242A, $18
    WRITE_PPU_DATA $242B, $22

    ;; is
    WRITE_PPU_DATA $202D, $18
    WRITE_PPU_DATA $202E, $22
    WRITE_PPU_DATA $242D, $18
    WRITE_PPU_DATA $242E, $22

    ;; a
    WRITE_PPU_DATA $2030, $10
    WRITE_PPU_DATA $2430, $10

    ;; message
    WRITE_PPU_DATA $2032, $1C
    WRITE_PPU_DATA $2033, $14
    WRITE_PPU_DATA $2034, $22
    WRITE_PPU_DATA $2035, $22
    WRITE_PPU_DATA $2036, $10
    WRITE_PPU_DATA $2037, $16
    WRITE_PPU_DATA $2038, $14
    WRITE_PPU_DATA $2432, $1C
    WRITE_PPU_DATA $2433, $14
    WRITE_PPU_DATA $2434, $22
    WRITE_PPU_DATA $2435, $22
    WRITE_PPU_DATA $2436, $10
    WRITE_PPU_DATA $2437, $16
    WRITE_PPU_DATA $2438, $14

    ;; Initialize sprite 0, which won't change across the run.
    lda #$06
    sta $200
    lda #$03
    sta $201
    lda #$00
    sta $202
    lda #$C0
    sta $203

    rts
.endproc

;; From level.s the only thing changed is the call to `show_hud`.
.proc main
    lda #$00
    sta PPU::zp_mask
    sta PPU::MASK

    jsr Palettes::init
    jsr Metatile::init
    jsr Driver::init
    jsr Background::init
    jsr Player::init

    ;; Show HUD.
    jsr show_hud

    cli

    lda #%10001000
    sta PPU::zp_control
    sta PPU::CONTROL

@main_game_loop:
    READ_JOYPAD1
    jsr Player::update
    jsr Driver::update

    lda #%10000000
    ora Globals::zp_flags
    sta Globals::zp_flags

@wait_for_render:
    bit Globals::zp_flags
    bmi @wait_for_render

    jmp @main_game_loop
.endproc

;; It's mostly as in `level.s`, but: 1. the scroll register is always set; 2. we
;; have to handle sprite 0 collision.
.proc nmi
    bit Globals::zp_flags
    bpl @next

    pha
    txa
    pha
    tya
    pha

    jsr Player::update_sprite

    OAM_WRITE_SPRITES

    FLUSH_PENDING_VRAM_BUFFER

    ;; Should we update PPU registers? If not, then we can go down to the next
    ;; section. Otherwise we need to update the PPU registers that have been
    ;; buffered. Note that in stark difference with `level.s` the scroll
    ;; register is not included inside of the code below. That's because it has
    ;; to be set unconditionally or the whole sprite 0 detection trick would
    ;; flicker whenever the player stops scrolling the screen.
    bit Globals::zp_flags
    bvc @scroll

    lda #%10111111
    and Globals::zp_flags
    sta Globals::zp_flags

    bit PPU::STATUS

    lda PPU::zp_control
    sta PPU::CONTROL
    lda PPU::zp_mask
    sta PPU::MASK

@scroll:
    ;; Is the level actually loaded? If not then it's pointless to mess with the
    ;; scroll register or waiting for anything: skip all of this.
    lda Globals::zp_flags
    and #%00100000
    beq @unset_render_flag

    ;; First of all, reset the scroll register to zero for the HUD.
    bit PPU::STATUS
    lda #$00
    sta PPU::SCROLL
    lda #$00
    sta PPU::SCROLL

    ;; To be safe, wait until the sprite 0 bit is unset. This will happen
    ;; whenever the PPU starts rendering the screen. In other words, we wait
    ;; until VBlank has been consumed because this whole trick has to happen
    ;; mid-frame rendering.
@wait_sprite0_unset:
    bit PPU::STATUS
    bvs @wait_sprite0_unset

    ;; And now everything will be rendered as usual, with scroll = 0. So wait
    ;; until the PPU detects a collision between a background element and sprite
    ;; 0. This will happen at the last point of the "E" in "MESSAGE", where our
    ;; sprite 0 has been "hidden". Whenever that happens, the PPU will set the
    ;; proper bit on the PPU::STATUS register.
@wait_sprite0_set:
    bit PPU::STATUS
    bvc @wait_sprite0_set

    ;; NOTE: after this some games like Super Mario Bros. set up a small delay,
    ;; but through testing both on emulators (FCEUX and Mesen) and on real
    ;; hardware, I haven't seen any problems without this delay.

    ;; Update the scroll register again to its real value.
    lda Background::zp_scroll
    sta PPU::SCROLL
    lda #$00
    sta PPU::SCROLL

    ;; And continue as in `level.s`.

@unset_render_flag:
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

.proc irq
    rti
.endproc

.segment "CHARS"
    .incbin "../assets/diskun.chr"
