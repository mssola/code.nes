;;;
;; Allow the player to scroll a level which spans more than two screens wide.
;; The heavy lifting is pulled by the engine contained in `include`, which even
;; if it has some big limitations, it's good enough for showing how this can be
;; achieved on the NES/Famicom. Read the comments along this file, but you will
;; have to dig deeper into `include` to better grasp how any of this works.
;;
;; As a final touch, you can press "Select" to switch between different levels,
;; even if I was lazy enough to only provide a second level.

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A

    .byte $02
    .byte $01

    .byte $01                   ; Vertical mirroring (important since we are using horizontal scrolling!)
    .byte $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CODE"

.include "include/all.s"

.proc main
    ;; The PPU mask is zero'ed out so no background nor sprites will be shown at
    ;; first. This will be the task of the `load_level_x` function which is
    ;; called during background initialization.
    lda #$00
    sta PPU::zp_mask
    sta PPU::MASK

    ;; Initialize engine.
    jsr Palettes::init
    jsr Metatile::init
    jsr Driver::init
    jsr Background::init
    jsr Player::init

    ;; Accept back interrupts.
    cli

    ;; 7: allow NMI; 5-4: background pattern table at $0000, sprites at $1000.
    ;;
    ;; NOTE: we store this same value both into the PPU register and into this
    ;; special `zp_control` variable. This variable will shadow the contents for
    ;; the PPU control register. Any operation that requires changing the value
    ;; for this register, from now on, we will simply touch this variable
    ;; instead. This is because from now on touching this register is only safe
    ;; inside of Vblank (a.k.a. NMI code). Our `nmi` handler has special code to
    ;; check whether there was an update on this register's value and update
    ;; things accordingly.
    lda #%10001000
    sta PPU::zp_control
    sta PPU::CONTROL

@main_game_loop:
    READ_JOYPAD1
    jsr Player::update
    jsr Driver::update

    ;; Set the `render` flag, meaning that the code logic is over and we can
    ;; safely go into `nmi` code.
    lda #%10000000
    ora Globals::zp_flags
    sta Globals::zp_flags

@wait_for_render:
    bit Globals::zp_flags
    bmi @wait_for_render

    ;; Rendering is done, we can perform another iteration of the loop!
    jmp @main_game_loop
.endproc

;; The basics are laid out in `basics/sprite.s`. Read the comments below for
;; more info.
.proc nmi
    ;; Skip this entirely if code is not finished. This is a safeguard, but
    ;; whenever it happens it means that we are stalling at least for a frame.
    bit Globals::zp_flags
    bpl @next

    ;; Save registers
    pha
    txa
    pha
    tya
    pha

    ;; Update the sprite of the player. For this simple game, it just means to
    ;; update its position.
    jsr Player::update_sprite

    ;; Render stuff.
    OAM_WRITE_SPRITES

    ;; Flush any pending background updates. This macro actually hides the most
    ;; expensive part executed during VBlank. Check the document on `buffer.s`
    ;; for more information.
    FLUSH_PENDING_VRAM_BUFFER

    ;; Should we update PPU registers? If not, then we can go down to the next
    ;; section. Otherwise we need to update the PPU registers that have been
    ;; buffered and set the scroll.
    bit Globals::zp_flags
    bvc @after_ppu

    ;; Zero out the "ppu" flag.
    lda #%10111111
    and Globals::zp_flags
    sta Globals::zp_flags

    ;; Reset the PPU address latch.
    bit PPU::STATUS

    ;; Update the PPU control/mask registers with their buffered values.
    lda PPU::zp_control
    sta PPU::CONTROL
    lda PPU::zp_mask
    sta PPU::MASK

    ;; Update scroll.
    lda Background::zp_scroll
    sta PPU::SCROLL
    lda #$00
    sta PPU::SCROLL

@after_ppu:
    ;; And unset the `render` flag so the `main` code is unblocked.
    lda #%01111111
    and Globals::zp_flags
    sta Globals::zp_flags

    ;; Restore registers.
    pla
    tay
    pla
    tax
    pla
@next:
    rti
.endproc

;; Unused.
.proc irq
    rti
.endproc

.segment "CHARS"
    .incbin "../assets/diskun.chr"
