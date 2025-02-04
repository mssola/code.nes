;;;
;; Make a character blink by performing bank switching on the PPU.
;;
;; This is done by using the MMC3 chip. Read more about this mapper here:
;; https://www.nesdev.org/wiki/MMC3. The MMC3 is a pretty advanced chip, so
;; first go over the `basics/` directory for a better understanding on easier
;; topics. Most importantly, take a look at examples like `basics/persist.s` or
;; `basics/unrom`, which also perform bank switching albeit with simpler
;; hardware.
;;
;; This example basically makes use of the bank switching capabilities of the
;; MMC3 chip, so the handling of IRQs is left to other examples (e.g. see
;; `scroll/roulette.s`).
;;
;; On the context of the MMC3 chip, the CPU ROM space is divided into 4 regions
;; of 8KB each. Two of these regions are swappable, the rest are fixed. This is
;; configured when performing bank switching itself. The MMC3 chip has 8
;; registers which hold which bank to go for any given memory address. Because
;; there's only two swappable banks on the CPU memory space, only two registers
;; are given for the CPU: R6 and R7. Bank switching will be a matter of setting
;; which memory bank corresponds to these two registers. The CHR ROM is similar
;; but in there the space is divided into 6 regions (hence 6 registers): 2 of
;; 2KB and 4 of 1KB. Which regions are 2KB and which 1KB is also configured when
;; doing the bank switching itself. Again, for more in-depth views on all of
;; this, check out the NesDev wiki. This example tries to be detailed whenever
;; bank switching happens.
;;
;; With that being said, some games like Megaman 5/6 performed some background
;; effects by simply performing bank switching on the CHR ROM space (e.g.
;; animating leaves from palm trees). This can easily be achieved by simply
;; performing a bank switch on the PPU space periodically with two similar
;; segments. On this example the character blinks because we periodically switch
;; the bank on the first half of the first pattern table between
;; shared/diskun{0,1}.chr. The only difference between these two files are the
;; top sprites for the character. Notice that the code doesn't have to manually
;; specify which sprite ID to look on each iteration: it's the same ID all the
;; time, it's just that the data underneath each ID subtly changes.

;; Include helpful definitions.
.include "../shared/mmc3.s"

;; Variables used on this example.
.scope Vars
    counter   = $00
    last_bank = $01
.endscope

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $10                   ; 16 * 16 PRG-ROM (256KB)
    .byte $10                   ; 16 * 8  CHR-ROM (128KB)
    .byte $42, $08              ; Mapper 4, battery present, iNES 2.0 header
    .res 8, 0

.segment "VECTORS"
    .addr nmi, reset, irq

;;; NOTE: lots of banks, all of them empty since we don't need them :)

.segment "PRG0_00"
.byte $FF
.segment "PRG0_01"
.byte $FF
.segment "PRG0_02"
.byte $FF
.segment "PRG0_03"
.byte $FF
.segment "PRG0_04"
.byte $FF
.segment "PRG0_05"
.byte $FF
.segment "PRG0_06"
.byte $FF
.segment "PRG0_07"
.byte $FF
.segment "PRG0_08"
.byte $FF
.segment "PRG0_09"
.byte $FF
.segment "PRG0_0A"
.byte $FF
.segment "PRG0_0B"
.byte $FF
.segment "PRG0_0C"
.byte $FF
.segment "PRG0_0D"
.byte $FF
.segment "PRG0_0E"
.byte $FF
.segment "PRG1_00"
.byte $FF
.segment "PRG1_01"
.byte $FF
.segment "PRG1_02"
.byte $FF
.segment "PRG1_03"
.byte $FF
.segment "PRG1_04"
.byte $FF
.segment "PRG1_05"
.byte $FF
.segment "PRG1_06"
.byte $FF
.segment "PRG1_07"
.byte $FF
.segment "PRG1_08"
.byte $FF
.segment "PRG1_09"
.byte $FF
.segment "PRG1_0A"
.byte $FF
.segment "PRG1_0B"
.byte $FF
.segment "PRG1_0C"
.byte $FF
.segment "PRG1_0D"
.byte $FF
.segment "PRG1_0E"
.byte $FF

;;; NOTE: the first fixed PRG bank will simply contain utilities for moving the
;;; player around.
.segment "FIXED"
.include "../shared/diskun.s"

;;; NOTE: the main bulk of this example. Comments only for the parts which are
;;; specific to this example.
.segment "TAIL"

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

    ;;;
    ;; NOTE: Setup MMC3

    ;; Just like we saw with the MMC1 chip on `basics/persist.s`, mirroring is
    ;; configurable (i.e. not soldered in hardware as with the regular NROM).
    ;; There's a register you can set for this, tied to even addresses between
    ;; $A000-$BFFE.
    ;;
    ;; Set mirroring to vertical (0).
    lda #$00
    sta MMC3::MIRRORING

    ;; Interrupts are a whole topic of their own on the MMC3 chip. Here we just
    ;; disable them and leave it for other examples (e.g. see
    ;; `scroll/roulette.s`). Again, this is tied to a register mapped to a
    ;; region in memory (even addresses on $E000-$FFFE in this case).
    sta MMC3::IRQ_DISABLE

    ;; PRG RAM can be protected from writes, but this is a feature that many
    ;; emulators choose to discard because it might conflict with the MMC6 chip
    ;; support. Long story short, here we just enable PRG RAM and leave it at
    ;; that.
    lda #$80
    sta MMC3::RAM_PROTECT

    ;; PRG banking setup. PRG-ROM is divided into 4 banks of 8KB each. The last
    ;; two banks are set to be fixed (otherwise the values below should have set
    ;; bit 7 each to make other regions fixed and others swappable, see the
    ;; documentation on NesDev). The first two banks are controlled by registers
    ;; 6 and 7. In this case, we will simply set the first two banks for these
    ;; two regions.
    BANK_REGISTER_SET 6, 0
    BANK_REGISTER_SET 7, 1

    ;; CHR banking setup. The PPU is divided into 8 banks 1KB each. Hence, we
    ;; have to fill up this 8KB of the usual CHR-ROM space through banking. The
    ;; first two registers controlling bank switching on the PPU, R0 and R1,
    ;; actually hold control over 2KB. Hence, the first two registers actually
    ;; span 4 banks (that is, the first pattern table on the PPU). We have to
    ;; account for that when writing into the first two registers (and that's
    ;; why they are set to 0 and 2 respectively). Other than that, R2-R5 hold
    ;; which bank goes into the other remaining regions which are 1KB each
    ;; (hence, the second pattern table is controlled via R2-R5). Because of
    ;; this, we can simply assign one 1KB bank to each register.
    ;;
    ;; To sum things up, on this setup the first pattern table is equally
    ;; divided by 2 and it's controlled by R0 and R1 respectively. The second
    ;; pattern table is equally divided by 4 and it's controlled by R2-R5.
    BANK_REGISTER_SET 0, 0
    BANK_REGISTER_SET 1, 2
    BANK_REGISTER_SET 2, 4
    BANK_REGISTER_SET 3, 5
    BANK_REGISTER_SET 4, 6
    BANK_REGISTER_SET 5, 7

    ;; NOTE: and from here on initialization proceeds as usual.

@vblankwait1:
    bit $2002
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

    lda #$ef
@sprite_reset_loop:
    sta $200, x
    inx
    bne @sprite_reset_loop

    lda #$00
    sta $2003
    lda #$02
    sta $4014

@vblankwait2:
    bit $2002
    bpl @vblankwait2

    lda #$3F
    sta $2006
    lda #$00
    sta $2006

    lda #$0F
    ldx #$20
@palettes_reset_loop:
    sta $2007
    dex
    bne @palettes_reset_loop
    jmp main

;;; NOTE: mainly as usual except that a bit of game loop has been added to
;;; handle the blinking state.
.proc main
    ;; The code will iterate between banks 4 and 6 on the pattern table, as
    ;; that's where sprites are located (check the CHARS segment for more info).
    lda #4
    sta Vars::last_bank

    jsr Diskun::init_palettes
    jsr init_sprites

    cli

    ;; NOTE: This looks like other examples, but here having background tiles on
    ;; the first pattern table and sprite tiles on the second pattern table is
    ;; not a matter of personal taste, but there are technical reasons for it.
    ;; If you check how IRQs work on the MMC3 chip:
    ;; https://www.nesdev.org/wiki/MMC3#IRQ_Specifics; you will find that on 8x8
    ;; tile mode having this arrangement actually spares us from a hardware bug.
    ;; Long story short, placing background tiles first and sprite tiles second
    ;; make scanline IRQs reliable. Hence, at least on all MMC3 examples, this
    ;; will be guaranteed.
    lda #%10001000
    sta $2000

    lda #%00011110
    sta $2001

@main_game_loop:
    jsr joypad_read
    jsr Diskun::update

    lda #%10000000
    ora $20
    sta $20
@wait_for_render:
    bit $20
    bmi @wait_for_render

    ;; NOTE: let there be a game logic :D

    ;; Is the counter already at the limit? If not just restart the game loop.
    lda Vars::counter
    cmp #$20
    bne @main_game_loop

    ;; Reset the counter
    lda #0
    sta Vars::counter

    ;; The whole trick is done on R2, which points to $1000, where the sprite
    ;; tiles begin. Hence, select it.
    lda #2
    sta MMC3::BANK_SELECT

    ;; The value for the register is either 4 or 6 depending on its last value.
    lda Vars::last_bank
    cmp #4
    beq :+
    lda #4
    jmp @set
:
    lda #6
@set:
    ;; Save which is the bank being used both internally and onto the MMC3 chip.
    sta Vars::last_bank
    sta MMC3::BANK_DATA

    jmp @main_game_loop
.endproc

;; NOTE: from here on nothing remarkable in comparison to other examples.

.proc init_sprites
    NUM_SPRITES = 4

    lda #$40
    sta Diskun::m_screen_y
    lda #$46
    sta Diskun::m_screen_x

    ldx #$00
@load_sprites_loop:
    lda initial_sprite_data, x
    sta $0200, x
    inx
    cpx #(4 * NUM_SPRITES)
    bne @load_sprites_loop
    rts
initial_sprite_data:
    ;; $200-$20F
    .byte $40, $01, %00000000, $46
    .byte $40, $01, %01000000, $4E
    .byte $48, $11, %00000000, $46
    .byte $48, $11, %01000000, $4E
.endproc

;;; NOTE: nothing to highlight here other than the counter is increased on each
;;; NMI.
nmi:
    bit $20
    bpl @next

    pha
    txa
    pha
    tya
    pha

    ;; Increase the counter for the blinking.
    inc Vars::counter

    jsr Diskun::nmi_update

    lda #$00
    sta $2003
    lda #$02
    sta $4014

    bit $2002
    lda #$00
    sta $2005
    sta $2005

    lda #%01111111
    and $20
    sta $20

    pla
    tay
    pla
    tax
    pla
@next:
    rti

;;; NOTE: IRQ is disabled when setting up the MMC3 chip for this example.
irq:
    rti

;;; NOTE: The header for this game advertises 128KB for CHR-ROM. This is wildly
;;; too much for this example, but it's a reasonable size for an MMC3 game.
;;; Considering only one pair of pattern tables are available at any given
;;; moment (8KB), this means that we need space for 128 / 8 = 16 pairs of
;;; pattern tables here. For this example the first 8KB are really only used,
;;; and the rest are left with a default value ($00).

.segment "CHARS"
;; As explained when initializing the PPUCTRL register ($2000), it's actually
;; important to place background tiles first and sprite tiles second on the
;; MMC3. This is guaranteed here by setting the first pattern table as empty (we
;; have no background on this example, really). The second pattern table is then
;; filled with `diskun0.chr` and `diskun1.chr`, which are 2KB each. Hence, the
;; 4th CHR bank contains the regular character, and the 6th CHR bank contains
;; the blinking version. You can see these values used when initializing
;; `Vars::last_bank`, or when performing bank switching.
.res $1000, $00
.incbin "../assets/diskun0.chr" ; First half of the second pattern table has the default diskun character.
.incbin "../assets/diskun1.chr" ; Second half of the second pattern table simply has the blinking version.

;; The 15 other 8KB portions are left empty.
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
.res $2000, $00
