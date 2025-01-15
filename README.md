# SecureDrop Worskatation Keyring (RPM)

This package contains the SecureDrop Release Public Key and a yum .repo file that points
to the SecureDrop Workstation production repo. It will be used for ease of bootstrapping
SecureDrop Workstation on QubesOS.

**At the moment this repo is experimental and should not be part of a production SDW installation.**

## SecureDrop Release Key
See https://media.securedrop.org/media/documents/securedrop-release-key-2021-2.asc
for verification.

## Package updates
Any updates to the SecureDrop Release Signing Key will require an updated version of
this package to be released. Submit a PR to this repository that contains the updated
SecureDrop Release Public Key and updates the rpm key ID, which will change any time the
key or its subkeys are changed. (The rpm key ID is ``gpg-pubkey-xxxxxxxx-yyyyyyyy``, used
in the ``.spec`` file and in ``tests``, and the new rpm key ID can be found by importing
the updated pubkey into rpmdb and querying for it via
``rpm -qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep 'SecureDrop Release Signing Key'``).

Then follow [the RPM release documentation](https://developers.securedrop.org/en/latest/workstation_release_management.html#release-an-rpm-package) to release an updated keyring
package.

Refer to the internal SecureDrop developer documentation for information on release key
update procedures.
