DEFAULT_GOAL: help
# If we're on anything but Fedora 37, execute some commands in a container
# Note: if your development environment is Fedora 37 based, you may want to
# manually prepend ./scripts/container.sh to commands you want to execute
CONTAINER := $(if $(shell grep "Thirty Seven" /etc/fedora-release),,./scripts/container.sh)

HOST=$(shell hostname)

.PHONY: build-rpm
build-rpm: ## Build RPM package
	USE_BUILD_CONTAINER=true $(CONTAINER) ./scripts/build-rpm.sh

# FIXME: the time variations have been temporarily removed from reprotest
# Suspecting upstream issues in rpm land is causing issues with 1 file\'s modification time not being clamped correctly only in a reprotest environment
.PHONY: reprotest
reprotest: ## Check RPM package reproducibility
	TERM=xterm-256color $(CONTAINER) bash -c "sudo ln -s $$PWD/scripts/fake-setarch.py /usr/local/bin/setarch && sudo reprotest 'make build-rpm' 'rpm-build/RPMS/noarch/*.rpm' --variations '+all,+kernel,-time,-fileordering,-domain_host'"

.PHONY: build-deps
build-deps: ## Install package dependencies to build RPMs
# Note: build dependencies are specified in the spec file, not here
	dnf install -y \
		git file rpmdevtools dnf-plugins-core
	dnf builddep -y rpm-build/SPECS/securedrop-workstation-keyring.spec

.PHONY: test-deps
test-deps: build-deps ## Install package dependencies for running tests
	dnf install -y \
		python3-pip rpmlint which libfaketime ShellCheck \
		hostname
	dnf --setopt=install_weak_deps=False -y install reprotest

.PHONY: lint
lint: rpmlint shellcheck ## Runs linter (rpmlint, shellcheck)

.PHONY: rpmlint
rpmlint: ## Runs rpmlint on the spec file
	$(CONTAINER) rpmlint rpm-build/SPECS/*.spec

.PHONY: shellcheck
shellcheck: ## Runs shellcheck on all shell scripts
	./scripts/shellcheck.sh

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
