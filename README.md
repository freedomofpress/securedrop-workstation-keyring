# SecureDrop Worskatation Keyring (RPM)

This repository contains the material needed to bootstrap a SecureDrop
Workstation installation - a .repo file and the SecureDrop Release Signing
Key (in `files`) and an rpm .spec file (in `rpm_spec`), which can be used with qubes-builderv2. A `.qubesbuilder` file is provided.

This repository will be submitted for inclusion in Qubes Contrib.

## Developer setup instructions
For developer convenience, this repository also includes make targets that bootstrap the qubes-builderv2 repo and allow developers to build and test packages signed by SecureDrop maintainers (i.e. dev and staging packages), as well as a build script.
These files (Makefile, `sd-qubes-builder` directory, and `scripts` directory) are not required for production package building via Qubes Contrib. OS-specific setup instructions are below.

### Qubes
On Qubes systems, clone the [qubes-builderv2](https://github.com/QubesOS/qubes-builderv2) repo in a sibling directory to this one and configure its dependencies.
Your disposable build VM should be Fedora-based and should be called `qubes-builder-dvm`.

If you are using split-gpg, ensure that you have imported the [Qubes Developer Keys](https://keys.qubes-os.org/keys/qubes-developers-keys.asc) and the [SecureDrop maintainer keys](sd-qubes-builder) into your vault vm. Note: if using split-gpg, it is your responsibility to keep these keys up to date!

### Debian or Fedora
Clone this repository and ensure your system has sufficient free space. Install docker or podman.

To set up the qubes-builderv2 repository and generate the build container, follow the manual setup instructions, or run `make qubes-builder`.
If the qubes-builderv2 repository is not already installed in a sibling directory, it will be cloned.
OS-specific dependencies will be installed (on local machines, you'll be prompted for your passphrase) and the executor image will be generated, which takes some time.

### Developer build instructions
Run `make build-rpm`. On Qubes systems, `BUILD_OS=qubes` is required to use the Qubes Fedora executor.

On succesful builds, an .rpm and .buildinfo file will be written to a `build` directory in this repository.

#### Build variants
`make build-rpm`, `make build-rpm-staging`, and `make build-rpm-dev` will build respective packages using Qubes builderv2.

`make build-rpm-local` build from the local repo.

`make build-rpm BRANCH=yourbranchname` also allows you to build from any branch.

`make build-rpm QUBES_RELEASE=4.3` allows you to build to target another Qubes version

#### Troubleshooting failed builds
When a build fails, you will generally see a traceback printed to the console that ends with

```
qubesbuilder.executors.ExecutorError: Cannot connect to container client.
```

This is a generic message that indicates a problem during one of the build steps. Scroll up
and inspect the lines before the traceback begins for more helpful debugging info.

```
[inspect here]
10:22:04 [qb] An error occurred: Cannot connect to container client.
10:22:04 [qb] 
Traceback (most recent call last):
[...]
```
##### Dirty `artifacts` directory
qubes-builderv2 clones a copy of the repository it's trying to build in
`qubes-builderv2/artifacts/sources/`, and does not take kindly to force-pushes or other changes in git history.
The make targets in this repository force a fresh clone of the repo on each new build, but if you are building manually with your own qubes-builderv2 setup and run into build issues after force-pushing, remove `qubes-builderv2/artifacts/sources/securedrop-workstation-keyring` and `qubes-builderv2/artifacts/repository/*/securedrop-workstation-keyring` and retry.

## SecureDrop Release Signing Key
See https://media.securedrop.org/media/documents/securedrop-release-key-2021-2.asc for verification.
