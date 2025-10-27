SHELL := /bin/bash
PATH := $(PATH):$(HOME)/flutter/bin
.PHONY: doctor analyze fix format test check

doctor:  ; flutter doctor -v
analyze: ; flutter analyze lib test
fix:     ; dart fix --apply || true
format:  ; dart format lib test
test:    ; flutter test -r expanded
check:   ; $(MAKE) doctor analyze test
