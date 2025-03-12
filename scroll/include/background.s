;; Reset the background cycle so a new column can be loaded even if the cycle
;; was stopped at the end of the loading of the previous screen.
.macro RESET_BACKGROUND_CYCLE
    lda #$FF
    sta Background::zp_background_cycle
.endmacro

;; All functions and related variables for keeping up with the background
;; elements. This is by far the most extensive and complex piece of code from
;; the scrolling examples, and it's the core of the render engine for them.
;;
;; Documentation has been added for it as much as possible, so follow along to
;; better grasp how to use and grok this piece of code.
.scope Background
    ;; Current value for the scroll on the X axis.
    zp_scroll = $95

    ;; Instead of attempting to load a column every time the player movement
    ;; requires it, stall things a bit (as much as defined in
    ;; `BACKGROUND_CYCLE_MAX`). This allows for loading columns at a slower
    ;; pace. This cycle is diregarded if you set it to
    ;; `DISABLED_BACGROUND_CYCLE`, which it just means something like "no more
    ;; columns to load".
    zp_background_cycle = $96

    ;; See `zp_background_cycle`.
    DISABLED_BACKGROUND_CYCLE = $FE
    BACKGROUND_CYCLE_MAX = $02

    ;; The offset for metatile rows. That is, from where should the engine start
    ;; counting rows of metatiles. By default it's 0, but it could be set to
    ;; something else to reserve so top space for a HUD or something similar.
    ;;
    ;; NOTE: configurable.
    .ifndef BACKGROUND_ROW_OFFSET
        BACKGROUND_ROW_OFFSET = 0
    .endif

    ;; The maximum row coordinate this engine is allowed to go. That is, until
    ;; which row each column is supposed to be rendered. By default it's $0F,
    ;; but it could be set to something else to allow a status element down the
    ;; screen.
    ;;
    ;; NOTE: configurable.
    .ifndef BACKGROUND_ROW_MAX
        BACKGROUND_ROW_MAX = $0F
    .endif

    ;; Current column (or the next to be loaded by functions like
    ;; `load_column`).
    zp_cur_column = $75

    ;; Current row (or the next to be loaded by functions like `load_column`).
    zp_cur_row = $76

    .proc init
        ;; Load the first level.
        ldx #$00
        JAL load_level_x
        ;; NOTE: returned value ignored as the level *must* have loaded at this
        ;; point.
    .endproc

    ;; Resets all the variables which touch in any way the loading of columns,
    ;; levels, etc. This is already being called by `load_level_x`, so outside
    ;; of this usage you shouldn't be calling it.
    .proc reset
        RESET_BACKGROUND_CYCLE

        lda #$00
        sta zp_scroll
        sta Buffer::zp_vram_idx
        sta zp_cur_column

        lda #BACKGROUND_ROW_OFFSET
        sta zp_cur_row

        rts
    .endproc

    ;; Load the level indexed by the `x` register. This function requires that
    ;; the PPU is disabled. If this is not the case, then it sets PPU::zp_mask
    ;; in a way so to disable the PPU on the next `nmi` call, and finally sets
    ;; `a` to 0 (i.e. level could not be loaded). Otherwise you can expect the
    ;; `a` register to contain 1 after calling this function.
    ;;
    ;; Moreover, the screen pointer is going to be left at the start of the
    ;; second screen, so future `load_column` calls can rely on this pointer
    ;; being set properly.
    .proc load_level_x
        ;; Is the PPU set to be disabled?
        lda PPU::zp_mask
        and #%00111100
        beq @load_level

        ;; The PPU is not disabled, set the mask so the PPU is disabled.
        lda #$00
        sta PPU::zp_mask

        ;; Reset the nametable being used.
        lda #%11111100
        and PPU::zp_control
        sta PPU::zp_control

        ;; Enable the `ppu` flag so these changes are not ignored.
        lda Globals::zp_flags
        ora #%01000000
        and #%11011111
        sta Globals::zp_flags
        lda #0
        rts

    @load_level:
        ;; Start by resetting any variables that touch on the loading of columns
        ;; in any way.
        jsr Background::reset

        ;; Reset all relevant flags.
        lda #%11000011
        and Globals::zp_flags
        sta Globals::zp_flags

        ;; Initialize the screen pointer by using the argument as passed through
        ;; the `x` register.
        lda levels_lo, x
        sta Metatile::zp_screen_ptr
        lda levels_hi, x
        sta Metatile::zp_screen_ptr + 1

    @loop:
        jsr load_column
        ;; NOTE: returned value ignored.

        ;; Increase the column being used and loop if we are not at the end of
        ;; the screen yet.
        lda #BACKGROUND_ROW_OFFSET
        sta zp_cur_row
        inc zp_cur_column
        lda zp_cur_column
        cmp #$10
        bne @loop

        ;; Advance the screen pointer so it points to the second screen.
        ADVANCE_SCREEN_PTR(1)

        ;; Enable back the PPU on the next NMI call.
        lda #%00011110
        sta PPU::zp_mask

        ;; And set the `ppu`, `level` and `nametable` flags.
        lda #%01100100
        ora Globals::zp_flags
        sta Globals::zp_flags

        ;; Reset things again just in case.
        jsr Background::reset

        lda #1
        rts
    .endproc

    ;; Translates the given metatile coordinate byte as given on the `a`
    ;; register and sets the first four argument variables from it. A "metatile
    ;; coordinate byte" is the first byte of a metatile reference on the screen
    ;; definition. Hence, the high nibble contains the Y metatile coordinate,
    ;; and the low nibble contains the X metatile coordinate.
    ;;
    ;; After calling this function you will have the following:
    ;;
    ;;  - zp_arg0: Y metatile coordinate (i.e. the high nibble as given on the
    ;;    `a` register shifted 4 times right).
    ;;  - zp_arg1: X metatile coordinate (i.e. the low nibble as given on the
    ;;    `a` register and the high nibble zero'ed out).
    ;;  - zp_arg2: low byte for the corresponding PPU base address.
    ;;  - zp_arg3: high byte for the corresponding PPU base address.
    .proc translate_mt_coordinates_to_arguments
        ;; Save the X metatile coordinate. This is also saved into a temporary
        ;; variable so it can be messed up when figuring out the PPU address.
        tay
        and #%00001111
        sta Globals::zp_arg1
        sta Globals::zp_tmp0

        ;; Save the Y metatile coordinate.
        tya
        and #%11110000
        lsr
        lsr
        lsr
        lsr
        sta Globals::zp_arg0

        ;; Now that the metatile coordinates have been isolated, let's go for
        ;; the PPU address.

        ;; The initial value for the high byte of the PPU address depends on the
        ;; nametable being used. For this we can take advantage of the fact that
        ;; this information is on bit 2 of the global flags. If we mask this
        ;; out, and add to it the base value of `$20`, we get either `$20` or
        ;; `$24`, which is the base high byte for either nametable.
        lda #%00000100
        and Globals::zp_flags
        clc
        adc #$20
        sta Globals::zp_arg3

        ;; Every 4 rows the high byte of the PPU address increases by one. This
        ;; means that with the Y metatile position, divide it by 4 (shift right
        ;; twice), and you can add that to the high byte directly.
        lda Globals::zp_arg0
        lsr
        lsr
        clc
        adc Globals::zp_arg3
        sta Globals::zp_arg3

        ;; After the high byte has been sorted out, notice that for the low byte
        ;; the base can only be the four values as defined in `ppu_offsets`,
        ;; as they repeat every four times.
        lda Globals::zp_arg0
        and #%00000011
        tax
        lda ppu_offsets, x

        ;; To that base we need to apply the X coordinate. Since each metatile
        ;; takes two tiles on the PPU, we can simply take the value on the X and
        ;; shift it left once. And finally add the base low byte from the row
        ;; with this shifted X value.
        asl Globals::zp_tmp0
        clc
        adc Globals::zp_tmp0
        sta Globals::zp_arg2

        rts
    ppu_offsets:
        .byte $00, $40, $80, $C0
    .endproc

    ;; Load the column as indexed by `Background::zp_cur_column` and
    ;; `Background:zp_cur_row`. This means that this function can be called at
    ;; any time, and so rendering columns in multiple iterations is indeed
    ;; possible. This is important to keep a small VRAM buffer.
    ;;
    ;; Returns 1 if the column has been completely loaded, 0 if there are rows
    ;; still to be loaded for the current column after calling this function.
    ;;
    ;; This function also sets the `ppu` and the `column` flags as expected in
    ;; each scenario, but it will *not* call functions such as
    ;; `prepare_next_column`, as that is to be done by the caller if necessary.
    .proc load_column
    @start:
        ;; First, compute the offset of the current metatile definition. That
        ;; is, what's left from the current row until the Y position of the next
        ;; metatile to push. First things first, check whether we are at the end
        ;; of the screen definition.
        ldy #0
        lda (Metatile::zp_screen_ptr), y
        cmp #$FF
        bne @fetch_offset

        ;; We are actually at the end of the screen definition. Then the offset
        ;; is simply the current row until the end. If that turns out to be
        ;; zero, then we are done.
        lda #BACKGROUND_ROW_MAX
        sec
        sbc zp_cur_row
        beq @done
        sta Globals::zp_idx
        jmp @default_loop

    @fetch_offset:
        ;; Otherwise, if we weren't at the end of the screen definition, fetch
        ;; the offset now. Note that if the offset is zero, then we can simply
        ;; go and push the metatile definition.
        jsr find_offset
        beq @push

        ;; This is an inner loop, which pushes the default metatile
        ;; `Globals::zp_idx` - 1 times.
        sta Globals::zp_idx
    @default_loop:
        ;; Make up a fake metatile position at the currently evaluated pair of
        ;; row/column. Afterwards just push it. Doing all this dance is
        ;; certainly not too expensive, but at the same time it could be easily
        ;; optimized. This is not done out of simplicity.
        lda zp_cur_row
        asl
        asl
        asl
        asl
        ora zp_cur_column
        jsr translate_mt_coordinates_to_arguments
        lda #$00
        jsr Buffer::push_metatile
        beq @end

        ;; The metatile was successfully pushed, now increase the row and check
        ;; if we have to push another default metatile.
        inc zp_cur_row
        dec Globals::zp_idx
        bne @default_loop

        ;; We are done pushing default metatiles. Check if we are done with the
        ;; column entirely.
        lda zp_cur_row
        cmp #BACKGROUND_ROW_MAX
        beq @done

        ;; Push the metatile pointed by the screen pointer.
    @push:
        ;; Pick up the current metatile position byte and set the arguments as
        ;; expected by `Buffer::push_metatile`,
        ;; `Collision::set_background_collision` and related functions.
        ldy #0
        lda (Metatile::zp_screen_ptr), y
        jsr translate_mt_coordinates_to_arguments

        ;; And now call `push_metatile` with the proper metatile definition.
        ldy #1
        lda (Metatile::zp_screen_ptr), y
        jsr Buffer::push_metatile
        beq @end

        ;; The two bytes for the metatile have been consumed, now advance the
        ;; screen pointer two bytes to point to the next metatile for the
        ;; screen.
        ADVANCE_SCREEN_PTR(2)

        ;; Increase the row being evaluated and go for another iteration if this
        ;; wasn't the last row for the column.
        inc zp_cur_row
        lda zp_cur_row
        cmp #$10
        bne @start

    @done:
        ;; Set the `ppu` flag and unset the `column` one. That is, a column is
        ;; now fully buffered and the PPU needs to update things.
        lda Globals::zp_flags
        ora #%01000000
        and #%11101111
        sta Globals::zp_flags

        lda #1
        rts
    @end:
        ;; Set the `ppu` and the `column` flags. Even if the column is not fully
        ;; buffered yet, we can already consume the VRAM buffer and empty it.
        ;; Setting the `column` flag will ask code elsewhere to beware of a
        ;; pending column to be loaded and act on it (e.g. by calling
        ;; `load_column` again to finish the task).
        lda Globals::zp_flags
        ora #%01010000
        sta Globals::zp_flags

        lda #0
        rts
    .endproc

    ;; Load a new column if the engine detects that it was needed. That is, it
    ;; will ask to load a column unless a column is already being rendered, or
    ;; the background cycle has not been consumed yet (or disabled entirely).
    .proc load_column_if_needed
        ;; If the `column` or the `level` flags are set, then we can skip the
        ;; loading altogether.
        lda #%00011000
        and Globals::zp_flags
        bne @end

        ;; Is the background cycle disabled? If so just go to the end.
        lda Background::zp_background_cycle
        cmp #DISABLED_BACKGROUND_CYCLE
        beq @end

        ;; Instead of loading a column every time it can be loaded, we add a bit
        ;; of a hiccup (i.e. "background cycle") so an entire level is not
        ;; loaded right away after the player moves one bit.
        inc Background::zp_background_cycle
        beq @do_load
        lda Background::zp_background_cycle
        cmp #BACKGROUND_CYCLE_MAX
        bne @end
        lda #$00
        sta Background::zp_background_cycle

    @do_load:
        ;; Load the column and increase the current column if it was fully
        ;; buffered. Otherwise it will be picked up by the `update` function.
        jsr load_column
        beq @end
        JAL prepare_next_column

    @end:
        rts
    .endproc

    ;; Load the next background column. You want to call this function on the
    ;; outside whenever a new column might be needed. This function will
    ;; eventually call `load_column_if_needed`, and it will also handle
    ;; overflows on the scroll values, changing the nametable being used, etc.
    ;;
    ;; Because of the above, this is the most suitable function to call whenever
    ;; you want to load a new column from the outside code, even if you are
    ;; unsure whether it's really needed.
    .proc load_next_background
        ;; Was there an overflow on the scroll's value?
        lda Background::zp_scroll
        bne @load_column_if_needed

        ;; Reset the background cycle so the next screen is picked up.
        RESET_BACKGROUND_CYCLE

        ;; Flip the nametable being used so the scroll makes sense for the
        ;; current context. After that, skip the loading of the column because
        ;; otherwise it would start loading on the currently displayed nametable
        ;; and that would make for weird glitches.
        lda PPU::zp_control
        eor #%00000001
        sta PPU::zp_control
        jmp @update_ppu_and_quit

    @load_column_if_needed:
        jsr Background::load_column_if_needed

    @update_ppu_and_quit:
        ;; Regardless of whether the loading of the column happened or not, the
        ;; scroll register has to change. Hence, set the `ppu` flag so at least
        ;; the PPU::SCROLL register is updated.
        lda Globals::zp_flags
        ora #%01000000
        sta Globals::zp_flags

        rts
    .endproc

    ;; Reset all the variables in preparation for the loading of a new column.
    ;; This function assumes that a column has already been fully buffered; and
    ;; it will also handle the case where it was the last column of the
    ;; screen/level by poking the right flags.
    .proc prepare_next_column
        ;; The row index always has to be set to zero.
        lda #BACKGROUND_ROW_OFFSET
        sta zp_cur_row

        ;; Is this the last column? If not, just quit.
        lda zp_cur_column
        cmp #$0F
        bne @end

        ;; Flip the nametable to be used.
        lda Globals::zp_flags
        eor #%00000100
        sta Globals::zp_flags

        ;; Mark the background cycle as over. This will make functions like
        ;; `load_column_if_needed` to refrain from loading a new column
        ;; altogether.
        lda #DISABLED_BACKGROUND_CYCLE
        sta zp_background_cycle

        ;; Reset the column to use. Note that the `@end` section will increase
        ;; the column to be used.
        lda #$FF
        sta zp_cur_column

        ;; If we were at the last column, we were out of metatiles for the
        ;; current screen. Hence, move to the next screen if possible.
        ADVANCE_SCREEN_PTR(1)

        ;; Do we have another "$FF" byte? If so then we are at the end of the
        ;; level entirely.
        ldy #0
        lda (Metatile::zp_screen_ptr), y
        cmp #$FF
        bne @end

        ;; Mark the end of the level.
        lda #%00001000
        ora Globals::zp_flags
        sta Globals::zp_flags

    @end:
        ;; Increase the current column and quit.
        inc zp_cur_column
        rts
    .endproc

    ;;;
    ;; Find the distance between the currently evaluated row and the one pointed
    ;; by the given argument. The argument is a byte where the Y value is
    ;; located on the high nibble, as expected from a metatile definition.
    ;;
    ;; NOTE: the argument and the returned value are on the `a` register.
    .proc find_offset
        ;; Are we at the right column?
        sta Globals::zp_arg0
        and #%00001111
        cmp zp_cur_column
        bne @to_the_end

        ;; We are: go until the current Y index.
        lda Globals::zp_arg0
        lsr
        lsr
        lsr
        lsr
        jmp @compute

    @to_the_end:
        ;; We aren't: go until the last row.
        lda #BACKGROUND_ROW_MAX

    @compute:
        ;; Subtract the current row with the one we are trying to reach.
        sec
        sbc zp_cur_row
        rts
    .endproc
.endscope
