V =
ifeq ($(strip $(V)),)
	E = @echo
	Q = @
else
	E = @\#
	Q =
endif

CC65   ?= cl65
CCOPTS ?= --target nes

.PHONY: all
all: clean deps build

.PHONY: clean
clean:
	@rm -rf out
	@find . -type f -name "*.o" -delete
	@find . -type f -name "*.nes" -delete
	@mkdir -p out/basics out/scroll out/space out/fx

.PHONY: deps
deps:
	@which $(CC65) >/dev/null 2>/dev/null || (echo "ERROR: $(CC65) not found." && false)

.PHONY: build
build: basics space scroll fx

.PHONY: basics
basics:
	$(E) "	CC	 basics/sprite"
	$(Q) $(CC65) $(CCOPTS) basics/sprite.s -C config/nrom.cfg -o out/basics/sprite.nes

	$(E) "	CC	 basics/input"
	$(Q) $(CC65) $(CCOPTS) basics/input.s -C config/nrom.cfg -o out/basics/input.nes

	$(E) "	CC	 basics/persist"
	$(Q) $(CC65) $(CCOPTS) basics/persist.s -C config/mmc1.cfg -o out/basics/persist.nes

	$(E) "	CC	 basics/flicker"
	$(Q) $(CC65) $(CCOPTS) basics/flicker.s -C config/nrom.cfg -o out/basics/flicker.nes

	$(E) "	CC	 basics/unrom"
	$(Q) $(CC65) $(CCOPTS) basics/unrom.s -C config/unrom.cfg -o out/basics/unrom.nes

	$(E) "	CC	 basics/chr-ram"
	$(Q) $(CC65) $(CCOPTS) basics/chr-ram.s -C config/unrom.cfg -o out/basics/chr-ram.nes

.PHONY: space
space:
	$(E) "	CC	 space"
	$(Q) $(CC65) $(CCOPTS) space/src/space.s -C config/nrom.cfg -o out/space/space.nes

.PHONY: scroll
scroll:
	$(E) "	CC	 scroll/toggle"
	$(Q) $(CC65) $(CCOPTS) scroll/toggle.s -C config/nrom.cfg -o out/scroll/toggle.nes

	$(E) "	CC	 scroll/level"
	$(Q) $(CC65) $(CCOPTS) scroll/level.s -C config/nrom.cfg -o out/scroll/level.nes

	$(E) "	CC	 scroll/sprite0"
	$(Q) $(CC65) $(CCOPTS) scroll/sprite0.s -C config/nrom.cfg -o out/scroll/sprite0.nes

	$(E) "	CC	 scroll/roulette"
	$(Q) $(CC65) $(CCOPTS) scroll/roulette.s -C config/mmc3.cfg -o out/scroll/roulette.nes

.PHONY: fx
fx:
	$(E) "	CC	 fx/blink"
	$(Q) $(CC65) $(CCOPTS) fx/blink.s -C config/mmc3.cfg -o out/fx/blink.nes
