#!/usr/bin/bash
set -e
set -u
set -o pipefail

# If no rpm supplied as commandline arg, build one 
if [[ "$#" -eq 0 ]]; then
    echo "No RPM supplied for smoketest, building..."
    source "$(dirname "$0")/build-rpm.sh"
    # Choose the fc37.noarch rpm
    RPM=$(find rpm-build/ -type f -iname "${PROJECT}-$(cat "${TOPLEVEL}/VERSION")*fc37.noarch.rpm")
elif [[ "$#" -eq 1 ]]; then
    RPM="${1}"
    source "$(dirname "$0")/common.sh"
else
    echo "Usage: smoketest.sh [path-to-rpm]"
    exit 1
fi

echo "Installing RPM..."
sudo dnf install -y "${RPM}"

echo "RPM installed. (Wait 60 seconds to begin smoketest)..."
# rpmdb isn't modified right away
sleep 60

echo "Begin smoketest..."
python3 "${TOPLEVEL}/tests/test_keyring.py" && echo "Test complete" || echo "Test failed"
