;;;
;; Repeat a scale of notes on the triangle channel.

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02, $01
    .res $0A, $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHARS"
    .incbin "../assets/basic.chr"

.segment "CODE"

.include "../shared/asm.s"
.include "../shared/apu.s"
.include "../shared/oam.s"
.include "../shared/ppu.s"
.include "../shared/clear.s"

.scope Vars
    zp_flags     = $20

    ;; Boolean value stating whether the currently indexed note should be
    ;; delivered to the triangle channel or not.
    zp_next_note = $21

    ;; Index to the 'notes_{low,high}' tables, pointing at the current note.
    zp_index     = $22

    ;; Simple counter increased/reset on NMI code.
    zp_counter   = $23
.endscope

;; Where the scale of notes should start and end.
INITIAL_NOTE = 40
HIGHEST_NOTE = 50

.proc reset
    sei
    cld

    ldx #$40
    stx APU::m_frame_counter

    ldx #$FF
    txs

    inx
    stx PPU::m_control
    stx PPU::m_mask
    stx APU::m_dmc

    bit PPU::m_status
@vblankwait1:
    bit PPU::m_status
    bpl @vblankwait1

    ldx #0
    lda #0
@ram_reset_loop:
    sta $000, x
    sta $100, x
    sta $300, x
    sta $400, x
    sta $500, x
    sta $600, x
    sta $700, x
    inx
    bne @ram_reset_loop

    lda #$EF
@sprite_reset_loop:
    sta $200, x
    inx
    bne @sprite_reset_loop

    OAM_WRITE_SPRITES

@vblankwait2:
    bit PPU::m_status
    bpl @vblankwait2

    lda #$3F
    sta PPU::m_address
    lda #$00
    sta PPU::m_address

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta PPU::m_data
    dex
    bne @palettes_reset_loop

    __fallthrough__ main
.endproc

.proc main
    CLEAR_SCREEN

    ;; Initialize the note index, reset the counter and ensure that the first
    ;; note is delivered.
    lda #INITIAL_NOTE
    sta Vars::zp_index
    ldx #0
    stx Vars::zp_counter
    inx
    stx Vars::zp_next_note

    ;; Same as beep.s
    lda #$0F
    sta APU::m_status

    ;; Enable the triangle channel.
    lda #%10000001
    sta APU::m_triangle_control

    cli
    lda #%10001000
    sta PPU::m_control
    lda #%00011110
    sta PPU::m_mask

@main_game_loop:
    ;; Should we change the note? If not, then skip this altogether, or
    ;; otherwise sending the same note over and over will result in a
    ;; blurry/ugly sound.
    lda Vars::zp_next_note
    beq @skip_note

    ;; Fetch the new note and send it to the triangle channel. Note that notes
    ;; on both tables are defined with the square channels in mind. Sicne the
    ;; triangle channel is an octave below, we need to divide the given value by
    ;; two.
    ldx Vars::zp_index
    lda notes_low, x
    lsr
    sta APU::m_triangle_low
    lda notes_high, x
    lsr
    sta APU::m_triangle_high

@skip_note:
    lda #%10000000
    ora Vars::zp_flags
    sta Vars::zp_flags
@wait_for_render:
    bit Vars::zp_flags
    bmi @wait_for_render

    jmp @main_game_loop

    ;; NOTE: notes taken from: https://www.nesdev.org/wiki/APU_basics.
    ;; NOTE: only valid for NTSC. For PAL we would need another set of values
    ;; which can be found in other places.
notes_low:
    .byte $f1,$7f,$13,$ad,$4d,$f3,$9d,$4c,$00,$b8,$74,$34
    .byte $f8,$bf,$89,$56,$26,$f9,$ce,$a6,$80,$5c,$3a,$1a
    .byte $fb,$df,$c4,$ab,$93,$7c,$67,$52,$3f,$2d,$1c,$0c
    .byte $fd,$ef,$e1,$d5,$c9,$bd,$b3,$a9,$9f,$96,$8e,$86
    .byte $7e,$77,$70,$6a,$64,$5e,$59,$54,$4f,$4b,$46,$42
    .byte $3f,$3b,$38,$34,$31,$2f,$2c,$29,$27,$25,$23,$21
    .byte $1f,$1d,$1b,$1a,$18,$17,$15,$14
notes_high:
    .byte $07,$07,$07,$06,$06,$05,$05,$05,$05,$04,$04,$04
    .byte $03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
.endproc

.proc nmi
    bit Vars::zp_flags
    bpl @next

    pha
    txa
    pha
    tya
    pha

    ;; Increase the counter and do nothing if we are not at the desired value yet.
    inc Vars::zp_counter
    lda Vars::zp_counter
    cmp #30
    bne @skip_reset

    ;; Reset counter, move the note index and state that we need to update the
    ;; triangle channel with this new note.
    lda #0
    sta Vars::zp_counter
    inc Vars::zp_index
    inc Vars::zp_next_note

    ;; Wrap around the note index if needed.
    lda Vars::zp_index
    cmp #HIGHEST_NOTE
    bne @done
    lda #INITIAL_NOTE
    sta Vars::zp_index
    bne @done

@skip_reset:
    ;; In the general case, avoid the current note to be delivered.
    lda #0
    sta Vars::zp_next_note

@done:
    lda #%01111111
    and Vars::zp_flags
    sta Vars::zp_flags

    pla
    tay
    pla
    tax
    pla
@next:
    rti
.endproc

.proc irq
    rti
.endproc
