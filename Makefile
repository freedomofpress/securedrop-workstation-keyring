DEFAULT_GOAL: help

# To build from a different branch, use the provided `dev` or `staging`
# make targets, or `make build-rpm BRANCH=yourbranch`
BRANCH ?= "main"

# On CI, manually install OS dependencies
CI_SKIP_PREREQS ?= 0

# The executor can be docker or podman, or the Qubes Fedora dispvm executor.
BUILD_CONTAINER ?= $(notdir $(shell command -v docker 2>/dev/null || command -v podman 2>/dev/null))
EXECUTOR ?= "docker"
EXECUTOROPTS ?= "image=qubes-builder-fedora:latest"

# On Qubes, export BUILD_OS="qubes" to use the Fedora dispvm executor,
# or leave unset to use docker/podman.
BUILD_OS ?= $(shell . /etc/os-release && echo $${ID_LIKE:-$$ID})
ifeq ($(BUILD_OS),qubes)
	BUILD_CONTAINER = ""
	EXECUTOR = "qubes"
	EXECUTOROPTS = "dispvm=qubes-builder-dvm"
endif

.PHONY: builder-system-deps
builder-system-deps: ## qubes-builderv2 OS dependencies
ifeq ($(BUILD_OS),debian)
	@echo "Installing Debian dependencies..."
	@xargs -r -a ../qubes-builderv2/dependencies-debian.txt sudo apt-get install -y
else ifeq ($(BUILD_OS),fedora)
	@echo "Installing Fedora dependencies..."
	@xargs -r -a ../qubes-builderv2/dependencies-fedora.txt sudo dnf install -y
else ifeq ($(BUILD_OS),qubes)
	@echo "Install Qubes (Fedora executor) dependencies manually in template"
else
	@echo "Unknown $(BUILD_OS), use manual install of qubes-builderv2 dependencies then retry"
endif

.PHONY: prereqs
prereqs: ## Docker/podman installed or BUILD_OS=qubes
	@if ! command -v docker > /dev/null && ! command -v podman > /dev/null && "${BUILD_OS}" != "qubes"; then \
		echo "Install Docker or Podman, or set BUILD_OS=qubes to use Qubes-Fedora executor."; \
		exit 1; \
	fi

.PHONY: qubes-builder
qubes-builder: prereqs ## qubes-builderv2 sibling repo and container
	@(cd ../ && test -e qubes-builderv2 || git clone https://github.com/QubesOS/qubes-builderv2)
ifeq ($(CI_SKIP_PREREQS),0)
	@echo "Ensure system dependencies installed..."
	@$(MAKE) builder-system-deps
endif
	@if [ "${BUILD_OS}" != "qubes" ]; then \
	    echo "Generate build image..." && \
		../qubes-builderv2/tools/generate-container-image.sh $(BUILD_CONTAINER);\
	fi
	@echo "Container image ready"

.PHONY: prepare
prepare: ## Configure plugins, verify tag
	@if [ ! -e ../qubes-builderv2 ]; then \
		echo "Error: Run \`make qubes-builder\` or install qubes-builderv2 in a sibling directory and configure its dependencies."; \
		exit 1; \
	fi
	@wget -q https://keys.qubes-os.org/keys/qubes-developers-keys.asc
	@gpg --homedir ../qubes-builderv2/.gnupg --import --quiet qubes-developers-keys.asc
	@echo "Verify qubes-builderv2 tag"
	@cd ../qubes-builderv2 && GNUPGHOME=.gnupg git tag -v `git describe` || (echo "Failed to verify tag" && exit 1)
	@cp sd-qubes-builder/*.asc ../qubes-builderv2/qubesbuilder/plugins/fetch/keys/
	@rm qubes-developers-keys.asc*
	@rm -r ../qubes-builderv2/.gnupg ||:
	@echo "qubes-builderv2 repository configured"

# Reprotest requires the qubes-builder clone step to be included
.PHONY: build-rpm
build-rpm: $(if $(REPROTEST),qubes-builder) prepare ## Build rpm (default: prod)
	@BRANCH=$(BRANCH) EXECUTOR=$(EXECUTOR) EXECUTOROPTS=$(EXECUTOROPTS) sd-qubes-builder/build-rpm.sh

.PHONY: build-rpm-dev
build-rpm-dev: ## Build dev rpm (test key, yum-test fedora-nightly repo)
	$(MAKE) build-rpm BRANCH=dev

.PHONY: build-rpm-staging
build-rpm-staging: ## Build staging rpm (test key, yum-test fedora repo)
	$(MAKE) build-rpm BRANCH=staging

.PHONY: reprotest
reprotest: ## Test reproducibility
	@which reprotest > /dev/null || (echo "Install reprotest" && exit 1)
	@test -e build/*.rpm || (echo "Run \`make build-rpm\` first" && exit 1)
	@sudo reprotest 'REPROTEST=1 make build-rpm BRANCH="${BRANCH}" EXECUTOR="${EXECUTOR}" EXECUTOROPTS="${EXECUTOROPTS}"' 'build/*.rpm' --variations '+all,+kernel,-time,-fileordering,-domain_host'

## The below commands should run in CI or a Fedora environment
# FIXME: the time variations have been temporarily removed from reprotest
# Suspecting upstream issues in rpm land is causing issues with 1 file\'s modification time not being clamped correctly only in a reprotest environment
.PHONY: ci-deps
ci-deps: ## Install package dependencies for running tests
	dnf install -y \
		git make sudo file rpmdevtools dnf-plugins-core rpmlint which libfaketime
	dnf --setopt=install_weak_deps=False -y install reprotest
	dnf builddep -y --spec rpm_spec/securedrop-workstation-keyring.spec

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
