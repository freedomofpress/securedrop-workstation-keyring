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
: "${QUBES_RELEASE:?QUBES_RELEASE missing; use make build-rpm}"
: "${FEDORA_DIST:?FEDORA_DIST missing; use make build-rpm}"

# Initialize empty signers file
touch ../qubes-builderv2/.git/allowed_signers
git -C ../qubes-builderv2/ config --local gpg.ssh.allowedSignersFile \
    ../qubes-builderv2/.git/allowed_signers

echo "Copy sd-builder.yml into qubes-builderv2 repo"
cp sd-qubes-builder/sd-builder.yml.conf ../qubes-builderv2/sd-builder.yml
sed -i "s/{{branch}}/${BRANCH}/g" "../qubes-builderv2/sd-builder.yml"

echo "Remove old build artifacts if present"
rm -rf build || true

# qubes-builderv2 repo clones and caches a copy of the target
echo "Remove SDW-keyring sources from qubes-builder"
rm -rf ../qubes-builderv2/artifacts/sources/securedrop-workstation-keyring || true
rm -rf ../qubes-builderv2/artifacts/repository/*/securedrop-workstation-keyring* || true

if [ "${BRANCH}" == "local" ]; then
    # OPTION 1: BUILDING FROM LOCAL DIRECTORY
    # Replace Qubes Builder's fetch with a symlink to this repo's directory
    REPO_ROOT=$(dirname $(dirname $(realpath $0)))
    if [ ! -d "$REPO_ROOT/.git" ]; then  # Check in case script changes location
        echo "ERROR: $REPO_ROOT not project root" >&2 && exit 1
    fi

    # Create sources directory (needed in first run)
    mkdir -p ../qubes-builderv2/artifacts/sources/

    ln -s $REPO_ROOT ../qubes-builderv2/artifacts/sources/securedrop-workstation-keyring
    SKIP_GIT_FETCH="true"
else
    # OPTION 2: BUILDING FROM BRANCH
    # If building from branches that have had force-pushes, or if
    # switching branches, stale git artifacts or a requirement for a rebase can
    # break the qubes-builder automation. Therefore, these sources are re-fetched.
    echo "Build from ${BRANCH}"
fi

echo "Begin build for Qubes Version ${QUBES_RELEASE} (${FEDORA_DIST})"
(
  cd ../qubes-builderv2
  ./qb --builder-conf sd-builder.yml \
      --option use-qubes-repo:version=${QUBES_RELEASE} \
      --option qubes-release=r${QUBES_RELEASE} \
      --option executor:type="${EXECUTOR}" \
      --option executor:options:"${EXECUTOROPTS}" \
      --option skip-git-fetch=${SKIP_GIT_FETCH:-'false'} \
      --option +distributions+"${FEDORA_DIST}" \
      -d "${FEDORA_DIST}" \
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