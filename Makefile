DEFAULT_GOAL: help

.PHONY: build-rpm
build-rpm: prepare ## Build RPM package
	./qb -c securedrop-workstation-keyring package fetch prep build

## TODO: the below commands will run in CI (Fedora container)
# FIXME: the time variations have been temporarily removed from reprotest
# Suspecting upstream issues in rpm land is causing issues with 1 file\'s modification time not being clamped correctly only in a reprotest environment
#.PHONY: reprotest
# reprotest: ## Check RPM package reproducibility
## TODO

.PHONY: test-deps
test-deps: build-deps ## Install package dependencies for running tests
	dnf install -y \
		python3-pip rpmlint which libfaketime ShellCheck \
		hostname
	dnf --setopt=install_weak_deps=False -y install reprotest

.PHONY: rpmlint
rpmlint: ## Runs rpmlint on the spec file
	# todo
	rpmlint rpm_spec/*.spec
	rpmlint test_rpm_spec/*.spec

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
