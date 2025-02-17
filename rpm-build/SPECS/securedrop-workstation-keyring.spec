Name:       securedrop-workstation-keyring
Version:    0.1.0
Release:    1%{?dist}
Summary:	SecureDrop Workstation Keyring

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

License:	AGPLv3
URL:		https://github.com/freedomofpress/securedrop-workstation-keyring
Source:		%{url}/archive/refs/tags/%{version}.tar.gz#/%{name}-%{version}.tar.gz
# See: https://docs.fedoraproject.org/en-US/packaging-guidelines/SourceURL/#_troublesome_urls

BuildArch:		noarch
#BuildRequires:	systemd-rpm-macros
BuildRequires: make


%description
This package contains the SecureDrop Release public key and yum .repo file
used to bootstrap installation of SecureDrop Workstation.

%prep
%setup -q -n files

%build
# No building necessary

%install
install -m 755 -d %{buildroot}/etc/yum.repos.d
install -m 755 -d %{buildroot}/etc/pki/rpm-gpg
install -m 644 %{_builddir}/files/securedrop-workstation-dom0.repo %{buildroot}/etc/yum.repos.d/
install -m 644 %{_builddir}/files/securedrop-release-signing-pubkey-2021.asc %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation

%files
/etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation
/etc/yum.repos.d/securedrop-workstation-dom0.repo

%postun
# Uninstall
if [ $1 -eq 0 ] ; then
    systemd-run  --on-active=15s rpm -e gpg-pubkey-7b22e6a3-609966ad ||:
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
    systemd-run --on-active=15s rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation ||:
fi
# Upgrade. Uninstall old key then install new key.
if [ $1 -gt 1 ] ; then
    # Remove SecureDrop Release Signing Key. In rpm database, the
    # pubkey name format is `gpg-pubkey-$VERSION-$CREATION_SEC_SINCE_UNIX_EPOCH`,
    # where $VERSION is the last 8 characters of the GPG key's fingerprint, and
    # $CREATIONDATE is the key creation date, expressed as
    # `date -d "1970-1-1 + $((0x$CREATION_UNIX_EPOCH)) sec"`
    systemd-run --on-active=15s sh -c 'rpm -e gpg-pubkey-7b22e6a3-609966ad; rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation' ||:
fi

%changelog
* Mon Dec 2 2024 13:12:00 SecureDrop Team <securedrop@freedom.press> - 0.1.0
- Initial keyring/bootstrap package
