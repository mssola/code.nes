;; This is the player code that gets re-used on all scrolling examples. This
;; will show a meta-sprite made up of four sprites that make up diskun. You can
;; move this player with the arrows, and the movement will be pretty basic (1
;; pixel each time). Furthermore, the sprite handles collision with background
;; elements (TODO), which is shared across all the scrolling examples.
;;
;; The sprite is stored in OAM memory $200-$20F, and the $30 and $31 memory
;; addresses are used for keeping up with the screen coordinates.
.scope Player
    m_screen_x = $30
    m_screen_y = $31

    .proc init
        lda #40
        sta m_screen_x
        sta m_screen_y

        lda #$01
        sta $201
        lda #$02
        sta $205
        lda #$11
        sta $209
        lda #$12
        sta $20D

        lda #0
        sta $202
        sta $206
        sta $20A
        sta $20E

        rts
    .endproc

    .proc update
        jsr update_coordinates
        jsr update_sprites
        rts
    .endproc

    .proc update_coordinates
        lda #Joypad::BUTTON_UP
        and Joypad::m_buttons1
        beq @check_down
        dec m_screen_y
        jmp @check_left
    @check_down:
        lda #Joypad::BUTTON_DOWN
        and Joypad::m_buttons1
        beq @check_left
        inc m_screen_y
    @check_left:
        lda #Joypad::BUTTON_LEFT
        and Joypad::m_buttons1
        beq @check_right
        dec m_screen_x
        rts
    @check_right:
        lda #Joypad::BUTTON_RIGHT
        and Joypad::m_buttons1
        beq @end
        inc m_screen_x
    ;; TODO: move scroll
    @end:
        rts
    .endproc

    .proc update_sprites
        lda m_screen_x
        sta $203
        sta $20B
        clc
        adc #8
        sta $207
        sta $20F

        lda m_screen_y
        sta $200
        sta $204
        clc
        adc #8
        sta $208
        sta $20C

        rts
    .endproc
.endscope
