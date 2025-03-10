;;;
;; This file contains definitions for metatiles and screens.
;;
;; *Metatiles* are a way to group multiple related background tiles into a
;; single entity. For the programs using this file, a metatile is a square of 4
;; tiles: that is, a block of 16x16 pixels. Screens are going to use metatiles
;; as building blocks, never tiles in on themselves. This means that rendering
;; and collision checking is done at the metatile level, never at the tile
;; level. This simplifies memory consumption a lot (e.g. smaller collision maps,
;; smaller screen definitions, etc.). As how things are defined here, a metatile
;; is a list of four consecutive bytes, which each represent the index on the
;; pattern table for the top-left, top-right, bottom-left and bottom-right tiles
;; respectively.
;;
;; Because of the above, a *screen* is laid out as a grid of 16x15 metatiles.
;; This means that we can set the metatile position with a single byte. In our
;; case, the high nibble will represent the "y coordinate" and the low one the
;; "x coordinate". For example, if we have a byte like so "$12", then it means
;; that it's the metatile at "1" on the vertical axis of the metatile grid, and
;; "2" on the horizontal one. In the rest of the code we would also say that $01
;; are its Y "metatile coordinates" and $02 its X "metatile coordinates". We
;; could have gone a step further and do like Super Mario Bros. which disregards
;; some of the metatile rows because they are not entirely visible anyways on a
;; CRT screen and because of the HUD on top. This amount of compression is not
;; needed here. That being said, there is one important gotcha: tiles have to be
;; sorted, both on the X and the Y axis. This makes the background loader
;; snappier.
;;
;; Other than that, we use another byte to store properties for each metatile
;; that we are placing. Since this is quite simple, we just reserve bit 7 to set
;; whether the metatile is to be considered for collisions or not, and the rest
;; encodes the metatile index. The metatile index simply identifies which of the
;; metatiles in `metatiles` we are referencing. Thus, a value of "$81" means
;; that we want the metatile with index 1 on `metatiles` and that it has to be
;; considered for collision checking.
;;
;; All in all, a screen here is a bunch of pairs of bytes, each pair encoding a
;; metatile for the screen. A screen definition stops whenever there is the byte
;; $FF.
;;
;; A *level* consists of one or more screens, each of them enclosed by the
;; termination byte $FF. A level is finished whenever we find the termination
;; $FF after another $FF one. Levels are indexed by the `levels_lo` and
;; `levels_hi` lists, which contain the low byte and the high byte respectively
;; of the address for each level. Splitting a 16-bit pointer into two separate
;; lists is quite convenient due to the architecture of the 6502 and indexing
;; operations. The level list is also closed by a '$FF' byte, which would result
;; in an impossible $FFFF pointer.
;;
;; One missing (and obvious) feature is allowing to also specify different
;; values for the attribute table. But I thought that this would add more
;; complexity to a code that was already too complex for the sake of giving away
;; an example.

;; Advance the screen pointer by the given `increment`.
.macro ADVANCE_SCREEN_PTR increment
    lda Metatile::zp_screen_ptr
    clc
    adc #increment
    sta Metatile::zp_screen_ptr
    lda #0
    adc Metatile::zp_screen_ptr + 1
    sta Metatile::zp_screen_ptr + 1
.endmacro

;; Transform the current value of the `a` register to a proper index for the
;; `metatiles` table. Note that the current value on the `a` register is assumed
;; to be a metatile definition (that is, the second byte of a metatile on a
;; screen). The end result is also left on the `a` register.
.macro A_TO_METATILE_INDEX
    ;; Each metatile definition on `metatiles` is 4 bytes long. Hence, the index
    ;; on that table is simply the given index multiplied by four. Or more
    ;; simply, shifted left twice. Moreover, shifting left at least once removes
    ;; the most significant bit, which was the collision bit that we needed to
    ;; discard anyways. All in all, this operation for now is simply shifting
    ;; the current value twice.
    asl
    asl
.endmacro

;; Holds variables which are useful to manipulate metatiles and how they are
;; laid out on screens.
.scope Metatile
    ;; The "screen pointer". A 16-bit pointer which points to the current
    ;; metatile definition for the current screen.
    zp_screen_ptr  = $70
    zp_screen_ptr1 = $71

    ;; The "metatile pointer". A 16-bit pointer which points to the base table
    ;; of metatile definitions.
    zp_metatile_ptr  = $72
    zp_metatile_ptr2 = $73

    ;; Initialize the pointers to handle metatiles on the game.
    .proc init
        lda #<metatiles
        sta zp_metatile_ptr
        lda #>metatiles
        sta zp_metatile_ptr + 1

        ;; NOTE: the screen pointer is supposed to be initialized when loading a
        ;; new level.

        rts
    .endproc
.endscope

;; List of metatiles.
metatiles:
    ;; Default metatile: transparent.
    .byte $00, $00, $00, $00

    ;; Super Mario Bros. block.
    .byte $05, $07, $06, $08

    ;; Super Mario Bros. ground.
    .byte $02, $01, $03, $04

;; Low bytes of the address for each level.
levels_lo:
    .byte <level1, <level2

    ;; End of levels.
    .byte $FF

;; High bytes of the address for each level.
levels_hi:
    .byte >level1, >level2

    ;; End of levels.
    .byte $FF

;;;
;; List of levels.

level1:
    ;;;
    ;; Screen 1.
    .byte $10, $81
    .byte $40, $81
    .byte $50, $81
    .byte $80, $81
    .byte $A0, $81
    .byte $94, $01
    .byte $65, $81
    .byte $75, $81
    .byte $37, $81
    .byte $38, $81
    .byte $39, $81
    .byte $3A, $81
    .byte $3B, $81
    .byte $3C, $81
    .byte $4C, $81
    .byte $3D, $81
    .byte $4F, $81
    .byte $FF

    ;;;
    ;; Screen 2.
    .byte $22, $81
    .byte $A4, $81
    .byte $C6, $81
    .byte $FF

    ;;;
    ;; Screen 3.
    .byte $43, $81
    .byte $24, $81
    .byte $A6, $81
    .byte $FF

    ;;;
    ;; Screen 4.
    .byte $75, $81
    .byte $37, $81
    .byte $38, $81
    .byte $39, $81
    .byte $3A, $81
    .byte $FF

    ;;;
    ;; End of level.
    .byte $FF

level2:
    ;;;
    ;; Screen 1.
    .byte $14, $81
    .byte $25, $81
    .byte $36, $81
    .byte $FF

    ;;;
    ;; Screen 2.
    .byte $47, $81
    .byte $58, $81
    .byte $69, $81
    .byte $FF

    ;;;
    ;; Screen 3.
    .byte $7A, $81
    .byte $8B, $81
    .byte $9C, $81
    .byte $FF

    ;;;
    ;; End of level.
    .byte $FF
