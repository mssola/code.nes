;;;
;; An example that showcases how you can tell apart a hardware IRQ from a
;; software IRQ, and how to get the "break mark" from a software IRQ (see:
;; https://www.masswerk.at/6502/6502_instruction_set.html#BRK).

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02, $01
    .byte $00
    .byte $00

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CODE"
;; asan:stack full

zp_ptr  = $00                   ; asan:reserve $02
zp_brk  = $02
m_stack = $100

.proc reset
    ;; Our code will simply call 'brk' to interrupt execution and then loop
    ;; forever.
    brk
    .byte $42

here:
    jmp here
.endproc

.proc nmi
    rti
.endproc

.proc irq
    ;; Save all registers.
    pha
    txa
    pha
    tya
    pha

    ;; On a 'brk' instruction, the status register is pushed onto the stack with
    ;; the 'B' flag set. Otherwise, on a hardware IRQ we will not get any such
    ;; thing. Hence, we first try to pull the status register.
    tsx

    ;; Where is it located? Well, the stack pointer points to the next element,
    ;; and we have pushed onto the stack three times in order to save the
    ;; registers when we entered irq(). Hence, it's at the current stack
    ;; position + 4 + the current stack frame (in 'x' thanks to the previous
    ;; 'tsx').
    lda m_stack + 4, x

    ;; Is the B flag set on the status register?
    and #$10

    ;; If that's not the case, then it's a hardware IRQ.
    ;;
    ;; NOTE: this crucial part is actually prone to errors! It might just be the
    ;; case that the stack contained garbage, we got a hardware IRQ, and
    ;; 'm_stack + 4 + stack frame' just so happened to match '#$10'. In order to
    ;; guarantee this to work, 'pla' usage would need to be coupled with a
    ;; cleaning of the given stack address as well, which is just unrealistic.
    beq is_hardware_irq

    ;; This is a software IRQ. Now, the low byte from the PC address was pushed
    ;; just before the status register. But the address that was pushed was
    ;; actually PC + 2 so to hop over the "break mark". That is, every 'brk'
    ;; instruction is coupled with an extra byte containing debugging
    ;; information for the given 'brk'. Hence, if we want to get the "break
    ;; mark", we have to pick up the address of PC - 1.
    lda m_stack + 5, x
    sec
    sbc #$01
    sta zp_ptr

    ;; The high byte from the PC address was pushed onto the stack before the
    ;; low one. Hence, it's the next byte. Moreover, we call 'sbc #$00' to apply
    ;; the borrow from the previous subtraction just in case it underflowed.
    lda m_stack + 6, x
    sbc #$00
    sta zp_ptr + 1

    ;; And now 'zp_ptr' points to the actual break mark.
    ldy #$00
    lda (zp_ptr), y

    ;; NOTE: when running this example, you should see the "break mark" ($42)
    ;; set into memory address 'zp_brk' ($02).
    sta zp_brk

is_hardware_irq:
    ;; Restore all registers.
    pla
    tay
    pla
    tax
    pla

    rti
.endproc

.segment "CHARS"
.byte $01
