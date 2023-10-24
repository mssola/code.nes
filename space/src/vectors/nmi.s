;; Non-Maskable Interrupts handler.
nmi:
    ;; As mentioned on the `main` subroutine, rendering will be skipped until
    ;; the proper flag is set.
    bit $20
    bpl @next

    ;; We can start rendering stuff.
    OAM_WRITE_SPRITES

    ;; And unset the render flag so the `main` code is unblocked.
    UNSET_RENDER_FLAG
@next:
    rti
