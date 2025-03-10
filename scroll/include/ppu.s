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
