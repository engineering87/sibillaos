#!/usr/bin/env bash
# update-digests.sh: maintainer tool. For every ollama entry of the
# catalog hosted as hf.co/{user}/{repo}, fetch the repository tree
# from the Hugging Face API and record the sha256 (LFS oid) of each
# single-file GGUF quant into the entry's "digests" map.
# After running it, review the diff and re-sign the catalog:
#   gpg --armor --detach-sign -o catalog/models.json.asc catalog/models.json
# Requires: curl, jq
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="${1:-$DIR/../catalog/models.json}"

# fail before touching anything: a missing jq once combined with the
# final output redirection to truncate the catalog to zero bytes
for dep in jq curl; do
  command -v "$dep" >/dev/null 2>&1 \
    || { echo "$dep is required and not in PATH; nothing was touched" >&2; exit 1; }
done

tmp=$(mktemp)
cp "$CATALOG" "$tmp"

while IFS= read -r id; do
  # jq.exe on Windows emits CRLF line endings and read keeps the CR,
  # which curl then rejects as a malformed URL: strip it always
  id="${id//$'\r'/}"

  # registry-backed entries (large tier): the digest is the sha256 of
  # the model layer in the ollama.com registry manifest, which is also
  # the blob name after a pull - same verification, second source
  if [[ "$id" != hf.co/* ]]; then
    name="${id%%:*}"
    tag="${id##*:}"
    echo "fetching registry manifest for $name:$tag" >&2
    manifest=$(curl -fsSL \
      -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
      "https://registry.ollama.ai/v2/library/$name/manifests/$tag") || {
      echo "  fetch failed, skipping" >&2
      continue
    }
    digests=$(echo "$manifest" | jq --arg t "$tag" \
      '{($t): (.layers[] | select(.mediaType == "application/vnd.ollama.image.model") | .digest)}')
    jq --arg id "$id" --argjson d "$digests" \
      '(.models[] | select(.id == $id)) .digests = $d' "$tmp" > "$tmp.new"
    mv "$tmp.new" "$tmp"
    continue
  fi

  repo="${id#hf.co/}"
  echo "fetching digests for $repo" >&2
  tree=$(curl -fsSL "https://huggingface.co/api/models/$repo/tree/main") || {
    echo "  fetch failed, skipping" >&2
    continue
  }
  # single-file GGUF quants only. The quant is the token after the
  # LAST separator, which is a dash for bartowski-style names
  # (model-Q4_K_M.gguf) and a dot for nomic-style ones
  # (model-v1.5.Q8_0.gguf): accept both, or the recorded key does not
  # match what sibilla model use/pull looks up
  digests=$(echo "$tree" | jq '[ .[]
      | select(.path | test("\\.gguf$"))
      | select(.lfs.oid != null)
      | {key: (.path | sub("\\.gguf$"; "") | sub("^.*[-.]"; "")),
         value: ("sha256:" + .lfs.oid)} ]
    | from_entries')
  jq --arg id "$id" --argjson d "$digests" \
    '(.models[] | select(.id == $id)) .digests = $d' "$tmp" > "$tmp.new"
  mv "$tmp.new" "$tmp"
done < <(jq -r '.models[] | select(.engines[]? == "ollama") | select((.id | startswith("hf.co/")) or .source? == "registry") | .id' "$CATALOG")

# write-then-move: the catalog is replaced only by a complete, valid
# result, never truncated by a failing pipeline (the redirection in
# the old `jq ... > "$CATALOG"` emptied the file before jq even ran
# when jq was missing)
jq --arg d "$(date +%Y-%m-%d)" '.updated = $d' "$tmp" > "$tmp.out"
jq -e '.models | length > 0' "$tmp.out" >/dev/null \
  || { echo "refusing to write a catalog with no models" >&2; rm -f "$tmp" "$tmp.out"; exit 1; }
mv "$tmp.out" "$CATALOG"
rm -f "$tmp"
echo "catalog updated: review the diff, then re-sign it" >&2
