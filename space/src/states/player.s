;;;
;; Player state: movement, animation, etc. The following memory addresses are
;; reserved for the player:
;;   -> $30-$3F: internal data.
;;   -> $0200-$0207: OAM data.
;;;
.scope Player
    ;; Unsigned screen coordinates on the X axis.
    m_screen_x = $30

    ;; Unsigned screen coordinates on the Y axis.
    m_screen_y = $31

    ;; The actual velocity on the X coordinates. This is a signed fixed point
    ;; 4.4 (high nibble: pixels; low: subpixels).
    m_velocity_x = $32

    ;; The actual velocity on the Y coordinates. This is a signed fixed point
    ;; 4.4 (high nibble: pixels; low: subpixels).
    m_velocity_y = $33

    ;; The target velocity on the X coordinates. This is a signed fixed point
    ;; 4.4 (high nibble: pixels; low: subpixels).
    m_target_velocity_x = $34

    ;; The target velocity on the Y coordinates. This is a signed fixed point
    ;; 4.4 (high nibble: pixels; low: subpixels).
    m_target_velocity_y = $35

    ;; Computed position on the X coordinates at the subpixel level. This is a
    ;; signed fixed point 12.4. NOTE: two bytes!
    m_position_x = $36

    ;; Computed position on the X coordinates at the subpixel level. This is a
    ;; signed fixed point 12.4. NOTE: two bytes!
    m_position_y = $38

    ;; Initializes the player by initializing its internal data and loading some
    ;; values of the sprite itself.
    .proc init
        ;; Initialize position + subpixel.
        lda #$B0
        sta m_position_y
        lda #$00
        sta m_position_y + 1
        lda #$7A
        sta m_position_x
        lda #$F0
        sta m_position_x + 1

        ;; Initialize velocity.
        lda #0
        sta m_velocity_x
        sta m_velocity_y
        sta m_target_velocity_x
        sta m_target_velocity_y

        rts
    .endproc

    ;; Contains all the subroutines that have to deal with computing the
    ;; movement of the sprite depending on the previous state, the buttons being
    ;; pressed, the current position, etc.
    .scope Movement
        .proc update
            jsr set_target_velocity
            jsr accelerate
            jsr apply_velocity
            jsr position_to_coordinates
            rts
        .endproc

        ;; Set the target velocity for the X and Y axis given the current button
        ;; presses.
        .proc set_target_velocity
            ;; The target velocity depends on whether B was pressed or not.
            ;; Depending on that we will set the x index to point to one element
            ;; of the velocity tables below or to another.
            ldx #0
            lda #Joypad::BUTTON_B
            and Joypad::m_buttons1
            beq @target_check_right
            inx
        @target_check_right:
            ;; The algorithm from here on is pretty straight-forward. Check the
            ;; right button. If it was not pressed jump to the left check. If it
            ;; was pressed load the target velocity on the x-axis from the given
            ;; table and jump into the arrow-up check.
            lda #Joypad::BUTTON_RIGHT
            and Joypad::m_buttons1
            beq @target_check_left
            lda positive_velocity, x
            sta m_target_velocity_x
            jmp @target_check_up
        @target_check_left:
            ;; Similar to before: if it was not pressed, then set the target
            ;; velocity to 0, otherwise set the proper value and jump to the up
            ;; check.
            lda #Joypad::BUTTON_LEFT
            and Joypad::m_buttons1
            beq @target_no_x
            lda negative_velocity, x
            sta m_target_velocity_x
            jmp @target_check_up
        @target_no_x:
            ;; None of the buttons on the X-axis were pressed. Set the target
            ;; velocity to 0.
            lda #0
            sta m_target_velocity_x
        @target_check_up:
            ;; Same as before but we return early if it was pressed, otherwise
            ;; we go into the arrow-down check.
            lda #Joypad::BUTTON_UP
            and Joypad::m_buttons1
            beq @target_check_down
            lda negative_velocity, x
            sta m_target_velocity_y
            rts
        @target_check_down:
            ;; If down was not pressed, go to the "no_y" case, otherwise return
            ;; early after setting the proper Y target velocity.
            lda #Joypad::BUTTON_DOWN
            and Joypad::m_buttons1
            beq @target_no_y
            lda positive_velocity, x
            sta m_target_velocity_y
            rts
        @target_no_y:
            ;; None of the buttons on the Y-axis were pressed. Set the target
            ;; velocity to 0.
            lda #0
            sta m_target_velocity_y
            rts
        positive_velocity:
            .byte $18, $28
        negative_velocity:
            .byte $E8, $D8
        .endproc

        ;; Increase the current velocity on each axis so to match the target
        ;; velocity on each case. Note that the velocity is simply increased by
        ;; one. A more detailed code could be more nuanced than this.
        .proc accelerate
            lda m_velocity_x
            sec
            sbc m_target_velocity_x
            bne @accelerate_x_check_greater
            jmp @accelerate_y
        @accelerate_x_check_greater:
            bmi @accelerate_x_check_lesser
            dec m_velocity_x
            jmp @accelerate_y
        @accelerate_x_check_lesser:
            inc m_velocity_x

        @accelerate_y:
            lda m_velocity_y
            sec
            sbc m_target_velocity_y
            bne @accelerate_y_check_greater
            rts
        @accelerate_y_check_greater:
            bmi @accelerate_y_check_lesser
            dec m_velocity_y
            rts
        @accelerate_y_check_lesser:
            inc m_velocity_y
            rts
        .endproc

        ;; Apply the currently computed velocity to the position at subpixel
        ;; level.
        .proc apply_velocity
            lda m_velocity_x
            bmi @apply_negative_velocity_x

            clc
            adc m_position_x
            sta m_position_x
            lda #0              ;NOTE: adding possible carry!
            adc m_position_x + 1
            sta m_position_x + 1
            jmp @apply_velocity_y
        @apply_negative_velocity_x:
            lda #0
            sec
            sbc m_velocity_x
            sta $00
            lda m_position_x
            sec
            sbc $00
            sta m_position_x
            lda m_position_x + 1
            sbc #0
            sta m_position_x + 1
        @apply_velocity_y:
            lda m_velocity_y
            bmi @apply_negative_velocity_y

            clc
            adc m_position_y
            sta m_position_y
            lda #0
            adc m_position_y + 1
            sta m_position_y + 1
            rts
        @apply_negative_velocity_y:
            lda #0
            sec
            sbc m_velocity_y
            sta $00
            lda m_position_y
            sec
            sbc $00
            sta m_position_y
            lda m_position_y + 1
            sbc #0
            sta m_position_y + 1
            rts
        .endproc

        ;; Translate the position at subpixel level to actual screen coordinates.
        .proc position_to_coordinates
            jsr position_to_coordinates_x
            jsr position_to_coordinates_y
            rts
        .endproc

        ;; Translate the X position at subpixel level to actual screen coordinates.
        .proc position_to_coordinates_x
            ;; Convert the fixed point position coordinate into screen coordinates
            lda m_position_x
            sta $00
            lda m_position_x + 1
            sta $01
            lsr $01
            ror $00
            lsr $01
            ror $00
            lsr $01
            ror $00
            lsr $01
            ror $00
            ; Assume that everything is fine and save the sprite position
            lda $00
            sta m_screen_x

            lda m_velocity_x
            bmi @position_from_negative_velocity

            lda $01
            bne @bound_upper_x
            lda $00
            cmp #239
            bcs @bound_upper_x
            rts
        @bound_upper_x:
            lda #$EF
            sta m_screen_x
            lda #$0E
            sta m_position_x + 1
            lda #$F0
            sta m_position_x
            lda #0
            sta m_velocity_x
            rts
        @position_from_negative_velocity:
            lda m_position_x + 1
            bmi @bound_lower_x
            rts
        @bound_lower_x:
            lda #0
            sta m_position_x
            sta m_position_x + 1
            sta m_screen_x
            sta m_velocity_x
            rts
        .endproc

        ;; Translate the Y position at subpixel level to actual screen coordinates.
        .proc position_to_coordinates_y
            ;; Convert the fixed point position coordinate into screen coordinates
            lda m_position_y
            sta $00
            lda m_position_y + 1
            sta $01
            lsr $01
            ror $00
            lsr $01
            ror $00
            lsr $01
            ror $00
            lsr $01
            ror $00
            ; Assume that everything is fine and save the sprite position
            lda $00
            sta m_screen_y

            lda m_velocity_y
            bmi @position_from_negative_velocity_y

            lda $01
            bne @bound_upper_y
            lda $00
            cmp #239
            bcs @bound_upper_y
            rts
        @bound_upper_y:
            lda #$EF
            sta m_screen_y
            lda #$0E
            sta m_position_y + 1
            lda #$F0
            sta m_position_y
            lda #0
            sta m_velocity_y
            rts
        @position_from_negative_velocity_y:
            lda m_position_y + 1
            bmi @bound_lower_y
            rts
        @bound_lower_y:
            lda #0
            sta m_position_y
            sta m_position_y + 1
            sta m_screen_y
            sta m_velocity_y
            rts
        .endproc
    .endscope

    ;; Functions related to the rendering and manipulation of the sprite itself.
    .scope Sprite
        ;; Update the sprite on OAM memory according to what we have in the
        ;; internal data stored in $30-$3F.
        .proc update
            ;; Update Y position.
            lda m_screen_y
            sta $200
            sta $204

            ;; Update X position.
            lda m_screen_x
            sta $203
            clc
            adc #8
            sta $207

            ;; If we have a target velocity, then we will show some fire,
            ;; otherwise we keep the basic ship.
            lda m_target_velocity_x
            bne @fire
            lda m_target_velocity_y
            bne @fire
            lda #0
            jmp @sprite_set
        @fire:
            lda #2
        @sprite_set:
            ;; The player itself is built with two identical sprites placed side
            ;; by side, where the second one is flipped horizontally. Thus, the
            ;; player takes up the first two slots on OAM data ($0200-$0207).
            ;; Here we only need to select the sprite and the attributes, since
            ;; the position will be updated on each game loop. Hence, here we
            ;; select the sprite as indexed by the value set on the `a` register
            ;; on the pattern table, and then we set for the second one the
            ;; horizontal flip bit for the attributes.
            sta $0201               ; First sprite select.
            sta $0205               ; Second sprite select.
            lda #%00000000
            sta $0202               ; First sprite attributes.
            lda #%01000000
            sta $0206               ; Second sprite attributes.

            rts
        .endproc
    .endscope
.endscope
