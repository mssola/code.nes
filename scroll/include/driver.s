;; The runtime of the game.
.scope Driver
    ;; Index of the current level.
    zp_level = $77

    ;; Whenever "Select" is pressed, it's used to count how many cycles have to
    ;; pass before allowing another level switch.
    zp_counter = $97

    ;; Value that will be set for the `zp_counter` whenever the "Select" button
    ;; is pressed for the first time.
    SELECT_COUNTER_VALUE = $20

    ;; Initialize global variables and other variables which have an impact on
    ;; the runtime of the game.
    .proc init
        lda #0
        sta Globals::zp_arg0
        sta Globals::zp_arg1
        sta Globals::zp_arg2
        sta Globals::zp_arg3
        sta Globals::zp_arg4
        sta Globals::zp_tmp0
        sta Globals::zp_tmp1
        sta Globals::zp_tmp2
        sta Globals::zp_tmp3
        sta Globals::zp_idx
        sta Globals::zp_flags
        sta zp_level
        sta zp_counter

        rts
    .endproc

    ;; Function to be called at each iteration of the game loop. It loads any
    ;; pending background columns and checks for level selection.
    .proc update
        ;; Are we actually loading a new level?
        lda #%00100000
        and Globals::zp_flags
        beq @new_level

        ;; Is the user actually allowed to hit the 'Select' button?
        lda zp_counter
        beq @check_select
        dec zp_counter
        jmp @check_column

    @check_select:
        ;; If `select` is pressed, then go for a new level. Otherwise check
        ;; whether there is a pending column to be loaded.
        lda #Joypad::BUTTON_SELECT
        and Joypad::zp_buttons1
        beq @check_column

        ;; Set the counter.
        lda #SELECT_COUNTER_VALUE
        sta zp_counter

        ;; 'Select' was pressed and we weren't loading another level. Hence,
        ;; increase the level index and load it.
        inc zp_level
    @new_level:
        ;; Check the level index.
        ldx zp_level
        cpx #$02
        bne :+
        ldx #$00
    :
        ;; And load the computed level.
        stx zp_level
        jsr Background::load_level_x
        beq :+

        ;; Level could be rendered, enable back the PPU.
        lda PPU::zp_mask
        sta PPU::MASK

        ;; Set the player back to its position.
        RESET_PLAYER_POSITION
    :
        rts

    @check_column:
        ;; Do nothing if the `column` flag is not set.
        lda #%00010000
        and Globals::zp_flags
        beq @end

        ;; Continue loading the pending column.
        jsr Background::load_column
        beq @end
        JAL Background::prepare_next_column

    @end:
        rts
    .endproc
.endscope
