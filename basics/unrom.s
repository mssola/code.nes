;;;
;; This is an example on how you can perform bank switching. In order to do this
;; I am using the UNROM chip (iNES mapper 2), which is one of the first chips to
;; ever support this. Because of this, it's also one of the simplest, which is
;; quite convenient in order to learn this technique.
;;
;; The program will do the following:
;;   - Switch to bank 0.
;;   - Call a function from bank 0 that will set $10 to #2.
;;   - Switch to bank 1.
;;   - Call a function from bank 1 that will set $11 to #3.
;;   - Sum the values from $10 and $11 and store them in $12.
;;
;; At this point there are two things you can do in order to check that the
;; whole thing worked:
;;
;;   1. The values on $10, $11 and $12 are as expected (2, 3, and 5
;;      respectively).
;;   2. The last bank we switched was 1, which has a fill value on linker
;;      configuration (see `config/unrom.cfg`) of `$f9`. Thus, check that except
;;      from the code on `hello_bank1`, the rest of the values on $8000-$BFFF
;;      are set to `$f9` (i.e. by using FCEUX's Debug -> Hex editor).

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $08                   ; 128KB  of PRG-ROM (8 x 16KB)
    .byte $00                   ; No CHR-ROM. Games using this chip used RAM instead.

    ;; On the 6th byte we have to set the lower nibble of the mapper (#%0010 for
    ;; UNROM).
    .byte $20

    ;; Forcing iNES 2.0 format, which will help us for the next bytes.
    .byte $08

    ;; And now iNES 2.0-specific thingies.
    .byte $00       ; No submapper
    .byte $00       ; PRG ROM not 4 MiB or larger
    .byte $00       ; No PRG RAM
    .byte $07       ; 8192 (64 * 2^7) bytes CHR RAM, no battery
    .byte $00       ; NTSC; use $01 for PAL
    .byte $00       ; No special PPU

.segment "VECTORS"
    .addr nmi, reset, irq

;;;
;; Note that we now define code on bank 0 and bank 1. These names are not magic:
;; they are defined on the linker configuration being used (see
;; `config/unrom.cfg`). All swappable banks are called `BANK#`. The bank that is
;; not swappable is simply called `FIXED`, and that's the bank where most of the
;; code from this example will reside.

.segment "BANK0"

hello_bank0:
    lda #2
    sta $10
    rts

.segment "BANK1"

hello_bank1:
    lda #3
    sta $11
    rts

;;;
;; The rest of the banks are simply not used by this example.

.segment "BANK2"
.byte $00

.segment "BANK3"
.byte $00

.segment "BANK4"
.byte $00

.segment "BANK5"
.byte $00

.segment "BANK6"
.byte $00

;;;
;; And the following code is "fixed". That is, it is stored at $C000-$FFFF,
;; which is not swappable. You can check this by using FCEUX's hex editor, for
;; example.

.segment "FIXED"

;; This table contains the actual sauce of bank switching. In general, the UNROM
;; does bank switching by writing to $8000-$BFFF, but the value we are writing
;; there *must* match the value located at the destination address in ROM
;; (otherwise we get a bus conflict). Writing to this table already ensures that
;; this never happens because the indexing will match the actual value.
banktable:
  .byte $00, $01, $02, $03, $04, $05, $06

;; Variable containing the bank we are currently in. It's useful to keep track
;; of the bank so the NMI handler can restore it if it does some bank switching
;; of its own.
zp_current_bank = $00

;; Perform a bankswitch by using the value on the `y` register. Note that you
;; can use the `bankswitch_nosave` variant, which is useful if you just want to
;; perform a temporary bankswitch (e.g. on NMI code).
bankswitch:
    sty zp_current_bank
bankswitch_nosave:
    tya
    sta banktable, y
    rts

;; Unused
.proc nmi
    rti
.endproc

;; Unused
.proc irq
    rti
.endproc

;; Check `basics/sprite.s` for a deeper look on the logic below. I have only
;; added code after configuration/reset is done.
.proc reset
    sei
    cld
    ldx #$40
    stx $4017

    ldx #$FF
    txs

    inx
    stx $2000
    stx $2001
    stx $4010

    bit $2002
@vblankwait1:
    bit $2002
    bpl @vblankwait1

    ldx #0
    lda #0
@ram_reset_loop:
    sta $000, x
    sta $100, x
    sta $200, x
    sta $300, x
    sta $400, x
    sta $500, x
    sta $600, x
    sta $700, x
    inx
    bne @ram_reset_loop

@vblankwait2:
    bit $2002
    bpl @vblankwait2

    ;;;
    ;; NOTE: configuration/reset is done, the code below is our actual program :D

    ;; Switch to bank 0 and call the function from there.
    ldy #0
    jsr bankswitch
    jsr hello_bank0

    ;; The same but on bank 1.
    ldy #1
    jsr bankswitch
    jsr hello_bank1

    ;; And now we can add the numbers that were saved by both banks.
    lda $10
    clc
    adc $11
    sta $12

    ;; Loop forever, there's nothing to be done here.
@loop:
    jmp @loop
.endproc
