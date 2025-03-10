;;;
;; Collisions for the background are handled by building up an array starting at
;; RAM address $0700. This array contains a list of values to be considered when
;; checking up background collision, and it's expected to be built when loading
;; a screen or parts of it (e.g. `load_column`).
;;
;; In summary, each row of metatiles is mapped by two bytes. There are 16 tiles
;; in a row (see `metatile.s`), so each bit from these two bytes map whether
;; that metatile has a collision block or not. More specifically, the first bit
;; from the first byte maps the first metatile on that row, the second bit from
;; the first byte the second metatile on that row, and so on. Considering that
;; there are 15 rows of tiles * 2 bytes for each row, it means that we can get a
;; whole screen mapped with 30 bytes. As explained on the `metatile.s` file and
;; taking the example of Super Mario Bros., things could have been further
;; compressed by disregarding some of the rows which are anyways unaccessible by
;; the player (e.g. by the HUD), but I have tried to keep things generic.
;;
;; Last but not least, we reserve space for two screens: one per nametable.
;; Thus, the memory usage looks like this:
;;
;;   - $0700-$071D: collision map for the screen on nametable 0.
;;   - $071E-$073B: collision map for the screen on nametable 1.
.scope Collision
    ;; The high byte value for the collision map (which lives at $0700 in RAM).
    COLLISION_MAP_HI = $07

    ;; Starting index for the collision map of the second screen.
    COLLISION_MAP_SECOND = $1E

    ;; Shadow references to Player::zp_screen_{x,y} and Background::zp_scroll.
    ;; Not awesome, but cc65 doesn't allow to re-open scopes or similar
    ;; code-sharing scenarios.
    zp_player_screen_x   = $30
    zp_player_screen_y   = $31
    zp_background_scroll = $95

    ;; Set/unset the proper bit on the collision map for the given metatile
    ;; position and collision bit.
    ;;
    ;; The `a` register has to contain the collision information as given on a
    ;; metatile reference for a screen. Hence, something like `$81` informs that
    ;; metatile with id 1 is a solid block, while `$01` would mean the same but
    ;; unsetting collision for that block.
    ;;
    ;; In memory you have to pass `Globals::zp_arg0` and `Globals::zp_arg1`,
    ;; which contain the Y and X metatile coordinates as passed around in
    ;; `Buffer::push_metatile`. This function won't touch other parameters, so
    ;; future code can rely on `Globals::zp_arg2` and the rest to be preserved
    ;; (i.e. only `Globals::zp_arg0` and `Globals::zp_arg1` will be affected).
    .proc set_background_collision
        ;; Preserve the collision byte for later.
        sta Globals::zp_tmp0

        ;; Select the screen to be used and save it into the `y` register, as
        ;; expected by the `get_background_collision_y` function.
        lda Globals::zp_flags
        and #%00000100
        lsr
        lsr
        tay

        ;; Get the bitmap address for the Y and X coordinates.
        jsr get_background_collision_y
        tax

        ;; Should we set or unset the collision bit?
        lda Globals::zp_tmp0
        bmi @set_collision

        ;; We have to unset it: flip the mask, unset the given bit and save the
        ;; result.
        txa
        eor #$FF
        and (Globals::zp_arg0), y
        sta (Globals::zp_arg0), y
        rts

    @set_collision:
        ;; We have to set it: apply the given mask and save the result.
        txa
        ora (Globals::zp_arg0), y
        sta (Globals::zp_arg0), y
        rts
    .endproc

    ;; Get the collision value for the Y and X positions of a metatile. These
    ;; two coordinates are given in memory arguments in this exact order, while
    ;; the `y` register selects which map to pick from (i.e. the screen).
    ;;
    ;; Returns two bytes in memory which correspond to the 16-bit pointer to the
    ;; row section that contains this metatile (remember that a row of metatiles
    ;; in screen is split in two). This pointer is complemented by the fact that
    ;; the `y` register will be set to the proper value. Hence, after calling
    ;; this function you can get the collision bitmap for the row section with:
    ;;
    ;;    lda (Globals::zp_arg0), y
    ;;
    ;; The `a` register will contain the mask which pin points the exact
    ;; location on the X coordinate. This is useful for collision detection.
    ;; Hence, combining with the above you can do:
    ;;
    ;;    jsr get_background_collision_y
    ;;    and (Globals::zp_arg0), y    ; Use the mask on `a` against the bitmap.
    ;;    bne @collision               ; Collision!
    ;;
    .proc get_background_collision_y
        ;; Each row is made up of two bytes worth of bitmaps. Hence, the Y
        ;; metatile position has to be multiplied by two to get to the proper
        ;; row.
        lda Globals::zp_arg0
        asl

        ;; Depending on the nametable being mapped, we have to pick one map or
        ;; the other. Since they are contiguous, this is a matter of simply
        ;; adding the base address for the second map if that's the case.
        cpy #1
        bne @store_base_pointer
        clc
        adc #COLLISION_MAP_SECOND
    @store_base_pointer:
        sta Globals::zp_arg0

        ;; Now it's time to figure things out given the value for the X
        ;; coordinate. First of all, set on the `y` register which bitmap to
        ;; pick for the row of metatiles (remember that a row is split in two
        ;; bitmaps). Moreover, update the coordinate if it's on the second
        ;; bitmap.
        lda Globals::zp_arg1
        ldy #0
        cmp #8
        bcc @eval_x
        sec
        sbc #8
        iny

        ;; With that, now we have to shift as many times as the X coordinate to
        ;; get the mask for the bitmap we are pointing at.
    @eval_x:
        tax
        lda #1
        cpx #0
        beq @end
    @loop:
        asl
        dex
        bne @loop

    @end:
        ;; The only thing missing is to set the high byte of the end 16-bit
        ;; pointer.
        ldx #COLLISION_MAP_HI
        stx Globals::zp_arg1

        ;; NOTE: Returned value is left untouched into the `a` register,
        ;; computed in the previous loop.

        rts
    .endproc

    ;; Translates the player's screen coordinates into metatile ones.
    ;;
    ;; This function takes two memory arguments, which are offsets to the Y and
    ;; X screen coordinates respectively. The screen coordinates are taken
    ;; directly from `Player::zp_screen_{y,x}`, and it also handles
    ;; `Background::zp_scroll`.
    ;;
    ;; In turn this function will store in `zp_arg0` the Y metatile coordinate,
    ;; and in `zp_arg1` the X one. The `y` register will also point if we are in
    ;; nametable 0 or 1.
    .proc screen_to_mt_coordinates
        ;; Add up the player's screen coordinates with the given Y offset.
        ;; Transforming that result into a metatile index is basically a matter
        ;; of shifting right 4 times, since metatiles are 16x16 pixels.
        lda Globals::zp_arg0
        clc
        adc Collision::zp_player_screen_y
        lsr
        lsr
        lsr
        lsr
        sta Globals::zp_arg0

        ;; The `y` register is generally the nametable where the focus is on.
        ;; This is handled on the PPU control register, and shadowed by a
        ;; `PPU::zp_control` variable. This will have to be adjusted depending
        ;; on the current scroll. See more below.
        lda #%00000001
        and PPU::zp_control
        tay

        ;; Before figuring out the X metatile coordinates, compute the metatile
        ;; coordinates if we were only to consider the scroll. This gives us
        ;; information on from which metatile column is the current nametable
        ;; visible. It will be used to correct the `y` register whenever columns
        ;; from the next nametable start appearing on the player's area.
        lda Collision::zp_background_scroll
        lsr
        lsr
        lsr
        lsr
        sta Globals::zp_tmp0

        ;; The coordinates for the X axis is similar to the Y one but we also
        ;; need to take into account scrolling. Note that overflow is permitted
        ;; as this will be handled by the correction code below (i.e. if the X
        ;; metatile is beyond what can be seen by the current nametable, focus
        ;; on the next one).
        lda Globals::zp_arg1
        clc
        adc Collision::zp_player_screen_x
        clc
        adc Collision::zp_background_scroll
        lsr
        lsr
        lsr
        lsr
        sta Globals::zp_arg1

        ;; Is the X metatile coordinate actually smaller than the scrolling
        ;; view?
        cmp Globals::zp_tmp0
        bcs @end

        ;; Yes! Then we are on the next nametable. Amend the value on the `y`
        ;; register and make sure it's either 1 or 0.
        iny
        tya
        and #%00000001
        tay

    @end:
        rts
    .endproc
.endscope
