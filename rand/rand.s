;;;
;; Showcase different strategies for Random Number Generation (RNG).
;;
;; Refer to the README.md file for documentation. Here I have left comments
;; whenever there's something "new" if you are coming from the `basics/`
;; directory.

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02, $01
    .byte $00, $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHARS"
.incbin "../assets/alphanum.chr"

.segment "CODE"

.include "../shared/ppu.s"
.include "../shared/clear.s"
.include "../shared/joypad.s"

;; Different algorithms.
.include "linear.s"
.include "precalc.s"

;; Number of algorithms for this game.
ALGORITHM_SIZE = $02

;; See Vars::zp_button_timer.
KEY_TIMER = 15

;; Variables used by this game.
.scope Vars
    ;; 0: "Press start" state; 1: "number generation" state.
    zp_state = $30

    ;; Timer for key presses. A button press will only be considered if the
    ;; button timer is zero. Whenever that's the case, the code will reset the
    ;; timer to this new value, and decrement it whenever a new press is found.
    ;; Whenever we reach back to zero, then the button press will be considered
    ;; again. All of this is because whenever the player presses a button, it
    ;; actually presses it for more than one frame, and things can go crazy from
    ;; this fact.
    zp_button_timer = $31

    ;; Algorithm that has been selected.
    zp_algorithm = $32

    ;; The random seed for this game. As described in the README.md file, this
    ;; is actually a frame counter for the "Press start" state, and whenever the
    ;; player hits "Start", it will be paused. That is, our random seed is
    ;; simply the number of frames that the player took to press "Start" at the
    ;; beginning.
    ;;
    ;; NOTE: it's not going to be initialized to get a more random feeling on
    ;; real hardware from unknown RAM state.
    zp_seed = $33

    ;; The number to be displayed.
    zp_number = $34
.endscope

;; Main function, this takes care of reading input, changing the state, and
;; calling the relevant algorithm to get new numbers.
.proc main
    ;; Initialize all variables (except Vars::zp_seed as explained above).
    lda #0
    sta Vars::zp_state
    sta Vars::zp_button_timer
    sta Vars::zp_algorithm
    sta Vars::zp_number

    ;; Clear both screens. Yes, over the top, but it gets the job done.
    CLEAR_SCREENS $20, $28

    ;; Initialize palettes and show the "Press start" message.
    jsr init_palettes
    jsr show_init_screen

    cli
    lda #%10001000
    sta $2000                   ; PPUCTRL
    lda #%00011110
    sta $2001                   ; PPUMASK

@main_game_loop:
    ;; Should we actually read the joypad? This is handled via the button timer
    ;; as explained above.
    lda Vars::zp_button_timer
    beq @check_joypad
    dec Vars::zp_button_timer
    jmp @end

@check_joypad:
    ;; Yes! Then read the joypad.
    READ_JOYPAD1

    ;; What's the current game state?
    lda Vars::zp_state
    bne @check_change_algorithm

    ;; "Press start" state. If the player is not pressing "Start", ignore
    ;; everything and go to the end.
    lda Joypad::zp_buttons1
    and #Joypad::BUTTON_START
    beq @end

    ;; Reset the button timer.
    lda #KEY_TIMER
    sta Vars::zp_button_timer

    ;; The random seed has a proper value and we can use that as a first random
    ;; number.
    lda Vars::zp_seed
    sta Vars::zp_number

    ;; The 'linear' algorithm actually disregards any parameters and needs a
    ;; 16-bit register. Let's initialize this register with the current seed.
    sta Linear::zp_register_lo
    sta Linear::zp_register_hi

    ;; Move into the next state.
    inc Vars::zp_state

    jmp @end

@check_change_algorithm:
    ;; We are in a running state. Check if the player is asking to change the
    ;; algorithm.
    lda Joypad::zp_buttons1
    and #Joypad::BUTTON_SELECT
    beq @check_a_button

    ;; Reset the button timer.
    lda #KEY_TIMER
    sta Vars::zp_button_timer

    ;; The player asked to change the algorithm. Do it now and go generate a new
    ;; number with that.
    ldx Vars::zp_algorithm
    inx
    cpx #ALGORITHM_SIZE
    bne @store_algorithm
    ldx #0
@store_algorithm:
    stx Vars::zp_algorithm
    jmp @next_number

@check_a_button:
    ;; Is the player asking for a new number? If not go to the end.
    lda Joypad::zp_buttons1
    and #Joypad::BUTTON_A
    beq @end

    ;; Reset the button timer.
    lda #KEY_TIMER
    sta Vars::zp_button_timer

@next_number:
    ;; Setup parameters depending on the algorithm and actually call it.
    ldx Vars::zp_algorithm
    bne @precalc
    jsr linear_feedback_shift_register
    jmp @store_number
@precalc:
    lda Vars::zp_number
    jsr precalc
@store_number:
    sta Vars::zp_number

@end:
    ;; And wait for the render to happen as it's done in any other example.
    lda #%10000000
    ora $20
    sta $20
@wait_for_render:
    bit $20
    bmi @wait_for_render

    jmp @main_game_loop
.endproc

;; NMI code is pretty standard. I have added comments for the code which is
;; specific to this game.
.proc nmi
    bit $20
    bpl @next

    pha
    txa
    pha
    tya
    pha

    lda #$00
    sta $2003                   ; OAMADDR
    lda #$02
    sta $4014                   ; OAMDMA

    ;; What's the current game state?
    lda Vars::zp_state
    beq @seed_inc

    ;; Running state. Print the current algorithm and number.
    jsr print_algorithm
    jsr print_value

    ;; The running state is displayed on the other nametable. Update the PPU
    ;; control register for this (it's of course stupid to update it every time,
    ;; but I didn't feel like doing the proper thing of shadowing the PPU
    ;; control register and update only on changes, etc.).
    lda #%10001010
    sta $2000                   ; PPUCTRL
    bne @after_seed

@seed_inc:
    ;; "Press start" state: just increase the frame counter which is used as a
    ;; seed.
    inc Vars::zp_seed

@after_seed:
    bit $2002                   ; PPUSTATUS
    lda #$00
    sta $2005                   ; PPUSCROLL
    sta $2005                   ; PPUSCROLL

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

;; Show the "Alg: <algorithm>" message on screen.
.proc print_algorithm
    ;; "ALG: "
    WRITE_PPU_DATA $298B, $1A
    WRITE_PPU_DATA $298C, $25
    WRITE_PPU_DATA $298D, $20
    WRITE_PPU_DATA $298E, $34
    WRITE_PPU_DATA $298F, $00

    lda Vars::zp_algorithm
    beq @linear

    ;; "PRECALC"
    WRITE_PPU_DATA $2990, $29
    WRITE_PPU_DATA $2991, $2B
    WRITE_PPU_DATA $2992, $1E
    WRITE_PPU_DATA $2993, $1C
    WRITE_PPU_DATA $2994, $1A
    WRITE_PPU_DATA $2995, $25
    WRITE_PPU_DATA $2996, $1C
    rts

    ;; "LINEAR "
@linear:
    WRITE_PPU_DATA $2990, $25
    WRITE_PPU_DATA $2991, $22
    WRITE_PPU_DATA $2992, $27
    WRITE_PPU_DATA $2993, $1E
    WRITE_PPU_DATA $2994, $1A
    WRITE_PPU_DATA $2995, $2B
    WRITE_PPU_DATA $2996, $00
    rts
.endproc

;; Show the "Val: $<number>" message on screen.
.proc print_value
    ;; "VAL: $"
    WRITE_PPU_DATA $29AB, $2F
    WRITE_PPU_DATA $29AC, $1A
    WRITE_PPU_DATA $29AD, $25
    WRITE_PPU_DATA $29AE, $34
    WRITE_PPU_DATA $29AF, $00
    WRITE_PPU_DATA $29B0, $35

    ;; Set the high byte on the 'y' register, and the low byte on the 'x'
    ;; register.
    lda #$F0
    and Vars::zp_number
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$10
    tay
    lda #$0F
    and Vars::zp_number
    clc
    adc #$10
    tax

    ;; Display the actual number.
    bit $2002
    lda #$29
    sta $2006
    lda #$B1
    sta $2006
    sty $2007
    stx $2007

    rts
.endproc

;; Show the "Press start" message.
.proc show_init_screen
    ;; "PRESS"
    WRITE_PPU_DATA $21AB, $29
    WRITE_PPU_DATA $21AC, $2B
    WRITE_PPU_DATA $21AD, $1E
    WRITE_PPU_DATA $21AE, $2C
    WRITE_PPU_DATA $21AF, $2C

    ;; "START"
    WRITE_PPU_DATA $21B1, $2C
    WRITE_PPU_DATA $21B2, $2D
    WRITE_PPU_DATA $21B3, $1A
    WRITE_PPU_DATA $21B4, $2B
    WRITE_PPU_DATA $21B5, $2D

    rts
.endproc

;; Initialize palettes. A bit over the top since only two colors are used.
.proc init_palettes
    lda #$3F
    sta $2006                   ; PPUADDR
    lda #$00
    sta $2006                   ; PPUADDR

    ldx #0
@load_palettes_loop:
    lda palettes, x
    sta $2007                   ; PPUDATA
    inx
    cpx #$20
    bne @load_palettes_loop
    rts
palettes:
    DEFAULT_COLOR = $0F

    ;; Background
    .byte DEFAULT_COLOR, $20, $FF, $FF
    .byte DEFAULT_COLOR, $20, $FF, $FF
    .byte DEFAULT_COLOR, $20, $FF, $FF
    .byte DEFAULT_COLOR, $20, $FF, $FF

    ;; Foreground
    .byte DEFAULT_COLOR, $20, $FF, $FF
    .byte DEFAULT_COLOR, $20, $FF, $FF
    .byte DEFAULT_COLOR, $20, $FF, $FF
    .byte DEFAULT_COLOR, $20, $FF, $FF

    rts
.endproc

;;;
;; NOTE: down below just boilerplate. Nothing special from the `basics/`
;; examples.

.proc reset
    sei
    cld

    ldx #$40
    stx $4017                   ; APU Frame Counter

    ldx #$FF
    txs

    inx
    stx $2000                   ; PPUCTRL
    stx $2001                   ; PPUMASK
    stx $4010                   ; APU DMC

    bit $2002                   ; PPUSTATUS
@vblankwait1:
    bit $2002                   ; PPUSTATUS
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
    bne @ram_reset_loop         ; if x overflows back to #00, then we are done.

    lda #$EF
@sprite_reset_loop:
    sta $200, x
    inx
    bne @sprite_reset_loop

    lda #$00
    sta $2003                   ; OAMADDR
    lda #$02
    sta $4014                   ; OAMDMA

@vblankwait2:
    bit $2002                   ; PPUSTATUS
    bpl @vblankwait2

    lda #$3F
    sta $2006                   ; PPUADDR
    lda #$00
    sta $2006                   ; PPUADDR

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta $2007                   ; PPUDATA
    dex
    bne @palettes_reset_loop

    jmp main
.endproc

.proc irq
    rti
.endproc

