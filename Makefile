# Convenience targets for local ARM64 Linux bring-up.
# Meson remains the source of truth for actual builds; this Makefile captures
# the repeatable build/test flows used during runtime coverage work.

MESON ?= meson
NINJA ?= ninja
CC ?= clang

RELEASE_BUILD_DIR ?= build-arm64-linux
DEBUG_BUILD_DIR ?= build-arm64-linux-debug
ROOTFS_DIR ?= $(CURDIR)/alpine-arm64-fakefs
REPORT_DIR ?= /workspace/tmp
TIMEOUT_S ?= 120
INSTALL_TIMEOUT_S ?= 1200

.PHONY: help
help:
	@echo "iSH ARM64 local targets:"
	@echo "  make build-arm64-linux              Build release Linux host binary"
	@echo "  make build-arm64-linux-debug        Build debug Linux host binary"
	@echo "  make build-arm64-linux-all          Build release + debug"
	@echo "  make test-arm64-runtime-coverage    Run staged Go/Bun/Node/npm coverage"
	@echo "  make test-arm64-runtime-coverage-debug"
	@echo "                                      Run coverage against debug binary"
	@echo ""
	@echo "Knobs: ROOTFS_DIR=$(ROOTFS_DIR) REPORT_DIR=$(REPORT_DIR) TIMEOUT_S=$(TIMEOUT_S) INSTALL_TIMEOUT_S=$(INSTALL_TIMEOUT_S)"

.PHONY: build-arm64-linux
build-arm64-linux:
	@test -d "$(RELEASE_BUILD_DIR)" || CC="$(CC)" $(MESON) setup "$(RELEASE_BUILD_DIR)" -Dguest_arch=arm64 --buildtype=release
	$(NINJA) -C "$(RELEASE_BUILD_DIR)"

.PHONY: build-arm64-linux-debug
build-arm64-linux-debug:
	@test -d "$(DEBUG_BUILD_DIR)" || CC="$(CC)" $(MESON) setup "$(DEBUG_BUILD_DIR)" -Dguest_arch=arm64 --buildtype=debug
	$(NINJA) -C "$(DEBUG_BUILD_DIR)"

.PHONY: build-arm64-linux-all
build-arm64-linux-all: build-arm64-linux build-arm64-linux-debug

.PHONY: test-arm64-runtime-coverage
test-arm64-runtime-coverage: build-arm64-linux
	ISH_BIN="$(CURDIR)/$(RELEASE_BUILD_DIR)/ish" \
	ROOTFS="$(ROOTFS_DIR)" \
	REPORT_DIR="$(REPORT_DIR)" \
	TIMEOUT_S="$(TIMEOUT_S)" \
	INSTALL_TIMEOUT_S="$(INSTALL_TIMEOUT_S)" \
	./tests/arm64/runtime-coverage.sh

.PHONY: test-arm64-runtime-coverage-debug
test-arm64-runtime-coverage-debug: build-arm64-linux-debug
	ISH_BIN="$(CURDIR)/$(DEBUG_BUILD_DIR)/ish" \
	ROOTFS="$(ROOTFS_DIR)" \
	REPORT_DIR="$(REPORT_DIR)" \
	TIMEOUT_S="$(TIMEOUT_S)" \
	INSTALL_TIMEOUT_S="$(INSTALL_TIMEOUT_S)" \
	./tests/arm64/runtime-coverage.sh
