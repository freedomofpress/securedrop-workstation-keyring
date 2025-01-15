#!/usr/bin/env python3
import subprocess
from pathlib import Path

#
# Basic acceptance testing for keyring package (Fedora-based)
#

# Update this pubkey ID if the key or its subkeys are updated; see README
GPG_PUBKEY_ID = "gpg-pubkey-7b22e6a3-609966ad"
RPM_QUERY_PACKAGE = ["rpm", "-q"]
RPM_GPG_QUERY_SD_RELEASE_KEY = ["rpm", "-q", GPG_PUBKEY_ID]
REPOFILE_PATH = "/etc/yum.repos.d/securedrop-workstation-dom0.repo"
KEYFILE_PATH = "/etc/pki/rpm-gpg/RPM-GPG-KEY-securedrop-workstation"

def is_fedora():
    with open("/etc/os-release") as f:
        for line in f:
            if line.startswith("NAME"):
                return "Fedora" in line.split("=")[-1]
    return False

def is_package_installed(package_name: str):
    query = RPM_QUERY_PACKAGE + [package_name]

    # raise if package is not installed
    subprocess.check_call(args=query, stdout=subprocess.DEVNULL)

def is_repo_file_installed():
    repofile = Path(REPOFILE_PATH)
    return repofile.exists()

def is_key_in_etc_pki():
    keyfile = Path(KEYFILE_PATH)
    return keyfile.exists()

def is_key_in_rpmdb():
    subprocess.check_call(RPM_GPG_QUERY_SD_RELEASE_KEY,
                              stdout=subprocess.DEVNULL)

if __name__ == "__main__":
    assert is_fedora()
    assert is_package_installed("systemd")
    assert is_package_installed("securedrop-workstation-keyring")
    assert is_repo_file_installed()
    assert is_key_in_etc_pki()
    assert is_key_in_rpmdb()
