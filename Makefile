DEFAULT_GOAL: help

# To build from a different branch, `make build-rpm BRANCH=yourbranch` (builder.conf automatically modified)
BRANCH ?= "main"

# The executor can be docker or podman. Instructions
# tested with docker, manual overrides possible.
BUILD_CONTAINER ?= $(notdir $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null))

# On CI, manually install OS dependencies
CI_SKIP_PREREQS ?= 0

# On Qubes, manually set BUILD_OS="qubes" to use the Fedora dispvm executor,
# or leave unset to use docker/podman + VM OS
BUILD_OS ?= $(shell . /etc/os-release && echo $${ID_LIKE:-$$ID})
ifeq ($(BUILD_OS),qubes)
	BUILD_CONTAINER = ""
endif

# Helper. Install qubes-builderv2 OS-specific dependencies
.PHONY: builder-system-deps
builder-system-deps:
ifeq ($(BUILD_OS),debian)
	@echo "Installing Debian dependencies..."
	@xargs -r -a ../qubes-builderv2/dependencies-debian.txt sudo apt-get install -y
else ifeq ($(BUILD_OS),fedora)
	@echo "Installing Fedora dependencies..."
	@xargs -r -a ../qubes-builderv2/dependencies-fedora.txt sudo dnf install -y
else ifeq ($(BUILD_OS),qubes)
	@echo "Installing Qubes (Fedora executor) dependencies..."
	@xargs -r -a ../qubes-builderv2/dependencies-qubes-fedora-executor.txt sudo dnf install -y
else
	@echo "Unknown $(BUILD_OS), use manual install of qubes-builderv2 dependencies then retry"
endif

# Helper: Docker/podman must be installed or BUILD_OS must be "qubes"
.PHONY: prereqs
prereqs:
	@(((which podman > /dev/null || which docker > /dev/null) && exit 0) && [ ${BUILD_OS} != "qubes" ]) || (echo "Install an executor or set BUILD_OS=qubes to use Qubes-Fedora executor" && exit 1)

# Ensure qubes-builderv2 repo exists in a sibling directory to this project,
# and container image is ready
.PHONY: qubes-builder
qubes-builder:
	@(cd ../ && test -e qubes-builderv2 || git clone https://github.com/QubesOS/qubes-builderv2)
	$(MAKE) prereqs
ifeq ($(CI_SKIP_PREREQS),0)
	@echo "Ensure system dependencies installed..."
	@$(MAKE) builder-system-deps
endif
	@if [ -z ${BUILD_CONTAINER} ]; then \
	    echo "Generate build image..." && \
		../qubes-builderv2/tools/generate-container-image.sh $(BUILD_CONTAINER);\
	fi
	@echo "Container image ready"

# Helper. Copy maintainer keys into qubes-builderv2 plugins directory
# (required for verifying signed tag and commits)
.PHONY: prepare
prepare: qubes-builder
	@$(test -e ../qubes-builderv2 || echo "Please install qubes-builderv2 in a sibling directory and configure its dependencies")
	@cp sd-qubes-builder/*.asc ../qubes-builderv2/qubesbuilder/plugins/fetch/keys/
	@echo "qubes-builderv2 repo installed"

# Default to main, custom branch via "make build-rpm BRANCH=yourbranch".
# Note that Qubes-Contrib will not use this builder.yml file, so we avoid
# any customizations other than target branch and our own signing keys.
.PHONY: build-rpm
build-rpm: prepare ## Build RPM package
	@echo "Copy builder.yml into qubes-builderv2"
	@cp sd-qubes-builder/builder.yml.conf ../qubes-builderv2/builder.yml
	@echo "Will build from ${BRANCH}"
	@sed -i "s/{{branch}}/${BRANCH}/g" "../qubes-builderv2/builder.yml"
	@echo "Remove old build artifacts if present"
	@((test -e build && rm -rf build)||:)
	@echo "Clean qubes-builder before building"
	@cd ../qubes-builderv2 && ((test -e artifacts && rm -rf artifacts)||:)
	@echo "Begin build..."
	@cd ../qubes-builderv2 && ./qb -c securedrop-workstation-keyring package fetch prep build
	@mkdir -p build
	@find ../qubes-builderv2/artifacts/components/securedrop-workstation-keyring -type f -iname "securedrop-workstation-keyring*.noarch.rpm" | xargs cp -t build/
	@echo "Build complete, RPM(s) and checksum(s):"
	@sha256sum build/*
	@echo "Note: build directory is regenerated on every build!"
	@echo "Save this .rpm locally if you want to preserve it and intend to run make build-rpm again."

# Build a dev keyring rpm (test key and yum-test f37-nightly repo)
# This provisions nightly CI builds of the securedrop-workstation-dom0-config RPM
.PHONY: build-rpm-dev
build-rpm-dev:
	$(MAKE) build-rpm BRANCH=dev

# Build a dev keyring rpm (test key and yum-test f37-nightly repo)
# This provisions nightly CI builds of the securedrop-workstation-dom0-config RPM
.PHONY: build-rpm-staging
build-rpm-staging:
	$(MAKE) build-rpm BRANCH=staging

.PHONY: reprotest
reprotest:
	@((which reprotest > /dev/null) && exit 0) || (echo "Install reprotest" && exit 1)
	@(test -e build/*.rpm || (echo "Run `make build-rpm` first" && exit 1))
	@sudo reprotest 'make build-rpm BRANCH=${BRANCH}' 'build/*.rpm' --variations '+all,+kernel,-time,-fileordering,-domain_host'

## The below commands should run in CI or a Fedora environment
# FIXME: the time variations have been temporarily removed from reprotest
# Suspecting upstream issues in rpm land is causing issues with 1 file\'s modification time not being clamped correctly only in a reprotest environment
.PHONY: ci-deps
ci-deps: ## Install package dependencies for running tests
	dnf install -y \
		git make sudo file rpmdevtools dnf-plugins-core rpmlint which libfaketime
	dnf --setopt=install_weak_deps=False -y install reprotest
	dnf builddep -y rpm_spec/securedrop-workstation-keyring.spec

.PHONY: rpmlint
rpmlint: ## Runs rpmlint on the spec file
	rpmlint rpm_spec/*.spec

# Explanation of the below shell command should it ever break.
# 1. Set the field separator to ": ##" to parse lines for make targets.
# 2. Check for second field matching, skip otherwise.
# 3. Print fields 1 and 2 with colorized output.
# 4. Sort the list of make targets alphabetically
# 5. Format columns with colon as delimiter.
.PHONY: help
help: ## Prints this message and exits
	@printf "Makefile for SecureDrop Workstation Keyring (RPM).\n"
	@printf "Subcommands:\n\n"
	@perl -F':.*##\s+' -lanE '$$F[1] and say "\033[36m$$F[0]\033[0m : $$F[1]"' $(MAKEFILE_LIST) \
		| sort \
		| column -s ':' -t
