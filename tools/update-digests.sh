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

tmp=$(mktemp)
cp "$CATALOG" "$tmp"

while IFS= read -r id; do
  repo="${id#hf.co/}"
  echo "fetching digests for $repo" >&2
  tree=$(curl -fsSL "https://huggingface.co/api/models/$repo/tree/main") || {
    echo "  fetch failed, skipping" >&2
    continue
  }
  # single-file GGUF quants only: name pattern <anything>-<QUANT>.gguf
  digests=$(echo "$tree" | jq '[ .[]
      | select(.path | test("\\.gguf$"))
      | select(.lfs.oid != null)
      | {key: (.path | sub("\\.gguf$"; "") | sub("^.*-"; "")),
         value: ("sha256:" + .lfs.oid)} ]
    | from_entries')
  jq --arg id "$id" --argjson d "$digests" \
    '(.models[] | select(.id == $id)) .digests = $d' "$tmp" > "$tmp.new"
  mv "$tmp.new" "$tmp"
done < <(jq -r '.models[] | select(.engines[]? == "ollama") | select(.id | startswith("hf.co/")) | .id' "$CATALOG")

jq --arg d "$(date +%Y-%m-%d)" '.updated = $d' "$tmp" > "$CATALOG"
rm -f "$tmp"
echo "catalog updated: review the diff, then re-sign it" >&2
