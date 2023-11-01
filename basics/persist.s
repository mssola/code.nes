;;;
;; This is an example on how you can persist data through different console
;; resets. That is, if you watch the value on memory at $6001, on each reset you
;; will see that it gets incremented. Depending on the emulator you can further
;; inspect this. For example, FCEUX stores saved data to the $HOME/.fceux/sav
;; directory (at least on my Linux machine). In there just execute `hexdump -C
;; persist.sav` and you should get what is actually persisted on the address
;; range $6000-$7FFF. In our case, you only need to care about the first two
;; bytes from this dump, which represent $6000 and $6001 respectively.
;;
;; Last but not least, all of this is done thanks to the MMC1 chip. Thus, this
;; file is also a minimalistic example on how to configure it, even if it
;; doesn't take full advantage of it (e.g. we are not doing any bank switching).

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02
    .byte $01

    ;; Some notes:
    ;;   - bit 0: it controls the mirroring. Here it's unset, so horizontal
    ;;            mirroring is applied, but this does not matter for MMC1
    ;;            because mirroring for this chip is done programmatically, not
    ;;            on hardware. Notice this when we configure the chip below.
    ;;   - bit 1: contains battery-backed PRG RAM ($6000-7FFF)
    ;;   - bit 7-4: the lower nibble of the mapper (#%0001 for MMC1)
    .byte $12
    .byte $00

.segment "VECTORS"
    .addr nmi
    .addr reset
    .addr irq

.segment "STARTUP"
.segment "CODE"


;; Unused
nmi:
irq:
  rti

;; Check `basics/sprite.s` for a deeper look on the logic below. I have only
;; added comments to MMC1-specific stuff.
reset:
    sei
    cld
    ldx #$40
    stx $4017

    ldx #$ff
    txs

    inx
    stx $2000
    stx $2001
    stx $4010

    ;; In order to reset the MMC1 chip you need to set the bit 7 of the data and
    ;; point to any address range of $8000-$FFFF. If you want to be sure about
    ;; it, you can simply do: `lda #%10000000` and then `sta $8000`. This will
    ;; ensure that the chip is reset. That being said, a micro-optimization can
    ;; be performed by taking advantage that the "CODE" segment resides above
    ;; address $8000. Then, you can use the `inc` instruction which first writes
    ;; the old value before the incremented one. All having thus the same effect
    ;; but saving 2 bytes. I know it's somewhat obfuscated and it's done for
    ;; just two bytes, but it's so simple it's even worth it.
reset_mmc1:
    inc reset_mmc1

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

    ;; In order to configure the MMC1 chip you have to perform 5 writes into any
    ;; address within the range $8000-$9FFF. This is because the MMC1 was built
    ;; through a serial port. Thus, similarly to when we read controllers (see
    ;; `basics/input.s`), only the lowest bit is read at a time. The control
    ;; register is 5 bits long, and that's why we need to write to it 5 times
    ;; (bit0 -> .. -> bit4).
    ;;
    ;; Let's see what this value being written means:
    ;;   - bits 0-1: the mirroring. We set it to `11` for horizontal mirroring.
    ;;               That's why it did not really matter what we had at the iNES
    ;;               header: mirroring is programmatically set, not
    ;;               hardware-bound.
    ;;   - bit 2: we have two regions (see bit 3): $8000-$BFFF and $C000-$FFFF.
    ;;            This bit configures which one of them is fixed and which can
    ;;            be swapped. We set this bit to one, meaning that $8000-$BFFF
    ;;            is swappable while the other is fixed to the last bank of PRG.
    ;;   - bit 3: swappable PRG size. If set to 0, then 32KB of memory is
    ;;            assumed, and thus bit 2 is ignored (i.e. the whole thing is to
    ;;            be swapped at once). Otherwise, if set to 1, then 16KB is
    ;;            assumed, meaning that we can establish two regions from
    ;;            $8000-$FFFF, and through bit 2 we have established which of
    ;;            them is swappable. In our case, we have established
    ;;            $8000-$BFFF as swappable, which is 16KB of size and thus we
    ;;            need to set this bit.
    lda #%00001111
    sta $8000
    lsr
    sta $8000
    lsr
    sta $8000
    lsr
    sta $8000
    lsr
    sta $8000

    ;; And now we configure the bank selector, which is simply bank 0. Bit 4
    ;; also enables PRG RAM when set to 0, which we must set this way if we want
    ;; things to actually persist. Later on you would need to write to
    ;; $E000-$FFFF if you wanted to perform a bank switch, but on this example
    ;; we don't need any of that.
    lda #0
    sta $E000
    sta $E000
    sta $E000
    sta $E000
    sta $E000

    ;;;
    ;; NOTE: configuration/reset is done, the code below is our actual program :D

    ;; We store at $6000 a boolean value which means: has this ever been
    ;; initialized? If this does not equal to 1, then we are sure it has never
    ;; been initialized and we do it now. Otherwise, we just increment the value
    ;; we store at $6001.
    lda $6000
    cmp #1
    bne @init_store
    inc $6001
    jmp @loop
@init_store:
    lda #1
    sta $6000
    lda #0
    sta $6001

    ;; Loop forever, there's nothing to be done here.
@loop:
    jmp @loop

.segment "CHARS"
