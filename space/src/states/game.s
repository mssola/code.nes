.scope Game
    ;; Contains relevant flags for the execution of the game:
    ;;   - 7: set to 1 whenever the game logic is over and we can start
    ;;        rendering; set to 0 when rendering is done.
    ;;   - 6-0: unused.
    flags = $20
.endscope

;; SET_RENDER_FLAG sets the render bit on Game::flags to 1.
.macro SET_RENDER_FLAG
  lda #%10000000
  ora Game::flags
  sta Game::flags
.endmacro

;; UNSET_RENDER_FLAG sets the render bit on Game::flags to 0.
.macro UNSET_RENDER_FLAG
  lda #%01111111
  and Game::flags
  sta Game::flags
.endmacro
