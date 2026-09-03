#!/usr/bin/env bash
# Regenerate checksums.txt for a <major.minor> SBOM tree and (optionally)
# sign it. scan-all.sh calls this itself for full local runs; CI's publish
# job also calls it directly after collecting every matrix job's artifact
# into place, since each matrix job only builds one distro/arch at a time.
#
# Usage: ./build-checksums.sh <major.minor>
# Example: ./build-checksums.sh 4.2
#
# Env vars: USE_COSIGN, COSIGN_MODE, COSIGN_KEY — same meaning as scan-all.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=./sign-blob.sh
source "$SCRIPT_DIR/sign-blob.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <major.minor>" >&2
  exit 1
fi

MAJOR_MINOR="$1"
SBOM_ROOT="$REPO_ROOT/$MAJOR_MINOR"
USE_COSIGN="${USE_COSIGN:-0}"

if [ ! -d "$SBOM_ROOT" ]; then
  echo "ERROR: no such directory $SBOM_ROOT" >&2
  exit 1
fi

cd "$SBOM_ROOT"
find . -name 'ood-*.cdx.json' -print0 | sort -z | xargs -0 sha256sum > checksums.txt
echo "Wrote $SBOM_ROOT/checksums.txt ($(wc -l < checksums.txt) entries)"

if [ "$USE_COSIGN" = "1" ]; then
  sign_blob "$SBOM_ROOT/checksums.txt"
  echo "✅ signed checksums.txt"
fi
