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
    m_control = $2000
    m_mask    = $2001
    m_status  = $2002
    m_scroll  = $2005
    m_address = $2006
    m_data    = $2007
.endscope
