;;
;; This example shows how to read from one controller and set it into the $20
;; memory address. The `Main` subroutine will call the `ReadController`
;; subroutine and then increment the value on $42 if the right arrow was
;; pressed. When running this ROM, watch for the following RAM addresses:
;;
;;  - $20: the bitmap of the current status of the controller (notice that since
;;         we are constantly polling it and filling it, the value will move constantly).
;;  - $21: the previous status of the right arrow.
;;  - $42: the counter which is incremented on each press of the right arrow button.
;;;

;;;
;; You can safely ignore all of this up until the `ReadController` subroutine.
;; This is boilerplate that is explained on the `sprite.s` example.
;;;

.segment "HEADER"
    .byte 'N', 'E', 'S', $1A
    .byte $02
    .byte $01
    .byte $00
    .byte $00

.segment "VECTORS"
  .addr nmi
  .addr reset
  .addr irq

.segment "STARTUP"

.segment "CODE"

nmi:
irq:
  rti

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

    jmp main

.proc ReadController
  ;; The status of the eight buttons fits into a single byte. We start the whole
  ;; dance by setting the first bit of the position we are storing this info
  ;; ($20). This bit will act as a guard in the following code.
  lda #1
  sta $20

  ;; The 4021 chip is the one responsible to bring the input from the controller
  ;; into the NES. The console reserves two addresses on the memory for the
  ;; controllers: $4016 and $4017 (see
  ;; https://www.nesdev.org/wiki/Input_devices). If you write into one of them
  ;; first with a #1 and then with a #0, we activate the latch for the
  ;; controller, and it will start to send a bit representing the state for each
  ;; button upon each read.
  ;;
  ;; Thus, since we conveniently now have #1 into the 'a' register, we send this
  ;; value to the 4021 chip, and we follow it by sending #0. This way we tell
  ;; the controller to start to deliver the data.
  sta $4016
  lda #0
  sta $4016

  ;; The status of the buttons will be provided one by one following a specific
  ;; order. The algorithm goes as follows:
  ;;
  ;;   1. Load the bit you get from the 4021 chip into `a`. After performing
  ;;      this read the controller will send the next one so it's ready for the
  ;;      next iteration.
  ;;   2. Shift the value right so to set the carry flag as its comes (note:
  ;;      overflowing from the right also sets the carry flag on!).
  ;;   3. Rotate one bit left from $20: C <- [$20] <- C. This way, we always get
  ;;      the result we put on the carry register at the right-most part of the
  ;;      byte on $20, and we clear the carry flag (the previous left-most bit
  ;;      moves into the carry register, which is 0 until we reach the one we
  ;;      planted as a guard).
  ;;   4. We jump back into `read_loop` if the carry flag is clear. This is the
  ;;      case for most of the time until the #1 that we set at the very
  ;;      beginning as a guard flows into the carry flag as expected from the
  ;;      `rol` instruction. At this point, we have already read the full byte.
read_loop:
  lda $4016
  lsr a
  rol $20
  bcc read_loop

  rts
.endproc

;; The main function will run indefinitely and it will continuously poll from
;; the controller and increment the value on $42 each time the user performs a
;; new press on the right arrow (that is, we want to count new presses on this
;; button, and we don't want to increment this value while the right arrow is
;; being pressed).
.proc main
  ;; Initialize the value on $21 (previous state) and on $42 (counter).
  lda #0
  sta $42
  sta $21

loop:
  jsr ReadController

  ;; Was the right arrow being pressed? If that's the case, then jump into the
  ;; `pressed` label to compare it with the previous state.
  lda #1
  and $20
  bne pressed

  ;; The right arrow was not being pressed. Thus, we need to update the previous
  ;; state to #0 before we read the controller again.
  lda #0
  sta $21
  jmp loop

pressed:
  ;; Now the right arrow is being pressed, and we have the guarantee that `a =
  ;; 1` (because of the `and $20` instruction returning a non-zero result). Now
  ;; do the same with the previous state. If it's a non-zero result, then it
  ;; means that the previous state was already of pressed. Hence, at this point
  ;; we can return into the main loop. If this was not the case, then it's a new
  ;; press.
  and $21
  bne loop

  ;; It's a new press, set $21 to #1 accordinly and increment the counter on $42.
  inc $21
  inc $42

  ;; There and back again.
  jmp loop

  rts
.endproc

.segment "CHARS"
