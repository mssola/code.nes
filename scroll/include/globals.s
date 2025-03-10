;; Global variables used throughout the code base.
.scope Globals
    ;;;
    ;; Argument values as defined in https://github.com/mssola/style.nes. Note
    ;; that these variables can also be used as temporary variables.
    zp_arg0 = $90
    zp_arg1 = $91
    zp_arg2 = $92
    zp_arg3 = $93
    zp_arg4 = $94

    ;;;
    ;; Random values that can be used inside of functions for temporary values
    ;; so `zp_argX` variables are not overwritten as often.
    zp_tmp0 = $9A
    zp_tmp1 = $9B
    zp_tmp2 = $9C
    zp_tmp3 = $9D

    ;;;
    ;; Reserve a byte of memory for preserving indices on memory. This is needed
    ;; whenever the `x` and `y` registers might not be reliable because of
    ;; underlying `jsr` calls that might tamper with their values. Sometimes
    ;; saving the value in memory is enough instead of playing with the stack.
    zp_idx = $9E

    ;; Flags that manage the state of the game.
    ;;
    ;; | Bit | Short name | Meaning when set                                            |
    ;; |-----+------------+-------------------------------------------------------------|
    ;; |   7 | render     | Game logic is over, block main code until NMI code is over. |
    ;; |   6 | ppu        | PPU registers (2000 and scroll) have to be updated.         |
    ;; |   5 | level      | The current level is active.                                |
    ;; |   4 | column     | The current column is still being buffered into the PPU.    |
    ;; |   3 | end        | We are at the end of the level                              |
    ;; |   2 | nametable  | Next nametable to be used                                   |
    ;; | 1-0 | -          | Unused                                                      |
    zp_flags = $20
.endscope
