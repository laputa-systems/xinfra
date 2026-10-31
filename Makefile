SHELL := /bin/sh

XSH_ROOT ?= ../xsh
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
TRIPLE ?= aarch64-apple-darwin
else ifeq ($(UNAME_M),x86_64)
TRIPLE ?= x86_64-unknown-linux-musl
else
TRIPLE ?= aarch64-unknown-linux-musl
endif

XSH ?= $(XSH_ROOT)/target/$(TRIPLE)/release/xsh
XSHT ?= $(XSH_ROOT)/target/$(TRIPLE)/release/xsht
LIMA_HOME ?= $(CURDIR)/.work/fixtures/lima
PYINFRA_VENV ?= $(CURDIR)/.work/oracle/venv
PYINFRA ?= $(PYINFRA_VENV)/bin/pyinfra

export LIMA_HOME

.PHONY: check test fixtures verify down oracle differential integration

check:
	$(XSHT) check

test:
	$(XSHT) test

fixtures:
	$(XSH) dev/fixtures.xsh up

verify:
	$(XSH) dev/fixtures.xsh verify

down:
	$(XSH) dev/fixtures.xsh down

oracle:
	@test -x $(PYINFRA) || { uv venv --python 3.13 $(PYINFRA_VENV) && uv pip install --python $(PYINFRA_VENV)/bin/python -r dev/oracle/requirements.txt; }

differential: oracle
	XINFRA_PYINFRA=$(PYINFRA) $(XSH) dev/fixtures.xsh exec --cwd $(CURDIR) -- $(XSH) dev/differential.xsh

integration:
	$(XSH) dev/fixtures.xsh exec --cwd $(CURDIR) -- $(XSH) dev/integration.xsh --case all
