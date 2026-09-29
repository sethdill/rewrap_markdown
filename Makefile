# Copyright 2026 Seth Dillingham
# SPDX-License-Identifier: Apache-2.0

PRODUCT := rewrap-markdown
VERSION := $(shell cat VERSION)
FILTER_NAME ?= Rewrap Markdown
FILTER_WIDTH ?= 70
RELEASE_BINARY := $(abspath .build/release/$(PRODUCT))
INSTALL_BIN_DIR ?= $(HOME)/.local/bin
INSTALLED_BINARY := $(INSTALL_BIN_DIR)/$(PRODUCT)
DIST_DIR := dist
ARCH := $(shell uname -m)
PKG_ARCHS ?= $(shell (lipo -archs "$(RELEASE_BINARY)" 2>/dev/null || uname -m) | tr ' ' ',')
DIST_BINARY := $(DIST_DIR)/$(PRODUCT)-$(VERSION)-macos-$(ARCH)
DIST_PYTHON := $(DIST_DIR)/$(PRODUCT)-$(VERSION).py
DIST_BBEDIT_SWIFT := $(DIST_DIR)/Rewrap Markdown (Swift)
DIST_BBEDIT_HARD_WRAP := $(DIST_DIR)/Markdown-Hard-Wrap-Menu-Action.applescript
PKG_IDENTIFIER ?= com.sethdillingham.rewrap-markdown
PKG_BUILD_DIR := .build/installer
PKG_COMPONENTS_DIR := $(PKG_BUILD_DIR)/components
PKG_RESOURCES_DIR := $(PKG_BUILD_DIR)/resources
PKG_ROOTS_DIR := $(PKG_BUILD_DIR)/roots
PKG_CORE_ROOT := $(PKG_ROOTS_DIR)/core
PKG_HARD_WRAP_ROOT := $(PKG_ROOTS_DIR)/hard-wrap
PKG_TEXT_FILTER_ROOT := $(PKG_ROOTS_DIR)/text-filter
PKG_COMMAND_LINE_ROOT := $(PKG_ROOTS_DIR)/command-line
PKG_HARD_WRAP_SCRIPTS := $(PKG_BUILD_DIR)/scripts/hard-wrap
PKG_TEXT_FILTER_SCRIPTS := $(PKG_BUILD_DIR)/scripts/text-filter
PKG_SHARED_DIR := Library/Application Support/Rewrap Markdown
PKG_TEXT_FILTER_PACKAGE := $(PKG_TEXT_FILTER_ROOT)/$(PKG_SHARED_DIR)/Components/Text Filter/Rewrap Markdown.bbpackage-template
PKG_TEXT_FILTER_COMPONENTS := $(PKG_BUILD_DIR)/text-filter-components.plist
PKG_DISTRIBUTION := $(PKG_BUILD_DIR)/Distribution.xml
DIST_INSTALLER := $(DIST_DIR)/$(PRODUCT)-$(VERSION)-unsigned.pkg
HARD_WRAP_SCRIPT_NAME := Text•Hard Wrap….scpt
HARD_WRAP_IMMEDIATE_SCRIPT_NAME := Text•Hard Wrap.scpt
BBEDIT_FILTERS_DIR ?= $(shell osascript \
	-e 'tell application "BBEdit" to set allFolders to support folders' \
	-e 'set targetFolder to (|text filters| of allFolders)' \
	-e 'return POSIX path of targetFolder' 2>/dev/null)
BBEDIT_MENU_SCRIPTS_DIR ?= $(shell osascript \
	-e 'tell application "BBEdit" to set allFolders to support folders' \
	-e 'set targetFolder to (|menu scripts| of allFolders)' \
	-e 'return POSIX path of targetFolder' 2>/dev/null)
INSTALLED_FILTER = $(BBEDIT_FILTERS_DIR)/$(FILTER_NAME)
INSTALLED_HARD_WRAP = $(patsubst %/,%,$(BBEDIT_MENU_SCRIPTS_DIR))/$(HARD_WRAP_SCRIPT_NAME)
INSTALLED_HARD_WRAP_IMMEDIATE = $(patsubst %/,%,$(BBEDIT_MENU_SCRIPTS_DIR))/$(HARD_WRAP_IMMEDIATE_SCRIPT_NAME)

.PHONY: build release test test-executable dist pkg-unsigned package-unsigned install-cli install install-hard-wrap install-all uninstall-cli uninstall uninstall-hard-wrap uninstall-all clean print-bbedit-filters-dir

build:
	swift build

release:
	swift build -c release

test:
	swift test

test-executable: release
	REWRAP_MARKDOWN_EXECUTABLE="$(RELEASE_BINARY)" swift test

dist: test-executable
	mkdir -p "$(DIST_DIR)"
	cp "$(RELEASE_BINARY)" "$(DIST_BINARY)"
	cp Reference/rewrap_markdown.py "$(DIST_PYTHON)"
	cp "Distribution/BBEdit/Rewrap Markdown (Swift)" "$(DIST_BBEDIT_SWIFT)"
	cp "Distribution/BBEdit/Markdown Hard Wrap Menu Action.applescript" "$(DIST_BBEDIT_HARD_WRAP)"
	chmod +x "$(DIST_BINARY)" "$(DIST_PYTHON)" "$(DIST_BBEDIT_SWIFT)"
	@echo "Created release artifacts in $(DIST_DIR):"
	@printf '  %s\n' "$(DIST_BINARY)" "$(DIST_PYTHON)" "$(DIST_BBEDIT_SWIFT)" "$(DIST_BBEDIT_HARD_WRAP)"

pkg-unsigned: test-executable package-unsigned

package-unsigned:
	rm -rf "$(PKG_BUILD_DIR)"
	mkdir -p "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)"
	mkdir -p "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/Components/Installer"
	mkdir -p "$(PKG_HARD_WRAP_ROOT)/$(PKG_SHARED_DIR)/Components/Hard Wrap"
	mkdir -p "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Text Filters"
	mkdir -p "$(PKG_COMMAND_LINE_ROOT)/usr/local/bin"
	mkdir -p "$(PKG_COMMAND_LINE_ROOT)/$(PKG_SHARED_DIR)/Components/Command Line"
	mkdir -p "$(PKG_HARD_WRAP_SCRIPTS)" "$(PKG_TEXT_FILTER_SCRIPTS)" "$(PKG_COMPONENTS_DIR)" "$(PKG_RESOURCES_DIR)"
	cp "$(RELEASE_BINARY)" "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/rewrap-markdown"
	chmod +x "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/rewrap-markdown"
	cp LICENSE NOTICE "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/"
	awk -f Packaging/pkg/unwrap-license.awk LICENSE > "$(PKG_RESOURCES_DIR)/LICENSE.txt"
	cp "Packaging/pkg/uninstall-rewrap-markdown" "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/uninstall-rewrap-markdown"
	cp "Packaging/pkg/resolve-user.sh" "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/Components/Installer/resolve-user.sh"
	chmod +x "$(PKG_CORE_ROOT)/$(PKG_SHARED_DIR)/uninstall-rewrap-markdown"
	osacompile -o "$(PKG_HARD_WRAP_ROOT)/$(PKG_SHARED_DIR)/Components/Hard Wrap/$(HARD_WRAP_SCRIPT_NAME)" "Distribution/BBEdit/Markdown Hard Wrap Menu Action.applescript"
	cp "Distribution/BBEdit/Rewrap Markdown (Swift)" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Text Filters/Rewrap Markdown"
	chmod +x "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Text Filters/Rewrap Markdown"
	plutil -create xml1 "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert DisplayName -string "Rewrap Markdown" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert PackageIdentifier -string "$(PKG_IDENTIFIER).bbedit" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert PackageVersion -string "$(VERSION)" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert PackageVersionDisplayString -string "$(VERSION)" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert CFBundleIdentifier -string "$(PKG_IDENTIFIER).bbedit" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert CFBundleVersion -string "$(VERSION)" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	plutil -insert CFBundleShortVersionString -string "$(VERSION)" "$(PKG_TEXT_FILTER_PACKAGE)/Contents/Info.plist"
	ln -s "/Library/Application Support/Rewrap Markdown/rewrap-markdown" "$(PKG_COMMAND_LINE_ROOT)/usr/local/bin/rewrap-markdown"
	touch "$(PKG_COMMAND_LINE_ROOT)/$(PKG_SHARED_DIR)/Components/Command Line/installed"
	cp "Packaging/pkg/resolve-user.sh" "$(PKG_HARD_WRAP_SCRIPTS)/resolve-user.sh"
	cp "Packaging/pkg/postinstall-hard-wrap" "$(PKG_HARD_WRAP_SCRIPTS)/postinstall"
	cp "Packaging/pkg/resolve-user.sh" "$(PKG_TEXT_FILTER_SCRIPTS)/resolve-user.sh"
	cp "Packaging/pkg/postinstall-text-filter" "$(PKG_TEXT_FILTER_SCRIPTS)/postinstall"
	chmod +x "$(PKG_HARD_WRAP_SCRIPTS)/postinstall" "$(PKG_TEXT_FILTER_SCRIPTS)/postinstall"
	pkgbuild --root "$(PKG_CORE_ROOT)" --install-location / --identifier "$(PKG_IDENTIFIER).core" --version "$(VERSION)" "$(PKG_COMPONENTS_DIR)/core.pkg"
	pkgbuild --root "$(PKG_HARD_WRAP_ROOT)" --scripts "$(PKG_HARD_WRAP_SCRIPTS)" --install-location / --identifier "$(PKG_IDENTIFIER).hard-wrap" --version "$(VERSION)" "$(PKG_COMPONENTS_DIR)/hard-wrap.pkg"
	pkgbuild --analyze --root "$(PKG_TEXT_FILTER_ROOT)" "$(PKG_TEXT_FILTER_COMPONENTS)"
	plutil -insert 0.BundleIsRelocatable -bool false "$(PKG_TEXT_FILTER_COMPONENTS)"
	pkgbuild --root "$(PKG_TEXT_FILTER_ROOT)" --component-plist "$(PKG_TEXT_FILTER_COMPONENTS)" --scripts "$(PKG_TEXT_FILTER_SCRIPTS)" --install-location / --identifier "$(PKG_IDENTIFIER).text-filter" --version "$(VERSION)" "$(PKG_COMPONENTS_DIR)/text-filter.pkg"
	pkgbuild --root "$(PKG_COMMAND_LINE_ROOT)" --install-location / --identifier "$(PKG_IDENTIFIER).command-line" --version "$(VERSION)" "$(PKG_COMPONENTS_DIR)/command-line.pkg"
	sed -e 's/@VERSION@/$(VERSION)/g' -e 's/@ARCH@/$(PKG_ARCHS)/g' "Packaging/pkg/Distribution.xml" > "$(PKG_DISTRIBUTION)"
	mkdir -p "$(DIST_DIR)"
	rm -f "$(DIST_INSTALLER)"
	productbuild --distribution "$(PKG_DISTRIBUTION)" --resources "$(PKG_RESOURCES_DIR)" --package-path "$(PKG_COMPONENTS_DIR)" "$(DIST_INSTALLER)"
	@echo "Created unsigned installer: $(DIST_INSTALLER)"

install-cli: release
	mkdir -p "$(INSTALL_BIN_DIR)"
	cp "$(RELEASE_BINARY)" "$(INSTALLED_BINARY)"
	chmod +x "$(INSTALLED_BINARY)"
	@echo "Installed rewrap-markdown executable: $(INSTALLED_BINARY)"

install: install-cli
	@if [ -z "$(BBEDIT_FILTERS_DIR)" ]; then \
		echo "Could not determine BBEdit's Text Filters folder."; \
		echo "Set BBEDIT_FILTERS_DIR=/path/to/Text Filters and run make install again."; \
		exit 1; \
	fi
	mkdir -p "$(BBEDIT_FILTERS_DIR)"
	@{ \
		printf '%s\n' '#!/bin/sh'; \
		printf '%s\n' '# Generated by rewrap-markdown make install.'; \
		printf '%s\n' '# Edit this value to use a different BBEdit wrapping width, such as 80 or 120.'; \
		printf '%s\n' 'WRAP_WIDTH=$(FILTER_WIDTH)'; \
		printf '%s\n' 'if [ "$$#" -eq 0 ]; then'; \
		printf '%s\n' '	exec "$(INSTALLED_BINARY)" "$$WRAP_WIDTH"'; \
		printf '%s\n' 'else'; \
		printf '%s\n' '	exec "$(INSTALLED_BINARY)" "$$@"'; \
		printf '%s\n' 'fi'; \
	} > "$(INSTALLED_FILTER)"
	chmod +x "$(INSTALLED_FILTER)"
	@echo "Installed BBEdit text filter: $(INSTALLED_FILTER)"

install-hard-wrap: install-cli
	@if [ -z "$(BBEDIT_MENU_SCRIPTS_DIR)" ]; then \
		echo "Could not determine BBEdit's Menu Scripts folder."; \
		echo "Set BBEDIT_MENU_SCRIPTS_DIR=/path/to/Menu Scripts and run make install-hard-wrap again."; \
		exit 1; \
	fi
	mkdir -p "$(BBEDIT_MENU_SCRIPTS_DIR)"
	osacompile -o "$(INSTALLED_HARD_WRAP)" "Distribution/BBEdit/Markdown Hard Wrap Menu Action.applescript"
	ln -sfn "$(HARD_WRAP_SCRIPT_NAME)" "$(INSTALLED_HARD_WRAP_IMMEDIATE)"
	@echo "Installed BBEdit Hard Wrap menu actions:"
	@printf '  %s\n' "$(INSTALLED_HARD_WRAP)" "$(INSTALLED_HARD_WRAP_IMMEDIATE)"

install-all: install install-hard-wrap

uninstall-cli:
	rm -f "$(INSTALLED_BINARY)"
	@echo "Removed rewrap-markdown executable: $(INSTALLED_BINARY)"

uninstall:
	@if [ -z "$(BBEDIT_FILTERS_DIR)" ]; then \
		echo "Could not determine BBEdit's Text Filters folder."; \
		echo "Set BBEDIT_FILTERS_DIR=/path/to/Text Filters and run make uninstall again."; \
		exit 1; \
	fi
	rm -f "$(INSTALLED_FILTER)"
	@echo "Removed BBEdit text filter: $(INSTALLED_FILTER)"

uninstall-hard-wrap:
	@if [ -z "$(BBEDIT_MENU_SCRIPTS_DIR)" ]; then \
		echo "Could not determine BBEdit's Menu Scripts folder."; \
		echo "Set BBEDIT_MENU_SCRIPTS_DIR=/path/to/Menu Scripts and run make uninstall-hard-wrap again."; \
		exit 1; \
	fi
	rm -f "$(INSTALLED_HARD_WRAP)" "$(INSTALLED_HARD_WRAP_IMMEDIATE)"
	@echo "Removed BBEdit Hard Wrap menu actions."

uninstall-all: uninstall uninstall-hard-wrap uninstall-cli

clean:
	swift package clean

print-bbedit-filters-dir:
	@if [ -z "$(BBEDIT_FILTERS_DIR)" ]; then \
		echo "Could not determine BBEdit's Text Filters folder."; \
		exit 1; \
	fi
	@printf '%s\n' "$(BBEDIT_FILTERS_DIR)"
