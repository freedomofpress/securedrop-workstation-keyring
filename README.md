# SecureDrop Worskatation Keyring (RPM)

This repository contains the material needed to bootstrap a SecureDrop
Workstation installation - a .repo file and the SecureDrop Release Signing
Key.

The production package will be hosted in Qubes-contrib.

**At the moment this repo is experimental and should not be part of a production SDW installation.**

## Setup instructions
Clone this repository and ensure your system has sufficient free space. On non-Qubes
systems, install Docker.

Then, either proceed to the convenience `make` targets, or clone the
[qubes-builderv2](https://github.com/QubesOS/qubes-builderv2) repo in a sibling
directory to this one.

## Build instructions
On Qubes systems, `BUILD_OS=qubes` is required to use the
Qubes Fedora executor.

`make build-rpm`, `make build-rpm-staging`, and `make build-rpm-dev` will build respective packages using Qubes builderv2. If the qubes-builderv2 repository is not installed in
a sibling directory, it will be cloned. The first time the qubes-builderv2 repo is set up, the executor image will be generated, which takes some time.

`make build-rpm BRANCH=yourbranchname` also allows you to build from any branch.

### Troubleshooting failed builds
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
#### Dirty `artifacts` directory
qubes-builderv2 clones a copy of the repository it's trying to build in
`qubes-builderv2/artifacts/sources/`, and does not take kindly to force-pushes or other
changes in git history.
The convenience targets use the provided `qb clean all` command, but in case of repeated
build failures, manually remove `qubes-builderv2/artifacts/sources/securedrop-workstation-keyring` before rebuilding (recommended when switching remotes
or branches).

## SecureDrop Release Signing Key
See https://media.securedrop.org/media/documents/securedrop-release-key-2021-2.asc for verification.
