;;;
;; Pseudo-random number implementation by a linear feedback shift register.
;;
;; This is one of the most common techniques developed on NES/Famicom games, and
;; it's based on the algorithm from french mathematician Évariste Galois:
;; https://en.wikipedia.org/wiki/Linear-feedback_shift_register#Galois_LFSRs.
;; That is, we have a wider-than-8-bit register which keeps on shifting and
;; "taps" on some bits whenever the carry flag is set. This sounds complicated
;; but it really is not, and it can be further optimized as Brad Smith proved:
;; https://github.com/bbbradsmith/prng_6502.
;;
;; All in all, the implementation here is based on the "basic" implementation
;; from NesHacker: https://github.com/NesHacker/NES-RNG/blob/main/nes-rng.s; as
;; it's easier to reason about. Other than that, refer to the NESDev wiki for
;; more information: https://www.nesdev.org/wiki/Random_number_generator.

;; Producing random numbers with a linear feedback shift register require at
;; least 16-bit. In this case, we have the low byte which will be the end result
;; upon each call to `linear_feedback_shift_register`; and the high byte which
;; will be messed up to feed the low byte on each iteration. If we wanted more
;; random numbers (i.e. how many random numbers can be generated before they
;; start repeating all over again), we would need to add more bytes. For a
;; simple 8-bit computer like the NES/Famicom, a 16-bit register for this is
;; more than enough.
.scope Linear
    zp_register_lo = $40
    zp_register_hi = $41
.endscope

;; Updates the 'a' register with a new random number as extracted from the
;; linear feedback shift register referenced in the `Linear` scope.
;;
;; See: https://github.com/NesHacker/NES-RNG/blob/main/nes-rng.s
.proc linear_feedback_shift_register
    lda Linear::zp_register_hi
    ldy #8

@loop:
    ;; Shift the least significant bit from the high byte to the low byte of the
    ;; 16-bit register.
    lsr
    ror Linear::zp_register_lo

    ;; Following the Galois algorithm, if the carry flag was set, then we need
    ;; to tap on some specific bits of the low byte with an xor. Hence, if the
    ;; carry flag is clear, skip the `eor` instruction.
    bcc @skip_eor
    eor #$B4

@skip_eor:
    ;; Save the current state of the high register and decrement the loop index.
    sta Linear::zp_register_hi
    dey
    bne @loop

    ;; The low byte now contains the shifted values from the loop. That's our
    ;; final "random" number!
    lda Linear::zp_register_lo

    rts
.endproc
