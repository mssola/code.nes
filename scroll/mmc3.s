;;;
;; The same as in `level.s` but at the bottom of the screen we have a "This is a
;; message" being shown. This message is part of the background but it does not
;; scroll like the rest of the screen, but it stays at the same coordinates all
;; the time. This is done via the MMC3 chip, and the same technique is further
;; developed in `roulette.s`. In short, this mapper chip implements a bunch of
;; features, and one of them is the ability to instruct the chip to send an IRQ
;; on a given scanline. This is then done to mess with the scroll value and
;; obtain different effects.
;;
;; This example shows the most basic usage of it, and it's what games like Super
;; Mario Bros. 3 and Kirby's Adventure did: implement a status bar at the bottom
;; of the screen in a way that is reliable and less CPU consuming than sprite 0
;; hit detection as it's done in `sprite0.s`. That is, instead of wasting CPU
;; cycles waiting for a sprite 0 hit, during VBlank we configure the chip to
;; send us an IRQ for a given scanline. Once the PPU arrives at this scanline,
;; then it sends us an IRQ in which we reset the scroll value. This scroll value
;; will then be configured again during VBlank.
;;
;; The code is a mix between `level.s` and `fx/blink.s`, so consider these two
;; examples as previous work and get to know them before jumping into this one.
;; In here I have just written comments which are specific to this example.

;; Just like `fx/blink.s`.
.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $10, $10
    .byte $42, $08
    .res 8, 0

.segment "VECTORS"
    .addr nmi, reset, irq

;; Just like `fx/blink.s`: empty on purpose as this is a simple example.

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
.segment "FIXED"
.byte $FF

;; Everything happens on this segment. Check the `config/mmc3.cfg` for more
;; information on where it is placed in the end.
.segment "TAIL"

;; Just like with `sprite0.s`, the engine in `include/` can be configured to a
;; degree. In this case we instruct it to never go over the `$0D` row as this
;; will be the one being used for showing the status bar.
BACKGROUND_ROW_MAX = $0D
.include "include/all.s"
.include "../shared/mmc3.s"

;; Clear out the a rows of tiles from the high byte for the PPU address as given
;; in the `x` register, and the low byte as given on the `y` register.
.proc clear_row_x_y
    bit PPU::STATUS

    stx PPU::ADDRESS
    sty PPU::ADDRESS

    lda #$00
    ldx #$20
@loop:
    sta PPU::DATA
    dex
    bne @loop

    rts
.endproc

;; Similar to `show_hud` in `sprite0.s`, we want to allocate this text in the
;; background where the engine will not touch it.
.proc show_status
    ;; Clear out the space in which we want to allocate or status bar.
    ldx #$23
    ldy #$40
    jsr clear_row_x_y
    ldx #$23
    ldy #$60
    jsr clear_row_x_y
    ldx #$23
    ldy #$80
    jsr clear_row_x_y
    ldx #$27
    ldy #$40
    jsr clear_row_x_y
    ldx #$27
    ldy #$60
    jsr clear_row_x_y
    ldx #$27
    ldy #$80
    jsr clear_row_x_y

    ;; Just like with `sprite0.s`, the message has to be repeated over the
    ;; nametable on $2400 as the engine will flip the base nametable address
    ;; whenever the scroll wraps around.

    ;; This
    WRITE_PPU_DATA $2368, $23
    WRITE_PPU_DATA $2369, $17
    WRITE_PPU_DATA $236A, $18
    WRITE_PPU_DATA $236B, $22
    WRITE_PPU_DATA $2768, $23
    WRITE_PPU_DATA $2769, $17
    WRITE_PPU_DATA $276A, $18
    WRITE_PPU_DATA $276B, $22

    ;; is
    WRITE_PPU_DATA $236D, $18
    WRITE_PPU_DATA $236E, $22
    WRITE_PPU_DATA $276D, $18
    WRITE_PPU_DATA $276E, $22

    ;; a
    WRITE_PPU_DATA $2370, $10
    WRITE_PPU_DATA $2770, $10

    ;; message
    WRITE_PPU_DATA $2372, $1C
    WRITE_PPU_DATA $2373, $14
    WRITE_PPU_DATA $2374, $22
    WRITE_PPU_DATA $2375, $22
    WRITE_PPU_DATA $2376, $10
    WRITE_PPU_DATA $2377, $16
    WRITE_PPU_DATA $2378, $14
    WRITE_PPU_DATA $2772, $1C
    WRITE_PPU_DATA $2773, $14
    WRITE_PPU_DATA $2774, $22
    WRITE_PPU_DATA $2775, $22
    WRITE_PPU_DATA $2776, $10
    WRITE_PPU_DATA $2777, $16
    WRITE_PPU_DATA $2778, $14

    ;; NOTE: in stark contrast with `sprite0.s`, there's no need to waste a
    ;; sprite for this purpose.

    rts
.endproc

.proc main
    ;; Setup the MMC3 chip. Note that this is better suited in the `reset`
    ;; function, but the engine already provides one and I didn't want to start
    ;; messing with `.ifdef` and the likes.
    ;;
    ;; NOTE: this is a copy-paste from `fx/blink.s`, so refer to that example on
    ;; what any of the code below means.

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

    ;; MMC3 configured, now go on as usual.

    lda #$00
    sta PPU::zp_mask
    sta PPU::MASK

    jsr Palettes::init
    jsr Metatile::init
    jsr Driver::init
    jsr Background::init
    jsr Player::init

    ;; Show the status bar down below.
    jsr show_status

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

;; The basics are laid out in `basics/sprite.s`. Read the comments below for
;; more info.
.proc nmi
    bit Globals::zp_flags
    bpl @next

    pha
    txa
    pha
    tya
    pha

    ;; Just like in `fx/blink.s`, acknowledge any previous IRQ as a safety
    ;; measure. But anyways set the next IRQ to happen on scanline 210.

    ldx #$00
    stx MMC3::IRQ_DISABLE

    lda #210
    sta MMC3::IRQ_LATCH
    sta MMC3::IRQ_RELOAD
    sta MMC3::IRQ_ENABLE

    ;; From here on as in `level.s`.

    jsr Player::update_sprite

    OAM_WRITE_SPRITES

    FLUSH_PENDING_VRAM_BUFFER

    bit Globals::zp_flags
    bvc @after_ppu

    lda #%10111111
    and Globals::zp_flags
    sta Globals::zp_flags

    bit PPU::STATUS

    lda PPU::zp_control
    sta PPU::CONTROL
    lda PPU::zp_mask
    sta PPU::MASK

@after_ppu:
    ;; NOTE: scroll is updated always. This is in contrast with `level.s`, but
    ;; if we don't do that the scroll would be lost if the player stops moving
    ;; the scroll position.
    lda Background::zp_scroll
    sta PPU::SCROLL
    lda #$00
    sta PPU::SCROLL

    ;; And as usual again.

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

;; This is a much simpler version of IRQ handling as you can see in examples
;; such as `roulette.s`.
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

    ;; Reset the scroll so the status bar is kept in place. The scroll will be
    ;; kept like this until VBlank happens, when the `nmi` function will set the
    ;; scroll value to what's perceived by the player.
    bit PPU::STATUS
    lda #$00
    sta $2005
    sta $2005

    ;; Restore previous context.
    pla
    tay
    pla
    tax
    pla

    rti
.endproc

.segment "CHARS"
;; Similar to `fx/blink.s` but here we really needed something for the
;; background :)
.incbin "../assets/diskun-background.chr"
.incbin "../assets/diskun0.chr"
.incbin "../assets/diskun1.chr"

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
