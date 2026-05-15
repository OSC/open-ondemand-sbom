#!/usr/bin/env bash
# Build OOD scan containers for each distro and produce SBOMs
# Output layout: ${REPO_ROOT}/<major.minor>/<distro>/<arch>/ood-<version>-<distro>-<arch>.cdx.json
# Usage: ./scan-all.sh [ood_version]
# Example: ./scan-all.sh 4.2.2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKERFILE_DIR="$REPO_ROOT/dockerfiles"
OOD_VERSION="${1:-4.2.2}"
MAJOR_MINOR="${OOD_VERSION%.*}"
ARCH="x86_64"
SBOM_ROOT="$REPO_ROOT/$MAJOR_MINOR"

DISTROS=(
  amzn2023
  el8
  el9
  el10
  noble
  resolute
  bookworm
  trixie
)

if ! command -v syft &>/dev/null; then
  echo "ERROR: syft not found. Run scripts/install-syft.sh first."
  exit 1
fi

for DISTRO in "${DISTROS[@]}"; do
  IMAGE_TAG="ood-sbom-scan:${OOD_VERSION}-${DISTRO}"
  DOCKERFILE="$DOCKERFILE_DIR/Dockerfile.${DISTRO}"
  OUTDIR="$SBOM_ROOT/${DISTRO}/${ARCH}"
  SBOM="${OUTDIR}/ood-${OOD_VERSION}-${DISTRO}-${ARCH}.cdx.json"

  if [ ! -f "$DOCKERFILE" ]; then
    echo "WARNING: No Dockerfile for $DISTRO at $DOCKERFILE — skipping"
    continue
  fi

  mkdir -p "$OUTDIR"

  echo ""
  echo "=========================================="
  echo "  $DISTRO/$ARCH  ($OOD_VERSION)"
  echo "=========================================="

  echo ">>> building $IMAGE_TAG"
  if ! docker build --no-cache -t "$IMAGE_TAG" -f "$DOCKERFILE" "$DOCKERFILE_DIR"; then
    echo "ERROR: Docker build failed for $DISTRO — skipping scan"
    continue
  fi

  echo ">>> scanning $IMAGE_TAG with syft"
  syft "$IMAGE_TAG" -o cyclonedx-json="$SBOM"

  if [ "$USE_COSIGN" = "1" ]; then
    cosign sign-blob --yes \
      --key "$COSIGN_KEY" \
      --output-signature   "${SBOM}.sig" \
      --output-certificate "${SBOM}.pem" \
      "$SBOM"
    echo ">>> signed $SBOM"
  fi

  # free disk between builds — these images are 500MB-1GB each
  docker rmi "$IMAGE_TAG" --force &>/dev/null || true
  echo "✅ $SBOM"
done

echo ""
echo "=========================================="
echo "  Manifest"
echo "=========================================="
cd "$SBOM_ROOT"
find . -name 'ood-*.cdx.json' -print0 \
  | xargs -0 sha256sum > checksums.txt

if [ "${USE_COSIGN:-0}" = "1" ]; then
  cosign sign-blob --yes \
    --key "$COSIGN_KEY" \
    --output-signature   checksums.txt.sig \
    --output-certificate checksums.txt.pem \
    checksums.txt
  echo "✅ signed checksums.txt"
fi

echo ""
echo "All done. Output tree under $SBOM_ROOT:"
find "$SBOM_ROOT" -type f | sort
