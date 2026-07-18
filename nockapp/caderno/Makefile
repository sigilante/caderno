## caderno-nockapp
##
## The UI build and the kernel build are coupled: Vite emits hashed asset
## filenames, and index.html is baked into the kernel with the /* rune, so
## a UI change means re-copying index.html and re-running hoonc. Forgetting
## that step leaves the kernel serving a page that references bundles which
## no longer exist. This encodes the dependency so make handles it.

UI_DIR      := ../ui
WEB_DIR     := $(abspath $(UI_DIR)/dist)
SITE_INDEX  := hoon/app/site/index.html
KERNEL      := out.jam
BIN         := target/release/caderno
STATE_DIR   := .data.caderno

HOON_SRCS   := $(shell find hoon -name '*.hoon' -not -path 'hoon/packages/*' 2>/dev/null)
UI_SRCS     := $(shell find $(UI_DIR)/src -type f 2>/dev/null) \
               $(wildcard $(UI_DIR)/package.json $(UI_DIR)/index.html $(UI_DIR)/vite.config.*)
RUST_SRCS   := $(shell find src -type f -name '*.rs' 2>/dev/null) Cargo.toml

CELL_TIMEOUT ?= 15

## No PORT knob on purpose: at the nockchain rev pinned in Cargo.toml the
## http driver hardcodes 127.0.0.1:8080 (drivers/http/http.rs) and reads no
## HTTP_PORT. Later revisions of that driver do honour one, so check before
## adding it back. To serve elsewhere, put a reverse proxy in front.

.DEFAULT_GOAL := build

.PHONY: build
build: $(KERNEL) $(BIN)   ## build everything (default)

.PHONY: deps
deps:                     ## install hoon packages (urbit/zuse, urbit/lull)
	cd .. && nockup package install

## A fresh checkout has no node_modules, and npm run build then fails with
## a bare exit 127. Install on demand, keyed on package.json.
$(UI_DIR)/node_modules: $(UI_DIR)/package.json
	cd $(UI_DIR) && npm install
	@touch $@

## The React app. Vite must be configured with base: '/static/', since the
## NockApp http driver mounts WEB_DIR at a hardcoded /static.
$(UI_DIR)/dist/index.html: $(UI_SRCS) | $(UI_DIR)/node_modules
	cd $(UI_DIR) && npm run build

.PHONY: ui
ui: $(UI_DIR)/dist/index.html   ## build the frontend

## Only index.html is baked into the kernel. The JS/CSS bundles are served
## from WEB_DIR by ServeDir -- never from Hoon, because the driver's
## response path panics on any body containing a 0x00 byte.
$(SITE_INDEX): $(UI_DIR)/dist/index.html
	@mkdir -p $(dir $@)
	cp $< $@

## hoonc has been observed printing a success banner on a failed build, so
## do not trust the banner: remove the jam first and require it to reappear.
$(KERNEL): $(HOON_SRCS) $(SITE_INDEX)
	@command rm -f $(KERNEL)
	hoonc hoon/app/app.hoon hoon
	@test -f $(KERNEL) || { echo "hoonc did not produce $(KERNEL)"; exit 1; }

.PHONY: kernel
kernel: $(KERNEL)         ## compile the hoon kernel

$(BIN): $(RUST_SRCS)
	cargo build --release

.PHONY: bin
bin: $(BIN)               ## build the rust binary

.PHONY: run
run: build                ## build and serve on 127.0.0.1:8080
	WEB_DIR=$(WEB_DIR) CADERNO_CELL_TIMEOUT=$(CELL_TIMEOUT) ./$(BIN)

.PHONY: reset
reset:                    ## discard all notebooks and start fresh
	command rm -rf $(STATE_DIR)

.PHONY: clean
clean:                    ## remove build outputs (keeps notebook state)
	command rm -f $(KERNEL) $(SITE_INDEX)
	command rm -rf $(UI_DIR)/dist
	cargo clean

.PHONY: help
help:                     ## list targets
	@grep -hE '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN{FS=":.*?## "};{printf "  \033[36m%-8s\033[0m %s\n",$$1,$$2}'
