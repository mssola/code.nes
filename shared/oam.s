.scope OAM
    m_addr = $2003
    m_dma  = $4014
.endscope

.macro OAM_WRITE_SPRITES
    lda #$00
    sta OAM::m_addr
    lda #$02
    sta OAM::m_dma
.endmacro
