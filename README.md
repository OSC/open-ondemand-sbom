# Open OnDemand SBOMs

CycloneDX Software Bill of Materials for [Open OnDemand](https://openondemand.org) releases.

## Layout
<major.minor>/<distro>/<arch>/ood-<version>-<distro>-<arch>.cdx.json

## Coverage

**4.2.2** — initial publication, `x86_64` across all supported distros:
`amzn2023`, `el8`, `el9`, `el10`, `bookworm`, `noble`, `resolute`, `trixie`.

`aarch64` and `ppc64le` coverage for RHEL-family distros is in progress and
will land in a follow-up commit. See `scripts/scan-all.sh` for the
reproducible build pipeline.

## Verifying

```bash
cd 4.2
sha256sum -c checksums.txt
```

## Regenerating

Requires `Docker`, `syft` (>=1.40), and access to OOD staging packages.

```bash
./scripts/scan-all.sh 4.2.2
```