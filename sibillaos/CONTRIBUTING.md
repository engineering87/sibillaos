# Contributing to SibillaOS

Thank you for taking the time to contribute. This document explains how the project is organized, how to build and test your changes, and what we expect from patches.

## Project layout

The repository builds an installable ISO by repacking the official Ubuntu 24.04 live-server image with an autoinstall seed, a set of Debian packages (the `llmd-*` components) and branding. The pieces fit together like this: `iso/build.sh` produces the ISO, `packages/` contains the components installed on the target system, `catalog/models.json` is the curated model list, and `docs/architecture.md` records every design decision with its reasoning. Read the architecture document before proposing structural changes; if a decision you want to revisit is listed there, open an issue first and argue against the recorded rationale.

## Building

You need a Linux host (or WSL) with `xorriso`, `curl`, `jq` and `dpkg-deb` available. Root is not required.

```bash
./packages/build-debs.sh    # builds the llmd-* packages into packages/dist/
./iso/build.sh              # downloads the Ubuntu base ISO, verifies it, repacks
```

The first run downloads about 3 GB for the Ubuntu base image; it is cached under `work/` afterwards. Setting `SIBILLA_TEST_MODEL` to an `hf.co/...` model id produces a CI-style unattended image; leaving it unset produces a release-style image with interactive installer screens.

## Testing

Continuous integration runs four jobs on every push and pull request: lint (shellcheck and catalog validation), build, boot smoke tests under both BIOS and UEFI, and a full install test that boots the ISO in QEMU, installs to a virtual disk, reboots, downloads a model and requires a real chat completion through the gateway. A change is not done until all four are green.

You can reproduce the boot test locally:

```bash
qemu-system-x86_64 -m 2048 -enable-kvm -cdrom out/sibillaos-*.iso -boot d
```

Shell scripts must pass `shellcheck` with no findings. Run it locally before pushing; the lint job runs it on every script in the repository.

## Submitting changes

Work on a branch and open a pull request against `main`. Commit messages follow the Conventional Commits format (`feat:`, `fix:`, `docs:`, `ci:` and so on) with a body that explains the reasoning when the change is not obvious. Keep pull requests focused on a single concern; unrelated cleanups belong in their own PR.

A few practical rules that reflect lessons this project has already paid for: never hand-write values that can be computed (hashes, checksums, version strings); pin versions of anything downloaded at install time and let the CI install test validate the bump; when you touch the boot or install path, expect to iterate against the CI debug artifacts (`boot-debug`, `install-debug`) rather than guessing.

## Model catalog

Additions to `catalog/models.json` must meet all of these criteria: a permissive license (Apache-2.0, MIT or equivalent), a non-gated Hugging Face repository, single-file GGUF quantizations for Ollama entries, and a repo id you have verified to exist. State in the PR how you verified each point. Where possible, record the per-quant sha256 digests (tools/update-digests.sh fetches them from the Hugging Face API). The catalog is a signed list: after any change a maintainer re-signs it (gpg --armor --detach-sign -o catalog/models.json.asc catalog/models.json), and CI rejects a catalog that does not verify once the signature exists. Models under community licenses (Llama, Gemma and similar) are not accepted in the default catalog regardless of quality, because the project does not redistribute or endorse terms the user has not accepted.

## Reporting issues

For build or boot problems, attach the relevant CI artifact (`install-debug` or `boot-debug`) or the serial log from your QEMU run, and state the commit id of the ISO. For issues on installed systems, include the output of `sibilla-model status` and `journalctl -u ollama -n 50` (or `-u vllm`).

Security issues should not be filed as public issues. Report them privately through GitHub security advisories.

## License

By contributing you agree that your contributions are licensed under the Apache License 2.0, the same license as the project. Do not submit code you do not have the right to license this way.
