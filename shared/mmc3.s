;;; Useful macros and constants for development on the MMC3 chip.

.scope MMC3
    BANK_SELECT = $8000
    BANK_DATA   = $8001
    MIRRORING   = $A000
    RAM_PROTECT = $A001
    IRQ_LATCH   = $C000
    IRQ_RELOAD  = $C001
    IRQ_DISABLE = $E000
    IRQ_ENABLE  = $E001
.endscope

.macro BANK_REGISTER_SET REGISTER_ID, REGISTER_VALUE
    .if REGISTER_ID < 0 || REGISTER_ID > 7
        .error "bad value for REGISTER_ID when bank switching"
    .endif

    lda #REGISTER_ID
    sta MMC3::BANK_SELECT
    lda #REGISTER_VALUE
    sta MMC3::BANK_DATA
.endmacro
