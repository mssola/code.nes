;; Set the player to its initial coordinates.
.macro RESET_PLAYER_POSITION
    lda #40
    sta Player::zp_screen_x
    sta Player::zp_screen_y
.endmacro

;; This is the player code that gets re-used on all scrolling examples. This
;; will show a meta-sprite made up of four sprites that make up diskun. You can
;; move this player with the arrows, and the movement will be pretty basic (1
;; pixel at a time). Furthermore, the sprite handles collision with background
;; elements, which is shared across all the scrolling examples.
;;
;; The sprite is stored in OAM memory $204-$213 (hence sprite0 is left out so
;; other examples can use it), and the $30 and $31 memory addresses are used for
;; keeping up with the screen coordinates.
.scope Player
    ;; The minimum value that the player is allowed to have on the Y axis.
    MIN_SCREEN_Y = 8

    ;; The maximum value of X that is allowed before we start updating the
    ;; scroll value.
    MAX_SCREEN_X = 144

    ;; The height for the player when it comes to detecting the edge of the
    ;; screen or background collisions.
    PLAYER_HEIGHT = 25

    ;; The width for the player when it comes to detecting the edge of the
    ;; screen or background collisions.
    PLAYER_WIDTH = 16

    ;; Indeces for the collisions table as defined on `check_bg_collision_x` so
    ;; the setting of the `x` register is less magical.
    TOP_COLLISION_INDEX   = (0 << 2)
    RIGHT_COLLISION_INDEX = (1 << 2)
    DOWN_COLLISION_INDEX  = (2 << 2)
    LEFT_COLLISION_INDEX  = (3 << 2)

    ;; Coordinates on the X axis.
    ;; NOTE: shadowed in collision.s. If you change it here, change it there as
    ;; well.
    zp_screen_x = $30

    ;; Coordinates on the Y axis.
    ;; NOTE: shadowed in collision.s. If you change it here, change it there as
    ;; well.
    zp_screen_y = $31

    ;; Initialize the sprite for the player.
    .proc init
        RESET_PLAYER_POSITION

        lda #$01
        sta $205
        lda #$02
        sta $209
        lda #$11
        sta $20D
        lda #$12
        sta $211

        lda #0
        sta $206
        sta $20A
        sta $20E
        sta $212

        rts
    .endproc

    ;; The update for the player is simply about checking for the d-pad. Note
    ;; that if pressing right, then the scroll value might also move, which
    ;; might mean to load the next background column until the end of the
    ;; screen.
    .proc update
        ;; Is the player requesting to go up?
        lda #Joypad::BUTTON_UP
        and Joypad::m_buttons1
        beq @check_down

        ;; If we are already at the top disregard this button press and check
        ;; for the left button.
        lda #MIN_SCREEN_Y
        cmp zp_screen_y
        beq @check_left

        ;; If, for whatever reason, we are below the minimum value, then reset
        ;; the value to this minimum Y value and jump to check the left button.
        bcc @update_y_up
        sta zp_screen_y
        jmp @check_left

    @update_y_up:
        ;; Try to go up and check for a collision with the background.
        dec zp_screen_y
        dec zp_screen_y
        ldx #TOP_COLLISION_INDEX
        jsr check_bg_collision_x
        beq @check_left

        ;; A collision was detected. Then get back to the old value of Y and
        ;; move on.
        inc zp_screen_y
        inc zp_screen_y
        jmp @check_left

    @check_down:
        ;; Is the player requesting to go down?
        lda #Joypad::BUTTON_DOWN
        and Joypad::m_buttons1
        beq @check_left

        ;; We have to move down unless we are already at the very bottom.
        lda zp_screen_y
        cmp #(240 - PLAYER_HEIGHT)
        bcc @update_y_down
        lda #(240 - PLAYER_HEIGHT)
        sta zp_screen_y
        jmp @check_left
    @update_y_down:
        ;; Try to go down as requested, but check for a collision with the
        ;; background.
        inc zp_screen_y
        inc zp_screen_y
        ldx #DOWN_COLLISION_INDEX
        jsr check_bg_collision_x
        beq @check_left

        ;; There was a collision with the background, restore back the value on
        ;; Y and move on.
        dec zp_screen_y
        dec zp_screen_y

    @check_left:
        ;; Is the player requesting to go left?
        lda #Joypad::BUTTON_LEFT
        and Joypad::m_buttons1
        beq @check_right

        ;; We have to move left unless we are already at the leftmost edge.
        lda zp_screen_x
        bne :+
        rts
    :
        ;; We are not at the leftmost edge, try to go left while also checking
        ;; for a background collision.
        dec zp_screen_x
        dec zp_screen_x
        ldx #LEFT_COLLISION_INDEX
        jsr check_bg_collision_x
        bne :+
        rts
    :
        ;; There was a collision, restore back the value on X and quit.
        inc zp_screen_x
        inc zp_screen_x
        rts

    @check_right:
        ;; Last check! Is the player requesting to go right?
        lda #Joypad::BUTTON_RIGHT
        and Joypad::m_buttons1
        bne @check_level_end
        rts

    @check_level_end:
        ;; Are we at the last screen? If so consume the rest of the missing
        ;; scroll. Whenever that is done (i.e. there are no more screens and the
        ;; scroll sits at a zero value), then we can no longer load more columns
        ;; or update the scroll: stick to updating the X position.
        lda #%00001000
        and Globals::zp_flags
        beq @check_max_screen
        lda Background::zp_scroll
        beq @update_x

    @check_max_screen:
        ;; Is the X position already at the MAX_SCREEN_X? If so, then we don't
        ;; move the character: we move the scroll instead.
        lda zp_screen_x
        cmp #Player::MAX_SCREEN_X
        bcc @update_x

        ;; Moving will then be a matter of increasing the scroll value.
        inc Background::zp_scroll
        inc Background::zp_scroll
        ldx #RIGHT_COLLISION_INDEX
        jsr check_bg_collision_x
        bne @collision_on_scroll

        ;; If there are no collisions in the scrolling scenario, then we might
        ;; need to load the next background column in advance. Whether that is
        ;; possible or something that we want to do is handled automatically by
        ;; the `Background::load_next_background` function. Hence, call this
        ;; function and quit.
        JAL Background::load_next_background

    @collision_on_scroll:
        ;; Collision was given. Hence, restore the value for the scroll and
        ;; quit.
        dec Background::zp_scroll
        dec Background::zp_scroll
        rts

    @update_x:
        ;; Do not overwrap the screen.
        lda zp_screen_x
        cmp #(256 - PLAYER_WIDTH)
        beq @end

        ;; We are not about to overwrap the screen, let's update the value on
        ;; the X axis and check whether a collision would happen.
        inc zp_screen_x
        inc zp_screen_x
        ldx #RIGHT_COLLISION_INDEX
        jsr check_bg_collision_x
        beq @end

        ;; There was a collision, roll back the value for the X axis.
        dec zp_screen_x
        dec zp_screen_x

    @end:
        rts
    .endproc

    ;; Check collision between the player and any background element. Note that
    ;; collision is not tested on all edges for the player, but you have to
    ;; provide a "collision index", which refers to which edges to test. See the
    ;; "*_COLLISION_INDEX" constants above and the `edges` data included inside
    ;; of this function. This collision index has to be provided on the `x`
    ;; register.
    ;;
    ;; Returns a non-zero value on the `a` register if a collision was detected,
    ;; zero otherwise.
    .proc check_bg_collision_x
        ;; We have to check for a collision on both the left and the right
        ;; edges, which should follow the same code. Unrolling it is simply
        ;; faster and more clear than setting up a loop.
        .repeat 2, I
            ;; Save the offset on the Y coordinate.
            lda edges, x
            sta Globals::zp_arg0

            ;; Save the offset on the X coordinate.
            inx
            lda edges, x
            sta Globals::zp_arg1

            ;; Save the edge index in preparation for the following calls.
            .if I = 0
                inx
                stx Globals::zp_idx
            .endif

            ;; Transform screen coordinates into metatile ones and fetch the
            ;; collision bitmap for it with its mask.
            jsr Collision::screen_to_mt_coordinates
            jsr Collision::get_background_collision_y

            ;; Restore back the edge index.
            .if I = 0
                ldx Globals::zp_idx
            .endif

            ;; Checking for a collision is as simple as performing an AND with the
            ;; bitmap at the `a` register and the byte that can be addressed with
            ;; the given pointer. If the result is non-zero, then we found a match.
            and (Globals::zp_arg0), y
            .if I = 0
                ;; If I = 1 we are falling through as expected anyways, so this
                ;; instruction is not needed.
                bne @collision
            .endif
        .endrepeat

        ;; The last instruction before ending up here will already have the `a`
        ;; register lined up to the proper return value. If a collision was
        ;; found (in either left/right case), `bne @collision` is good, and
        ;; hence `a` has an expected non-zero value. The same is true when not
        ;; in a collision.
    @collision:
        rts

    edges:
        ;; Up: top-left (y, x), top-right (y, x)
        .byte $02, $02, $02, $0F

        ;; Right: top-right (y, x), bottom-right (y, x)
        .byte $02, $0F, $0F, $0F

        ;; Down: bottom-left (y, x), bottom-right (y, x)
        .byte $0F, $02, $0F, $0F

        ;; Left: top-left (y, x), bottom-left (y, x)
        .byte $02, $01, $0F, $01
    .endproc

    ;; Update the memory on the PPU with the current values for the screen
    ;; coordinates of the player.
    ;;
    ;; NOTE: only call this function on NMI Code.
    .proc update_sprite
        lda zp_screen_x
        sta $207
        sta $20F
        clc
        adc #8
        sta $20B
        sta $213

        lda zp_screen_y
        sta $204
        sta $208
        clc
        adc #8
        sta $20C
        sta $210

        rts
    .endproc
.endscope
