;; WRITE_PPU_DATA is a macro that will write into PPUADDR the given address and
;; into PPUDATA the given byte value.
.macro WRITE_PPU_DATA address, value
    bit $2002
    lda #.HIBYTE(address)
    sta $2006
    lda #.LOBYTE(address)
    sta $2006
    lda #value
    sta $2007
.endmacro

.scope PPU
    CONTROL = $2000
    MASK    = $2001
    STATUS  = $2002
    SCROLL  = $2005
    ADDRESS = $2006
    DATA    = $2007

    ;; Variable that shadows the value on PPU::CONTROL.
    zp_control = $80

    ;; Variable that shadows the value on PPU::MASK.
    zp_mask = $81
.endscope
