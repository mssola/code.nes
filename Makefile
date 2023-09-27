CC65     ?= cl65
CCOPTS   ?= --verbose --target nes

##
# General targets.

.PHONY: all
all: clean deps build

.PHONY: clean
clean:
	@rm -rf out
	@mkdir out

.PHONY: deps
deps:
	@which $(CC65) >/dev/null 2>/dev/null || (echo "ERROR: $(CC65) not found." && false)

.PHONY: build
build: out/input.nes out/sprite.nes

out/%.nes: examples/%.s
	$(CC65) $(CCOPTS) $< -o $@
