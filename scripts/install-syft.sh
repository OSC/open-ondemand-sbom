#!/usr/bin/env bash
# Installs syft (https://github.com/anchore/syft) via its official install
# script.
#
# Usage: ./install-syft.sh [install_dir]
#   install_dir   defaults to /usr/local/bin
#
# Env vars:
#   SYFT_VERSION  pin a specific release, e.g. "v1.48.0". Defaults to
#                 latest. CI pins this (see .github/workflows) so builds
#                 stay reproducible between runs — bump it there when a
#                 new syft release is worth picking up.
set -euo pipefail

DEST="${1:-/usr/local/bin}"

if [ -n "${SYFT_VERSION:-}" ]; then
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sh -s -- -b "$DEST" "$SYFT_VERSION"
else
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sh -s -- -b "$DEST"
fi

syft version
