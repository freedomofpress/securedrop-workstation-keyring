Name:       securedrop-workstation-keyring
Version:    0.1.0
Release:    1%{?dist}
Summary:    SecureDrop Workstation Keyring (TESTING)

# For reproducible builds:
#
#   * Ensure that SOURCE_DATE_EPOCH env is honored and inherited from the
#     last changelog entry, and enforced for package content mtimes
%define source_date_epoch_from_changelog 1
%define use_source_date_epoch_as_buildtime 1
%define clamp_mtime_to_source_date_epoch 1
#   * By default, changelog entries for the last two years of the current time
#     (_not_ SOURCE_DATE_EPOCH) are included, everything else is discarded.
#     For easy reproducibility we'll keep everything
%define _changelog_trimtime 0
%define _changelog_trimage 0
#   * _buildhost varies based on environment, we build with containers but
#     ensure this is the same regardless
%global _buildhost %{name}
#   * optflags is for multi-arch support: otherwise rpmbuild sets 'OPTFLAGS: -O2 -g -march=i386 -mtune=i686'
%global optflags -O2 -g
# To ensure forward-compatibility of RPMs regardless of updates to the system
# Python, we disable the creation of bytecode at build time via the build
# root policy.
%undefine py_auto_byte_compile

License:    AGPLv3
URL:        https://github.com/freedomofpress/securedrop-workstation-keyring

BuildArch:  noarch

%package staging
Summary:    SecureDrop Workstation Keyring (STAGING)

%package dev
Summary:    SecureDrop Workstation Keyring (NIGHTLY)

%description

%description staging
This package contains the SecureDrop Test public key and .repo file used to bootstrap a staging version (yum-test.securedrop.org) of the securedrop-workstation-dom0-config RPM.

%description dev
This package contains the SecureDrop Test public key and .repo file
used to bootstrap a dev version (yum-test.securedrop.org nightly builds)
of the securedrop-workstation-dom0-config RPM.

%prep
# No prep necessary

%build
# No building necessary

%install
install -m 755 -d %{buildroot}/etc/yum.repos.d
install -m 755 -d %{buildroot}/etc/pki/rpm-gpg
install -m 644  %{_projdir}/test_files/*.repo %{buildroot}/etc/yum.repos.d/
install -m 644  %{_projdir}/test_files/securedrop-test-key.asc %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation-test

%files staging
/etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation-test
/etc/yum.repos.d/securedrop-workstation-dom0-staging.repo

%files dev
/etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation-test
/etc/yum.repos.d/securedrop-workstation-dom0-dev.repo

%postun
# Uninstall test key
if [ $1 -eq 0 ] ; then
    systemd-run  --on-active=15s rpm -e gpg-pubkey-3fab65ab-660f2beb ||:
fi

%posttrans
# For versions of rpm >= 4.2.0 and rpm-sequoia >= 1.7.0, importing
# an updated key (same fingerprint, different subkeys) will successfully
# update the key, and this can be simplified to a single rpm --import
# command. But until that lands in dom0, ship this logic (in case of unexpected
# upgrade).
#
# New install
if [ $1 -eq 1 ] ; then
    systemd-run --on-active=15s rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation-test ||:
fi
# Upgrade. Uninstall old key then install new key.
if [ $1 -gt 1 ] ; then
    # Remove SecureDrop Release Signing Key. In rpm database, the
    # pubkey name format is `gpg-pubkey-$VERSION-$CREATION_SEC_SINCE_UNIX_EPOCH`,
    # where $VERSION is the last 8 characters of the GPG key's fingerprint, and
    # $CREATIONDATE is the key creation date, expressed as
    # `date -d "1970-1-1 + $((0x$CREATION_UNIX_EPOCH)) sec"`
    systemd-run --on-active=15s sh -c 'rpm -e gpg-pubkey-3fab65ab-660f2beb; rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation-test' ||:
fi

%changelog
* Mon Jun 16 2025 13:48:00 SecureDrop Team <securedrop@freedom.press> - 0.2.0
- Initial test keyring package
