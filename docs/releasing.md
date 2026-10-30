# Releasing SibillaOS

The release is not done at the tag. This is the whole procedure, in
order, because the post-tag half is the half that gets forgotten.

## Before the PR

1. The cycle's roadmap section flips to `(released)` with a one-line
   summary and a link to `docs/releases/vX.Y.0.md`, which exists and
   follows the structure of the previous notes. A stub section for the
   next cycle carries everything that survives.
2. The catalog, if it changed this cycle, verifies in the clone:
   `gpg --verify catalog/models.json.asc catalog/models.json` says
   Good with the date of the cycle's re-sign, and the digest count is
   what the cycle left (`jq '[.models[].digests // {} | length] | add'`).

## The PR and the tag

3. Squash PR from `release/X.Y` to `main`, title
   `release: SibillaOS X.Y.0 - <the cycle's name>`. Merge on green.
4. `git checkout main && git pull && git tag vX.Y.0 && git push origin vX.Y.0`.
5. Wait for the TAG run to go fully green. Tag runs carry the real
   version into the debs and the demo; branch runs carry a fallback
   version, which is why nothing below may use a branch-run artifact.

## After the tag - the forgettable half

6. GitHub Release: draft on tag vX.Y.0, body = the full content of
   `docs/releases/vX.Y.0.md`, attach the tag run's artifacts:
   SHA256SUMS, SHA256SUMS-cloud-amd64, SHA256SUMS-cloud-arm64, both
   SBOMs, installed-packages.tsv, the ISO `.part` files and the cloud
   qcow2 parts. The previous release shows the expected set (14 assets).
7. The demo: download the TAG run's `terminal-demo` artifact, then
   verify before swapping - `grep -c "X.Y.0" demo.svg` above zero,
   `grep -c "0.2.0" demo.svg` exactly zero (0.2.0 is the dev fallback
   version; seeing it means a branch-run artifact) - and commit it as
   `branding/demo-quickstart.svg` directly on main.
8. Confirm the apt repository answers with the new version:
   the upgrade-test job on the next push proves it end to end, and
   `https://engineering87.github.io/sibillaos/apt/InRelease` answering
   is the quick manual check.
9. Only now branch `release/X.Y+1` from the updated main. A branch cut
   before the merge is missing the whole previous cycle and must be
   deleted and recut, not rebased by hand.

## Announcing

10. The distribution pack for the release references files on main:
    publish only after the tag, and only when there is time to answer
    comments in the first hours.
