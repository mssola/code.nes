;;;
;; VRAM buffer
;;
;; As a general rule, you do *not* modify the PPU memory outside of `nmi` code:
;; this can incur into graphical glitches because of writing into PPU memory
;; while the PPU is consuming it. Instead, you append all writes into a VRAM
;; buffer so the changes are finally committed during VBlank.
;;
;; The format of the VRAM buffer being used here is quite straight-forward
;; and needs three bytes per update: two bytes for the PPU address, and
;; another for the data to be passed into the PPU. This means that for each
;; metatile we need 3 bytes per tile update * 4 tiles per metatile = 12
;; bytes per update on a metatile. This is important when considering the
;; capacity for this buffer. One idea could be to allow a whole column of
;; metatiles to fit this buffer, which would require 12 bytes per metatile *
;; 15 rows = 180 bytes. This does not look like a lot at first, but bear in
;; mind that flushing this buffer has to be done during VBlank, which has a
;; very tight time frame. Testing this number I noticed that even with 160
;; bytes for this buffer (the suggested size on the NesDev wiki:
;; https://www.nesdev.org/wiki/Sample_RAM_map) the NMI code would be
;; struggling to fit the time frame.
;;
;; Thus, by poking with different values, I ended up with 96 bytes for this
;; buffer, which allows for updates on 8 metatiles (a little more than half
;; a screen's column). This looks quite reasonable with all the tests I have
;; done.
;;
;; As a final note, on a real game you'd want to be more "aggressive" than this,
;; as the format on the VRAM buffer directly influences how fast the code during
;; VBlank can go. Hence, this buffer might not be suitable for your case.
.scope Buffer
    ;; The index of the next element to be evaluated on the VRAM buffer. If this
    ;; index reaches `VRAM_BUFFER_CAP` then we are sure that we are done
    ;; flushing updates. It's up for the user to notice when the buffer is full
    ;; and should stop sending in more updates: the user should stop things as
    ;; they are and continue on the next frame by picking up this index again.
    zp_vram_idx = $19

    ;; The VRAM buffer lives at a somewhat dangerous RAM address: $0100. This
    ;; can be dangerous because we set the stack to start at $01FF and grows in
    ;; decreasing addresses. Considering that the buffer is capped at $60, it
    ;; means that if there are no buffer overflows, the memory layout for the
    ;; $01xx RAM space is:
    ;;
    ;;   - $0100-$0159: VRAM buffer (96 bytes).
    ;;   - $0160-$01FF: Stack (160 bytes).
    ;;
    ;; Crossing fingers there are no leaks on the VRAM buffer, we have 160 bytes
    ;; for the stack, which realistically should be more than enough for any
    ;; game out there. That is, unless you are abusing the stack a la
    ;; Battletoads.
    m_vram_buffer = $0100

    ;; As explained above, the maximum capacity for the VRAM buffer, which
    ;; amounts to 96 bytes (allowing for updates on 8 metatiles during VBlank).
    VRAM_BUFFER_CAP = $60

    ;; A tile in the VRAM buffer spans 3 bytes: 2 for the address, 1 for the
    ;; sprite identifier. Since a metatile is made up of 4 tiles, then a
    ;; metatile "bucket" is 3 * 4 = 12 bytes long.
    METATILE_SIZE = 3 * 4

    ;; Push the given metatile into the graphics and the collision map. How the
    ;; graphics are updated depends on whether the PPU is enabled or not. If
    ;; it's enabled then all updates are pushed into the VRAM buffer (given that
    ;; enough space is available on this buffer, see more on the return value).
    ;; Otherwise it pushes data into the PPU directly so everything is good
    ;; after enabling the PPU back. This function expects the following
    ;; *parameters*:
    ;;
    ;;   - `a` register: the metatile definition as described in `metatile.s`.
    ;;     More specifically, the second byte on a metatile reference on the
    ;;     screen. Hence, something like `$81` for metatile with ID = 1 and with
    ;;     collision.
    ;;   - `zp_arg0`: the Y metatile coordinate.
    ;;   - `zp_arg1`: the X metatile coordinate.
    ;;   - `zp_arg2`: low byte for the corresponding PPU base address.
    ;;   - `zp_arg3`: high byte for the corresponding PPU base address.
    ;;
    ;; For the memory arguments see:
    ;; `Background::translate_mt_coordinates_to_arguments`, as calling this
    ;; function will set these values properly.
    ;;
    ;; *Returns* 1 if the push was successful, 0 otherwise. A push can only
    ;; *not* be successful if the VRAM buffer doesn't have enough space for the
    ;; push.
    ;;
    ;; NOTE: the VRAM size check also happens even if the PPU is disabled. That
    ;; is, whenever you disable the PPU, make sure to mark the VRAM buffer as
    ;; free as well.
    .proc push_metatile
        ;; Do we actually have room for this metatile? If not then just return
        ;; early.
        ldx zp_vram_idx
        cpx #(VRAM_BUFFER_CAP - METATILE_SIZE)
        bne @has_enough_space
        lda #0
        rts

    @has_enough_space:
        ;; Set the proper collision for the given metatile definition, while
        ;; also preserving the value from the `a` register.
        pha
        jsr Collision::set_background_collision
        pla

        ;; Set the `y` register to contain the index on the `metatiles` table
        ;; from `metatile.s`. This index will then be incremented on each
        ;; iteration to index each tile on a metatile.
        A_TO_METATILE_INDEX
        tay

        ;; Is the PPU enabled?
        lda #%00011000
        and PPU::zp_mask
        bne @buffered_push

        ;; The PPU is disabled, we can push directly graphics into it.
        ldx #$00
    @direct_push_loop:
        bit PPU::STATUS

        ;; Write the high byte of the PPU address being used.
        lda Globals::zp_arg3
        sta PPU::ADDRESS

        ;; The low byte for the PPU address is the base as given from the
        ;; parameter plus an offset that we have pre-computed (nothing too
        ;; misterious, just check what we need to add for each tile of the
        ;; metatile).
        lda ppu_offsets, x
        clc
        adc Globals::zp_arg2
        sta PPU::ADDRESS

        ;; Load the tile id for this part of the metatile and increment the `y`
        ;; register in preparation for the next iteration.
        lda (Metatile::zp_metatile_ptr), y
        sta PPU::DATA
        iny

        inx
        cpx #4
        bne @direct_push_loop
        jmp @end

    @buffered_push:
        ;; Set on `Globals::zp_tmp0` the index on the metatile table, and on
        ;; `Globals::zp_tmp1` the loop index.
        sty Globals::zp_tmp0
        lda #$00
        sta Globals::zp_tmp1
        ldx zp_vram_idx

    @buffered_push_loop:
        ;; The first element being pushed is the high byte for the PPU address
        ;; to be used, which can be pushed directly.
        lda Globals::zp_arg3
        sta m_vram_buffer, x
        inx

        ;; The low byte needs some addition as in `@direct_push_loop`, but
        ;; taking into account that the index is handled in memory instead of
        ;; registers.
        ldy Globals::zp_tmp1
        lda ppu_offsets, y
        clc
        adc Globals::zp_arg2
        sta m_vram_buffer, x
        inx

        ;; Load on `y` the index on the metatile table and increase it for the
        ;; next iteration.
        ldy Globals::zp_tmp0
        inc Globals::zp_tmp0

        ;; And push the tile id for this part.
        lda (Metatile::zp_metatile_ptr), y
        sta m_vram_buffer, x
        inx

        ;; Should we continue?
        inc Globals::zp_tmp1
        lda Globals::zp_tmp1
        cmp #4
        bne @buffered_push_loop

        ;; And save the current index for the VRAM buffer.
        stx zp_vram_idx

    @end:
        ;; End of the push, set the proper return value.
        lda #1
        rts
    ppu_offsets:
        .byte $00, $01, $20, $21
    .endproc

    ;; Flush the current contents of the VRAM buffer into the PPU. This function
    ;; will also set the "ppu" flag if data was actually pushed.
    ;;
    ;; NOTE (NMI): this function should *only* be called during VBlank.
    .proc flush_vram_buffer
        ldx #$FF

    @loop:
        inx
        cpx zp_vram_idx
        beq @after_loop

        bit PPU::STATUS

        lda m_vram_buffer, x
        sta PPU::ADDRESS

        inx
        lda m_vram_buffer, x
        sta PPU::ADDRESS

        inx
        lda m_vram_buffer, x
        sta PPU::DATA

        jmp @loop

    @after_loop:
        ;; If no loop cycle was performed then, in theory, there is no data to
        ;; be buffered into PPU. If this was not the case, and things had to be
        ;; updated anyways (e.g. the scroll moved regardless of this), then it's
        ;; up for the caller to decide.
        lda zp_vram_idx
        beq @end

        ;; Buffer a write into the PPU control register, so the scroll is also
        ;; left at a known state after touching the PPU address register.
        lda #%01000000
        ora Globals::zp_flags
        sta Globals::zp_flags

        ;; If there were some bytes actually consumed by this loop, ensure that
        ;; it's reset.
        lda #0
        sta zp_vram_idx

    @end:
        rts
    .endproc
.endscope

;; Flush the VRAM buffer if there are pending updates.
;;
;; NOTE (NMI): this macro should *only* be used during VBlank.
.macro FLUSH_PENDING_VRAM_BUFFER
    lda Buffer::zp_vram_idx
    beq :+
    jsr Buffer::flush_vram_buffer
:
.endmacro
