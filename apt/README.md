# SibillaOS APT repository

Installed systems receive llmd package updates through a signed APT
repository published on GitHub Pages at
`https://engineering87.github.io/sibillaos/apt/`. The repository uses
a flat layout (Packages, Release, InRelease at the root): minimal
tooling, fully supported by apt, adequate for a handful of packages.

`build-repo.sh` builds and signs the repository from `packages/dist`;
the `publish-apt` workflow runs it on every push (signing with a
throwaway key on branches, verifying the result with apt itself
against a local source) and deploys to Pages on release tags, signed
with the project key.

Once `sibillaos-archive-key.asc` (the project public key) is committed
in this directory, `packages/build-debs.sh` embeds the keyring and the
apt sources entry into the llmd-hw package, so freshly installed
systems are preconfigured.

## One-time maintainer setup

1. Generate the signing key (no passphrase: it is used by CI):

   ```console
   $ gpg --batch --quick-generate-key "SibillaOS APT <apt@sibillaos>" ed25519 sign never
   $ gpg --list-secret-keys
   ```

2. Commit the public half into this directory:

   ```console
   $ gpg --armor --export KEYID > apt/sibillaos-archive-key.asc
   ```

3. Store the private half as the repository secret
   `SIBILLA_GPG_PRIVATE_KEY` (Settings, Secrets and variables,
   Actions):

   ```console
   $ gpg --armor --export-secret-keys KEYID
   ```

4. Enable Pages with source "GitHub Actions" (Settings, Pages).

Tag builds fail loudly if the secret is missing, so a release can
never ship a repository signed by a throwaway key.

## Manual client setup

Preconfigured on SibillaOS installs. On any other Debian-based system:

```console
$ curl -fsSL https://engineering87.github.io/sibillaos/apt/sibillaos-archive-key.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/sibillaos-archive-keyring.gpg
$ printf 'Types: deb\nURIs: https://engineering87.github.io/sibillaos/apt/\nSuites: ./\nSigned-By: /usr/share/keyrings/sibillaos-archive-keyring.gpg\n' \
    | sudo tee /etc/apt/sources.list.d/sibillaos.sources
$ sudo apt update
```
