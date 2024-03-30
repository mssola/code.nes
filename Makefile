CC65   ?= cl65
CA65   ?= ca65
LD65   ?= ld65
CCOPTS ?= --verbose --target nes

.PHONY: all
all: clean deps build

.PHONY: clean
clean:
	@rm -rf out
	@find . -type f -name "*.o" -delete
	@find . -type f -name "*.nes" -delete
	@mkdir -p out/basics out/scroll

.PHONY: deps
deps:
	@which $(CC65) >/dev/null 2>/dev/null || (echo "ERROR: $(CC65) not found." && false)

.PHONY: build
build: basics space scroll

.PHONY: basics
basics:
	$(CC65) $(CCOPTS) basics/sprite.s -o out/basics/sprite.nes
	$(CC65) $(CCOPTS) basics/input.s -o out/basics/input.nes
	$(CC65) $(CCOPTS) basics/persist.s -o out/basics/persist.nes

	$(CA65) $(CCOPTS) basics/unrom.s -o basics/unrom.o
	$(LD65) basics/unrom.o -C config/unrom.cfg -o out/basics/unrom.nes
	@rm -f basics/unrom.o

	$(CA65) $(CCOPTS) basics/chr-ram.s -o basics/chr-ram.o
	$(LD65) basics/chr-ram.o -C config/unrom.cfg -o out/basics/chr-ram.nes
	@rm -f basics/chr-ram.o

.PHONY: space
space:
	@cd space && CC65=$(CC65) CCOPTS="$(CCOPTS)" $(MAKE)
	@mv space/space.nes out/

.PHONY: scroll
scroll:
	$(CC65) $(CCOPTS) scroll/level.s -o out/scroll/level.nes
