CC65     ?= cl65
CCOPTS   ?= --verbose --target nes

.PHONY: all
all: clean deps build

.PHONY: clean
clean:
	@rm -rf out
	@mkdir -p out/basics

.PHONY: deps
deps:
	@which $(CC65) >/dev/null 2>/dev/null || (echo "ERROR: $(CC65) not found." && false)

.PHONY: build
build: basics space

.PHONY: basics
basics:
	$(CC65) $(CCOPTS) basics/sprite.s -o out/basics/sprite.nes
	$(CC65) $(CCOPTS) basics/input.s -o out/basics/input.nes
	$(CC65) $(CCOPTS) basics/persist.s -o out/basics/persist.nes

.PHONY: space
space:
	@cd space && CC65=$(CC65) CCOPTS="$(CCOPTS)" $(MAKE)
	@mv space/space.nes out/
