#!/usr/bin/env bash
# Builds the SibillaOS APT repository from packages/dist into apt-site/
# and signs it with the given GPG key.
# Flat layout (Packages, Release, InRelease at the repository root):
# minimal tooling, fully supported by apt, adequate for a handful of
# packages; a pool/dists tree can replace it later without breaking
# clients if the URL keeps serving InRelease.
# Requires: apt-ftparchive (apt-utils), gpg
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBS="${SIBILLA_DEBS_DIR:-$DIR/../packages/dist}"
OUT="${SIBILLA_APT_OUT:-$(pwd)/apt-site}"
KEY_ID="${SIBILLA_GPG_KEY_ID:-}"

command -v apt-ftparchive >/dev/null 2>&1 || { echo "apt-ftparchive not found (install apt-utils)" >&2; exit 1; }
[[ -n "$KEY_ID" ]] || { echo "SIBILLA_GPG_KEY_ID not set" >&2; exit 1; }
ls "$DEBS"/*.deb >/dev/null 2>&1 || { echo "no debs in $DEBS (run packages/build-debs.sh first)" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/apt"
cp "$DEBS"/*.deb "$OUT/apt/"

(
  cd "$OUT/apt"
  apt-ftparchive packages . > Packages
  gzip -k -9 Packages
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=SibillaOS \
    -o APT::FTPArchive::Release::Label=SibillaOS \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
    -o APT::FTPArchive::Release::Description="SibillaOS llmd packages" \
    release . > Release
  gpg --batch --yes -u "$KEY_ID" --clearsign -o InRelease Release
  gpg --batch --yes -u "$KEY_ID" -abs -o Release.gpg Release
)

# the public key is published next to the repository for manual setups
gpg --batch --yes --export --armor "$KEY_ID" > "$OUT/apt/sibillaos-archive-key.asc"

cat > "$OUT/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>SibillaOS APT repository</title></head>
<body>
<h1>SibillaOS APT repository</h1>
<p>The repository lives under <a href="apt/">/apt/</a>. Installed
SibillaOS systems are preconfigured; manual setup instructions are in
the <a href="https://github.com/engineering87/sibillaos">project
repository</a>.</p>
</body>
</html>
HTML

echo "apt repository built and signed in $OUT (key $KEY_ID)"
