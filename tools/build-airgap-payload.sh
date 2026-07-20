#!/usr/bin/env bash
# build-airgap-payload.sh: prepare the companion payload for air-gapped
# SibillaOS machines, on a machine that does have network.
#
#   ./tools/build-airgap-payload.sh --out DIR --model ID:QUANT [--model ...]
#
# For every requested model the script looks the quant digest up in the
# signed catalog, resolves the file on Hugging Face BY THAT DIGEST (the
# LFS oid), downloads it and verifies the sha256 before it enters the
# payload: what goes on the stick is the reviewed artifact, provably.
# A minimal profile declaring the first model is generated unless
# --profile provides one. Copy the output onto a volume labeled
# SIBILLA-AIRGAP and plug it in before first boot; llmd-firstboot picks
# it up (docs/airgap.md).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$DIR/../catalog/models.json"
KEY_FILE="$DIR/../apt/sibillaos-archive-key.asc"

OUT=""
PROFILE_IN=""
MODELS=()

usage() {
  cat <<USAGE
usage: build-airgap-payload.sh --out DIR --model ID:QUANT [--model ID:QUANT ...]
                               [--profile FILE] [--catalog FILE]

Only catalog entries with a recorded digest for the requested quant can
enter a payload. Currently eligible:
USAGE
  jq -r '.models[] | select(.digests) | .id as $id | .digests | keys[] | "  " + $id + ":" + .' \
    "$CATALOG" 2>/dev/null || true
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)     OUT="$2"; shift 2 ;;
    --model)   MODELS+=("$2"); shift 2 ;;
    --profile) PROFILE_IN="$2"; shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$OUT" && ${#MODELS[@]} -gt 0 ]] || usage

# catalog trust, same policy as everywhere else: a broken signature
# always aborts, unsigned transitional builds warn and continue
if [[ -f "$CATALOG.asc" && -f "$KEY_FILE" ]]; then
  kr=$(mktemp)
  gpg --batch --yes --dearmor -o "$kr" < "$KEY_FILE"
  gpgv --keyring "$kr" "$CATALOG.asc" "$CATALOG" \
    || { echo "catalog signature does not verify, refusing to build" >&2; exit 1; }
  rm -f "$kr"
else
  echo "WARNING: catalog signature not checked (key or signature not present)"
fi

mkdir -p "$OUT/models"

for spec in "${MODELS[@]}"; do
  base="${spec%%:*}"
  quant="${spec##*:}"
  [[ "$spec" == *:* && -n "$quant" ]] || { echo "no quant in '$spec' (ID:QUANT)" >&2; exit 1; }
  digest=$(jq -r --arg id "$base" --arg q "$quant" \
    '.models[] | select(.id == $id) | .digests[$q]? // empty' "$CATALOG")
  [[ -n "$digest" ]] || { echo "no digest recorded for $spec; only reviewed artifacts enter a payload" >&2; exit 1; }
  hex="${digest#sha256:}"

  # resolve the file on Hugging Face by its LFS oid: the digest is the
  # identity, the filename is just where it happens to live
  repo="${base#hf.co/}"
  [[ "$repo" != "$base" ]] || { echo "only hf.co models are supported: $spec" >&2; exit 1; }
  file=$(curl -fsSL --retry 3 "https://huggingface.co/api/models/$repo/tree/main" \
    | jq -r --arg oid "$hex" '.[] | select(.lfs.oid? == $oid) | .path' | head -1)
  [[ -n "$file" ]] || { echo "no file with digest $digest in $repo; catalog and repo disagree" >&2; exit 1; }

  dest="$OUT/models/$file"
  if [[ -f "$dest" ]] && echo "$hex  $dest" | sha256sum -c --quiet 2>/dev/null; then
    echo "already present and verified: $file"
  else
    echo "downloading $file ($spec)"
    curl -fL --retry 3 -o "$dest" "https://huggingface.co/$repo/resolve/main/$file"
    echo "$hex  $dest" | sha256sum -c --quiet \
      || { echo "downloaded file does not match the catalog digest, refusing" >&2; rm -f "$dest"; exit 1; }
    echo "verified: $file is $digest"
  fi
done

# the profile makes the payload self-sufficient: first boot serves the
# declared model instead of trying to download the hardware default
if [[ -n "$PROFILE_IN" ]]; then
  cp "$PROFILE_IN" "$OUT/profile"
else
  printf 'MODEL=%s\n' "${MODELS[0]}" > "$OUT/profile"
  echo "generated profile: MODEL=${MODELS[0]}"
fi

( cd "$OUT" && find models -type f -exec sha256sum {} \; > SHA256SUMS )
{
  echo "SibillaOS air-gapped payload, built $(date -u +%Y-%m-%d)"
  echo "models:"
  printf '  %s\n' "${MODELS[@]}"
  echo "Copy this directory onto a volume labeled SIBILLA-AIRGAP and"
  echo "attach it before the machine's first boot. See docs/airgap.md."
} > "$OUT/MANIFEST.txt"

echo "payload ready in $OUT ($(du -sh "$OUT" | cut -f1))"
