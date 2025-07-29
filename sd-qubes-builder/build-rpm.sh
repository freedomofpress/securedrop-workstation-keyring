#!/usr/bin/bash
set -e
set -u
set -o pipefail

# Build RPM using qubes-builderv2 repo (cloned as a sibling
# directory).

# Variables come from Makefile
: "${BRANCH:?BRANCH missing; use make build-rpm}"
: "${EXECUTOR:?EXECUTOR missing; use make build-rpm}"
: "${EXECUTOROPTS:?EXECUTOROPTS missing; use make build-rpm}"

echo "Copy sd-builder.yml into qubes-builderv2 repo"
cp sd-qubes-builder/sd-builder.yml.conf ../qubes-builderv2/sd-builder.yml

echo "Build from ${BRANCH}"
sed -i "s/{{branch}}/${BRANCH}/g" "../qubes-builderv2/sd-builder.yml"

echo "Remove old build artifacts if present"
rm -rf build || true

# qubes-builderv2 repo clones and caches a copy of the target
# git repository. If building from branches that have had
# force-pushes, or if switching branches, stale git artifacts
# or a requirement for a rebase can break the qubes-builder
# automation. 
echo "Remove SDW-keyring sources from qubes-builder"
rm -rf ../qubes-builderv2/artifacts/sources/securedrop-workstation-keyring || true
rm -rf ../qubes-builderv2/artifacts/repository/*/securedrop-workstation-keyring* || true

echo "Begin build..."
(
  cd ../qubes-builderv2
  ./qb --builder-conf sd-builder.yml \
      --option executor:type="${EXECUTOR}" \
      --option executor:options:"${EXECUTOROPTS}" \
      -c securedrop-workstation-keyring package fetch prep build
)

echo "Copy RPM and buildinfo to local build directory"
mkdir -p build
find ../qubes-builderv2/artifacts/components/securedrop-workstation-keyring \
    -type f -iname "securedrop-workstation-keyring*.noarch.rpm" \
    -exec cp -t build/ {} +
find ../qubes-builderv2/artifacts/components/securedrop-workstation-keyring \
    -type f -iname "securedrop-workstation-keyring*.buildinfo" \
    -exec cp -t build/ {} +

echo "Build complete, RPM and checksum:"
sha256sum build/*.rpm

echo "Note: build directory is regenerated on every build!"
echo "Save this .rpm locally if you want to preserve it and intend to run the build again."
echo "To test reproducibility, run \`make reprotest\`."