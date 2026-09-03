# Open OnDemand SBOMs

CycloneDX Software Bill of Materials for [Open OnDemand](https://openondemand.org) releases.

## Layout
`<major.minor>/<distro>/<arch>/ood-<version>-<distro>-<arch>.cdx.json`

## Coverage

**4.2.2** — initial publication, `x86_64` across all supported distros:
`amzn2023`, `el8`, `el9`, `el10`, `bookworm`, `noble`, `resolute`, `trixie`.

From **4.2.3** onward, `x86_64` and `aarch64` are built automatically by CI
(see below) for every supported distro. `ppc64le` isn't covered yet — there's
no GitHub-hosted runner for it; a self-hosted or IBM-managed-runner path is
being tracked separately (issue #1).

## Building via CI

Pushing a plain version tag (e.g. `4.2.3`) to this repo triggers
[`.github/workflows/build-sboms.yml`](.github/workflows/build-sboms.yml),
which builds and scans every distro on native `x86_64`/`aarch64` runners (no
QEMU), signs each SBOM and the aggregate `checksums.txt` keylessly with
cosign/Fulcio, and opens a PR with the results for review.

```bash
git tag 4.2.3
git push origin 4.2.3
```

## Verifying

```bash
cd 4.2
sha256sum -c checksums.txt
```

To verify a cosign signature (keyless, signed by the CI workflow):

```bash
cosign verify-blob --certificate <file>.pem --signature <file>.sig \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <file>
```

## Regenerating locally

Requires `Docker`, `syft` (>=1.40), and access to OOD staging packages.
The version is parameterized end-to-end — nothing is hardcoded per release.

```bash
./scripts/install-syft.sh          # if you don't already have syft
./scripts/scan-all.sh 4.2.3        # all distros, x86_64
ARCH=aarch64 ./scripts/scan-all.sh 4.2.3   # if you're on an arm64 host
```

Add `USE_COSIGN=1` to sign locally. `COSIGN_MODE` defaults to `keyless`
(Fulcio) — set `COSIGN_MODE=key COSIGN_KEY=/path/to/key` to sign with a
private key instead.
