CC65     ?= cl65
CCOPTS   ?= --verbose --target nes

.PHONY: all
all: clean build

.PHONY: clean
clean:
	@rm -f space.nes

.PHONY: build
build: space.nes

%.nes: src/%.s
	$(CC65) $(CCOPTS) $< -o $@
