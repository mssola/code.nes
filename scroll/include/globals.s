;; Resets the background buffer to a zero-sized array.
.macro CLEAR_BACKGROUND_BUFFER
    lda #$FF
    sta Globals::m_background_buffer
.endmacro

;; TODO: macro PUSH_TO_BACKGROUND_BUFFER_X

;; Global variables used throughout the scrolling examples.
.scope Globals
    ;;;
    ;; Temporary values.

    m_tmp_1  = $90
    m_tmp_2  = $91
    m_tmp_3  = $92

    ;; Current value for the scroll on the X axis.
    m_scroll = $93

    m_background_idx = $19

    ;; TODO
    m_collisions = $20

    ;; TODO
    m_background_buffer = $40

    ;; Initialize global variables.
    .proc init
        lda #0
        sta m_tmp_1
        sta m_tmp_2
        sta m_tmp_3
        sta m_scroll
        sta m_background_idx

        CLEAR_BACKGROUND_BUFFER
        sta m_collisions

        rts
    .endproc
.endscope
