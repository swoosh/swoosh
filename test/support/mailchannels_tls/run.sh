#!/usr/bin/env bash
# Setup dependencies with network access, then run only local TLS fixtures without it.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
cache_dir=${SWOOSH_MAILCHANNELS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/swoosh-mailchannels}
image=elixir:1.18.4-otp-27@sha256:a7b2c4772e05616cf0a3323758ba5abc3288af452a33d1263705840a52154e85
mkdir -p "$cache_dir"
common=(--rm -e MIX_ENV=test -e MIX_HOME=/cache/mix -e HEX_HOME=/cache/hex
  --mount "type=bind,src=$cache_dir,dst=/cache"
  --mount "type=bind,src=$repo_root,dst=/workspace" -w /workspace)
docker run "${common[@]}" "$image" sh -c 'mix local.hex --force && mix local.rebar --force && mix deps.get'
docker run "${common[@]}" --network none \
  --add-host api.mailchannels.net:127.0.0.1 --add-host redirect.example.test:127.0.0.1 \
  -e MAILCHANNELS_LOCAL_TLS_FIXTURE=1 "$image" \
  sh -c 'bash test/support/mailchannels_tls/certificates.sh && mix test test/integration/adapters/mailchannels_tls_test.exs --include integration --seed 0'
