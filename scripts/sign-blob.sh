#!/usr/bin/env bash
# Shared helper for signing a single file with cosign. Meant to be sourced
# (not executed directly) by scan-all.sh and build-checksums.sh.
#
# Env vars:
#   COSIGN_MODE   "keyless" (default) — Fulcio/OIDC signing. Used in CI:
#                 cosign automatically picks up the GitHub Actions OIDC
#                 token when the job has `permissions: id-token: write`.
#                 "key" — sign with a local private key instead. Only
#                 useful for manual/local runs; requires COSIGN_KEY.
#   COSIGN_KEY    path to a cosign private key — only read when
#                 COSIGN_MODE=key.
#
# Writes "<target>.sig" and "<target>.pem" next to the signed file.

sign_blob() {
  local target="$1"
  local mode="${COSIGN_MODE:-keyless}"

  if ! command -v cosign &>/dev/null; then
    echo "ERROR: cosign not found. Install it before signing (sigstore/cosign-installer in CI, or your package manager locally)." >&2
    return 1
  fi

  if [ "$mode" = "key" ]; then
    if [ -z "${COSIGN_KEY:-}" ]; then
      echo "ERROR: COSIGN_MODE=key requires COSIGN_KEY to point at a private key." >&2
      return 1
    fi
    cosign sign-blob --yes \
      --key "$COSIGN_KEY" \
      --output-signature   "${target}.sig" \
      --output-certificate "${target}.pem" \
      "$target"
  elif [ "$mode" = "keyless" ]; then
    cosign sign-blob --yes \
      --output-signature   "${target}.sig" \
      --output-certificate "${target}.pem" \
      "$target"
  else
    echo "ERROR: unknown COSIGN_MODE '$mode' (expected 'keyless' or 'key')" >&2
    return 1
  fi
}
