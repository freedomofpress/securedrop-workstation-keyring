#!/usr/bin/bash
# Helper script for fully reproducible RPMs
set -e
set -u
set -o pipefail

source "$(dirname "$0")/common.sh"

# Default to prod (rpm_spec directory) but
# allow override for test RPM purposes
SPECFILE_DIR=${SPECFILE_DIR:-rpm_spec}

# %_projdir is a custom macro that lets us
# refer to static files inside the project directory
rpmbuild \
    --quiet \
    --define "_projdir ${PWD}" \
    --define "_topdir ${PWD}/rpm-build" \
    -bb --clean "${SPECFILE_DIR}/${PROJECT}.spec"

printf '\nBuild complete! RPMs and their checksums are:\n\n'
find rpm-build/ -type f -iname "*.rpm" -print0 | sort -zV | xargs -0 sha256sum
