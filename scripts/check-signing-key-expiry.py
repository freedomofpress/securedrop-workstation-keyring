#!/usr/bin/env python3
import subprocess
import datetime
import sys
import re

SIGNING_KEY_PATH = "files/securedrop-release-signing-pubkey-2021.asc"
SIGNING_KEY_FPR = "2359E6538C0613E652955E6C188EDD3B7B22E6A3"
SIGNING_KEY_UID = "SecureDrop Release Signing Key <securedrop-release-key-2021@freedom.press>"
EXPECTED_EXPIRY_YEAR = 2027

MIN_SQ_CLI_VERSION = "1.2.0"

# Check signing key metadata and ensure that there is one key,
# our key, with the right user and expiry
signing_key_metadata = subprocess.check_output(
    ["sq", "--cli-version", MIN_SQ_CLI_VERSION, "inspect", SIGNING_KEY_PATH]
).decode()

fpr = re.search(r"Fingerprint:\s*([\w ]+)", signing_key_metadata)
uid = re.search(r"UserID:\s*(.+)", signing_key_metadata)
expiry = re.search(r"Expiration time:\s*([0-9\-: UTC]+)", signing_key_metadata)

if not all((fpr, uid, expiry)):
    sys.exit(f"Couldn't parse {SIGNING_KEY_PATH}")

fpr = fpr.group(1).replace(" ", "")
if fpr != SIGNING_KEY_FPR:
    sys.exit(f"Fingerprint mismatch: {fpr} != {SIGNING_KEY_FPR}")

if len(re.findall(r"UserID:", signing_key_metadata)) != 1:
    sys.exit("More than one User ID found")

if uid.group(1).strip() != SIGNING_KEY_UID:
    sys.exit(f"User ID mismatch: {uid.group(1)} != {SIGNING_KEY_UID}")

exp = datetime.datetime.strptime(expiry.group(1).strip(), "%Y-%m-%d %H:%M:%S UTC")
if exp.year != EXPECTED_EXPIRY_YEAR:
    sys.exit(f"Expiry year mismatch: {exp.year} != {EXPECTED_EXPIRY_YEAR}")

if exp <= datetime.datetime.utcnow() + datetime.timedelta(days=180):
    sys.exit(f"Expiry too soon: {exp.date()}")

print("All signing key checks passed.")
