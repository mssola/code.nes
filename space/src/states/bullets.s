;;;
;; Implements the pool of bullets available when pressing B. The main code
;; should just want to call `init` for initializing the memory space, and then
;; `update` on each main game loop iteration. The following addresses are
;; reserved:
;;      -> $40-$41: internal data.
;;      -> $0208-$0213: OAM data (this is a pool of three sprites).
;;
;; NOTE: the code in here touch the addresses on OAM directly, instead of
;; keeping them in some internal addresses on zero page. This is usually not a
;; good idea, and more so if we were to do collision checking and stuff like
;; that. That being said, because of its simplicity, it's not that big of a
;; deal.
.scope Bullets
    ;; The number of bullets shown on screen for the current frame.
    zp_bullets_screen = $40

    ;; Frame counter. See `FRAMES` below.
    zp_frames = $41

    ;; How many frames have to pass to allow the user to shoot another bullet
    ;; after the previous one.
    FRAMES = 15

    ;; Initializes the pool of bullets.
    .proc init
        ;; Initializing variables.

        lda #0
        sta zp_bullets_screen

        lda #FRAMES
        sta zp_frames

        ;; Set X and Y positions off-screen for the three available slots.

        lda #$FF
        sta $208
        sta $20C
        sta $210
        sta $20B
        sta $20F
        sta $213

        ;; All three sprites are instances of the same tile.

        lda #4
        sta $209
        sta $20D
        sta $210

        ;; Nothing special for these sprites, set attributes to 0.

        lda #0
        sta $20A
        sta $20E
        sta $212

        rts
    .endproc

    ;; Update bullets on screen, check if a new one has to be shown, etc.
    .proc update
        ;; If the frame counter has the same value as our allowed one, we can go
        ;; into the `bullets_pressed` subroutine, otherwise we will skip it
        ;; altogether.
        lda zp_frames
        cmp #FRAMES
        beq @check
        inc zp_frames
        jmp @position
    @check:
        jsr bullets_pressed
    @position:
        jsr update_positions

        rts
    .endproc

    ;; Shows a new bullet right in front of the ship if the player requested it
    ;; and it is possible.
    .proc bullets_pressed
        ;; If we reached the maximum of bullets on screen, return early.
        lda zp_bullets_screen
        cmp #3
        bne :+
        rts
    :
        ;; If the B button is not pressed, return early.
        lda #Joypad::BUTTON_B
        and Joypad::m_buttons1
        bne :+
        rts
    :
        ;; The following code will loop through the three bullet sprites and
        ;; find one that is free (off-screen). If one could be found, it will
        ;; assign it to the ship's position.
        ldx #0
    @loop:
        ;; Is the Y position on this sprite $FF? If so then it's free and we can
        ;; jump into @set so we re-initialize the position for this bullet.
        lda $208, x
        cmp #$FF
        beq @set

        ;; Oops, that was not the case. At this point, is this the last bullet?
        ;; If so, we can go to the @end, otherwise we increase the index and try
        ;; again.
        cpx #8
        beq @end
        inx
        inx
        inx
        inx
        jmp @loop
    @set:
        ;; At the current index we have a bullet to initialize. Hence, give it
        ;; the Y value from the player and the X one (+4 so it's at the center
        ;; of the ship on the X axis).
        lda Player::zp_screen_y
        sta $208, x
        lda Player::zp_screen_x
        clc
        adc #4
        inx
        inx
        inx
        sta $208, x

        ;; Reset the `zp_frames` so to disallow too many bullets being shot at
        ;; once, and increate the `zp_bullets_screen` variable.
        lda #0
        sta zp_frames
        inc zp_bullets_screen
    @end:
        rts
    .endproc

    ;; Updates the positions from the bullets being shown on screen. If one
    ;; bullet goes off screen, then it's properly freed so it can be picked up
    ;; by another B press.
    .proc update_positions
        ldx #0
    @loop:
        ;; Do nothing if the bullet is free.
        lda $208, x
        cmp #$FF
        beq @next

        ;; The indexed bullet is shown on screen, and we should make it move
        ;; upward by 10 units. That being said, if its Y position is lesser or
        ;; equal than 10, we can directly free it now. Otherwise, just update
        ;; the Y value by performing this subtraction.
        cmp #10
        bcc @free
        beq @free
        sec
        sbc #10
        jmp @save
    @free:
        ;; This bullet should be freed, decrease `zp_bullets_screen` and set `a`
        ;; to an off-screen value.
        dec zp_bullets_screen
        lda #$FF
    @save:
        ;; Either way you reach this, in `a` we have the Y value to be stored.
        sta $208, x
    @next:
        ;; If we are already at the last bullet, jump to the @end. Otherwise
        ;; increase the index and loop again.
        cpx #8
        beq @end
        inx
        inx
        inx
        inx
        jmp @loop
    @end:
        rts
    .endproc
.endscope
