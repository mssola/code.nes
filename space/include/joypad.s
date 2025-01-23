.segment "CODE"

;;;
;; Joypad controller code. The following memory addresses are reserved: $21-$23.
;;
;; Memory address $21 is used for internal purposes, whereas $22 and $23 contain
;; the bitmask of the buttons that are pressed from each controller.
;;;

;; READ_CONTROLLER reads the input from the controller mapped into the given
;; port, and saves the state into the given `buttons` address.
;; Implementation taken from NESHacker's example of smb3-like movement.
.macro READ_CONTROLLER port, buttons
    lda Joypad::m_inv_buttons
    tay
    lda #1
    sta port
    sta Joypad::m_inv_buttons
    lsr
    sta port
:
    lda port
    lsr
    rol Joypad::m_inv_buttons
    bcc :-
    tya
    eor Joypad::m_inv_buttons
    and Joypad::m_inv_buttons
    sta buttons
.endmacro

.scope Joypad
    ;; Button masks.
    BUTTON_A      = 1 << 7
    BUTTON_B      = 1 << 6
    BUTTON_SELECT = 1 << 5
    BUTTON_START  = 1 << 4
    BUTTON_UP     = 1 << 3
    BUTTON_DOWN   = 1 << 2
    BUTTON_LEFT   = 1 << 1
    BUTTON_RIGHT  = 1 << 0

    ;; Port addresses for controllers.
    JOYPAD1 = $4016
    JOYPAD2 = $4017

    ;; We keep all the information from controller from mainly two variables:
    ;; m_buttons1 and m_buttons2; containing respectively the buttons pressed
    ;; for this frame for both controllers. The m_inv_buttons ($21) is an
    ;; internal variable and should not be used for anything outside of this
    ;; usage.
    m_inv_buttons = $21
    m_buttons1    = $22
    m_buttons2    = $23

    ;; read sets the values for m_buttons1 and m_buttons2 as read from both
    ;; controllers.
    .proc read
        READ_CONTROLLER JOYPAD1, m_buttons1
        READ_CONTROLLER JOYPAD2, m_buttons2
        rts
    .endproc
.endscope
