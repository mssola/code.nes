;;;
;;; TODO: reduce the scope of this to just:
;;;   - Movement through subpixels.
;;;   - Shooting (no collision or anything)
;;; -> link to jetpac.nes for more stuff
;;;
;; This is similar to the sprite.s example, but it expands on it greatly into a
;; full game by:
;;   - Having a moving background.
;;   - The ship can be moved:
;;     - The movement is done through subpixels for a smoother experience.
;;     - The ship's sprites are updated accordingly: resting, acceleration, full
;;       speed.
;;   - Random asteroids will appear from time to time and they can collide with
;;     the ship:
;;     - A collision decreases the live status from the ship (cracks will appear
;;       to the sprite).
;;     - When the live status reaches 0 -> game over.
;;   - The ship can shoot and destroy asteroids.
;;   - There is a score.
;;;

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A

    ;; 2x PRG-ROM; 1x CHR-ROM
    .byte $02
    .byte $01

    ;; Horizontal mirroring, no special mapper.
    .byte $00
    .byte $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHARS"
    .incbin "../assets/space.chr"

.segment "STARTUP"

.segment "CODE"

.include "../include/apu.s"
.include "../include/oam.s"
.include "../include/ppu.s"
.include "../include/joypad.s"

.include "states/game.s"
.include "states/player.s"
.include "vectors/reset.s"
.include "vectors/nmi.s"
.include "vectors/irq.s"

;;;
;; This is our main subroutine, the reset procedure will call at the very end of
;; initializing the hardware.
;;;
.proc main
    ;; Before starting the game loop proper we initialize all our assets: load
    ;; the palettes, nametables and sprites for this game.
    jsr init_palettes
    jsr init_nametable
    jsr Player::init

    ;; Reset scroll.
    bit PPU::STATUS
    lda #$00
    sta PPU::SCROLL
    sta PPU::SCROLL

    cli

    ;; 7: allow NMI; 5: sprite size is 8x16; 4: background pattern table starts
    ;; at $1000.
    lda #%10110000
    sta PPU::CONTROL

    ;; 4: show sprites; 3: show background; 2: show sprites in leftmost pixels
    ;; on the screen; 1: same as 2 but for background.
    lda #%00011110
    sta PPU::MASK

@main_game_loop:
    jsr Joypad::read
    jsr Player::Movement::update
    jsr Player::Sprite::update

    ;; This is a hand-shake between the code on `main` and the code on the
    ;; `nmi`. See Game::flags for more.
    SET_RENDER_FLAG
@wait_for_render:
    bit Game::flags
    bmi @wait_for_render

    ;; Rendering is done, we can perform another iteration of the loop!
    jmp @main_game_loop
.endproc

;; init_palettes copies all the palettes for our game into the proper PPU
;; address.
.proc init_palettes
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
    .byte $0F, $12, $22, $32
    .byte $0F, $00, $28, $30
    .byte $0F, $28, $16, $2D
    .byte $0F, $28, $16, $2D

    ;; Foreground
    .byte $0F, $00, $05, $30
    .byte $0F, $00, $00, $00
    .byte $0F, $00, $00, $00
    .byte $0F, $00, $00, $00
.endproc

;; init_nametable loads the relevant data to the nametable that is then going to
;; be used in order to build up the background.
.proc init_nametable
    bit PPU::STATUS

    ;; Big stars.
    WRITE_PPU_DATA $20C8, $02
    WRITE_PPU_DATA $227A, $02

    ;; Small stars.
    WRITE_PPU_DATA $20B9, $04
    WRITE_PPU_DATA $21CE, $04
    WRITE_PPU_DATA $21BA, $04
    WRITE_PPU_DATA $22B8, $04
    WRITE_PPU_DATA $22E7, $04

    ;; Select palette 1 for one of the small stars, giving it a red-ish look.
    WRITE_PPU_DATA $23CE, %00000001

    rts
.endproc
