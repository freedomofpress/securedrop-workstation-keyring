DEFAULT_GOAL: help

# To build from a different branch, `make build-rpm BRANCH=yourbranch` (builder.conf automatically modified)
BRANCH = "main"

# The executor can be docker or podman. Instructions
# tested with docker, manual overrides possible.
CONTAINER = $(shell (which docker || which podman))

# On Qubes, manually set BUILD_OS="qubes"
BUILD_OS = $(if $(shell test -f /etc/fedora-release),"fedora","debian")
ifeq ($(BUILD_OS),"debian")
	INSTALL_CMD="sudo apt install -y ../qubes-builderv2/dependencies-debian.txt"
else ifeq ("$(BUILD_OS)","fedora")
	INSTALL_CMD = "sudo dnf install -y ../qubes-builderv2/dependencies-fedora.txt"
else ifeq ("$(BUILD_OS)","qubes")
	INSTALL_CMD = "sudo dnf install -y ../qubes-builderv2/dependencies-fedora-qubes-executor.txt"
	CONTAINER = ""
endif

.PHONY: prereqs
prereqs:
	@(((which podman > /dev/null || which docker > /dev/null) && exit 0) && [ ${BUILD_OS} != "qubes" ]) || (echo "Install an executor or use Qubes" && exit 1)

.PHONY: qubes-builder
qubes-builder: prereqs
	@(cd ../ && test -e qubes-builderv2 || git clone https://github.com/QubesOS/qubes-builderv2)
	@if [ -z ${CONTAINER} ]; then \
		echo "Generate build image..." && \
		../qubes-builderv2/tools/generate-container-image.sh $(CONTAINER);\
	fi
	@echo "Container image ready"

.PHONY: prepare
prepare: qubes-builder
	@$(test -e ../qubes-builderv2 || echo "Please install qubes-builderv2 in a sibling directory and configure its dependencies")
	@cp sd-qubes-builder/*.asc ../qubes-builderv2/qubesbuilder/plugins/fetch/keys/
	@echo "qubes-builderv2 repo installed"

# Default to main, custom branch via "make build-rpm BRANCH=yourbranch".
# Note that Qubes-Contrib will not use this builder.yml file, so we avoid
# any customizations other than target branch and our own signing keys
.PHONY: build-rpm
build-rpm: prepare ## Build RPM package
	@echo "Copy builder.yml into qubes-builderv2"
	@cp sd-qubes-builder/builder.yml.conf ../qubes-builderv2/builder.yml
	@echo "Will build from ${BRANCH}"
	@sed -i "s/{{branch}}/${BRANCH}/g" "../qubes-builderv2/builder.yml"
	@echo "Clean qubes-builder before building"
	@cd ../qubes-builderv2 && ((test -e artifacts && ./qb clean all)||:)
	@echo "Begin build..."
	@cd ../qubes-builderv2 && ./qb -c securedrop-workstation-keyring package fetch prep build
	@echo "Build complete, RPM(s) and checksum(s):"
	@find ../qubes-builderv2/artifacts/components/securedrop-workstation-keyring -type f -iname "securedrop-workstation-keyring*.noarch.rpm" -print0 | sort -zV | xargs -0 sha256sum

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

## TODO: the below commands will run in CI (Fedora container)
# FIXME: the time variations have been temporarily removed from reprotest
# Suspecting upstream issues in rpm land is causing issues with 1 file\'s modification time not being clamped correctly only in a reprotest environment
.PHONY: test-deps
test-deps: build-deps ## Install package dependencies for running tests
	dnf install -y \
		python3-pip rpmlint which libfaketime
	dnf --setopt=install_weak_deps=False -y install reprotest

.PHONY: build-deps
build-deps: ## Install package dependencies to build RPMs
# Note: build dependencies are specified in the spec file, not here
	dnf install -y \
		git file rpmdevtools dnf-plugins-core
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
