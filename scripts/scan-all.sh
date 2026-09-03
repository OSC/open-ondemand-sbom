#!/usr/bin/env bash
# Build OOD scan containers for each distro and produce SBOMs
# Output layout: ${REPO_ROOT}/<major.minor>/<distro>/<arch>/ood-<version>-<distro>-<arch>.cdx.json
#
# Usage: ./scan-all.sh <ood_version> [distro]
# Example: ./scan-all.sh 4.2.3            # all distros
#          ./scan-all.sh 4.2.3 el9        # just el9 — used by the CI matrix,
#                                           one job per distro/arch
#
# Env vars:
#   ARCH          arch label used in output paths/filenames. Set this to
#                 match the arch you're actually building on — it does not
#                 change what gets built, it only affects where results
#                 land. CI sets it per matrix leg. Default: x86_64
#   USE_COSIGN    1 to sign SBOMs (and, on a full run, checksums.txt) after
#                 generation. Default: 0
#   COSIGN_MODE   "keyless" (Fulcio/OIDC — used in CI) or "key" (local,
#                 needs COSIGN_KEY). Default: keyless
#   COSIGN_KEY    path to a cosign private key — only read when
#                 COSIGN_MODE=key
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKERFILE_DIR="$REPO_ROOT/dockerfiles"
# shellcheck source=./sign-blob.sh
source "$SCRIPT_DIR/sign-blob.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ood_version> [distro]" >&2
  exit 1
fi

OOD_VERSION="$1"
DISTRO_FILTER="${2:-}"

if ! [[ "$OOD_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: '$OOD_VERSION' doesn't look like a semver OOD version (expected e.g. 4.2.3)" >&2
  exit 1
fi

MAJOR_MINOR="${OOD_VERSION%.*}"
ARCH="${ARCH:-x86_64}"
SBOM_ROOT="$REPO_ROOT/$MAJOR_MINOR"
USE_COSIGN="${USE_COSIGN:-0}"

ALL_DISTROS=(
  amzn2023
  el8
  el9
  el10
  noble
  resolute
  bookworm
  trixie
)

if [ -n "$DISTRO_FILTER" ]; then
  DISTROS=("$DISTRO_FILTER")
else
  DISTROS=("${ALL_DISTROS[@]}")
fi

if ! command -v syft &>/dev/null; then
  echo "ERROR: syft not found. Run scripts/install-syft.sh first."
  exit 1
fi

for DISTRO in "${DISTROS[@]}"; do
  IMAGE_TAG="ood-sbom-scan:${OOD_VERSION}-${DISTRO}-${ARCH}"
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
  if ! docker build --no-cache \
      --build-arg "OOD_VERSION=${OOD_VERSION}" \
      --build-arg "OOD_MAJOR_MINOR=${MAJOR_MINOR}" \
      -t "$IMAGE_TAG" -f "$DOCKERFILE" "$DOCKERFILE_DIR"; then
    echo "ERROR: Docker build failed for $DISTRO — skipping scan"
    continue
  fi

  echo ">>> scanning $IMAGE_TAG with syft"
  syft "$IMAGE_TAG" -o cyclonedx-json="$SBOM"

  if [ "$USE_COSIGN" = "1" ]; then
    sign_blob "$SBOM"
    echo ">>> signed $SBOM"
  fi

  # free disk between builds — these images are 500MB-1GB each
  docker rmi "$IMAGE_TAG" --force &>/dev/null || true
  echo "✅ $SBOM"
done

# Only rebuild the aggregate manifest on a full (all-distro) run — a
# single-distro CI leg doesn't have the full picture. CI's publish job
# calls build-checksums.sh itself once every leg's artifact is collected.
if [ -z "$DISTRO_FILTER" ]; then
  echo ""
  echo "=========================================="
  echo "  Manifest"
  echo "=========================================="
  "$SCRIPT_DIR/build-checksums.sh" "$MAJOR_MINOR"
fi

echo ""
echo "All done. Output tree under $SBOM_ROOT:"
find "$SBOM_ROOT" -type f | sort
