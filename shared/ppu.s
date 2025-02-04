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
